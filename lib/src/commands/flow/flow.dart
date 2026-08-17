import 'package:args/command_runner.dart';
import 'package:chalkdart/chalkstrings.dart';
import 'package:cli_spin/cli_spin.dart';
import 'package:fpdart/fpdart.dart';

import '../../config.dart';
import '../../execution.dart';
import '../../service_locator.dart';
import '../org/create_scratch.dart';
import '../../failure.dart';

class FlowCommand extends Command implements ReadsConfig {
  @override
  String get name => 'flow';

  @override
  String get description => 'Runs a flow defined in the config file.';

  FlowCommand() {
    final config = loadedConfig();
    if (config == null) {
      return;
    }

    for (final flow in config.flows) {
      addSubcommand(NamedFlowCommand(config, flow));
    }
  }

  @override
  Either<Failure, String> run() {
    if (subcommands.isEmpty) {
      return Left(Failure('No flows are defined in $configFileName.'));
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
  Future<Either<Failure, String>> run() async {
    // A flow is a sequence somebody wrote down, so there is no one step for an argument to belong
    // to. Saying so is the point: taking them and running the flow unchanged is indistinguishable
    // from having honoured them.
    final unread = argResults?.rest ?? const [];
    if (unread.isNotEmpty) {
      return Left(
        Failure(
          "A flow takes no arguments, and '$name' was given "
          "${unread.join(' ')}. Arguments go to one command: cirrus run <command> -- ...",
        ),
      );
    }

    final logger = getIt.get<Logger>();
    logger.log(
      'Running flow "${name.italic}"',
      chalk: chalk.yellow.bold,
      separator: true,
    );

    // One execution for the whole flow, so a prerequisite named twice within it runs once.
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

      final result = switch (step) {
        CreateScratchFlowStep() => await runCreateScratch(
          step.orgName,
          setDefault: step.setDefault,
        ),
        RunCommandFlowStep() => await execution.step(step.commandName),
      };
      spinner.stop();

      if (result case Left(:final value)) {
        return Left(value);
      }

      logger.success('Step ${step.printable().italic} completed successfully.');
    }

    return Right('Finished running flow $name.');
  }
}
