import 'dart:io';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';
import 'package:toml/toml.dart';

import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/run.dart';
import 'package:cirrus/src/service_locator.dart';

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
      getIt.registerSingleton<CliRunner>(runner);

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
      getIt.registerSingleton<CliRunner>(runner);

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
      getIt.registerSingleton<CliRunner>(runner);

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
      getIt.registerSingleton<CliRunner>(runner);

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
      getIt.registerSingleton<CliRunner>(runner);

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
        getIt.registerSingleton<CliRunner>(runner);

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
      getIt.registerSingleton<CliRunner>(runner);

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
      getIt.registerSingleton<CliRunner>(runner);

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
      getIt.registerSingleton<CliRunner>(runner);

      await run('flow test'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('echo'));
      expect(runner.args, contains('Hello, World!'));
      expect(runner.args, contains('Goodbye, World!'));
    });
  });

  group('package', () {
    test('Errors when there is no sfdx-project.json file', () async {
      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => FakeFileSystem(path, false),
      );

      await run('package create'.toArguments(), configFileName: "");

      expect(logger.errors, hasLength(1));
      expect(
        logger.errors.first,
        contains('sfdx-project.json file not found in the current directory.'),
      );
    });

    test('Increments the major version', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=major'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(fakeFileSystem.contents, isNotEmpty);
      expect(
        fakeFileSystem.contents,
        contains('"versionNumber": "3.0.0.NEXT"'),
      );
      expect(runner.args, contains('--package=SamplePackage'));
    });

    test('Increments the minor version', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=minor'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(fakeFileSystem.contents, isNotEmpty);
      expect(
        fakeFileSystem.contents,
        contains('"versionNumber": "2.31.0.NEXT"'),
      );
      expect(runner.args, contains('--package=SamplePackage'));
    });

    test('Increments the patch version', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=patch'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(fakeFileSystem.contents, isNotEmpty);
      expect(
        fakeFileSystem.contents,
        contains('"versionNumber": "2.30.1.NEXT"'),
      );
      expect(runner.args, contains('--package=SamplePackage'));
    });

    test('Updates the name', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=minor --name="New Name"'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(fakeFileSystem.contents, contains('"versionName": "New Name"'));
    });

    test('Forwards the code coverage to the executed command', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=minor --code-coverage'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--code-coverage'));
    });

    test('Forwards the definition file to the executed command', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=minor --definition-file=config/definition.json'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--definition-file=config/definition.json'));
    });

    test('Forwards the installation key to the executed command', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=minor --installation-key=12345'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--installation-key=12345'));
    });

    test(
      'Forwards the installation key bypass to the executed command',
      () async {
        FakeFileSystem fakeFileSystem = FakeFileSystem(
          'sfdx-project.json',
          true,
        );

        getIt.registerSingleton<Either<String, Config>>(
          Left('No config available'),
        );

        getIt.registerFactoryParam<FileSystem, String, void>(
          (String path, _) => fakeFileSystem,
        );

        final runner = TestRunner();
        getIt.registerSingleton<CliRunner>(runner);
        getIt.registerSingleton<TestLogger>(logger);

        await run(
          'package create --package SamplePackage --version-type=minor --installation-key-bypass'
              .toArguments(),
          configFileName: "",
        );

        expect(logger.errors, isEmpty);
        expect(runner.args, contains('--installation-key-bypass'));
      },
    );

    test('Forwards the target dev hub to the executed command', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=minor --target-dev-hub=MyDevHub'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--target-dev-hub=MyDevHub'));
    });

    test('Forwards the wait to the executed command', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=minor --wait=10'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--wait=10'));
    });

    test('Forwards the async validation to the executed command', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=minor --async-validation'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--async-validation'));
    });

    test('Forwards the skip validation to the executed command', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=minor --skip-validation'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--skip-validation'));
    });

    test('Forwards the verbose flag to the executed command', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner();
      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=minor --verbose'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--verbose'));
    });

    test('Executes the promote command when --promote is used', () async {
      FakeFileSystem fakeFileSystem = FakeFileSystem('sfdx-project.json', true);

      getIt.registerSingleton<Either<String, Config>>(
        Left('No config available'),
      );

      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fakeFileSystem,
      );

      final runner = TestRunner(
        simulatedOutput: """
      {
        "result": {
          "SubscriberPackageVersionId": "04t1t0000000abcAAA"
        }
      }
      """,
      );

      getIt.registerSingleton<CliRunner>(runner);
      getIt.registerSingleton<TestLogger>(logger);

      await run(
        'package create --package SamplePackage --version-type=minor --promote'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('promote'));
      expect(runner.args, contains('--package=04t1t0000000abcAAA'));
    });
  });
}

class FakeFileSystem implements FileSystem {
  final String path;
  final bool _exists;
  String contents = '';

  FakeFileSystem(this.path, this._exists);

  @override
  bool exists() => _exists;

  @override
  String readAsStringSync() => sampleSfdxProjectJson;

  @override
  void write(String content) {
    contents = content;
  }
}

String sampleSfdxProjectJson = """
{
  "packageDirectories": [
    {
      "path": "force-app",
      "default": true,
      "versionName": "2.30.0.NEXT",
      "versionNumber": "2.30.0.NEXT",
      "package": "SamplePackage"
    }
  ],
  "name": "sample-sf-project",
  "namespace": "",
  "sfdcLoginUrl": "https://login.salesforce.com",
  "sourceApiVersion": "64.0"
}
""";
