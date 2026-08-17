import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';
import 'flow/flow.dart';
import 'package/package.dart';
import '../service_locator.dart';
import '../config.dart';
import '../version.dart';
import 'init/innit.dart';
import 'org/org.dart';
import 'run/run.dart';
import '../failure.dart';

class CirrusCommandRunner extends CommandRunner<dynamic> {
  CirrusCommandRunner()
    : super(
        'cirrus',
        'A lean command-line interface tool for Salesforce development automation.',
      ) {
    // No `-v`: `sf` spends it on `--target-dev-hub`, which is what it means on `package create`
    // here too. An abbreviation that means one thing globally and another under a subcommand is
    // the kind of trap that only shows up as a command that did something else.
    argParser.addFlag(
      'version',
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
      ..addCommand(OrgCommand())
      ..addCommand(RunCommand())
      ..addCommand(FlowCommand())
      ..addCommand(PackageCommand()),
    (error, _) => Failure('Unexpected error: $error'),
  );

  final logger = getIt.get<Logger>();
  switch (runner) {
    case Right(:final value):
      // `run` and `flow` offer subcommands read out of the config file, so dispatching them
      // against a config that did not load reports a missing subcommand - the symptom - while the
      // cause goes unmentioned. They fail here instead, once, before the arguments are parsed.
      final configError = _configErrorFacing(value, arguments);
      if (configError != null) {
        return _failed(logger, configError);
      }

      try {
        final result = await value.run(arguments);

        if (result is Either<Failure, String>) {
          switch (result) {
            case Right(:final value):
              // A command that finished with nothing to say finishes silently, which is what
              // `cirrus run` has always done.
              if (value.isNotEmpty) {
                logger.success(value);
              }
            case Left(:final value):
              return _failed(logger, value);
          }
        }
      } on UsageException catch (e) {
        final status = _failed(logger, Failure(e.message));
        logger.log(value.usage);
        return status;
      } on Failure catch (failure) {
        // A command that shelled out and failed; its status came from the command itself.
        return _failed(logger, failure);
      } catch (e) {
        return _failed(logger, Failure('$e'));
      }

    case Left(:final value):
      return _failed(logger, value);
  }

  return 0;
}

/// Reporting a failure and exiting non-zero are the same act: the message is what a person reads,
/// and the status is the only part a build server can see. They are one function so that no path
/// can do the first without the second, and the status comes from the failure rather than being
/// chosen here - only the failure knows whether a command ran and said so, or cirrus never got
/// that far.
int _failed(Logger logger, Failure failure) {
  logger.error(failure.message);
  return failure.status;
}

/// Why the config file did not load, when the command being run is one that needs it. `init` and
/// `--version` are answerable without a config, and never ask for one.
Failure? _configErrorFacing(CommandRunner runner, List<String> arguments) {
  final invoked = _invoked(runner, arguments);
  if (invoked is! ReadsConfig ||
      !getIt.isRegistered<Either<Failure, Config>>()) {
    return null;
  }

  return getIt.get<Either<Failure, Config>>().getLeft().toNullable();
}

/// The command these arguments name, according to the parser that will dispatch them.
///
/// Read off the parse rather than off `arguments.first`, which is the command only while nothing
/// can precede it. A global option taking a value would sit there instead, the lookup would miss,
/// and the cause would silently stop being reported - leaving the missing-subcommand symptom this
/// exists to replace.
Command? _invoked(CommandRunner runner, List<String> arguments) {
  try {
    final named = runner.parse(arguments).command?.name;
    return named == null ? null : runner.commands[named];
  } on UsageException {
    // Arguments the parser cannot read name no command, and are reported as themselves.
    return null;
  }
}
