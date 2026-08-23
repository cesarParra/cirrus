import 'dart:convert';
import 'package:cirrus/src/commands/package/versions.dart';
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

  group('package install', () {
    PackageVersion aVersion({
      int build = 1,
      String id = '04t1t0000000abcAAA',
      int major = 2,
      String created = '2025-01-01 00:00',
    }) => PackageVersion(
      majorVersion: major,
      minorVersion: 30,
      patchVersion: 0,
      buildNumber: build,
      subscriberPackageVersionId: id,
      name: "SamplePackage Version",
      namespacePrefix: "",
      description: "",
      isPasswordProtected: false,
      isReleased: false,
      installUrl: "",
      createdDate: created,
    );

    String listing(List<PackageVersion> versions) =>
        '{"result": [${versions.map((v) => v.toJson().encoded()).join(',')}]}';

    test('installs a version id as given, without asking which is latest', () async {
      final runner = registerSfdxProject().runner;

      await run(
        'package install --package 04t1t0000000abcAAA -o MyOrg'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.commands, hasLength(1));
      expect(runner.commands.first, contains('sf package install'));
      expect(runner.args, contains('--package=04t1t0000000abcAAA'));
      expect(runner.args, contains('--target-org=MyOrg'));
    });

    test('installs the newest version of a package named by alias', () async {
      final (files: files, :runner) = registerSfdxProject(
        simulatedOutput: listing([
          aVersion(build: 1, id: '04t1t0000000oldAAA', created: '2025-01-01 00:00'),
          aVersion(build: 9, id: '04t1t0000000newAAA', created: '2026-01-01 00:00'),
        ]),
      );
      files.contents = SfdxProjectJson(
        packageDirectories: [PackageDirectory(package: 'SamplePackage')],
        packageAliases: {'SamplePackage': '0Ho1t0000000abcAAA'},
      ).toJson().encoded();

      await run(
        'package install --package SamplePackage'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--package=04t1t0000000newAAA'));
    });

    /// A package refuses to install without them, so the order is the whole point.
    test('installs the dependencies the project names before the package', () async {
      final (files: files, :runner) = registerSfdxProject(
        simulatedOutput: listing([aVersion(id: '04t1t0000000abcAAA')]),
      );
      files.contents = jsonEncode({
        'packageDirectories': [
          {
            'package': 'SamplePackage',
            'dependencies': [
              {'package': '04t1t0000000depAAA'},
            ],
          },
        ],
        'packageAliases': {'SamplePackage': '0Ho1t0000000abcAAA'},
      });

      await run(
        'package install --package SamplePackage --with-dependencies'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      final installs = runner.commands
          .where((command) => command.contains('sf package install'))
          .toList();
      expect(installs, hasLength(2));
      expect(installs.first, contains('04t1t0000000depAAA'));
      expect(installs.last, contains('04t1t0000000abcAAA'));
    });

    test('resolves a dependency named by alias rather than by id', () async {
      final (files: files, :runner) = registerSfdxProject(
        simulatedOutput: listing([aVersion(id: '04t1t0000000abcAAA')]),
      );
      files.contents = jsonEncode({
        'packageDirectories': [
          {
            'package': 'SamplePackage',
            'dependencies': [
              {'package': 'OtherPackage'},
            ],
          },
        ],
        'packageAliases': {
          'SamplePackage': '0Ho1t0000000abcAAA',
          'OtherPackage': '04t1t0000000othAAA',
        },
      });

      await run(
        'package install --package SamplePackage --with-dependencies'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.commands.first, contains('04t1t0000000othAAA'));
    });

    test('says so when a named dependency resolves to nothing', () async {
      final files = registerSfdxProject().files;
      files.contents = jsonEncode({
        'packageDirectories': [
          {
            'package': 'SamplePackage',
            'dependencies': [
              {'package': 'MissingPackage'},
            ],
          },
        ],
        'packageAliases': {'SamplePackage': '0Ho1t0000000abcAAA'},
      });

      await run(
        'package install --package SamplePackage --with-dependencies'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, hasLength(1));
      expect(logger.errors.first, contains('MissingPackage'));
    });

    test('leaves dependencies alone unless asked for them', () async {
      final (files: files, :runner) = registerSfdxProject(
        simulatedOutput: listing([aVersion(id: '04t1t0000000abcAAA')]),
      );
      files.contents = jsonEncode({
        'packageDirectories': [
          {
            'package': 'SamplePackage',
            'dependencies': [
              {'package': '04t1t0000000depAAA'},
            ],
          },
        ],
        'packageAliases': {'SamplePackage': '0Ho1t0000000abcAAA'},
      });

      await run(
        'package install --package SamplePackage'.toArguments(),
        configFileName: "",
      );

      expect(
        runner.commands.where((c) => c.contains('sf package install')),
        hasLength(1),
      );
    });

    /// A project that moves off calendar versioning makes its newest build the lowest-numbered
    /// one, and the highest number then names a build from before the change.
    test('installs the most recently built version, not the highest numbered', () async {
      final (files: files, :runner) = registerSfdxProject(
        simulatedOutput: listing([
          aVersion(major: 2025, build: 3, id: '04t1t0000000oldAAA', created: '2025-05-11 09:00'),
          aVersion(major: 0, build: 28, id: '04t1t0000000newAAA', created: '2026-08-23 09:00'),
        ]),
      );
      files.contents = SfdxProjectJson(
        packageDirectories: [PackageDirectory(package: 'SamplePackage')],
        packageAliases: {'SamplePackage': '0Ho1t0000000abcAAA'},
      ).toJson().encoded();

      await run(
        'package install --package SamplePackage'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--package=04t1t0000000newAAA'));
    });

    test('says so when the package has no versions to install', () async {
      final (files: files, :runner) = registerSfdxProject(
        simulatedOutput: '{"result": []}',
      );
      files.contents = SfdxProjectJson(
        packageDirectories: [PackageDirectory(package: 'SamplePackage')],
        packageAliases: {'SamplePackage': '0Ho1t0000000abcAAA'},
      ).toJson().encoded();

      await run(
        'package install --package SamplePackage'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, hasLength(1));
      expect(logger.errors.first, contains('cirrus package create'));
    });
  });

  group('package get_latest --json', () {
    test('emits the version as JSON another command can read', () async {
      final (files: files, :runner) = registerSfdxProject(
        simulatedOutput:
            '{"result": [${PackageVersion(majorVersion: 2, minorVersion: 30, patchVersion: 0, buildNumber: 7, subscriberPackageVersionId: "04t1t0000000abcAAA", name: "", namespacePrefix: "", description: "", isPasswordProtected: false, isReleased: true, installUrl: "").toJson().encoded()}]}',
      );
      files.contents = SfdxProjectJson(
        packageDirectories: [PackageDirectory(package: 'SamplePackage')],
        packageAliases: {'SamplePackage': '0Ho1t0000000abcAAA'},
      ).toJson().encoded();

      await run(
        'package get_latest --package SamplePackage --json'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      final reported = jsonDecode(logger.successes.last) as Map<String, dynamic>;
      expect(
        reported['result']['SubscriberPackageVersionId'],
        equals('04t1t0000000abcAAA'),
      );
    });
  });
}
