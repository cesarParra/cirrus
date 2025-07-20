import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:chalkdart/chalkstrings.dart';
import 'package:cli_script/cli_script.dart' as cli;
import 'package:fpdart/fpdart.dart';
import 'init_template.dart';
import 'create_scratch.dart';
import 'config.dart';

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
    stderr.writeln(errorMessage.red.bold);
    log("");
  }

  @override
  log(String messageToPrint) {
    print(messageToPrint);
  }

  @override
  success(String message) {
    print(message.green.bold);
  }
}

Future<void> run(
  List<String> arguments,
  ConfigParser parser, {
  CliRunner cliRunner = cli.run,
  required String configFileName,
  Logger logger = const StdIOLogger(),
}) async {
  final configFile = Either.tryCatch(() {
    final unparsed = parser();
    return Config.parse(unparsed);
  }, (error, _) => "Was not able to load the cirrus.toml file.\r\n$error'");

  final runner = Either.tryCatch(
    () =>
        CommandRunner(
            "cirrus",
            "A lean command-line interface tool for Salesforce development automation.",
          )
          ..addCommand(InitCommand(configFileName))
          ..addCommand(RunCommand(configFile, cliRunner: cliRunner))
          ..addCommand(FlowCommand(cliRunner, configFile)),
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

  RunCommand(Either<String, Config> config, {required CliRunner cliRunner}) {
    // Parse the config file to pass the necessary information
    // each individual command need

    addCreateScratchSubcommand(config, cliRunner: cliRunner);
    addConfiguredSubcommands(config, cliRunner: cliRunner);
  }

  void addCreateScratchSubcommand(
    Either<String, Config> config, {
    required CliRunner cliRunner,
  }) {
    addSubcommand(CreateScratchCommand(config, cliRunner: cliRunner));
  }

  void addConfiguredSubcommands(
    Either<String, Config> config, {
    required CliRunner cliRunner,
  }) {
    switch (config) {
      case Left():
        return;
      case Right(:final value):
        for (final namedCommand in value.commands) {
          addSubcommand(RunNamedCommand(namedCommand, cliRunner: cliRunner));
        }
    }
  }
}

// Default run commands

class CreateScratchCommand extends Command {
  final Either<String, Config> config;
  final CliRunner cliRunner;

  @override
  final name = 'create_scratch';

  @override
  String get description => 'Creates a scratch org.';

  CreateScratchCommand(this.config, {required this.cliRunner}) {
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
      cliRunner,
      config,
      argResults?.option('name') ?? '',
      setDefault: argResults?.flag('set-default') ?? true,
    );
  }
}

class RunNamedCommand extends Command {
  final NamedCommand command;

  @override
  String get name => command.name;

  final CliRunner cliRunner;

  @override
  String get description => 'Execute the $name command.';

  RunNamedCommand(this.command, {required this.cliRunner});

  @override
  Future<void> run() async {
    await cliRunner(command.command);
  }
}

// Flows

// TODO: Run create_scratch from flow
// TODO: Run other commands from flow
// TODO: Run string commands directly from flow
// TODO: Run other flows from flow
// TODO: Ability to use the output of one step as the input of another step

// TODO: Support for other types of flow steps

class FlowCommand extends Command {
  final CliRunner cliRunner;
  final Either<String, Config> config;

  @override
  String get name => 'flow';

  @override
  String get description => 'Runs a flow defined in the config file.';

  FlowCommand(this.cliRunner, this.config) {
    for (final flowCommand in parsedSubcommands) {
      addSubcommand(flowCommand);
    }
  }

  List<NamedFlowCommand> get parsedSubcommands => switch (config) {
    Left() => [],
    Right(value: final config) =>
      config.flows
          .map(
            (currentFlow) => NamedFlowCommand(cliRunner, config, currentFlow),
          )
          .toList(),
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

// TODO: I am doing way too much parsing unecessarily. Parsing should
// be done at the top and return an object that has everything parsed
// or the error string to the left side.

class NamedFlowCommand extends Command {
  final CliRunner cliRunner;
  final Config config;
  final Flow flow;

  @override
  String get name => flow.name;

  @override
  String get description => flow.description ?? '';

  NamedFlowCommand(this.cliRunner, this.config, this.flow);

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
        cliRunner,
        Right(config),
        step.orgName,
        setDefault: step.setDefault ?? true,
      ),
      RunCommandFlowStep() => await runCommand(step.commandName),
    };
  }

  Future<Either<String, void>> runCommand(String commandName) async {
    final command = config.commands.firstWhereOrOption(
      (command) => command.name == commandName,
    );

    Future<Either<String, void>> runCommand(String command) async {
      try {
        await cliRunner(command);
        return Right(null);
      } catch (e) {
        return Left('$e');
      }
    }

    // TODO: Instead of bombing in the middle of the flow, there
    // should be an initial validation to make sure the flow is
    // correctly configured
    return switch (command) {
      None() => Left('Command $commandName not found'),
      Some(:final value) => await runCommand(value.command),
    };
  }
}
