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

  @override
  error(String errorMessage) {
    errors.add(errorMessage);
  }

  @override
  log(String messageToPrint) {
    messages.add(messageToPrint);
  }
}

main() {
  group('init', () async {
    Map<String, dynamic> parser() {
      throw 'toml parsing error';
    }

    await run('init'.toArguments(), parser);

    // TODO
  });

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
