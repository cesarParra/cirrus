import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:chalkdart/chalkstrings.dart';
import 'package:fpdart/fpdart.dart';
import 'coammands/package.dart';
import 'service_locator.dart';
import 'init_template.dart';
import 'create_scratch.dart';
import 'config.dart';
import 'version.dart';
import 'package:cli_spin/cli_spin.dart';

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
    final configFile = getIt.get<FileSystem>(param1: configFileName);

    if (configFile.exists()) {
      return Left('$configFileName already exists in the current directory');
    }

    configFile.write(configContent);
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
    await cliRunner.run(command.command);
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
    final logger = getIt.get<Logger>();
    logger.log(
      'Running flow "${name.italic}"',
      chalk: chalk.yellow.bold,
      separator: true,
    );

    for (final step in flow.steps) {
      final spinner = CliSpin(
        text: step.printable().yellow.bold,
        spinner: CliSpinners.dots,
        color: CliSpinnerColor.yellow,
      ).start();

      Either<String, String> result = (await runStep(step)).map((_) {
        spinner.stop();
        logger.success(
          'Step ${step.printable().italic} completed successfully.',
        );
        return 'Step completed';
      });

      if (result.isLeft()) {
        spinner.stop();
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
        await cliRunner.run(command);
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
