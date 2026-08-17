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
  });

  group('a name the config makes up', () {
    test('is a config error when it is not a legal command name', () {
      expect(
        () => registerConfig("""
commands:
  "deploy everything": sf project deploy start
"""),
        throwsA(contains('deploy everything')),
      );
    });

    test('is a config error when it could be read as an option', () {
      expect(
        () => registerConfig("""
commands:
  --help: sf project deploy start
"""),
        throwsA(contains('--help')),
      );
    });

    test('is a config error for a flow name too', () {
      expect(
        () => registerConfig("""
orgs:
  dev:
    definitionFile: config/dev.json
flows:
  "set up":
    steps:
      - createScratch: dev
"""),
        throwsA(contains('set up')),
      );
    });

    test('leaves a legal name alone', () {
      expect(
        () => registerConfig("""
commands:
  deploy-all_2: sf project deploy start
"""),
        returnsNormally,
      );
    });
  });
}
