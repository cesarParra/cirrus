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

  group('flows', () {
    test('errors when trying to run a flow that does not exist', () {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
        [commands]
        hello = "echo 'Hello, World!'"

        [flow.test]
        description = "Test flow"
        steps = [{ type = "command", name = "hello" }]
        """).toMap();
      }

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );

      run('flow my_non_existent_flow'.toArguments(), configFileName: "").then((
          _,
          ) {
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
    });

    test('runs a flow with a single command', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
        [commands]
        hello = "echo 'Hello, World!'"

        [flow.test]
        description = "Test flow"
        steps = [{ type = "command", name = "hello" }]
        """).toMap();
      }

      final runner = TestRunner();

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );
      getIt.registerSingleton<CliRunner>(runner);

      await run('flow test'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('echo'));
      expect(runner.args, contains('Hello, World!'));
    });

    test('runs a flow with multiple steps', () async {
      Map<String, dynamic> parser() {
        return TomlDocument.parse("""
          [commands]
          hello = "echo 'Hello, World!'"
          goodbye = "echo 'Goodbye, World!'"

          [flow.test]
          description = "Test flow"
          steps = [
            { type = "command", name = "hello" },
            { type = "command", name = "goodbye" }
          ]
          """).toMap();
      }

      final runner = TestRunner();

      getIt.registerSingleton<Either<String, Config>>(
        Right(Config.parse(parser())),
      );
      getIt.registerSingleton<CliRunner>(runner);

      await run('flow test'.toArguments(), configFileName: "");

      expect(logger.errors, isEmpty);
      expect(runner.args, contains('echo'));
      expect(runner.args, contains('Hello, World!'));
      expect(runner.args, contains('Goodbye, World!'));
    });
  });
}