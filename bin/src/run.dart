import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:chalkdart/chalkdart.dart';
import 'package:cli_script/cli_script.dart' as cli;
import 'package:fpdart/fpdart.dart';

typedef ConfigParser = Map<String, dynamic> Function();

abstract class Logger {
  error(String errorMessage);
  print(String messageToPrint);
}

class StdIOLogger implements Logger {
  const StdIOLogger();

  @override
  error(String errorMessage) {
    stderr.writeln(chalk.red(errorMessage));
    print("");
  }

  @override
  print(String messageToPrint) {
    print(messageToPrint);
  }
}

Future<void> run(
  List<String> arguments,
  ConfigParser parser, {
  Logger logger = const StdIOLogger(),
}) async {
  print(arguments);
  final runner =
      Either.tryCatch(
        () => parser(),
        (_, _) =>
            "Was not able to load the cirrus.toml file. Make sure it exists",
      ).flatMap(
        (document) => Either.tryCatch(
          () => CommandRunner(
            "cirrus",
            "A lean command-line interface tool for Salesforce development automation.",
          )..addCommand(RunCommand(document)),
          (error, _) => 'Unexpected error: $error',
        ),
      );

  switch (runner) {
    case Right(:final value):
      try {
        await value.run(arguments);
      } on UsageException catch (e) {
        logger.error(e.message);
        logger.print(value.usage);
      } catch (e) {
        logger.error('$e');
      }

    case Left(:final value):
      logger.error(value);
  }
}

class RunCommand extends Command {
  @override
  final name = 'run';

  @override
  String get description => 'Runs a standalone command';

  RunCommand(Map<String, dynamic> config) {
    // Parse the config file to pass the necessary information
    // each individual command needs

    final orgDefinitions = switch (config) {
      {'orgs': List<dynamic> orgs} =>
        orgs.map(ScratchOrgDefinition.parse).toList(),
      _ => <ScratchOrgDefinition>[],
    };

    addSubcommand(CreateScratchCommand(orgDefinitions));

    if (config['commands'] is Map<String, dynamic>) {
      for (var MapEntry(:key, :value) in config['commands'].entries) {
        addSubcommand(RunNamedCommand(key, value));
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
  final List<ScratchOrgDefinition> definitions;

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
    final orgName = argResults?.option('name') ?? '';
    final orgDefinition = definitions.firstWhereOrOption(
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
