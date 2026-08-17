import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
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

  const oneOrg = """
orgs:
  default:
    definitionFile: config/project-scratch-def.json
    duration: 30
""";

  group('org create', () {
    test('errors when any error occurs parsing the config file', () async {
      registerConfigFailure('yaml parsing error');

      await run('org create test'.toArguments(), configFileName: "");

      expect(logger.errors, hasLength(1));
      expect(logger.errors.first, contains('yaml parsing error'));
      expect(logger.messages, isEmpty);
    });

    test('runs the sf org scratch create command', () async {
      registerConfig(oneOrg);

      await run('org create default'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('sf'));
      expect(runner.args, contains('org'));
      expect(runner.args, contains('scratch'));
      expect(runner.args, contains('create'));
    });

    test('provides the definition file', () async {
      registerConfig(oneOrg);

      await run('org create default'.toArguments(), configFileName: "");

      expect(
        runner.args,
        contains('--definition-file=config/project-scratch-def.json'),
      );
    });

    test('provides the duration if present in the config file', () async {
      registerConfig(oneOrg);

      await run('org create default'.toArguments(), configFileName: "");

      expect(runner.args, contains('--duration-days=30'));
    });

    test('is set as default by default', () async {
      registerConfig(oneOrg);

      await run('org create default'.toArguments(), configFileName: "");

      expect(runner.args, contains('--set-default'));
    });

    test('can avoid setting as the default', () async {
      registerConfig(oneOrg);

      await run(
        'org create default --no-set-default'.toArguments(),
        configFileName: "",
      );

      expect(runner.args, isNot(contains('--set-default')));
    });

    test(
      'does not provide duration if not present in the config file',
      () async {
        registerConfig("""
orgs:
  default:
    definitionFile: config/project-scratch-def.json
""");

        await run('org create default'.toArguments(), configFileName: "");

        expect(runner.args, isNot(contains('--duration-days')));
      },
    );

    test('creates one org at a time', () async {
      registerConfig(oneOrg);

      final status = await run(
        'org create default ci'.toArguments(),
        configFileName: "",
      );

      expect(status, isNot(0));
      expect(runner.commands, isEmpty);
    });

    test('errors when the org is not defined in the config file', () async {
      registerConfig(oneOrg);

      await run(
        'org create non_existent_org'.toArguments(),
        configFileName: "",
      );

      expect(logger.errors, hasLength(1));
      expect(
        logger.errors.first,
        contains(
          "The org 'non_existent_org' is not defined in the $configFileName file.",
        ),
      );
      expect(logger.messages, isEmpty);
    });

    group('the alias the org is created under', () {
      test('is the name it is keyed by when it says nothing else', () async {
        registerConfig(oneOrg);

        await run('org create default'.toArguments(), configFileName: "");

        expect(runner.args, contains('--alias=default'));
      });

      test('is the alias the org gives', () async {
        registerConfig("""
orgs:
  ci:
    definitionFile: config/project-scratch-def.json
    alias: scratch-org
""");

        await run('org create ci'.toArguments(), configFileName: "");

        expect(runner.args, contains('--alias=scratch-org'));
        expect(runner.args, isNot(contains('--alias=ci')));
      });
    });

    group('an org that is not shaped like the project', () {
      test(
        'is created without the package namespace when it says so',
        () async {
          registerConfig("""
orgs:
  subscriber:
    definitionFile: config/subscriber.json
    namespace: false
""");

          await run('org create subscriber'.toArguments(), configFileName: "");

          expect(logger.errors, isEmpty);
          expect(runner.args, contains('--no-namespace'));
        },
      );

      test('waits as long as the org asks', () async {
        registerConfig("""
orgs:
  slow:
    definitionFile: config/subscriber.json
    wait: 25
""");

        await run('org create slow'.toArguments(), configFileName: "");

        expect(runner.args, contains('--wait=25'));
      });

      test('is neither when the org asks for neither', () async {
        registerConfig(oneOrg);

        await run('org create default'.toArguments(), configFileName: "");

        expect(runner.args, isNot(contains('--no-namespace')));
        expect(runner.args, isNot(anyElement(startsWith('--wait'))));
      });
    });

    test('sends an alias with a space in it as one argument', () async {
      // The command line is parsed back into arguments, so a value that was one thing in the
      // config has to still be one thing by the time `sf` sees it.
      registerConfig("""
orgs:
  spaced:
    definitionFile: config/dev def.json
    alias: my org
""");

      await run('org create spaced'.toArguments(), configFileName: "");

      expect(runner.args, contains('--alias=my org'));
      expect(runner.args, contains('--definition-file=config/dev def.json'));
    });

    group('when the command names no org', () {
      test('creates the one the config marks as the default', () async {
        registerConfig("""
defaultOrg: ci
orgs:
  dev:
    definitionFile: config/dev.json
  ci:
    definitionFile: config/ci.json
""");

        await run('org create'.toArguments(), configFileName: "");

        expect(logger.errors, isEmpty);
        expect(runner.args, contains('--definition-file=config/ci.json'));
      });

      test('says so when no org is marked', () async {
        registerConfig(oneOrg);

        await run('org create'.toArguments(), configFileName: "");

        expect(logger.errors, hasLength(1));
        expect(logger.errors.first, contains('defaultOrg'));
      });
    });
  });
}
