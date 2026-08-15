import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// What a build server reads. Everything else cirrus reports - the red text, the stopped flow - is
/// for a person watching; the exit status is the only part CI can see, and a zero on a failure is
/// a red build reporting green.
void main() {
  tearDown(() {
    getIt.reset();
  });

  void withConfig(String yaml, {bool failing = false}) {
    registerDoubles(failing: failing);
    registerConfig(yaml);
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
""", failing: true);

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
""", failing: true);

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
    registerDoubles();
    registerConfigFailure('Was not able to load the $configFileName file.');

    expect(await run('flow demo'.toArguments(), configFileName: ""), isNonZero);
  });
}
