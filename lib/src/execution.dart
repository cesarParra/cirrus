import 'package:fpdart/fpdart.dart';

import 'config.dart';
import 'service_locator.dart';
import 'package:cli_script/cli_script.dart' as cli;
import 'failure.dart';

/// One run of cirrus, and the commands it has already carried out.
///
/// The two ways a command can be reached are not the same thing. A **prerequisite** says what has
/// to have happened before something else can run, so it happens once however many times it is
/// named - `build` named by both `lint` and `test` builds once. A **step** is an order somebody
/// wrote down, so naming the same command twice in a flow runs it twice.
///
/// Both are the same command underneath, which is why they share this: the dedup is a property of
/// how the command was reached, not of the command.
class Execution {
  final Config config;
  final Set<String> _completed = {};

  Execution(this.config);

  /// Runs [name], whatever has run before it. Its prerequisites still run at most once.
  ///
  /// [arguments] are appended to this command's command line and to nothing else: they were asked
  /// for by name, and a prerequisite dragged in behind it did not ask for them.
  Future<Either<Failure, void>> step(
    String name, {
    List<String> arguments = const [],
  }) async {
    final command = config.command(name);

    // Every name in the config is checked when it is read, so this is reachable only from a
    // caller that made one up.
    if (command == null) {
      return Left(Failure("Command $name not found"));
    }

    return await _execute(command, arguments);
  }

  /// Runs everything in [names] that this run has not already, in the order given, stopping at the
  /// first that fails.
  Future<Either<Failure, void>> prerequisites(List<String> names) async {
    for (final name in names) {
      if (_completed.contains(name)) {
        continue;
      }

      final result = await step(name);
      if (result.isLeft()) {
        return result;
      }
    }

    return Right(null);
  }

  Future<Either<Failure, void>> _execute(
    NamedCommand command,
    List<String> arguments,
  ) async {
    final prerequisitesRun = await prerequisites(command.dependsOn);
    if (prerequisitesRun.isLeft()) {
      return prerequisitesRun;
    }

    final commandLine = command.run;
    if (commandLine != null) {
      try {
        await getIt.get<CliRunner>().run(
          [commandLine, ...arguments.map(cli.arg)].join(' '),
        );
      } on cli.ScriptException catch (error) {
        // The command ran and answered. Its status is what the caller wanted to know - a build
        // server reading 1 for "your tests failed" and 1 for "your config is invalid" cannot tell
        // them apart, and only this line knows which one this is.
        return Left(Failure.fromCommand('$error', error.exitCode));
      } catch (error) {
        return Left(Failure('$error'));
      }
    }

    _completed.add(command.name);
    return Right(null);
  }
}
