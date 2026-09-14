import 'dart:convert';

import 'package:cirrus/src/plan/resolve.dart';
import 'package:cirrus/src/sfdx_project_json.dart';
import 'package:test/test.dart';

SfdxProjectJson projectFrom(String source) =>
    SfdxProjectJson.fromJson(jsonDecode(source) as Map<String, dynamic>);

/// Prose's aliases, trimmed to the builds that matter. `0.1.0-4` sorts above `0.1.0-33` as a
/// string, which is the mistake this resolution exists to not make.
final prose = projectFrom('''
{
  "packageDirectories": [
    {
      "path": "force-app/prose",
      "default": true,
      "package": "Prose",
      "versionNumber": "0.1.0.NEXT",
      "dependencies": [{ "package": "04tRb000005Y0txIAC" }]
    }
  ],
  "packageAliases": {
    "Prose": "0HoPl000001gDBhKAM",
    "Expression": "04tRb000005Y0txIAC",
    "Prose@0.1.0-4": "04tPl000000RwO5IAK",
    "Prose@0.1.0-28": "04tPl000000SaTZIA0",
    "Prose@0.1.0-33": "04tPl000000SgqjIAC",
    "Expression@1.52.0-1": "04tRb000005Y0txIAC"
  }
}
''');

final neverlapse = projectFrom('''
{
  "packageDirectories": [
    {
      "path": "neverlapse",
      "default": true,
      "package": "NeverLapse",
      "versionNumber": "0.1.0.NEXT",
      "dependencies": [
        { "package": "04t3j000000wz45AAA" },
        { "package": "04t1J000000KefwQAC" },
        { "package": "04t3k000001ywkZAAQ" },
        { "package": "04t2I000000T4tTQAS" },
        { "package": "04tKj000000iGZJIA2" }
      ]
    }
  ],
  "packageAliases": {
    "NeverLapse": "0HoPl00000VYtppKAD",
    "NeverLapse@0.1.0-1": "04tPl000000TL2fIAG",
    "NeverLapse@0.1.0-2": "04tPl000000TMMvIAO"
  }
}
''');

const nowhere = ResolvedFrom(repo: null, commit: null);

