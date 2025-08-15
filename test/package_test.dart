import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/service_locator.dart';
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
