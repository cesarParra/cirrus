import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// A prerequisite, not a step: `dependsOn` says what has to have happened before this can run, and
/// each of them happens once however many times it is named. Steps are the other thing - an order
/// somebody wrote down, where naming the same command twice means running it twice.
void main() {
  late TestLogger logger;
  late TestRunner runner;

  setUp(() {
    (logger: logger, runner: runner) = registerDoubles();
  });

  tearDown(() {
    getIt.reset();
  });

  /// The commands the runner was asked to run, in the order it was asked.
  List<String> ran() => runner.commands;

  group('a command with prerequisites', () {
    test('runs them before itself', () async {
      registerConfig("""
commands:
  build: echo building
  test:
    run: echo testing
    dependsOn: [build]
""");

      await run('run test'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(ran(), ['echo building', 'echo testing']);
    });

    test('runs them in the order they are written', () async {
      registerConfig("""
commands:
  tw: echo tailwind
  lwc: echo lwc
  core: echo core
  build:
    dependsOn: [tw, lwc, core]
""");

      await run('run build'.toArguments(), configFileName: "");

      expect(ran(), ['echo tailwind', 'echo lwc', 'echo core']);
    });

    test('runs a prerequisite of a prerequisite first', () async {
      registerConfig("""
commands:
  tw: echo tailwind
  build:
    run: echo building
    dependsOn: [tw]
  check:
    run: echo checking
    dependsOn: [build]
""");

      await run('run check'.toArguments(), configFileName: "");

      expect(ran(), ['echo tailwind', 'echo building', 'echo checking']);
    });

    test('runs a shared prerequisite once', () async {
      registerConfig("""
commands:
  build: echo building
  lint:
    run: echo linting
    dependsOn: [build]
  test:
    run: echo testing
    dependsOn: [build]
  check:
    dependsOn: [lint, test]
""");

      await run('run check'.toArguments(), configFileName: "");

      expect(ran(), ['echo building', 'echo linting', 'echo testing']);
    });

    test('needs no command line of its own', () async {
      registerConfig("""
commands:
  lint: echo linting
  check:
    description: Am I done?
    dependsOn: [lint]
""");

      await run('run check'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(ran(), ['echo linting']);
    });

    test('does not run when a prerequisite fails', () async {
      await getIt.reset();
      (logger: logger, runner: runner) = registerDoubles(failing: true);
      registerConfig("""
commands:
  build: exit 1
  test:
    run: echo testing
    dependsOn: [build]
""");

      final status = await run('run test'.toArguments(), configFileName: "");

      expect(status, isNonZero);
      expect(ran(), ['exit 1']);
    });
  });

  group('a flow with prerequisites', () {
    test('runs them before its first step', () async {
      registerConfig("""
commands:
  build: echo building
  deploy: echo deploying

flows:
  release:
    dependsOn: [build]
    steps:
      - command: deploy
""");

      await run('flow release'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(ran(), ['echo building', 'echo deploying']);
    });

    test('runs a prerequisite of a step it shares once', () async {
      registerConfig("""
commands:
  build: echo building
  deploy:
    run: echo deploying
    dependsOn: [build]

flows:
  release:
    dependsOn: [build]
    steps:
      - command: deploy
""");

      await run('flow release'.toArguments(), configFileName: "");

      expect(ran(), ['echo building', 'echo deploying']);
    });

    test('runs a command named twice in its steps twice', () async {
      // Steps are an order somebody wrote down, and repeating one is a thing they can mean.
      registerConfig("""
commands:
  deploy: echo deploying

flows:
  twice:
    steps:
      - command: deploy
      - command: deploy
""");

      await run('flow twice'.toArguments(), configFileName: "");

      expect(ran(), ['echo deploying', 'echo deploying']);
    });
  });

  group('a config that cannot be run', () {
    test('is refused when a prerequisite is not a command', () {
      expect(
        () => Config.fromYaml("""
commands:
  test:
    run: echo testing
    dependsOn: [build]
"""),
        throwsA(allOf(contains('test'), contains('build'))),
      );
    });

    test('is refused when the prerequisites form a cycle', () {
      expect(
        () => Config.fromYaml("""
commands:
  a:
    run: echo a
    dependsOn: [b]
  b:
    run: echo b
    dependsOn: [a]
"""),
        throwsA(allOf(contains('a'), contains('b'))),
      );
    });

    test('is refused when a command depends on itself', () {
      expect(
        () => Config.fromYaml("""
commands:
  a:
    run: echo a
    dependsOn: [a]
"""),
        throwsA(contains('a')),
      );
    });

    test(
      'is refused when a flow depends on something that is not a command',
      () {
        expect(
          () => Config.fromYaml("""
flows:
  release:
    dependsOn: [build]
    steps:
      - command: deploy
"""),
          throwsA(allOf(contains('release'), contains('build'))),
        );
      },
    );
  });
}
