import 'package:cirrus/src/config.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

Config parse(String yaml) => Config.parse(asPlainMap(loadYaml(yaml)));

void main() {
  group('orgs', () {
    test('are keyed by name', () {
      final config = parse("""
orgs:
  dev:
    definitionFile: config/dev.json
    duration: 30
  ci:
    definitionFile: config/ci.json
""");

      expect(config.scratchOrgDefinitions.map((o) => o.name), ['dev', 'ci']);
      expect(
        config.scratchOrgDefinitions.first.definitionFile,
        'config/dev.json',
      );
      expect(config.scratchOrgDefinitions.first.duration, 30);
      expect(config.scratchOrgDefinitions.last.duration, isNull);
    });

    test('report the org that is missing its definition file', () {
      expect(
        () => parse("""
orgs:
  dev:
    duration: 30
"""),
        throwsA(contains('dev')),
      );
    });
  });

  group('commands', () {
    test('a bare string is the command to run', () {
      final config = parse("""
commands:
  hello: echo hello
""");

      expect(config.commands.single.name, 'hello');
      expect(config.commands.single.run, 'echo hello');
      expect(config.commands.single.description, isNull);
    });

    test('a mapping carries a description alongside the command', () {
      final config = parse("""
commands:
  deploy:
    description: Ship it to an org.
    run: sf project deploy start
""");

      expect(config.commands.single.run, 'sf project deploy start');
      expect(config.commands.single.description, 'Ship it to an org.');
    });

    test('report the command that has nothing to run', () {
      expect(
        () => parse("""
commands:
  deploy:
    description: Ship it to an org.
"""),
        throwsA(contains('deploy')),
      );
    });
  });

  group('flows', () {
    test('read their steps from the key that names the step type', () {
      final config = parse("""
flows:
  setup:
    description: Create a scratch org and deploy.
    steps:
      - createScratch: dev
        setDefault: true
      - command: deploy
""");

      final flow = config.flows.single;
      expect(flow.name, 'setup');
      expect(flow.description, 'Create a scratch org and deploy.');
      expect(flow.steps, hasLength(2));

      final first = flow.steps.first as CreateScratchFlowStep;
      expect(first.orgName, 'dev');
      expect(first.setDefault, isTrue);

      expect((flow.steps.last as RunCommandFlowStep).commandName, 'deploy');
    });

    test('leave setDefault unset when the step does not say', () {
      final config = parse("""
flows:
  setup:
    steps:
      - createScratch: dev
""");

      expect(
        (config.flows.single.steps.single as CreateScratchFlowStep).setDefault,
        isNull,
      );
    });

    test('report the flow and the step that cannot be understood', () {
      expect(
        () => parse("""
flows:
  setup:
    steps:
      - deployTheThing: dev
"""),
        throwsA(allOf(contains('setup'), contains('deployTheThing'))),
      );
    });
  });

  test('an empty file is a config with nothing in it', () {
    final config = parse("commands:\n  hello: echo hello\n");

    expect(config.scratchOrgDefinitions, isEmpty);
    expect(config.flows, isEmpty);
    expect(config.commands, hasLength(1));
  });
}
