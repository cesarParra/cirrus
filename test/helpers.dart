import 'package:chalkdart/chalk.dart';
import 'package:cirrus/src/service_locator.dart';

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

  TestRunner({String? simulatedOutput})
      : simulatedOutput = simulatedOutput ?? 'Simulated output';

  @override
  Future<void> run(String command) async {
    args.addAll(command.toArguments());
  }

  @override
  Future<String> output(String command) async {
    args.addAll(command.toArguments());
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