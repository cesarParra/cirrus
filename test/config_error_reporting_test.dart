import 'package:cirrus/src/commands/flow/flow.dart';
import 'package:cirrus/src/commands/run/run.dart';
import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// A command whose subcommands come out of the config file has none when the file did not load, so
/// dispatching it reports a missing subcommand - the symptom - while the cause goes unmentioned.
/// Which command was invoked is what decides whether the cause is worth saying.
void main() {
  late TestLogger logger;

  setUp(() {
    (logger: logger, runner: _) = registerDoubles();
  });

  tearDown(() {
    getIt.reset();
  });

  test('names the cause when the command needs a config', () async {
    registerConfigFailure('yaml parsing error');

    await run('run anything'.toArguments(), configFileName: "");

    expect(logger.errors.single, contains('yaml parsing error'));
  });

  test('finds the command however the arguments reach it', () async {
    // The invoked command is read off the parse, not off `arguments.first`. A global option ahead
    // of the command is what tells those two apart, and the day one takes a value is the day the
    // cause silently stops being reported.
    registerConfigFailure('yaml parsing error');

    await run('--help run'.toArguments(), configFileName: "");

    expect(
      logger.errors.where((e) => e.contains('yaml parsing error')),
      isNotEmpty,
      reason: 'the cause is the same wherever the command sits in argv',
    );
  });

  test('no config-fed subcommand carries an alias', () {
    // `addSubcommand` registers a command under its name *and* every alias, in the one namespace
    // `args` refuses a duplicate in - while the runner is being built, which takes the whole CLI
    // down rather than one command. Names are checked when the config is read; aliases would not
    // be, so the safe number of them is none.
    registerConfig("""
commands:
  deploy: sf project deploy start
flows:
  setup:
    steps:
      - command: deploy
""");

    final runner = CirrusCommandRunner()
      ..addCommand(RunCommand())
      ..addCommand(FlowCommand());

    for (final topic in ['run', 'flow']) {
      for (final sub in runner.commands[topic]!.subcommands.values) {
        expect(sub.aliases, isEmpty, reason: '$topic ${sub.name}');
      }
    }
  });
}
