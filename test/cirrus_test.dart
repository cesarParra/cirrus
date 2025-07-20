import 'package:test/test.dart';

import '../bin/src/run.dart';

extension on String {
  List<String> toArguments() {
    return split(' ');
  }
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
  log(String messageToPrint) {
    messages.add(messageToPrint);
  }

  @override
  success(String message) {
    successes.add(message);
  }
}

main() {
  group('create_scratch', () {
    test('errors when any error occurs parsing the cirrus.toml file', () async {
      Map<String, dynamic> parser() {
        throw 'toml parsing error';
      }

      final logger = TestLogger();

      await run('run create_scratch'.toArguments(), parser, logger: logger);

      expect(logger.errors, hasLength(1));
      expect(logger.errors.first, contains('toml parsing error'));
      expect(logger.messages, isEmpty);
    });

    // TODO: Positive tests
  });

  // TODO: Generic commands
}
