import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:chalkdart/chalkdart.dart';
import 'package:cli_script/cli_script.dart' as cli;
import 'package:fpdart/fpdart.dart';
import 'init_template.dart';

typedef ConfigParser = Map<String, dynamic> Function();

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
          ..addCommand(RunCommand(configFile)),
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

  RunCommand(Either<String, Map<String, dynamic>> config) {
    // Parse the config file to pass the necessary information
    // each individual command need

    addCreateScratchSubcommand(config);
    addConfiguredSubcommands(config);
  }

  void addCreateScratchSubcommand(Either<String, Map<String, dynamic>> config) {
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

    addSubcommand(CreateScratchCommand(orgDefinitions));
  }

  void addConfiguredSubcommands(Either<String, Map<String, dynamic>> config) {
    switch (config) {
      case Left():
        return;
      case Right(:final value):
        if (value['commands'] is Map<String, dynamic>) {
          for (var MapEntry(:key, :value) in value['commands'].entries) {
            addSubcommand(RunNamedCommand(key, value));
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

  @override
  final name = 'create_scratch';

  @override
  String get description => 'Creates a scratch org.';

  CreateScratchCommand(this.definitions) {
    argParser
      ..addOption(
        'name',
        abbr: 'n',
        mandatory: true,
        help: 'The name of the scratch org definition to create',
      )
      ..addOption('alias', abbr: 'a', help: 'Alias for the scratch org.');
  }

  @override
  Future<void> run() async {
    switch (definitions) {
      case Left(:final value):
        throw 'Error parsing the cirrus.toml file: $value';
      case Right(:final value):
        execute(value);
    }
  }

  Future<void> execute(List<ScratchOrgDefinition> configs) async {
    final orgName = argResults?.option('name') ?? '';
    final orgDefinition = configs.firstWhereOrOption(
      (def) => def.name == orgName,
    );

    switch (orgDefinition) {
      case Some(:final value):
        final additionalArguments = <(String, String)>[];
        if (argResults?.option('alias') != null) {
          additionalArguments.add(('alias', argResults!.option('alias')!));
        }

        final command = build(value, additionalArguments);
        print(chalk.green('Running: $command'));
        await cli.run(command);
      case None():
        throw 'The org "$orgName" is not defined in the cirrus.toml file.';
    }
  }

  String build(
    ScratchOrgDefinition orgDefinition,
    List<(String, String)> additionalArguments,
  ) {
    var root =
        'sf org scratch create --definition-file=${orgDefinition.definitionFile}';

    for (final additionalArgument in additionalArguments) {
      root = '$root --${additionalArgument.$1}=${additionalArgument.$2}';
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

  @override
  String get description => 'Execute the $name command.';

  RunNamedCommand(this.name, this.command);

  @override
  Future<void> run() async {
    await cli.run(command);
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
