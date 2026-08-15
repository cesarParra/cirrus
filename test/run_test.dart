import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

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

  group('generic commands', () {
    test('can run any defined command', () async {
      Map<String, dynamic> parser() {
        return asPlainMap(
          loadYaml("""
commands:
  hello: echo 'Hello, World!'
"""),
        );
      }

      final runner = TestRunner();

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );
      getIt.registerSingleton<CliRunner>(runner);

      await run('run hello'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('echo'));
      expect(runner.args, contains('Hello, World!'));
    });

    test('errors when the command is not defined', () async {
      Map<String, dynamic> parser() {
        return asPlainMap(
          loadYaml("""
commands:
  hello: echo 'Hello, World!'
"""),
        );
      }

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );

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
      getIt.registerSingleton<Either<String, Config>>(
        Left('Found a cirrus.toml. Cirrus reads cirrus.yaml as of 0.3.0.'),
      );

      await run('run hello'.toArguments(), configFileName: "");

      expect(logger.errors, hasLength(1));
      expect(logger.errors.first, contains('Found a cirrus.toml'));
      expect(
        logger.errors.first,
        isNot(contains('Could not find a subcommand')),
      );
    });
  });
}
