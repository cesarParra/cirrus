import 'dart:io';

import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late TestLogger logger;

  setUp(() {
    logger = TestLogger();
    getIt.registerSingleton<Logger>(logger);
  });

  tearDown(() {
    getIt.reset();
  });

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
      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );
      getIt.registerSingleton<CliRunner>(TestRunner());
      getIt.registerFactoryParam<FileSystem, String, void>(
            (String path, _) => FileSystem.open(path),
      );

      await run('init'.toArguments(), configFileName: testFileName);

      expect(logger.successes.first, contains('created successfully'));
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
}