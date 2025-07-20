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
  print(String messageToPrint) {
    messages.add(messageToPrint);
  }
}

main() {
  test('errors when an error occurs parsing the cirrus.toml file', () {
    Map<String, dynamic> parser() {
      throw 'toml parsing error';
    }

    final logger = TestLogger();

    run('run'.toArguments(), parser, logger: logger);

    expect(logger.errors, hasLength(1));
    expect(
      logger.errors.first,
      'Was not able to load the cirrus.toml file. Make sure it exists',
    );
    expect(logger.messages, isEmpty);
  });
}
