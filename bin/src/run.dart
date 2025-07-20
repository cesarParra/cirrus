import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:chalkdart/chalkdart.dart';
import 'package:cli_script/cli_script.dart' as cli;
import 'package:fpdart/fpdart.dart';
import 'init_template.dart';

typedef ConfigParser = Map<String, dynamic> Function();
typedef CliRunner = Future<void> Function(String);

abstract class Logger {
  error(String errorMessage);
  log(String messageToPrint);
  success(String message);
}

class StdIOLogger implements Logger {
  const StdIOLogger();

  @override
  error(String errorMessage) {
    stderr.writeln(chalk.red(errorMessage));
    log("");
  }

  @override
  log(String messageToPrint) {
    print(messageToPrint);
  }

  @override
  success(String message) {
    print(chalk.green(message));
  }
}

Future<void> run(
  List<String> arguments,
  ConfigParser parser, {
  CliRunner cliRunner = cli.run,
  required String configFileName,
  Logger logger = const StdIOLogger(),
}) async {
  final configFile = Either.tryCatch(
    () => parser(),
    (error, _) => "Was not able to load the cirrus.toml file.\r\n$error'",
  );

  final runner = Either.tryCatch(
    () =>
        CommandRunner(
            "cirrus",
            "A lean command-line interface tool for Salesforce development automation.",
          )
          ..addCommand(InitCommand(configFileName))
          ..addCommand(RunCommand(configFile, cliRunner: cliRunner)),
    (error, _) => 'Unexpected error: $error',
  );

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

  RunCommand(
    Either<String, Map<String, dynamic>> config, {
    required CliRunner cliRunner,
  }) {
    // Parse the config file to pass the necessary information
    // each individual command need

    addCreateScratchSubcommand(config, cliRunner: cliRunner);
    addConfiguredSubcommands(config, cliRunner: cliRunner);
  }

  void addCreateScratchSubcommand(
    Either<String, Map<String, dynamic>> config, {
    required CliRunner cliRunner,
  }) {
    Either<String, List<ScratchOrgDefinition>> orgDefinitions =
        switch (config) {
          Left(:final value) => Left(value),
          Right(:final value) => Right<String, List<ScratchOrgDefinition>>(
            switch (value) {
              {'orgs': List<dynamic> orgs} =>
                orgs.map(ScratchOrgDefinition.parse).toList(),
              _ => <ScratchOrgDefinition>[],
            },
          ),
        };

    addSubcommand(CreateScratchCommand(orgDefinitions, cliRunner: cliRunner));
  }

  void addConfiguredSubcommands(
    Either<String, Map<String, dynamic>> config, {
    required CliRunner cliRunner,
  }) {
    switch (config) {
      case Left():
        return;
      case Right(:final value):
        if (value['commands'] is Map<String, dynamic>) {
          for (var MapEntry(:key, :value) in value['commands'].entries) {
            addSubcommand(RunNamedCommand(key, value, cliRunner: cliRunner));
          }
        }
    }
  }
}

// Default run commands

// TODO: Set default support
// TODO: Target devhub support
class ScratchOrgDefinition {
  final String name;
  final String definitionFile;
  final int? duration;

  ScratchOrgDefinition(this.name, this.definitionFile, [this.duration]);

  factory ScratchOrgDefinition.parse(dynamic def) {
    return switch (def) {
      {"name": String name, "definitionFile": String definitionFile} =>
        ScratchOrgDefinition(name, definitionFile, def['duration']),
      _ => throw 'Could not parse scratch org definition.',
    };
  }
}

class CreateScratchCommand extends Command {
  final Either<String, List<ScratchOrgDefinition>> definitions;
  final CliRunner cliRunner;

  @override
  final name = 'create_scratch';

  @override
  String get description => 'Creates a scratch org.';

  CreateScratchCommand(this.definitions, {required this.cliRunner}) {
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
    switch (definitions) {
      case Left(:final value):
        return Left('Error parsing the cirrus.toml file: $value');
      case Right(:final value):
        return await execute(value);
    }
  }

  Future<Either<String, String>> execute(
    List<ScratchOrgDefinition> configs,
  ) async {
    final orgName = argResults?.option('name') ?? '';
    final orgDefinition = configs.firstWhereOrOption(
      (def) => def.name == orgName,
    );

    switch (orgDefinition) {
      case Some(:final value):
        final additionalArguments = <(String, String)>[('alias', value.name)];

        final command = build(
          value,
          additionalArguments,
          setDefault: argResults?.flag('set-default') ?? true,
        );
        await cliRunner(command);
        return Right('Scratch org created successfully.');
      case None():
        return Left(
          "The org '$orgName' is not defined in the cirrus.toml file.\r\nThese are the available orgs: ${configs.map((e) => e.name).join(', ')}",
        );
    }
  }

  String build(
    ScratchOrgDefinition orgDefinition,
    List<(String, String)> additionalArguments, {
    required bool setDefault,
  }) {
    var root =
        'sf org scratch create --definition-file=${orgDefinition.definitionFile}';

    for (final additionalArgument in additionalArguments) {
      root = '$root --${additionalArgument.$1}=${additionalArgument.$2}';
    }

    if (setDefault) {
      root = '$root --set-default';
    }

    if (orgDefinition.duration == null) {
      return root;
    }

    return '$root --duration-days=${orgDefinition.duration}';
  }
}

class RunNamedCommand extends Command {
  @override
  final String name;

  final String command;

  final CliRunner cliRunner;

  @override
  String get description => 'Execute the $name command.';

  RunNamedCommand(this.name, this.command, {required this.cliRunner});

  @override
  Future<void> run() async {
    await cliRunner(command);
  }
}

extension IterableExtestons<T> on Iterable<T> {
  Option<T> firstWhereOrOption(Function(T) f) {
    for (final current in this) {
      if (f(current)) return Some(current);
    }

    return None();
  }
}
