import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';
import 'flow/flow.dart';
import 'package/package.dart';
import '../service_locator.dart';
import '../version.dart';
import 'init/innit.dart';
import 'run/run.dart';

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

/// Returns the process exit status: zero when the command did what it was asked, non-zero when it
/// did not. `bin/cirrus.dart` is what applies it - returning it rather than setting `exitCode`
/// here keeps the result something a test can read.
Future<int> run(
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
              return _failed(logger, value);
          }
        }
      } on UsageException catch (e) {
        final status = _failed(logger, e.message);
        logger.log(value.usage);
        return status;
      } catch (e) {
        return _failed(logger, '$e');
      }

    case Left(:final value):
      return _failed(logger, value);
  }

  return 0;
}

/// Reporting a failure and exiting non-zero are the same act: the message is what a person reads,
/// and the status is the only part a build server can see. They are one function so that no path
/// can do the first without the second.
int _failed(Logger logger, String message) {
  logger.error(message);
  return 1;
}
