import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';

import '../../failure.dart';
import '../../plan/artifact.dart';
import '../../plan/events.dart';
import '../../plan/execute.dart';
import '../../plan/org.dart';
import '../../plan/run_config.dart';

class Execute extends Command {
  @override
  String get name => 'execute';

  @override
  String get description =>
      'Runs a published plan against an org, narrating it as JSON events on stdout.';

  /// A step ran and did not succeed. [Failure.couldNot] says cirrus never started, and the caller
  /// needs to tell those apart: only one of them touched the org.
  static const stepFailed = 1;

  Execute() {
    argParser.addOption(
      'plan',
      abbr: 'p',
      mandatory: true,
      help: 'Path to the plan artifact to run.',
    );
  }

  @override
  Future<Either<Failure, String>> run() async {
    final path = argResults!['plan'] as String;
    final file = File(path);
    if (!file.existsSync()) {
      return Left(Failure('No plan at $path.'));
    }

    final parsedPlan = Plan.parse(file.readAsStringSync());
    if (parsedPlan is Left<Failure, Plan>) return Left(parsedPlan.value);

    final String first;
    try {
      first = await stdin
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first;
    } catch (_) {
      return Left(Failure('Expected the run configuration on stdin.'));
    }

    final parsedConfig = RunConfig.parse(first);
    if (parsedConfig is Left<Failure, RunConfig>) {
      return Left(parsedConfig.value);
    }

    final config = (parsedConfig as Right<Failure, RunConfig>).value;
    final org = HttpOrg(
      instanceUrl: config.instanceUrl,
      accessToken: config.accessToken,
    );

    try {
      final installed = await PlanExecution(
        plan: (parsedPlan as Right<Failure, Plan>).value,
        config: config,
        org: org,
        events: Events.toStdout(),
      ).run();

      return installed
          ? Right('')
          : Left(
              Failure.fromCommand(
                'The plan did not finish. The step.failed event says why.',
                stepFailed,
              ),
            );
    } finally {
      org.close();
    }
  }
}
