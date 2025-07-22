import 'dart:io';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';
import 'package:toml/toml.dart';

import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/run.dart';
import 'package:cirrus/src/service_locator.dart';

CliRunner doNothingRunner() {
  return (String command) async {
    // This runner does nothing, it's just for testing purposes.
  };
}

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
    args.addAll(command.toArguments());
  }
}

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
      getIt.registerLazySingleton<CliRunner>(doNothingRunner);

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

  group('create_scratch', () {
    test('errors when any error occurs parsing the cirrus.toml file', () async {
      getIt.registerSingleton<Either<String, Config>>(
        Left('toml parsing error'),
      );

      await run(
        'run create_scratch --name=test'.toArguments(),
        configFileName: "",
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

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );
      getIt.registerSingleton<CliRunner>(runner.run);

      await run(
        'run create_scratch -n default'.toArguments(),
        configFileName: "",
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

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );
      getIt.registerSingleton<CliRunner>(runner.run);

      await run(
        'run create_scratch -n default'.toArguments(),
        configFileName: "",
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

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );
      getIt.registerSingleton<CliRunner>(runner.run);

      await run(
        'run create_scratch -n default'.toArguments(),
        configFileName: "",
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

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );
      getIt.registerSingleton<CliRunner>(runner.run);

      await run(
        'run create_scratch -n default'.toArguments(),
        configFileName: "",
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

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );
      getIt.registerSingleton<CliRunner>(runner.run);

      await run(
        'run create_scratch -n default --no-set-default'.toArguments(),
        configFileName: "",
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

        getIt.registerSingleton<Either<String, Config>>(
          Right(Config.parse(parser())),
        );
        getIt.registerSingleton<CliRunner>(runner.run);

        await run(
          'run create_scratch -n default'.toArguments(),
          configFileName: "",
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

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );

      await run(
        'run create_scratch -n non_existent_org'.toArguments(),
        configFileName: "",
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

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );
      getIt.registerSingleton<CliRunner>(runner.run);

      await run('run hello'.toArguments(), configFileName: "");

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

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );

      await run('run non_existent_command'.toArguments(), configFileName: "");

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

  group('flows', () {
    test('errors when trying to run a flow that does not exist', () {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
        [commands]
        hello = "echo 'Hello, World!'"

        [flow.test]
        description = "Test flow"
        steps = [{ type = "command", name = "hello" }]
        """).toMap();
      }

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );

      run('flow my_non_existent_flow'.toArguments(), configFileName: "").then((
        _,
      ) {
        expect(logger.errors, hasLength(1));
        expect(
          logger.errors.first,
          contains("Could not find a subcommand named"),
        );
        expect(
          logger.messages,
          isNot(isEmpty),
          reason: "Expected the 'usage' message to be printed",
        );
      });
    });

    test('runs a flow with a single command', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
        [commands]
        hello = "echo 'Hello, World!'"

        [flow.test]
        description = "Test flow"
        steps = [{ type = "command", name = "hello" }]
        """).toMap();
      }

      final runner = TestRunner();

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );
      getIt.registerSingleton<CliRunner>(runner.run);

      await run('flow test'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('echo'));
      expect(runner.args, contains('Hello, World!'));
    });

    test('runs a flow with multiple steps', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
          [commands]
          hello = "echo 'Hello, World!'"
          goodbye = "echo 'Goodbye, World!'"

          [flow.test]
          description = "Test flow"
          steps = [
            { type = "command", name = "hello" },
            { type = "command", name = "goodbye" }
          ]
          """).toMap();
      }

      final runner = TestRunner();

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );
      getIt.registerSingleton<CliRunner>(runner.run);

      await run('flow test'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('echo'));
      expect(runner.args, contains('Hello, World!'));
      expect(runner.args, contains('Goodbye, World!'));
    });
  });
}
