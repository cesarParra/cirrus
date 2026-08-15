import 'package:cirrus/src/commands/runner.dart';
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

  group('flows', () {
    test('errors when trying to run a flow that does not exist', () async {
      registerConfig("""
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
      registerConfig("""
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
      registerConfig("""
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
      registerConfig("""
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
