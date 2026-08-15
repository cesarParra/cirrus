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

  tearDown(() {
    getIt.reset();
  });

  group('a command with prerequisites', () {
    test('runs them before itself', () async {
      (logger: logger, runner: runner) = withConfig("""
commands:
  build: echo building
  test:
    run: echo testing
    dependsOn: [build]
""");

      await run('run test'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.commands, ['echo building', 'echo testing']);
    });

    test('runs them in the order they are written', () async {
      (logger: logger, runner: runner) = withConfig("""
commands:
  tw: echo tailwind
  lwc: echo lwc
  core: echo core
  build:
    dependsOn: [tw, lwc, core]
""");

      await run('run build'.toArguments(), configFileName: "");

      expect(runner.commands, ['echo tailwind', 'echo lwc', 'echo core']);
    });

    test('runs a prerequisite of a prerequisite first', () async {
      (logger: logger, runner: runner) = withConfig("""
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

      expect(runner.commands, [
        'echo tailwind',
        'echo building',
        'echo checking',
      ]);
    });

    test('runs a shared prerequisite once', () async {
      (logger: logger, runner: runner) = withConfig("""
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

      expect(runner.commands, [
        'echo building',
        'echo linting',
        'echo testing',
      ]);
    });

    test('needs no command line of its own', () async {
      (logger: logger, runner: runner) = withConfig("""
commands:
  lint: echo linting
  check:
    description: Am I done?
    dependsOn: [lint]
""");

      await run('run check'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.commands, ['echo linting']);
    });

    test('does not run when a prerequisite fails', () async {
      (logger: logger, runner: runner) = withConfig("""
commands:
  build: exit 1
  test:
    run: echo testing
    dependsOn: [build]
""", failing: true);

      final status = await run('run test'.toArguments(), configFileName: "");

      expect(status, isNonZero);
      expect(runner.commands, ['exit 1']);
    });
  });

  group('a flow with prerequisites', () {
    test('runs them before its first step', () async {
      (logger: logger, runner: runner) = withConfig("""
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
      expect(runner.commands, ['echo building', 'echo deploying']);
    });

    test('runs a prerequisite of a step it shares once', () async {
      (logger: logger, runner: runner) = withConfig("""
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

      expect(runner.commands, ['echo building', 'echo deploying']);
    });

    test('runs a command named twice in its steps twice', () async {
      // Steps are an order somebody wrote down, and repeating one is a thing they can mean.
      (logger: logger, runner: runner) = withConfig("""
commands:
  deploy: echo deploying

flows:
  twice:
    steps:
      - command: deploy
      - command: deploy
""");

      await run('flow twice'.toArguments(), configFileName: "");

      expect(runner.commands, ['echo deploying', 'echo deploying']);
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

    test('is refused when a flow step names no command', () {
      // The failure this exists to prevent: found while running, the flow has already created an
      // org and deployed into it before reaching the step that names nothing.
      expect(
        () => Config.fromYaml("""
commands:
  deploy: echo deploying

flows:
  release:
    steps:
      - command: deploy
      - command: nope
"""),
        throwsA(allOf(contains('release'), contains('nope'))),
      );
    });

    test('is refused when a flow step names no org', () {
      expect(
        () => Config.fromYaml("""
flows:
  release:
    steps:
      - createScratch: nope
"""),
        throwsA(allOf(contains('release'), contains('nope'))),
      );
    });

    test('names the cycle rather than the way into it', () {
      expect(
        () => Config.fromYaml("""
commands:
  a:
    run: echo a
    dependsOn: [b]
  b:
    run: echo b
    dependsOn: [c]
  c:
    run: echo c
    dependsOn: [b]
"""),
        throwsA(allOf(contains("'b' -> 'c' -> 'b'"), isNot(contains("'a'")))),
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
