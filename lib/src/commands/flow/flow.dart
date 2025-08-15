import 'package:args/command_runner.dart';
import 'package:chalkdart/chalkstrings.dart';
import 'package:cirrus/src/utils.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:fpdart/fpdart.dart';

import '../../config.dart';
import '../../service_locator.dart';
import '../run/create_scratch.dart';

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