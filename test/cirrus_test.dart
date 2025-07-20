import 'dart:io';

import 'package:test/test.dart';
import 'package:toml/toml.dart';

import '../bin/src/run.dart';

extension on String {
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

class TestRunner {
  List<String> args = [];

  Future<void> run(String command) async {
    args = command.toArguments();
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

    test('runs the sf org scratch create command', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
          [[orgs]]
          name = "default"
          definitionFile = "config/project-scratch-def.json"
          duration = 30
          """).toMap();
      }

      final runner = TestRunner();
      final logger = TestLogger();

      await run(
        'run create_scratch -n default'.toArguments(),
        configFileName: "",
        parser,
        cliRunner: runner.run,
        logger: logger,
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('sf'));
      expect(runner.args, contains('org'));
      expect(runner.args, contains('scratch'));
      expect(runner.args, contains('create'));
    });

    test('provides the definition file', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
          [[orgs]]
          name = "default"
          definitionFile = "config/project-scratch-def.json"
          duration = 30
          """).toMap();
      }

      final runner = TestRunner();
      final logger = TestLogger();

      await run(
        'run create_scratch -n default'.toArguments(),
        configFileName: "",
        parser,
        cliRunner: runner.run,
        logger: logger,
      );

      expect(
        runner.args,
        contains('--definition-file=config/project-scratch-def.json'),
      );
    });

    test('provides the duration if present in the config file', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
          [[orgs]]
          name = "default"
          definitionFile = "config/project-scratch-def.json"
          duration = 30
          """).toMap();
      }

      final runner = TestRunner();
      final logger = TestLogger();

      await run(
        'run create_scratch -n default'.toArguments(),
        configFileName: "",
        parser,
        cliRunner: runner.run,
        logger: logger,
      );

      expect(runner.args, contains('--duration-days=30'));
    });

    test('is set as default by default', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
          [[orgs]]
          name = "default"
          definitionFile = "config/project-scratch-def.json"
          duration = 30
          """).toMap();
      }

      final runner = TestRunner();
      final logger = TestLogger();

      await run(
        'run create_scratch -n default'.toArguments(),
        configFileName: "",
        parser,
        cliRunner: runner.run,
        logger: logger,
      );

      expect(runner.args, contains('--set-default'));
    });

    test('can avoid setting as the default', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
          [[orgs]]
          name = "default"
          definitionFile = "config/project-scratch-def.json"
          duration = 30
          """).toMap();
      }

      final runner = TestRunner();
      final logger = TestLogger();

      await run(
        'run create_scratch -n default --no-set-default'.toArguments(),
        configFileName: "",
        parser,
        cliRunner: runner.run,
        logger: logger,
      );

      expect(runner.args, isNot(contains('--set-default')));
    });

    test(
      'does not provide duration if not present in the config file',
      () async {
        Map<String, dynamic> parser() {
          return TomlDocument.parse("""
          [[orgs]]
          name = "default"
          definitionFile = "config/project-scratch-def.json"
          """).toMap();
        }

        final runner = TestRunner();
        final logger = TestLogger();

        await run(
          'run create_scratch -n default'.toArguments(),
          configFileName: "",
          parser,
          cliRunner: runner.run,
          logger: logger,
        );

        expect(runner.args, isNot(contains('--duration-days')));
      },
    );

    test('errors when the org is not defined in the cirrus.toml file', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
          [[orgs]]
          name = "default"
          definitionFile = "config/project-scratch-def.json"
          duration = 30
          """).toMap();
      }

      final logger = TestLogger();

      await run(
        'run create_scratch -n non_existent_org'.toArguments(),
        configFileName: "",
        cliRunner: (String command) async {},
        parser,
        logger: logger,
      );

      expect(logger.errors, hasLength(1));
      expect(
        logger.errors.first,
        contains(
          "The org 'non_existent_org' is not defined in the cirrus.toml file.",
        ),
      );
      expect(logger.messages, isEmpty);
    });
  });

  group('generic commands', () {
    test('can run any defined command', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
          [commands]
          hello = "echo 'Hello, World!'"
          """).toMap();
      }

      final runner = TestRunner();
      final logger = TestLogger();

      await run(
        'run hello'.toArguments(),
        configFileName: "",
        parser,
        cliRunner: runner.run,
        logger: logger,
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('echo'));
      expect(runner.args, contains('Hello, World!'));
    });

    test('errors when the command is not defined', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
          [commands]
          hello = "echo 'Hello, World!'"
          """).toMap();
      }

      final logger = TestLogger();

      await run(
        'run non_existent_command'.toArguments(),
        configFileName: "",
        cliRunner: (String command) async {},
        parser,
        logger: logger,
      );

      expect(logger.errors, hasLength(1));
      expect(
        logger.errors.first,
        contains("Could not find a subcommand named"),
      );
      expect(
        logger.messages,
        isNotEmpty,
        reason: "Expected the 'usage' message to be printed",
      );
    });
  });
}
