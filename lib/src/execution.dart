import 'package:fpdart/fpdart.dart';

import 'config.dart';
import 'service_locator.dart';
import 'utils.dart';

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
  Future<Either<String, void>> step(String name) async {
    return switch (_command(name)) {
      Some(:final value) => await _execute(value),
      None() => Left("Command $name not found"),
    };
  }

  /// Runs [name] unless this run already has.
  Future<Either<String, void>> prerequisite(String name) async {
    if (_completed.contains(name)) {
      return Right(null);
    }

    return await step(name);
  }

  /// Runs everything in [names], in the order given, stopping at the first that fails.
  Future<Either<String, void>> prerequisites(List<String> names) async {
    for (final name in names) {
      final result = await prerequisite(name);
      if (result.isLeft()) {
        return result;
      }
    }

    return Right(null);
  }

  Future<Either<String, void>> _execute(NamedCommand command) async {
    final prerequisitesRun = await prerequisites(command.dependsOn);
    if (prerequisitesRun.isLeft()) {
      return prerequisitesRun;
    }

    final commandLine = command.run;
    if (commandLine != null) {
      try {
        await getIt.get<CliRunner>().run(commandLine);
      } catch (error) {
        return Left('$error');
      }
    }

    _completed.add(command.name);
    return Right(null);
  }

  Option<NamedCommand> _command(String name) =>
      config.commands.firstWhereOrOption((command) => command.name == name);
}
