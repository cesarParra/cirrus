import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';
import 'package:toml/toml.dart';

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
}