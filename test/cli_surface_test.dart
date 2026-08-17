import 'dart:convert';

import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late TestLogger logger;
  late TestRunner runner;

  setUp(() {
    (logger: logger, runner: runner) = registerDoubles();
  });

  tearDown(() {
    getIt.reset();
  });

  group('arguments a flow was never going to read', () {
    const oneFlow = """
commands:
  deploy: sf project deploy start
flows:
  setup:
    steps:
      - command: deploy
""";

    test('are refused rather than accepted and dropped', () async {
      registerConfig(oneFlow);

      final status = await run(
        'flow setup -- --project=chromium'.toArguments(),
        configFileName: "",
      );

      expect(status, isNot(0));
      expect(logger.errors, hasLength(1));
      expect(logger.errors.first, contains('--project=chromium'));
      expect(runner.commands, isEmpty);
    });

    test('leave a flow given none alone', () async {
      registerConfig(oneFlow);

      final status = await run('flow setup'.toArguments(), configFileName: "");

      expect(status, 0);
      expect(logger.errors, isEmpty);
      expect(runner.commands, contains('sf project deploy start'));
    });
  });

  group('the abbreviations sf already spends', () {
    test('-v is not the version, which sf spends on the dev hub', () async {
      registerConfigFailure('no config');

      final status = await run(['-v'], configFileName: "");

      expect(status, isNot(0));
      expect(logger.errors, isNotEmpty);
    });

    test('--version still answers', () async {
      registerConfigFailure('no config');

      final status = await run(['--version'], configFileName: "");

      expect(status, 0);
      expect(logger.errors, isEmpty);
    });
  });

  group('package create says whether to bump, not which none', () {
    late FakeFileSystem fileSystem;

    setUp(() {
      fileSystem = FakeFileSystem('sfdx-project.json', true);
      getIt.registerSingleton<Either<String, Config>>(Left('No config'));
      getIt.registerFactoryParam<FileSystem, String, void>(
        (String path, _) => fileSystem,
      );
    });

    test('--no-bump still writes a version name it was given', () async {
      await run(
        'package create --package SamplePackage --no-bump --version-name="New Name"'
            .toArguments(),
        configFileName: "",
      );

      expect(logger.errors, isEmpty);
      expect(fileSystem.contents, contains('"versionName": "New Name"'));
      expect(fileSystem.contents, contains('"versionNumber": "2.30.0.NEXT"'));
    });

    test('--version-type no longer answers whether', () async {
      final status = await run(
        'package create --package SamplePackage --version-type=none'
            .toArguments(),
        configFileName: "",
      );

      expect(status, isNot(0));
      expect(runner.commands, isEmpty);
    });

    test('--name no longer means the version label', () async {
      final status = await run(
        'package create --package SamplePackage --name="New Name"'
            .toArguments(),
        configFileName: "",
      );

      expect(status, isNot(0));
      expect(jsonDecode(fileSystem.contents), isNot(contains('New Name')));
    });
  });
}
