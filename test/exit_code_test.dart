import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'helpers.dart';

/// What a build server reads. Everything else cirrus reports - the red text, the stopped flow - is
/// for a person watching; the exit status is the only part CI can see, and a zero on a failure is
/// a red build reporting green.
void main() {
  late TestLogger logger;

  setUp(() {
    logger = TestLogger();
    getIt.registerSingleton<Logger>(logger);
  });

  tearDown(() {
    getIt.reset();
  });

  void withConfig(String yaml, {CliRunner? runner}) {
    getIt.registerSingleton<Either<String, Config>>(
      Right(Config.parse(asPlainMap(loadYaml(yaml)))),
    );
    getIt.registerSingleton<CliRunner>(runner ?? TestRunner());
  }

  test('is zero when a command succeeds', () async {
    withConfig("""
commands:
  hello: echo hello
""");

    expect(await run('run hello'.toArguments(), configFileName: ""), 0);
  });

  test('is non-zero when a command fails', () async {
    withConfig("""
commands:
  boom: "false"
""", runner: TestRunner(fails: true));

    expect(await run('run boom'.toArguments(), configFileName: ""), isNonZero);
  });

  test('is non-zero when a flow step fails', () async {
    withConfig("""
commands:
  boom: "false"

flows:
  demo:
    steps:
      - command: boom
""", runner: TestRunner(fails: true));

    expect(await run('flow demo'.toArguments(), configFileName: ""), isNonZero);
  });

  test('is non-zero when the command does not exist', () async {
    withConfig("""
commands:
  hello: echo hello
""");

    expect(await run('run nope'.toArguments(), configFileName: ""), isNonZero);
  });

  test('is non-zero when the config file cannot be read', () async {
    getIt.registerSingleton<Either<String, Config>>(
      Left('Was not able to load the cirrus.yaml file.'),
    );
    getIt.registerSingleton<CliRunner>(TestRunner());

    expect(await run('flow demo'.toArguments(), configFileName: ""), isNonZero);
  });
}
