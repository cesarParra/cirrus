import 'dart:convert';
import 'dart:io';

import 'package:cirrus/src/commands/init/init_template.dart';
import 'package:cirrus/src/config.dart';
import 'package:test/test.dart';

Config parse(String yaml) => Config.fromYaml(yaml);

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
orgs:
  dev:
    definitionFile: config/dev.json

commands:
  deploy: sf project deploy start

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

    test('set the created org as the default unless a step says otherwise', () {
      final config = parse("""
orgs:
  dev:
    definitionFile: config/dev.json
  ci:
    definitionFile: config/ci.json

flows:
  setup:
    steps:
      - createScratch: dev
      - createScratch: ci
        setDefault: false
""");

      final steps = config.flows.single.steps.cast<CreateScratchFlowStep>();
      expect(steps.first.setDefault, isTrue);
      expect(steps.last.setDefault, isFalse);
    });

    test('refuse a step that is two kinds of step at once', () {
      expect(
        () => parse("""
orgs:
  dev:
    definitionFile: config/dev.json

commands:
  deploy: sf project deploy start

flows:
  setup:
    steps:
      - createScratch: dev
        command: deploy
"""),
        throwsA(allOf(contains('setup'), contains('one thing'))),
      );
    });

    test('refuse a flow with no steps in it', () {
      expect(
        () => parse("""
flows:
  setup:
    steps: []
"""),
        throwsA(contains('setup')),
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

  group('a field of the wrong type', () {
    test('names the field and the org it is in', () {
      expect(
        () => parse("""
orgs:
  dev:
    definitionFile: config/dev.json
    duration: thirty
"""),
        throwsA(allOf(contains('duration'), contains('dev'))),
      );
    });
  });

  group('a document with nothing in it', () {
    test('is a config with nothing in it, rather than an error', () {
      final config = parse("");

      expect(config.scratchOrgDefinitions, isEmpty);
      expect(config.commands, isEmpty);
      expect(config.flows, isEmpty);
    });

    test('is what `cirrus init` writes, so cirrus can read it', () {
      // The template is entirely comments, which YAML reads as nothing at all. Parsing it here is
      // the only thing that checks the file cirrus writes against the parser cirrus reads it with.
      final config = parse(configContent);

      expect(config.scratchOrgDefinitions, isEmpty);
      expect(config.commands, isEmpty);
      expect(config.flows, isEmpty);
    });
  });

  test('a section that is not a mapping says which section', () {
    expect(() => parse("commands: nope\n"), throwsA(contains('commands')));
  });

  group('a name the config makes up', () {
    test('is a config error when it is not a legal command name', () {
      expect(
        () => parse("""
commands:
  "deploy everything": sf project deploy start
"""),
        throwsA(contains('deploy everything')),
      );
    });

    test('is a config error when it could be read as an option', () {
      expect(
        () => parse("""
commands:
  --help: sf project deploy start
"""),
        throwsA(contains('--help')),
      );
    });

    test('is a config error for a flow name too', () {
      expect(
        () => parse("""
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
        () => parse("""
commands:
  deploy-all_2: sf project deploy start
"""),
        returnsNormally,
      );
    });
  });

  test('the schema states the same rule the parser enforces', () {
    // An editor reads the schema and cirrus reads the regex. Two statements of one rule drift
    // apart silently: the editor blesses a name the parser then refuses, or the reverse.
    final schema =
        jsonDecode(File('schema/cirrus.schema.json').readAsStringSync())
            as Map<String, dynamic>;
    final defined = schema[r'$defs']['name']['pattern'] as String;

    expect(defined, nameOnACommandLine.pattern);

    const reference = {r'$ref': r'#/$defs/name'};
    for (final section in ['orgs', 'commands', 'flows']) {
      final propertyNames = schema['properties'][section]['propertyNames'];
      expect(propertyNames, reference, reason: '$section keys are typed too');
    }
  });
}
