import 'package:cirrus/src/commands/run/run.dart';
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

  group('generic commands', () {
    test('can run any defined command', () async {
      registerConfig("""
commands:
  hello: echo 'Hello, World!'
""");

      await run('run hello'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('echo'));
      expect(runner.args, contains('Hello, World!'));
    });

    test('errors when the command is not defined', () async {
      registerConfig("""
commands:
  hello: echo 'Hello, World!'
""");

      await run('run non_existent_command'.toArguments(), configFileName: "");

      expect(logger.errors, hasLength(1));
      expect(
        logger.errors.first,
        contains("Could not find a subcommand named"),
      );
      expect(
        logger.messages,
        isNotEmpty,
        reason: "Expected the 'usage' message to be printed",
      );
    });

    test('reports why the config did not load, not the command it cost', () async {
      // Every command `cirrus run` offers comes from the config file, so when that file cannot be
      // read there are no commands at all - and reporting the missing subcommand names the
      // symptom while hiding the cause.
      registerConfigFailure(
        'Found a cirrus.toml. Cirrus reads $configFileName as of 0.3.0.',
      );

      await run('run hello'.toArguments(), configFileName: "");

      expect(logger.errors, hasLength(1));
      expect(logger.errors.first, contains('Found a cirrus.toml'));
      expect(
        logger.errors.first,
        isNot(contains('Could not find a subcommand')),
      );
    });

    test('describes itself the way the command that defines it does', () {
      final described = RunNamedCommand(
        NamedCommand(
          'deploy',
          'sf project deploy start',
          description: 'Ship it to an org.',
        ),
      );
      final undescribed = RunNamedCommand(NamedCommand('hello', 'echo hi'));

      expect(described.description, 'Ship it to an org.');
      expect(undescribed.description, contains('hello'));
    });

    test('leaves a usage error alone for a command that needs no config', () async {
      // `init` exists to be run where there is no config, so a mistyped option there is the user's
      // own mistake and has to be reported as one - the config error would bury it.
      registerConfigFailure('Found a cirrus.toml.');

      await run('init --nope'.toArguments(), configFileName: "");

      expect(logger.errors.first, contains('nope'));
      expect(logger.errors.first, isNot(contains('cirrus.toml')));
    });
  });
}