void main() {
  group('an alias becomes a concrete id', () {
    test('a package alias takes its highest version, sorted numerically', () {
      expect(
        pinned(prose, 'Prose').getOrElse((failure) => fail(failure.message)),
        (id: '04tPl000000SgqjIAC', version: '0.1.0-33'),
      );
    });

    test('an alias already naming a version is that version', () {
      expect(
        pinned(prose, 'Expression@1.52.0-1').getOrElse((f) => fail(f.message)),
        (id: '04tRb000005Y0txIAC', version: '1.52.0-1'),
      );
    });

    test('an alias pointing straight at an id needs no resolution', () {
      expect(pinned(prose, 'Expression').getOrElse((f) => fail(f.message)), (
        id: '04tRb000005Y0txIAC',
        version: null,
      ));
    });

    test('an alias nothing defines says so by name', () {
      expect(
        pinned(prose, 'Nothing').getLeft().toNullable()?.message,
        contains('Nothing'),
      );
    });

    test('a package alias with no built version says so', () {
      final unbuilt = projectFrom(
        '{"packageDirectories":[],"packageAliases":{"New":"0HoPl00000000000AA"}}',
      );
      expect(
        pinned(unbuilt, 'New').getLeft().toNullable()?.message,
        contains('no version'),
      );
    });
  });

  group('a repository with no plans', () {
    test('requires what it depends on and installs what it builds', () {
      final resolved = resolve(
        project: neverlapse,
        plan: null,
        from: nowhere,
      ).getOrElse((failure) => fail(failure.message));

      expect(resolved.product, 'neverlapse');
      expect(resolved.version, '0.1.0-2');
      expect(resolved.toJson()['steps'], [
        {
          'kind': 'requirePackages',
          'name': 'Requirements',
          'description':
              'Packages NeverLapse needs, which this install checks for but never installs.',
          'packages': [
            '04t3j000000wz45AAA',
            '04t1J000000KefwQAC',
            '04t3k000001ywkZAAQ',
            '04t2I000000T4tTQAS',
            '04tKj000000iGZJIA2',
          ],
        },
        {
          'kind': 'installPackage',
          'name': 'NeverLapse',
          'packageVersionId': '04tPl000000TMMvIAO',
        },
      ]);
    });

    test('never installs a package it did not build', () {
      final steps =
          resolve(
                project: neverlapse,
                plan: null,
                from: nowhere,
              ).getOrElse((f) => fail(f.message)).toJson()['steps']
              as List<dynamic>;

      final installed = steps
          .where((step) => step['kind'] == 'installPackage')
          .map((step) => step['packageVersionId'])
          .toList();

      expect(installed, ['04tPl000000TMMvIAO']);
    });

    test('omits the requirement step when nothing is depended on', () {
      final alone = projectFrom('''
        {
          "packageDirectories": [{"path": "x", "default": true, "package": "Solo"}],
          "packageAliases": {"Solo": "0HoPl00000000000AA", "Solo@1.0.0-1": "04tPl000000000000A"}
        }
      ''');

      final steps =
          resolve(
                project: alone,
                plan: null,
                from: nowhere,
              ).getOrElse((f) => fail(f.message)).toJson()['steps']
              as List<dynamic>;

      expect(steps.map((step) => step['kind']), ['installPackage']);
    });
  });

  group('a repository with a plan', () {
    test(
      'installs the dependency the plan names, in the order it names it',
      () {
        final resolved = resolve(
          project: prose,
          plan: const PlanDefinition(
            name: 'install',
            title: 'Install Prose',
            steps: [
              PlanStepDefinition(
                installPackage: 'Expression',
                description: 'The formula engine Prose evaluates with.',
              ),
              PlanStepDefinition(installPackage: 'Prose'),
            ],
          ),
          from: nowhere,
        ).getOrElse((failure) => fail(failure.message));

        expect(resolved.toJson()['steps'], [
          {
            'kind': 'installPackage',
            'name': 'Expression',
            'description': 'The formula engine Prose evaluates with.',
            'packageVersionId': '04tRb000005Y0txIAC',
          },
          {
            'kind': 'installPackage',
            'name': 'Prose',
            'packageVersionId': '04tPl000000SgqjIAC',
          },
        ]);
      },
    );

    test('takes the requirements the plan lists, by id', () {
      final resolved = resolve(
        project: neverlapse,
        plan: const PlanDefinition(
          name: 'install',
          title: 'Install NeverLapse',
          steps: [
            PlanStepDefinition(
              requirePackages: 'Fonteva',
              packages: ['04t3j000000wz45AAA'],
            ),
            PlanStepDefinition(installPackage: 'NeverLapse'),
          ],
        ),
        from: nowhere,
      ).getOrElse((failure) => fail(failure.message));

      expect((resolved.toJson()['steps'] as List).first, {
        'kind': 'requirePackages',
        'name': 'Fonteva',
        'packages': ['04t3j000000wz45AAA'],
      });
    });
  });

  group('what the artifact records about itself', () {
    test('is readable by the cirrus that has to run it', () {
      final json = resolve(
        project: neverlapse,
        plan: null,
        from: const ResolvedFrom(
          repo: 'https://github.com/TheRadicalOnes/neverlapse-app',
          commit: 'c6cd755',
        ),
      ).getOrElse((f) => fail(f.message)).toJson();

      expect(json['schemaVersion'], 1);
      expect(json['resolvedFrom'], containsPair('commit', 'c6cd755'));
      expect(json['resolvedFrom'], containsPair('plan', 'derived'));
      expect(json['resolvedAt'], isA<String>());
    });

    test('names the plan it was resolved from', () {
      final json = resolve(
        project: prose,
        plan: const PlanDefinition(
          name: 'install',
          title: 'Install Prose',
          steps: [PlanStepDefinition(installPackage: 'Prose')],
        ),
        from: nowhere,
      ).getOrElse((f) => fail(f.message)).toJson();

      expect(json['resolvedFrom'], containsPair('plan', 'install'));
    });
  });
}
