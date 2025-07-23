import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';
import 'service_locator.dart';
import 'init_template.dart';
import 'create_scratch.dart';
import 'config.dart';
import 'version.dart';

class CirrusCommandRunner extends CommandRunner<dynamic> {
  CirrusCommandRunner()
    : super(
        'cirrus',
        'A lean command-line interface tool for Salesforce development automation.',
      ) {
    argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the version number',
    );
  }

  @override
  Future<dynamic> run(Iterable<String> args) async {
    final argResults = parse(args);

    // Handle version flag before running commands
    if (argResults['version'] as bool) {
      print('cirrus version $appVersion');
      return;
    }

    return super.run(args);
  }
}

Future<void> run(
  List<String> arguments, {
  required String configFileName,
}) async {
  final runner = Either.tryCatch(
    () => CirrusCommandRunner()
      ..addCommand(InitCommand(configFileName))
      ..addCommand(RunCommand())
      ..addCommand(FlowCommand())
      ..addCommand(PackageCommand()),
    (error, _) => 'Unexpected error: $error',
  );

  final logger = getIt.get<Logger>();
  switch (runner) {
    case Right(:final value):
      try {
        final result = await value.run(arguments);

        if (result is Either<String, String>) {
          switch (result) {
            case Right(:final value):
              logger.success(value);
            case Left(:final value):
              logger.error(value);
          }
        }
      } on UsageException catch (e) {
        logger.error(e.message);
        logger.log(value.usage);
      } catch (e) {
        logger.error('$e');
      }

    case Left(:final value):
      logger.error(value);
  }
}

class InitCommand extends Command {
  final String configFileName;

  @override
  String get name => 'init';

  @override
  String get description => 'Initializes the cirrus.toml file.';

  InitCommand(this.configFileName);

  @override
  Either<String, String> run() {
    final configFile = File(configFileName);

    if (configFile.existsSync()) {
      return Left('$configFileName already exists in the current directory');
    }

    configFile.writeAsStringSync(configContent);
    return Right('$configFileName created successfully');
  }
}

class RunCommand extends Command {
  @override
  final name = 'run';

  @override
  String get description => 'Runs a standalone command';

  RunCommand() {
    // Parse the config file to pass the necessary information
    // each individual command need

    addCreateScratchSubcommand();
    addConfiguredSubcommands();
  }

  void addCreateScratchSubcommand() {
    addSubcommand(CreateScratchCommand());
  }

  void addConfiguredSubcommands() {
    final config = getIt.get<Either<String, Config>>();
    switch (config) {
      case Left():
        return;
      case Right(:final value):
        for (final namedCommand in value.commands) {
          addSubcommand(RunNamedCommand(namedCommand));
        }
    }
  }
}

// Default run commands

class CreateScratchCommand extends Command {
  @override
  final name = 'create_scratch';

  @override
  String get description => 'Creates a scratch org.';

  CreateScratchCommand() {
    argParser
      ..addOption(
        'name',
        abbr: 'n',
        mandatory: true,
        help: 'The name of the scratch org definition to create',
      )
      ..addFlag(
        'set-default',
        abbr: 'd',
        defaultsTo: true,
        negatable: true,
        help: 'Set the created scratch org as the default org.',
      );
  }

  @override
  Future<Either<String, String>> run() async {
    return await runCreateScratch(
      argResults?.option('name') ?? '',
      setDefault: argResults?.flag('set-default') ?? true,
    );
  }
}

class RunNamedCommand extends Command {
  final NamedCommand command;

  @override
  String get name => command.name;

  @override
  String get description => 'Execute the $name command.';

  RunNamedCommand(this.command);

  @override
  Future<void> run() async {
    final cliRunner = getIt.get<CliRunner>();
    await cliRunner(command.command);
  }
}

// Flows

class FlowCommand extends Command {
  final Either<String, Config> config;

  @override
  String get name => 'flow';

  @override
  String get description => 'Runs a flow defined in the config file.';

  FlowCommand() : config = getIt.get<Either<String, Config>>() {
    for (final flowCommand in parsedSubcommands) {
      addSubcommand(flowCommand);
    }
  }

