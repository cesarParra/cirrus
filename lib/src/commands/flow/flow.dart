import 'package:args/command_runner.dart';
import 'package:chalkdart/chalkstrings.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:fpdart/fpdart.dart';

import '../../config.dart';
import '../../execution.dart';
import '../../service_locator.dart';
import '../run/create_scratch.dart';

class FlowCommand extends Command implements ReadsConfig {
  @override
  String get name => 'flow';

  @override
  String get description => 'Runs a flow defined in the config file.';

  FlowCommand() {
    final config = getIt.get<Either<String, Config>>();

    // A config that did not load is reported before any command is dispatched, so there is nothing
    // to say about it here - there are simply no flows to offer.
    final loaded = config.getRight().toNullable();
    for (final flow in loaded?.flows ?? const <Flow>[]) {
      addSubcommand(NamedFlowCommand(loaded!, flow));
    }
  }

  @override
  Either<String, String> run() {
    if (subcommands.isEmpty) {
      return Left('No flows are defined in $configFileName.');
    }

    return Right('Available flows: ${subcommands.keys.join(', ')}');
  }
}

class NamedFlowCommand extends Command {
  final Config config;
  final Flow flow;

  @override
  String get name => flow.name;

  @override
  String get description => flow.description ?? '';

  NamedFlowCommand(this.config, this.flow);

  @override
  Future<Either<String, String>> run() async {
    final logger = getIt.get<Logger>();
    logger.log(
      'Running flow "${name.italic}"',
      chalk: chalk.yellow.bold,
      separator: true,
    );

    // One execution for the whole flow, so a prerequisite named by the flow and again by one of
    // its steps runs once. The steps themselves are an order somebody wrote down, and repeat.
    final execution = Execution(config);

    final prerequisites = await execution.prerequisites(flow.dependsOn);
    if (prerequisites case Left(:final value)) {
      return Left(value);
    }

    for (final step in flow.steps) {
      final spinner = CliSpin(
        text: step.printable().yellow.bold,
        spinner: CliSpinners.dots,
        color: CliSpinnerColor.yellow,
      ).start();

      final result = await _runStep(execution, step);
      spinner.stop();

      if (result case Left(:final value)) {
        return Left(value);
      }

      logger.success('Step ${step.printable().italic} completed successfully.');
    }

    return Right('Finished running flow $name.');
  }

  Future<Either<String, void>> _runStep(
    Execution execution,
    FlowStep step,
  ) async {
    return switch (step) {
      CreateScratchFlowStep() => await runCreateScratch(
        step.orgName,
        setDefault: step.setDefault,
      ),
      RunCommandFlowStep() => await execution.step(step.commandName),
    };
  }
}
