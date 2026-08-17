import 'package:cirrus/src/commands/package/get_latest.dart';
import 'package:cirrus/src/sfdx_project_json.dart';
import 'package:test/test.dart';

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

  group('package create', () {
    test('Errors when there is no sfdx-project.json file', () async {
      registerSfdxProject(exists: false);

      await run('package create'.toArguments(), configFileName: "");

      expect(logger.errors, hasLength(1));
      expect(
        logger.errors.first,
        contains('sfdx-project.json file not found in the current directory.'),
      );
    });

    test('Increments the major version', () async {
      final (files: fakeFileSystem, :runner) = registerSfdxProject();

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

    test('leaves the version alone when asked for no bump', () async {
      // A project whose versionNumber ends in `.NEXT` lets Salesforce move the build number, so a
      // pipeline that cuts a version per night must not rewrite the file it checked out.
      final (files: fakeFileSystem, :runner) = registerSfdxProject();

      final before = fakeFileSystem.contents;

      await run(
        'package create --package SamplePackage --no-bump'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(
        fakeFileSystem.contents,
        before,
        reason: 'Expected sfdx-project.json to be left as it was found',
      );
      expect(
        fakeFileSystem.contents,
        contains('"versionNumber":"2.30.0.NEXT"'),
      );
      expect(runner.args, contains('--package=SamplePackage'));
    });

    test('refuses --version-type=none, which --no-bump answers', () async {
      final (files: fileSystem, :runner) = registerSfdxProject();
      final before = fileSystem.contents;

      final status = await run(
        'package create --package SamplePackage --version-type=none'
            .toArguments(),
        configFileName: "",
      );

      expect(status, isNot(0));
      expect(runner.commands, isEmpty);
      expect(fileSystem.contents, before);
    });

    test('refuses --no-bump alongside an explicit --version-type', () async {
      final (files: fileSystem, :runner) = registerSfdxProject();
      final before = fileSystem.contents;

      final status = await run(
        'package create --package SamplePackage --no-bump --version-type=major'
            .toArguments(),
        configFileName: "",
      );

      expect(status, isNot(0));
      expect(runner.commands, isEmpty);
      expect(fileSystem.contents, before);
    });

    test('refuses --name, which is now --version-name', () async {
      final fileSystem = registerSfdxProject().files;

      final status = await run(
        'package create --package SamplePackage --name="New Name"'
            .toArguments(),
        configFileName: "",
      );

      expect(status, isNot(0));
      expect(fileSystem.contents, isNot(contains('New Name')));
    });

    test('writes a version name alongside --no-bump', () async {
      final fileSystem = registerSfdxProject().files;

      await run(
        'package create --package SamplePackage --no-bump --version-name="New Name"'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(fileSystem.contents, contains('"versionName": "New Name"'));
      expect(fileSystem.contents, contains('"versionNumber": "2.30.0.NEXT"'));
    });

    test('Increments the minor version', () async {
      final (files: fakeFileSystem, :runner) = registerSfdxProject();

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
      final (files: fakeFileSystem, :runner) = registerSfdxProject();

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

    test('Keeps any extra fields in the package directory', () async {
      final (files: fakeFileSystem, :runner) = registerSfdxProject();

      await run(
        'package create --package SamplePackage --version-type=minor'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(fakeFileSystem.contents, isNotEmpty);
      expect(
        fakeFileSystem.contents,
        contains('"path": "packages/SamplePackage"'),
      );
      expect(runner.args, contains('--package=SamplePackage'));
    });

    test('Updates the name', () async {
      final (files: fakeFileSystem, :runner) = registerSfdxProject();

      await run(
        'package create --package SamplePackage --version-type=minor --version-name="New Name"'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(fakeFileSystem.contents, contains('"versionName": "New Name"'));
    });

    test('Forwards the code coverage to the executed command', () async {
      final runner = registerSfdxProject().runner;

      await run(
        'package create --package SamplePackage --version-type=minor --code-coverage'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--code-coverage'));
    });

    test('Forwards the definition file to the executed command', () async {
      final runner = registerSfdxProject().runner;

      await run(
        'package create --package SamplePackage --version-type=minor --definition-file=config/definition.json'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--definition-file=config/definition.json'));
    });

    test('Forwards the installation key to the executed command', () async {
      final runner = registerSfdxProject().runner;

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
        final runner = registerSfdxProject().runner;
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
      final runner = registerSfdxProject().runner;

      await run(
        'package create --package SamplePackage --version-type=minor --target-dev-hub=MyDevHub'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--target-dev-hub=MyDevHub'));
    });

    test('Forwards the wait to the executed command', () async {
      final runner = registerSfdxProject().runner;

      await run(
        'package create --package SamplePackage --version-type=minor --wait=10'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--wait=10'));
    });

    test('Forwards the async validation to the executed command', () async {
      final runner = registerSfdxProject().runner;

      await run(
        'package create --package SamplePackage --version-type=minor --async-validation'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--async-validation'));
    });

    test('Forwards the skip validation to the executed command', () async {
      final runner = registerSfdxProject().runner;

      await run(
        'package create --package SamplePackage --version-type=minor --skip-validation'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--skip-validation'));
    });

    test('Forwards the verbose flag to the executed command', () async {
      final runner = registerSfdxProject().runner;

      await run(
        'package create --package SamplePackage --version-type=minor --verbose'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--verbose'));
    });

    test('Executes the promote command when --promote is used', () async {
      final runner = registerSfdxProject(
        simulatedOutput: """
      {
        "result": {
          "SubscriberPackageVersionId": "04t1t0000000abcAAA"
        }
      }
      """,
      ).runner;
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

  group('package get_latest', () {
    group('package alias', () {
      test('errors when there is no sfdx-project.json file', () async {
        registerSfdxProject(exists: false);

        await run(
          'package get_latest --package SamplePackage'.toArguments(),
          configFileName: "",
        );

        expect(logger.errors, hasLength(1));
        expect(
          logger.errors.first,
          contains(
            'sfdx-project.json file not found in the current directory.',
          ),
        );
      });

      test(
        'errors when the alias block does not exist in the sfdx-project.json file',
        () async {
          registerSfdxProject();

          await run(
            'package get_latest --package SamplePackage'.toArguments(),
            configFileName: "",
          );

          expect(logger.errors, hasLength(1));
          expect(
            logger.errors.first,
            contains('SamplePackage was not found in the packageAliases'),
          );
        },
      );

      test(
        'errors when the alias does not exist in the sfdx-project.json file',
        () async {
          final fakeFileSystem = registerSfdxProject().files;

          fakeFileSystem.contents = SfdxProjectJson(
            packageDirectories: [
              PackageDirectory(
                package: 'SamplePackage',
                versionNumber: '2.30.0.NEXT',
              ),
            ],
            packageAliases: {'AnotherPackage': '04t1t0000000xyzAAA'},
          ).toJson().encoded();

          await run(
            'package get_latest --package SamplePackage'.toArguments(),
            configFileName: "",
          );

          expect(logger.errors, hasLength(1));
          expect(
            logger.errors.first,
            contains('SamplePackage was not found in the packageAliases'),
          );
        },
      );

      test('returns successful result when the alias exists', () async {
        final testPackageVersion = PackageVersion(
          majorVersion: 2,
          minorVersion: 30,
          patchVersion: 0,
          buildNumber: 1,
          subscriberPackageVersionId: "04t1t0000000abcAAA",
          name: "SamplePackage Version",
          namespacePrefix: "",
          description: "",
          isPasswordProtected: false,
          isReleased: false,
          installUrl: "",
        );

        final (files: fakeFileSystem, :runner) = registerSfdxProject(
          simulatedOutput:
              """
      {
        "result": [
          ${testPackageVersion.toJson().encoded()}
        ]
      }
      """,
        );

        fakeFileSystem.contents = SfdxProjectJson(
          packageDirectories: [
            PackageDirectory(
              package: 'SamplePackage',
              versionNumber: '2.31.0.NEXT',
            ),
          ],
          packageAliases: {'SamplePackage': '04t1t0000000abcAAA'},
        ).toJson().encoded();

        await run(
          'package get_latest --package SamplePackage'.toArguments(),
          configFileName: "",
        );

        expect(logger.errors, isEmpty);
        expect(runner.args, contains('04t1t0000000abcAAA'));
      });
    });
  });
}
