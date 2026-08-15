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

  group('flows', () {
    test('errors when trying to run a flow that does not exist', () async {
      withConfig("""
commands:
  hello: echo 'Hello, World!'

flows:
  test:
    description: Test flow
    steps:
      - command: hello
""");

      await run('flow my_non_existent_flow'.toArguments(), configFileName: "");

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

    test('runs a flow with a single command', () async {
      withConfig("""
commands:
  hello: echo 'Hello, World!'

flows:
  test:
    description: Test flow
    steps:
      - command: hello
""");

      await run('flow test'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('echo'));
      expect(runner.args, contains('Hello, World!'));
    });

    test('runs a flow with multiple steps', () async {
      withConfig("""
commands:
  hello: echo 'Hello, World!'
  goodbye: echo 'Goodbye, World!'

flows:
  test:
    description: Test flow
    steps:
      - command: hello
      - command: goodbye
""");

      await run('flow test'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('echo'));
      expect(runner.args, contains('Hello, World!'));
      expect(runner.args, contains('Goodbye, World!'));
    });

    test('creates a scratch org from a flow step', () async {
      withConfig("""
orgs:
  dev:
    definitionFile: config/dev.json

flows:
  setup:
    steps:
      - createScratch: dev
        setDefault: true
""");

      await run('flow setup'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('--definition-file=config/dev.json'));
      expect(runner.args, contains('--set-default'));
    });
  });
}
