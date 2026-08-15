import 'package:chalkdart/chalk.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:fpdart/fpdart.dart';

/// The recording doubles a command test runs against: a logger that keeps what it was told instead
/// of printing it, and a runner that keeps the command line instead of running it.
({TestLogger logger, TestRunner runner}) registerDoubles({
  bool failing = false,
}) {
  final logger = TestLogger();
  final runner = TestRunner(fails: failing);
  getIt.registerSingleton<Logger>(logger);
  getIt.registerSingleton<CliRunner>(runner);
  return (logger: logger, runner: runner);
}

/// The config the command under test reads.
void registerConfig(String yaml) {
  getIt.registerSingleton<Either<String, Config>>(Right(Config.fromYaml(yaml)));
}

/// A config that could not be read, and why.
void registerConfigFailure(String reason) {
  getIt.registerSingleton<Either<String, Config>>(Left(reason));
}

class TestLogger implements Logger {
  final List<String> errors = [];
  final List<String> messages = [];
  final List<String> successes = [];

  @override
  error(String errorMessage) {
    errors.add(errorMessage);
  }

  @override
  log(String messageToPrint, {Chalk? chalk, bool separator = false}) {
    messages.add(messageToPrint);
  }

  @override
  success(String message) {
    successes.add(message);
  }
}

class TestRunner implements CliRunner {
  List<String> args = [];
  final String simulatedOutput;

  /// Behaves like a command that exited non-zero. cli_script throws in that case, which is how a
  /// real failure reaches cirrus.
  final bool fails;

  TestRunner({String? simulatedOutput, this.fails = false})
    : simulatedOutput = simulatedOutput ?? 'Simulated output';

  @override
  Future<void> run(String command) async {
    args.addAll(command.toArguments());
    if (fails) {
      throw '$command failed with exit code 1.';
    }
  }

  @override
  Future<String> output(String command) async {
    args.addAll(command.toArguments());
    if (fails) {
      throw '$command failed with exit code 1.';
    }
    // Simulate output for testing purposes
    return simulatedOutput;
  }
}

extension CliExtensions on String {
  List<String> toArguments() {
    final List<String> args = [];
    final StringBuffer currentArg = StringBuffer();
    bool inQuotes = false;
    bool inSingleQuotes = false;
    bool escapeNext = false;

    for (int i = 0; i < length; i++) {
      final char = this[i];

      if (escapeNext) {
        currentArg.write(char);
        escapeNext = false;
        continue;
      }

      if (char == '\\') {
        escapeNext = true;
        continue;
      }

      if (char == '"' && !inSingleQuotes) {
        inQuotes = !inQuotes;
        continue;
      }

      if (char == "'" && !inQuotes) {
        inSingleQuotes = !inSingleQuotes;
        continue;
      }

      if (char == ' ' && !inQuotes && !inSingleQuotes) {
        if (currentArg.isNotEmpty) {
          args.add(currentArg.toString());
          currentArg.clear();
        }
        continue;
      }

      currentArg.write(char);
    }

    if (currentArg.isNotEmpty) {
      args.add(currentArg.toString());
    }

    return args;
  }
}
