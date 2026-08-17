import 'package:cirrus/src/commands/flow/flow.dart';
import 'package:cirrus/src/commands/run/run.dart';
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

  group('the run namespace holds only what the config defines', () {
    test('a command may take the name a built-in used to have', () async {
      registerConfig("""
commands:
  create_scratch: ./scripts/my-own-org-setup.sh
""");

      final status = await run(
        'run create_scratch'.toArguments(),
        configFileName: "",
      );

      expect(status, 0);
      expect(logger.errors, isEmpty);
      expect(runner.commands, contains('./scripts/my-own-org-setup.sh'));
    });

    test('and no such name takes the whole CLI down', () async {
      registerConfig("""
commands:
  create_scratch: ./scripts/my-own-org-setup.sh
""");

      final status = await run(['--version'], configFileName: "");

      expect(status, 0);
      expect(logger.errors, isEmpty);
    });

    test('so a config naming none leaves both topics empty', () {
      registerConfig('');

      // The property, not the instance: `create_scratch` passing is only evidence about
      // `create_scratch`. This fails the moment any built-in is added back to either topic, which
      // is what reopens the collision the whole namespace change closed.
      final runner = CirrusCommandRunner()
        ..addCommand(RunCommand())
        ..addCommand(FlowCommand());

      expect(runner.commands['run']!.subcommands, isEmpty);
      expect(runner.commands['flow']!.subcommands, isEmpty);
    });
  });

  group('a config that names no commands', () {
    test('says so rather than failing to dispatch', () async {
      registerConfig('');

      final status = await run(
        'run anything'.toArguments(),
        configFileName: "",
      );

      expect(status, isNot(0));
      expect(logger.errors, hasLength(1));
      expect(logger.errors.first, contains('No commands are defined'));
      expect(runner.commands, isEmpty);
    });
  });
}
