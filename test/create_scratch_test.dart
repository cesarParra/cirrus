import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'helpers.dart';

void main() {
  late TestLogger logger;
  late TestRunner runner;

  setUp(() {
    logger = TestLogger();
    runner = TestRunner();
    getIt.registerSingleton<Logger>(logger);
    getIt.registerSingleton<CliRunner>(runner);
  });

  tearDown(() {
    getIt.reset();
  });

  void withConfig(String yaml) {
    getIt.registerSingleton<Either<String, Config>>(
      Right(Config.parse(asPlainMap(loadYaml(yaml)))),
    );
  }

  const oneOrg = """
orgs:
  default:
    definitionFile: config/project-scratch-def.json
    duration: 30
""";

  group('create_scratch', () {
    test('errors when any error occurs parsing the config file', () async {
      getIt.registerSingleton<Either<String, Config>>(
        Left('yaml parsing error'),
      );

      await run(
        'run create_scratch --name=test'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, hasLength(1));
      expect(logger.errors.first, contains('yaml parsing error'));
      expect(logger.messages, isEmpty);
    });

    test('runs the sf org scratch create command', () async {
      withConfig(oneOrg);

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
      withConfig(oneOrg);

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
      withConfig(oneOrg);

      await run(
        'run create_scratch -n default'.toArguments(),
        configFileName: "",
      );

      expect(runner.args, contains('--duration-days=30'));
    });

    test('is set as default by default', () async {
      withConfig(oneOrg);

      await run(
        'run create_scratch -n default'.toArguments(),
        configFileName: "",
      );

      expect(runner.args, contains('--set-default'));
    });

    test('can avoid setting as the default', () async {
      withConfig(oneOrg);

      await run(
        'run create_scratch -n default --no-set-default'.toArguments(),
        configFileName: "",
      );

      expect(runner.args, isNot(contains('--set-default')));
    });

    test(
      'does not provide duration if not present in the config file',
      () async {
        withConfig("""
orgs:
  default:
    definitionFile: config/project-scratch-def.json
""");

        await run(
          'run create_scratch -n default'.toArguments(),
          configFileName: "",
        );

        expect(runner.args, isNot(contains('--duration-days')));
      },
    );

    test('errors when the org is not defined in the config file', () async {
      withConfig(oneOrg);

      await run(
        'run create_scratch -n non_existent_org'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, hasLength(1));
      expect(
        logger.errors.first,
        contains(
          "The org 'non_existent_org' is not defined in the cirrus.yaml file.",
        ),
      );
      expect(logger.messages, isEmpty);
    });

    group('the alias the org is created under', () {
      test('is the name it is keyed by when it says nothing else', () async {
        withConfig(oneOrg);

        await run(
          'run create_scratch -n default'.toArguments(),
          configFileName: "",
        );

        expect(runner.args, contains('--alias=default'));
      });

      test('is the alias the org gives', () async {
        withConfig("""
orgs:
  ci:
    definitionFile: config/project-scratch-def.json
    alias: scratch-org
""");

        await run('run create_scratch -n ci'.toArguments(), configFileName: "");

        expect(runner.args, contains('--alias=scratch-org'));
        expect(runner.args, isNot(contains('--alias=ci')));
      });
    });

    group('when the command names no org', () {
      test('creates the one the config marks as the default', () async {
        withConfig("""
orgs:
  dev:
    definitionFile: config/dev.json
  ci:
    definitionFile: config/ci.json
    default: true
""");

        await run('run create_scratch'.toArguments(), configFileName: "");

        expect(logger.errors, isEmpty);
        expect(runner.args, contains('--definition-file=config/ci.json'));
      });

      test('says so when no org is marked', () async {
        withConfig(oneOrg);

        await run('run create_scratch'.toArguments(), configFileName: "");

        expect(logger.errors, hasLength(1));
        expect(logger.errors.first, contains("default: true"));
        expect(logger.errors.first, contains('default'));
      });

      test('refuses a config where two orgs are the default', () async {
        expect(
          () => withConfig("""
orgs:
  dev:
    definitionFile: config/dev.json
    default: true
  ci:
    definitionFile: config/ci.json
    default: true
"""),
          throwsA(allOf(contains('dev'), contains('ci'))),
        );
      });
    });
  });
}