  List<NamedFlowCommand> get parsedSubcommands => switch (config) {
    Left() => [],
    Right(value: final config) =>
      config.flows.map((currentFlow) => NamedFlowCommand(currentFlow)).toList(),
  };

  @override
  Either<String, String> run() {
    switch (config) {
      case Left(:final value):
        throw value;
      case _:
        if (parsedSubcommands.isEmpty) {
          return Left('No flows defined in the config file.');
        }
        return Right(
          'Available flows: ${parsedSubcommands.map((e) => e.name).join(', ')}',
        );
    }
  }
}

class NamedFlowCommand extends Command {
  final Flow flow;

  @override
  String get name => flow.name;

  @override
  String get description => flow.description ?? '';

  NamedFlowCommand(this.flow);

  @override
  Future<Either<String, String>> run() async {
    for (final step in flow.steps) {
      Either<String, String> result = (await runStep(
        step,
      )).map((_) => 'Success');
      if (result.isLeft()) {
        return result;
      }
    }

    return Right('Finished running flow $name.');
  }

  Future<Either<String, void>> runStep(FlowStep step) async {
    return switch (step) {
      CreateScratchFlowStep() => await runCreateScratch(
        step.orgName,
        setDefault: step.setDefault ?? true,
      ),
      RunCommandFlowStep() => await runCommand(step.commandName),
    };
  }

  Future<Either<String, void>> runCommand(String commandName) async {
    final config = getIt.get<Either<String, Config>>();

    switch (config) {
      case Left(:final value):
        return Left('Error parsing the cirrus.toml file: $value');
      case Right(:final value):
        return await execute(value, commandName);
    }
  }

  Future<Either<String, void>> execute(
    Config config,
    String commandName,
  ) async {
    final command = config.commands.firstWhereOrOption(
      (command) => command.name == commandName,
    );

    final cliRunner = getIt.get<CliRunner>();
    Future<Either<String, void>> runCommand(String command) async {
      try {
        await cliRunner(command);
        return Right(null);
      } catch (e) {
        return Left('$e');
      }
    }

    return switch (command) {
      None() => Left('Command $commandName not found'),
      Some(:final value) => await runCommand(value.command),
    };
  }
}

class PackageCommand extends Command {
  @override
  String get name => 'package';

  @override
  String get description => 'Releases a new package version.';

  PackageCommand() {
    argParser
      ..addOption(
        'package',
        abbr: 'p',
        mandatory: true,
        help:
            'The name of the package to release, as defined in the sfdx-project.json file.',
      )
      ..addOption(
        'version-number',
        abbr: 'n',
        help: 'The version type to increment the package to.',
        defaultsTo: 'minor',
        allowed: ['major', 'minor', 'patch'],
      )
      ..addOption(
        'name',
        abbr: 'a',
        help:
            'The name of the new version to create. If not provided, the new version number will be used.',
      )
      ..addOption(
        'code-coverage',
        abbr: 'c',
        help:
            'Calculate and store the code coverage percentage by running the packaged Apex tests included in this package version.',
      )
      ..addOption(
        'definition-file',
        abbr: 'f',
        help:
            'Path to a definition file similar to scratch org definition file that contains the list of features and org preferences that the metadata of the package version depends on.',
      )
      ..addOption(
        'installation-key',
        abbr: 'k',
        help:
            'Installation key for key-protected package. (either --installation-key or --installation-key-bypass is required)',
      )
      ..addOption(
        'target-dev-hub',
        abbr: 'v',
        help:
            'Username or alias of the Dev Hub org. Not required if the `target-dev-hub` configuration variable is already set.',
      )
      ..addOption(
        'wait',
        abbr: 'w',
        help:
            'Number of minutes to wait for the package version to be created.',
      )
      ..addFlag(
        'installation-key-bypass',
        abbr: 'x',
        negatable: false,
        help:
            'Bypass the installation key requirement. (either --installation-key or --installation-key-bypass is required)',
      )
      ..addFlag(
        'async-validation',
        negatable: false,
        help:
            'Return a new package version before completing package validations.',
      )
      ..addFlag(
        'skip-validation',
        negatable: false,
        help:
            'Skip validation during package version creation; you can’t promote unvalidated package versions.',
      )
      ..addFlag(
        'verbose',
        negatable: false,
        help: 'Display verbose command output.',
      );
  }

