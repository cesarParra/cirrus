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
