import 'dart:io';

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
  group('init', () {
    const testFileName = "test_tmp/cirrus.toml";

    setUp(() {
      // Ensure the test_tmp directory exists
      final testDir = Directory('test_tmp');
      if (!testDir.existsSync()) {
        testDir.createSync(recursive: true);
      }

      // Ensure that the test file does not exist before each test
      final testFile = File(testFileName);
      if (testFile.existsSync()) {
        testFile.deleteSync();
      }
    });

    tearDown(() {
      // Clean up the test file after each test
      final testFile = File(testFileName);
      if (testFile.existsSync()) {
        testFile.deleteSync();
      }

      // Delete the test_tmp directory if it's empty
      final testDir = Directory('test_tmp');
      if (testDir.existsSync() && testDir.listSync().isEmpty) {
        testDir.deleteSync();
      }
    });

    test('initializes a new cirrus.toml file', () async {
      final logger = TestLogger();

      await run(
        'init'.toArguments(),
        () => {},
        configFileName: testFileName,
        logger: logger,
      );

      //expect(logger.messages, contains('cirrus.toml created successfully'));
      expect(logger.errors, isEmpty);
      final testFile = File(testFileName);
      expect(testFile.existsSync(), isTrue);

      final content = testFile.readAsStringSync();
      expect(
        content,
        contains('# Uncomment the following lines to define a scratch org.'),
      );
    });
  });

  group('create_scratch', () {
    test('errors when any error occurs parsing the cirrus.toml file', () async {
      Map<String, dynamic> parser() {
        throw 'toml parsing error';
      }

      final logger = TestLogger();

      await run(
        'run create_scratch'.toArguments(),
        configFileName: "",
        parser,
        logger: logger,
      );

      expect(logger.errors, hasLength(1));
      expect(logger.errors.first, contains('toml parsing error'));
      expect(logger.messages, isEmpty);
    });

    // TODO: Positive tests
  });

  // TODO: Generic commands
}
