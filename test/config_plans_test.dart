import 'package:cirrus/src/config.dart';
import 'package:test/test.dart';

Config parse(String yaml) => Config.fromYaml(yaml);

void main() {
  group('plans', () {
    test('are keyed by name and keep the order their steps are written in', () {
      final config = parse("""
plans:
  install:
    title: Install Prose
    steps:
      - installPackage: Expression
        description: The formula engine Prose evaluates with.
      - installPackage: Prose
""");

      final plan = config.plans.single;
      expect(plan.name, 'install');
      expect(plan.title, 'Install Prose');
      expect(plan.steps.map((step) => step.installPackage), [
        'Expression',
        'Prose',
      ]);
      expect(
        plan.steps.first.description,
        'The formula engine Prose evaluates with.',
      );
      expect(plan.steps.last.description, isNull);
    });

    test('take a requirement step naming packages by id', () {
      final config = parse("""
plans:
  install:
    steps:
      - requirePackages: Fonteva
        description: NeverLapse runs on Fonteva.
        packages:
          - 04t3j000000wz45AAA
          - 04t1J000000KefwQAC
      - installPackage: NeverLapse
""");

      final step = config.plans.single.steps.first;
      expect(step.requirePackages, 'Fonteva');
      expect(step.packages, ['04t3j000000wz45AAA', '04t1J000000KefwQAC']);
      expect(step.installPackage, isNull);
    });

    test('are findable by the name the operator picked', () {
      final config = parse("""
plans:
  install:
    steps:
      - installPackage: Prose
  demo:
    steps:
      - installPackage: Prose
""");

      expect(config.plans.map((plan) => plan.name), ['install', 'demo']);
      expect(config.planNamed('demo')?.name, 'demo');
      expect(config.planNamed('nothing'), isNull);
    });

    test('report a plan with no steps by name', () {
      expect(
        () => parse('plans:\n  install:\n    title: Nothing\n'),
        throwsA(contains('install')),
      );
    });

    test('report a step that names neither thing a step can be', () {
      expect(
        () => parse('plans:\n  install:\n    steps:\n      - description: hi\n'),
        throwsA(
          allOf(contains('installPackage'), contains('requirePackages')),
        ),
      );
    });

    test('report a step that is both at once', () {
      expect(
        () => parse("""
plans:
  install:
    steps:
      - installPackage: Prose
        requirePackages: Fonteva
        packages: [04t3j000000wz45AAA]
"""),
        throwsA(contains('install')),
      );
    });

    test('report a requirement naming no packages', () {
      expect(
        () => parse("""
plans:
  install:
    steps:
      - requirePackages: Fonteva
"""),
        throwsA(contains('packages')),
      );
    });

    test('refuse a key cirrus does not read', () {
      expect(
        () => parse("""
plans:
  install:
    stepz:
      - installPackage: Prose
"""),
        throwsA(contains('stepz')),
      );
    });
  });
}
