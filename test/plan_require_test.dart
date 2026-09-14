import 'dart:convert';

import 'package:cirrus/src/plan/artifact.dart';
import 'package:cirrus/src/plan/events.dart';
import 'package:cirrus/src/plan/execute.dart';
import 'package:cirrus/src/plan/org.dart';
import 'package:cirrus/src/plan/run_config.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

/// A version id, the package behind it, and what the org has of that package - null for an org that
/// does not have it at all.
typedef Known = ({String packageId, String name, String wanted, String? has});

class PackagesOrg implements Org {
  final Map<String, Known> world;
  final bool namesAreUnreadable;
  final List<(String, Map<String, dynamic>)> posts = [];

  PackagesOrg(this.world, {this.namesAreUnreadable = false});

  @override
  Future<OrgResponse> post(String path, Map<String, dynamic> body) async {
    posts.add((path, body));
    return const OrgResponse(201, {'id': '0Hf000000000001'});
  }

  @override
  Future<OrgResponse> get(String path) async {
    final soql = Uri.decodeQueryComponent(path.split('q=').last);

    if (soql.contains('FROM SubscriberPackageVersion')) {
      final entry = world.entries
          .where((e) => soql.contains(e.key))
          .firstOrNull;
      if (entry == null) return const OrgResponse(200, {'records': []});
      return OrgResponse(200, {
        'records': [
          {
            'SubscriberPackageId': entry.value.packageId,
            ..._parts(entry.value.wanted),
          },
        ],
      });
    }

    if (soql.contains('FROM SubscriberPackage ')) {
      if (namesAreUnreadable) return const OrgResponse(400, {});
      final entry = world.values
          .where((known) => soql.contains(known.packageId))
          .firstOrNull;
      return OrgResponse(200, {
        'records': entry == null ? [] : [
          {'Name': entry.name},
        ],
      });
    }

    final held = world.values
        .where((known) => soql.contains(known.packageId) && known.has != null)
        .firstOrNull;
    return OrgResponse(200, {
      'records': held == null
          ? []
          : [
              {'SubscriberPackageVersion': _parts(held.has!)},
            ],
    });
  }

  static Map<String, dynamic> _parts(String version) {
    final numbers = version.split('.').map(int.parse).toList();
    return {
      'MajorVersion': numbers[0],
      'MinorVersion': numbers[1],
      'PatchVersion': numbers[2],
      'BuildNumber': numbers[3],
    };
  }
}

String planRequiring(List<String> ids) => jsonEncode({
  'schemaVersion': 1,
  'product': 'neverlapse',
  'version': '0.1.0-2',
  'title': 'NeverLapse',
  'steps': [
    {'kind': 'requirePackages', 'name': 'Requirements', 'packages': ids},
  ],
});

Future<(List<Map<String, dynamic>>, bool)> run(String json, Org org) async {
  final out = StringBuffer();
  final ok = await PlanExecution(
    plan: (Plan.parse(json) as Right<dynamic, Plan>).value,
    config: const RunConfig(
      instanceUrl: 'https://example.my.salesforce.com',
      accessToken: 'token',
      apiVersion: '67.0',
      installationKeys: {},
    ),
    org: org,
    events: Events(out),
    pollInterval: Duration.zero,
  ).run();

  return (
    const LineSplitter()
        .convert(out.toString())
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList(),
    ok,
  );
}

const framework = '04t3j000000wz45AAA';
const pagesApi = '04t1J000000KefwQAC';

void main() {
  group('the artifact', () {
    test('reads a requirePackages step', () {
      final parsed = Plan.parse(planRequiring([framework]));
      final step = parsed.getRight().toNullable()!.steps.single;
      expect(step, isA<RequirePackages>());
      expect((step as RequirePackages).packages, [framework]);
    });

    test('refuses a requirePackages step naming nothing', () {
      final parsed = Plan.parse(
        '{"schemaVersion":1,"steps":[{"kind":"requirePackages","name":"R","packages":[]}]}',
      );
      expect(parsed.getLeft().toNullable()?.message, contains('no packages'));
    });

    test('refuses a package that is not a version id', () {
      final parsed = Plan.parse(planRequiring(['Fonteva Framework']));
      expect(
        parsed.getLeft().toNullable()?.message,
        contains('Fonteva Framework'),
      );
    });
  });

  group('checking an org against what a plan requires', () {
    test('passes when every package is there, touching nothing', () async {
      final org = PackagesOrg({
        framework: (
          packageId: '033a',
          name: 'Fonteva Framework',
          wanted: '1.0.0.1',
          has: '1.0.0.1',
        ),
        pagesApi: (
          packageId: '033b',
          name: 'Fonteva PagesApi',
          wanted: '1.0.0.1',
          has: '2.0.0.1',
        ),
      });

      final (events, ok) = await run(planRequiring([framework, pagesApi]), org);

      expect(ok, isTrue);
      expect(org.posts, isEmpty, reason: 'a check must not install anything');
      expect(events.last, {'event': 'finished', 'status': 'ok'});
    });

    test('fails naming the package the org does not have', () async {
      final org = PackagesOrg({
        framework: (
          packageId: '033a',
          name: 'Fonteva Framework',
          wanted: '1.0.0.1',
          has: '1.0.0.1',
        ),
        pagesApi: (
          packageId: '033b',
          name: 'Fonteva PagesApi',
          wanted: '1.0.0.1',
          has: null,
        ),
      });

      final (events, ok) = await run(planRequiring([framework, pagesApi]), org);

      expect(ok, isFalse);
      expect(org.posts, isEmpty);

      final failed = events.firstWhere((e) => e['event'] == 'step.failed');
      expect(failed['message'], contains('Fonteva PagesApi'));
      expect(
        failed['message'],
        isNot(contains('Fonteva Framework')),
        reason: 'naming what is present buries what is missing',
      );
    });

    test('says what is installed when it is too old', () async {
      final org = PackagesOrg({
        framework: (
          packageId: '033a',
          name: 'Fonteva Framework',
          wanted: '2.0.0.1',
          has: '1.4.0.3',
        ),
      });

      final (events, _) = await run(planRequiring([framework]), org);
      final failed = events.firstWhere((e) => e['event'] == 'step.failed');

      expect(failed['message'], contains('1.4.0.3'));
      expect(failed['message'], contains('2.0.0.1'));
    });

    test('falls back to the id when the org will not say the name', () async {
      final org = PackagesOrg({
        framework: (
          packageId: '033a',
          name: 'Fonteva Framework',
          wanted: '1.0.0.1',
          has: null,
        ),
      }, namesAreUnreadable: true);

      final (events, ok) = await run(planRequiring([framework]), org);

      expect(ok, isFalse);
      expect(
        events.firstWhere((e) => e['event'] == 'step.failed')['message'],
        contains(framework),
      );
    });

    test('fails when the org cannot be asked about a package at all', () async {
      final org = PackagesOrg(const {});

      final (events, ok) = await run(planRequiring([framework]), org);

      expect(ok, isFalse);
      expect(
        events.firstWhere((e) => e['event'] == 'step.failed')['message'],
        contains(framework),
      );
    });
  });
}
