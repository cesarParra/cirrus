import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// One command, two callers wanting different arguments: the pull-request build runs the suite in
/// one browser and the merge build runs it in all of them. Without this the config needs a command
/// per caller, which is the duplication the config exists to remove.
void main() {
  late TestRunner runner;

  tearDown(() {
    getIt.reset();
  });

  test('what follows -- is appended to the command', () async {
    (runner: runner, logger: _) = withConfig("""
commands:
  e2e: playwright test
""");

    await run(
      'run e2e -- --project=chromium --workers=1'.toArguments(),
      configFileName: "",
    );

    expect(runner.commands, ['playwright test --project=chromium --workers=1']);
  });

  test('an argument holding a space survives as one argument', () async {
    (runner: runner, logger: _) = withConfig("""
commands:
  greet: echo
""");

    await run(['run', 'greet', '--', 'hello world'], configFileName: "");

    expect(runner.args, ['echo', 'hello world']);
  });

  test('prerequisites are left as they are written', () async {
    // The arguments belong to the command that was asked for, not to everything it drags in.
    (runner: runner, logger: _) = withConfig("""
commands:
  build: echo building
  e2e:
    run: playwright test
    dependsOn: [build]
""");

    await run(
      'run e2e -- --project=chromium'.toArguments(),
      configFileName: "",
    );

    expect(runner.commands, [
      'echo building',
      'playwright test --project=chromium',
    ]);
  });
}