  @override
  Future<Either<String, String>> run() async {
    // Look for the "sfdx-project.json" file in the current directory
    final projectFile = File('sfdx-project.json');
    if (!projectFile.existsSync()) {
      return Left('sfdx-project.json file not found in the current directory.');
    }

    // Parse the project file and get the package information
    final projectContent = projectFile.readAsStringSync();
    // Parse the JSON content
    final projectData = jsonDecode(projectContent) as Map<String, dynamic>;

    // Loop through the "packageDirectories" array and find a "package" with the given name
    final packageName = argResults?['package'] as String?;
    if (packageName == null || packageName.isEmpty) {
      return Left('Please provide a package name using the --package option.');
    }

    final packageDirectories =
        projectData['packageDirectories'] as List<dynamic>?;
    if (packageDirectories == null || packageDirectories.isEmpty) {
      return Left('No package directories found in sfdx-project.json.');
    }

    final packageDirectory = packageDirectories.firstWhereOrOption(
      (dir) => (dir as Map<String, dynamic>)['package'] == packageName,
    );

    switch (packageDirectory) {
      case None():
        return Left('Package "$packageName" not found in sfdx-project.json.');
      case Some(value: final dir):
        // Increment the version based on the provided version type
        final versionType = argResults?['version-number'] as String?;
        if (versionType == null || versionType.isEmpty) {
          return Left(
            'Please provide a version type using the --version option.',
          );
        }

        // Increment the version name and the version number
        final versionName = argResults?['name'] as String?;
        final packageVersion =
            (dir as Map<String, dynamic>)['versionNumber'] as String?;

        if (packageVersion == null || packageVersion.isEmpty) {
          return Left('No versionName found for package "$packageName".');
        }

        final newVersion = incrementVersion(packageVersion, versionType);
        final newVersionName = versionName ?? newVersion;

        // Update the package directory with the new version
        (dir)['versionName'] = newVersionName;
        (dir)['versionNumber'] = newVersion;
        // Write the updated project data back to the file
        projectData['packageDirectories'] = packageDirectories;
        projectFile.writeAsStringSync(getPrettyJSONString(projectData));

        final cliRunner = getIt.get<CliRunner>();

        // Run the command to create the package version
        final command = [
          'sf',
          'package',
          'version',
          'create',
          '--package',
          packageName,
          if (argResults?['code-coverage'] == true) '--code-coverage',
          if (argResults?['definition-file'] != null) '--definition-file',
          ?argResults?['definition-file'],
          if (argResults?['installation-key'] != null) '--installation-key',
          ?argResults?['installation-key'],
          if (argResults?['installation-key-bypass'] == true)
            '--installation-key-bypass',
          if (argResults?['target-dev-hub'] != null) '--target-dev-hub',
          ?argResults?['target-dev-hub'],
          if (argResults?['wait'] != null) '--wait',
          ?argResults?['wait'],
          if (argResults?['async-validation'] == true) '--async-validation',
          if (argResults?['skip-validation'] == true) '--skip-validation',
          if (argResults?['verbose'] == true) '--verbose',
        ];

        await cliRunner(command.join(' '));

        return Right(
          'Package "$packageName" version updated to $newVersionName ($newVersion).',
        );
    }
  }

  String incrementVersion(String version, String type) {
    final parts = version.split('.');
    if (parts.length != 3 && parts.length != 4) {
      // Versions might have a trailing "build" number. This can be a number
      // or the string "NEXT".
      throw ArgumentError(
        'Invalid version format. Expected format is "major.minor.patch" or "major.minor.patch.build".',
      );
    }

    final major = int.parse(parts[0]);
    final minor = int.parse(parts[1]);
    final patch = int.parse(parts[2]);

    return switch (type) {
      'major' => '${major + 1}.0.0.NEXT',
      'minor' => '$major.${minor + 1}.0.NEXT',
      'patch' => '$major.$minor.${patch + 1}.NEXT',
      _ => throw ArgumentError('Invalid version type: $type'),
    };
  }

  String getPrettyJSONString(dynamic jsonObject) {
    final encoder = JsonEncoder.withIndent("  ");
    return encoder.convert(jsonObject);
  }
}
