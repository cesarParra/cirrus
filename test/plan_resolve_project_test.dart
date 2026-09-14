import 'dart:io';

import 'package:cirrus/src/plan/project.dart';
import 'package:test/test.dart';

late Directory project;

String at(String name) => '${project.path}/$name';

void write(String name, String contents) =>
    File(at(name)).writeAsStringSync(contents);

const sfdxProject = '''
{
  "packageDirectories": [
    {
      "path": "neverlapse",
      "default": true,
      "package": "NeverLapse",
      "dependencies": [{ "package": "04t3j000000wz45AAA" }]
    }
  ],
  "packageAliases": {
    "NeverLapse": "0HoPl00000VYtppKAD",
    "NeverLapse@0.1.0-2": "04tPl000000TMMvIAO"
  }
}
''';

void main() {
  setUp(() {
    project = Directory.systemTemp.createTempSync('cirrus-resolve');
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  group('what a repository offers', () {
    test('is nothing to choose from when it has no config at all', () {
      write('sfdx-project.json', sfdxProject);

      final offered = plansIn(project.path).getRight().toNullable()!;
      expect(offered.names, isEmpty);
      expect(offered.derives, isTrue);
    });

    test('is nothing to choose from when its config names no plans', () {
      write('sfdx-project.json', sfdxProject);
      write('cirrus.yaml', 'commands:\n  deploy: sf project deploy start\n');

      final offered = plansIn(project.path).getRight().toNullable()!;
      expect(offered.names, isEmpty);
      expect(offered.derives, isTrue);
    });

    test('is the plans it names, in the order it names them', () {
      write('sfdx-project.json', sfdxProject);
      write('cirrus.yaml', '''
plans:
  install:
    steps:
      - installPackage: NeverLapse
  demo:
    steps:
      - installPackage: NeverLapse
''');

      final offered = plansIn(project.path).getRight().toNullable()!;
      expect(offered.names, ['install', 'demo']);
      expect(offered.derives, isFalse);
    });

    test('is an error a person can act on when the config will not parse', () {
      write('sfdx-project.json', sfdxProject);
      write('cirrus.yaml', 'plans:\n  install:\n    stepz: []\n');

      expect(
        plansIn(project.path).getLeft().toNullable()?.message,
        contains('stepz'),
      );
    });
  });

  group('resolving in a directory', () {
    test('derives a plan when the repository names none', () {
      write('sfdx-project.json', sfdxProject);

      final resolved = resolveIn(
        project.path,
        planName: null,
      ).getRight().toNullable()!;

      expect(resolved.plan, 'derived');
      expect(resolved.product, 'neverlapse');
      expect(resolved.version, '0.1.0-2');
      expect((resolved.toJson()['steps'] as List).map((step) => step['kind']), [
        'requirePackages',
        'installPackage',
      ]);
    });

    test('uses the plan it is asked for', () {
      write('sfdx-project.json', sfdxProject);
      write('cirrus.yaml', '''
plans:
  install:
    steps:
      - installPackage: NeverLapse
  demo:
    steps:
      - requirePackages: Fonteva
        packages: [04t3j000000wz45AAA]
      - installPackage: NeverLapse
''');

      final resolved = resolveIn(
        project.path,
        planName: 'demo',
      ).getRight().toNullable()!;

      expect(resolved.plan, 'demo');
      expect((resolved.toJson()['steps'] as List).first['name'], 'Fonteva');
    });

    test('prefers the plan called install when asked for none', () {
      write('sfdx-project.json', sfdxProject);
      write('cirrus.yaml', '''
plans:
  demo:
    steps:
      - installPackage: NeverLapse
  install:
    steps:
      - installPackage: NeverLapse
''');

      expect(
        resolveIn(project.path, planName: null).getRight().toNullable()?.plan,
        'install',
      );
    });

    test('takes the only plan there is when it is not called install', () {
      write('sfdx-project.json', sfdxProject);
      write('cirrus.yaml', '''
plans:
  demo:
    steps:
      - installPackage: NeverLapse
''');

      expect(
        resolveIn(project.path, planName: null).getRight().toNullable()?.plan,
        'demo',
      );
    });

    test('refuses to guess between plans, naming the ones there are', () {
      write('sfdx-project.json', sfdxProject);
      write('cirrus.yaml', '''
plans:
  demo:
    steps:
      - installPackage: NeverLapse
  trial:
    steps:
      - installPackage: NeverLapse
''');

      final message = resolveIn(
        project.path,
        planName: null,
      ).getLeft().toNullable()?.message;

      expect(message, allOf(contains('demo'), contains('trial')));
    });

    test('names the plan that was asked for and is not there', () {
      write('sfdx-project.json', sfdxProject);
      write('cirrus.yaml', '''
plans:
  install:
    steps:
      - installPackage: NeverLapse
''');

      expect(
        resolveIn(
          project.path,
          planName: 'staging',
        ).getLeft().toNullable()?.message,
        contains('staging'),
      );
    });

    test('says what is missing when there is no sfdx-project.json', () {
      expect(
        resolveIn(project.path, planName: null).getLeft().toNullable()?.message,
        contains('sfdx-project.json'),
      );
    });

    test('says so when sfdx-project.json is not JSON', () {
      write('sfdx-project.json', '{ this is not json');

      expect(
        resolveIn(project.path, planName: null).getLeft().toNullable()?.message,
        contains('sfdx-project.json'),
      );
    });
  });
}
