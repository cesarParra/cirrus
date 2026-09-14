import 'dart:convert';
import 'dart:io';

import 'package:cirrus/src/plan/artifact.dart';
import 'package:cirrus/src/plan/events.dart';
import 'package:cirrus/src/plan/execute.dart';
import 'package:cirrus/src/plan/org.dart';
import 'package:cirrus/src/plan/run_config.dart';
import 'package:fpdart/fpdart.dart';
import 'package:test/test.dart';

class FakeOrg implements Org {
  final List<String> polls = [];
  final List<String> queries = [];
  final List<(String, Map<String, dynamic>)> posts = [];

  List<Map<String, dynamic>> installed;
  (int, int, int, int)? wanted;

  int? queryStatus;
  bool queryThrows = false;

  OrgResponse Function(Map<String, dynamic> body) onPost;

  /// The statuses a poll walks through, one per call, the last repeating.
  List<String> statuses;
  Map<String, dynamic>? errors;

  FakeOrg({
    OrgResponse Function(Map<String, dynamic>)? onPost,
    this.statuses = const ['IN_PROGRESS', 'SUCCESS'],
    this.errors,
    this.installed = const [],
    this.wanted,
    this.queryStatus,
    this.queryThrows = false,
  }) : onPost =
           onPost ?? ((_) => const OrgResponse(201, {'id': '0Hf000000000001'}));

  @override
  Future<OrgResponse> post(String path, Map<String, dynamic> body) async {
    posts.add((path, body));
    return onPost(body);
  }

  @override
  Future<OrgResponse> get(String path) async {
    if (path.contains('/query?q=')) {
      queries.add(path);
      if (queryThrows) throw const SocketException('Connection reset by peer');
      if (queryStatus != null) return OrgResponse(queryStatus!, const {});
      if (Uri.decodeQueryComponent(
        path,
      ).contains('FROM SubscriberPackageVersion')) {
        final version = wanted;
        return OrgResponse(200, {
          'records': version == null
              ? []
              : [
                  {
                    'SubscriberPackageId': '033x',
                    'MajorVersion': version.$1,
                    'MinorVersion': version.$2,
                    'PatchVersion': version.$3,
                    'BuildNumber': version.$4,
                  },
                ],
        });
      }
      return OrgResponse(200, {'records': installed});
    }

    polls.add(path);
    final at = polls.length - 1;
    final status = statuses[at < statuses.length ? at : statuses.length - 1];
    return OrgResponse(200, {
      'Status': status,
      if (errors != null) 'Errors': errors,
    });
  }
}

Plan planOf(String json) => (Plan.parse(json) as Right<dynamic, Plan>).value;

const onePackage = '''
{
  "schemaVersion": 1,
  "product": "prose",
  "version": "0.1.0",
  "title": "Prose",
  "steps": [{"kind": "installPackage", "name": "Prose", "packageVersionId": "04tPl000000SgqjIAC"}]
}
''';

RunConfig configOf({Map<int, String> keys = const {}}) => RunConfig(
  instanceUrl: 'https://example.my.salesforce.com',
  accessToken: 'token',
  apiVersion: '67.0',
  installationKeys: keys,
);

Future<(List<Map<String, dynamic>>, bool)> execute(
  Plan plan,
  FakeOrg org, {
  RunConfig? config,
  Duration timeout = const Duration(minutes: 20),
}) async {
  final out = StringBuffer();
  final ok = await PlanExecution(
    plan: plan,
    config: config ?? configOf(),
    org: org,
    events: Events(out),
    pollInterval: Duration.zero,
    timeout: timeout,
  ).run();

  final events = const LineSplitter()
      .convert(out.toString())
      .map((line) => jsonDecode(line) as Map<String, dynamic>)
      .toList();
  return (events, ok);
}

void main() {
  group('the plan artifact', () {
    test('refuses a schema version it does not read', () {
      final parsed = Plan.parse('{"schemaVersion": 2, "steps": []}');
      expect(
        parsed.getLeft().toNullable()?.message,
        contains('schemaVersion 2'),
      );
    });

    test('refuses a step kind it cannot run', () {
      final parsed = Plan.parse(
        '{"schemaVersion": 1, "steps": [{"kind": "runApex", "name": "Seed"}]}',
      );
      expect(parsed.getLeft().toNullable()?.message, contains('runApex'));
    });

    test('refuses a packageVersionId that is not one', () {
      for (final id in [
        "04tXXX' OR Id != '",
        'not-an-id',
        '04t',
        '033Pl00000HGd6rIAD',
      ]) {
        final parsed = Plan.parse(
          '{"schemaVersion": 1, "steps": [{"kind": "installPackage", '
          '"name": "Prose", "packageVersionId": "$id"}]}',
        );
        expect(
          parsed.getLeft().toNullable()?.message,
          contains('not a subscriber package version id'),
          reason: '$id should be refused',
        );
      }
    });

    test('takes a real subscriber package version id', () {
      final parsed = Plan.parse(
        '{"schemaVersion": 1, "steps": [{"kind": "installPackage", '
        '"name": "Prose", "packageVersionId": "04tPl000000SgqjIAC"}]}',
      );
      expect(parsed.getRight().toNullable()?.steps, hasLength(1));
    });

    test('refuses an installPackage with no package', () {
      final parsed = Plan.parse(
        '{"schemaVersion": 1, "steps": [{"kind": "installPackage", "name": "Prose"}]}',
      );
      expect(
        parsed.getLeft().toNullable()?.message,
        contains('no packageVersionId'),
      );
    });
  });

  group('the run configuration', () {
    test('reads keys addressed by step index', () {
      final parsed = RunConfig.parse(
        '{"instanceUrl": "https://x", "accessToken": "t", "installationKeys": {"1": "abc"}}',
      );
      expect(parsed.getRight().toNullable()?.installationKeys, {1: 'abc'});
    });

    test('refuses a configuration with no access token', () {
      final parsed = RunConfig.parse('{"instanceUrl": "https://x"}');
      expect(parsed.getLeft().toNullable()?.message, contains('accessToken'));
    });

    test('trims the trailing slash off the instance url', () {
      final parsed = RunConfig.parse(
        '{"instanceUrl": "https://x/", "accessToken": "t"}',
      );
      expect(parsed.getRight().toNullable()?.instanceUrl, 'https://x');
    });
  });

  group('plan execute', () {
    test('installs a package and narrates it', () async {
      final org = FakeOrg();
      final (events, ok) = await execute(planOf(onePackage), org);

      expect(ok, isTrue);
      expect(events.first, containsPair('event', 'started'));
      expect(events.first, containsPair('protocol', 1));
      expect(events.first, containsPair('steps', 1));
      expect(events.last, {'event': 'finished', 'status': 'ok'});
      expect(
        events.map((e) => e['event']),
        containsAllInOrder([
          'started',
          'step.started',
          'step.progress',
          'step.finished',
          'finished',
        ]),
      );

      final (path, body) = org.posts.single;
      expect(
        path,
        '/services/data/v67.0/tooling/sobjects/PackageInstallRequest',
      );
      expect(body['SubscriberPackageVersionKey'], '04tPl000000SgqjIAC');
      expect(body['SecurityType'], 'None');
      expect(body['NameConflictResolution'], 'Block');
      expect(body.containsKey('Password'), isFalse);
    });

    test('reports each status change once', () async {
      final org = FakeOrg(
        statuses: ['IN_PROGRESS', 'IN_PROGRESS', 'IN_PROGRESS', 'SUCCESS'],
      );
      final (events, ok) = await execute(planOf(onePackage), org);

      expect(ok, isTrue);
      final progress = events
          .where((e) => e['event'] == 'step.progress')
          .map((e) => e['message'])
          .toList();
      expect(progress, ['IN_PROGRESS', 'SUCCESS']);
    });

    test('sends the installation key as the password', () async {
      final org = FakeOrg();
      await execute(
        planOf(
          '{"schemaVersion": 1, "steps": [{"kind": "installPackage", "name": "Prose", '
          '"packageVersionId": "04tRb000005Y0txIAC", "requiresInstallationKey": true}]}',
        ),
        org,
        config: configOf(keys: {0: 'sekrit'}),
      );

      expect(org.posts.single.$2['Password'], 'sekrit');
    });

    test('fails before touching the org when a key is missing', () async {
      final org = FakeOrg();
      final (events, ok) = await execute(
        planOf(
          '{"schemaVersion": 1, "steps": [{"kind": "installPackage", "name": "Prose", '
          '"packageVersionId": "04tRb000005Y0txIAC", "requiresInstallationKey": true}]}',
        ),
        org,
      );

      expect(ok, isFalse);
      expect(org.posts, isEmpty);
      expect(
        events.firstWhere((e) => e['event'] == 'step.failed')['message'],
        contains('No installation key'),
      );
    });

    test('stops at the step that failed and leaves the rest unrun', () async {
      final org = FakeOrg(
        statuses: ['ERROR'],
        errors: const {'message': 'Missing dependency'},
      );
      final (events, ok) = await execute(
        planOf(
          '{"schemaVersion": 1, "steps": ['
          '{"kind": "installPackage", "name": "Prose", "packageVersionId": "04tRb000005Y0txIAC"},'
          '{"kind": "installPackage", "name": "Expression", "packageVersionId": "04tPl000000SgqjIAC"}]}',
        ),
        org,
      );

      expect(ok, isFalse);
      expect(org.posts, hasLength(1));
      final failed = events.firstWhere((e) => e['event'] == 'step.failed');
      expect(failed['step'], 0);
      expect(failed['detail'], {
        'errors': {'message': 'Missing dependency'},
      });
      expect(events.last, {'event': 'finished', 'status': 'failed'});
      expect(events.any((e) => e['name'] == 'Expression'), isFalse);
    });

    test('fails when Salesforce refuses the request', () async {
      final org = FakeOrg(
        onPost: (_) => const OrgResponse(400, {
          'errors': [
            {'message': 'invalid id'},
          ],
        }),
      );
      final (events, ok) = await execute(planOf(onePackage), org);

      expect(ok, isFalse);
      expect(org.polls, isEmpty);
      expect(
        events.firstWhere((e) => e['event'] == 'step.failed')['message'],
        contains('refused'),
      );
    });

    test('says what Salesforce said, not only that it failed', () async {
      final org = FakeOrg(
        statuses: ['ERROR'],
        errors: const {
          'errors': [
            {
              'message':
                  "Missing dependent package(s): 'Spark' version '124.4'",
            },
          ],
        },
      );
      final (events, ok) = await execute(planOf(onePackage), org);

      expect(ok, isFalse);
      expect(
        events.firstWhere((e) => e['event'] == 'step.failed')['message'],
        contains("Missing dependent package(s): 'Spark' version '124.4'"),
      );
    });

    test('says what Salesforce said when it refused the request too', () async {
      final org = FakeOrg(
        onPost: (_) => const OrgResponse(400, {
          'errors': [
            {'message': 'invalid id'},
          ],
        }),
      );
      final (events, _) = await execute(planOf(onePackage), org);

      expect(
        events.firstWhere((e) => e['event'] == 'step.failed')['message'],
        contains('invalid id'),
      );
    });

    test('falls back to its own words when Salesforce gave none', () async {
      final org = FakeOrg(statuses: ['ERROR']);
      final (events, _) = await execute(planOf(onePackage), org);

      expect(
        events.firstWhere((e) => e['event'] == 'step.failed')['message'],
        contains('Prose'),
      );
    });

    test(
      'skips a package the org already has at the asked-for version',
      () async {
        final org = FakeOrg(
          installed: [
            {
              'SubscriberPackageId': '033x',
              'SubscriberPackageVersion': {
                'MajorVersion': 0,
                'MinorVersion': 1,
                'PatchVersion': 0,
                'BuildNumber': 33,
              },
            },
          ],
          wanted: (0, 1, 0, 33),
        );

        final (events, ok) = await execute(planOf(onePackage), org);

        expect(ok, isTrue);
        expect(org.posts, isEmpty, reason: 'nothing was installed');
        expect(org.polls, isEmpty, reason: 'nothing was polled');

        final finished = events.firstWhere(
          (e) => e['event'] == 'step.finished',
        );
        expect(finished['status'], 'skipped');
        expect(finished['message'], contains('already installed'));
        expect(events.last, {'event': 'finished', 'status': 'ok'});
      },
    );

    test('skips a package the org has at a later version', () async {
      final org = FakeOrg(
        installed: [
          {
            'SubscriberPackageId': '033x',
            'SubscriberPackageVersion': {
              'MajorVersion': 0,
              'MinorVersion': 2,
              'PatchVersion': 0,
              'BuildNumber': 1,
            },
          },
        ],
        wanted: (0, 1, 0, 33),
      );

      final (_, ok) = await execute(planOf(onePackage), org);

      expect(ok, isTrue);
      expect(org.posts, isEmpty);
    });

    test('installs when the org has an older version', () async {
      final org = FakeOrg(
        installed: [
          {
            'SubscriberPackageId': '033x',
            'SubscriberPackageVersion': {
              'MajorVersion': 0,
              'MinorVersion': 1,
              'PatchVersion': 0,
              'BuildNumber': 32,
            },
          },
        ],
        wanted: (0, 1, 0, 33),
      );

      final (events, ok) = await execute(planOf(onePackage), org);

      expect(ok, isTrue);
      expect(org.posts, hasLength(1), reason: 'an upgrade still installs');
      expect(
        events.firstWhere((e) => e['event'] == 'step.finished')['status'],
        'ok',
      );
    });

    test('installs when the org answers that nothing is installed', () async {
      final org = FakeOrg(installed: const [], wanted: null);

      final (_, ok) = await execute(planOf(onePackage), org);

      expect(ok, isTrue);
      expect(org.posts, hasLength(1));
    });

    test('installs when the check is refused', () async {
      final org = FakeOrg(queryStatus: 400, wanted: (0, 1, 0, 33));

      final (_, ok) = await execute(planOf(onePackage), org);

      expect(ok, isTrue);
      expect(
        org.posts,
        hasLength(1),
        reason: 'a refused query is not a missing package',
      );
    });

    test(
      'installs when the check throws, rather than failing the plan',
      () async {
        final org = FakeOrg(queryThrows: true, wanted: (0, 1, 0, 33));

        final (events, ok) = await execute(planOf(onePackage), org);

        expect(ok, isTrue);
        expect(org.posts, hasLength(1));
        expect(
          events.any((e) => e['event'] == 'step.failed'),
          isFalse,
          reason: 'a check that broke is not a step that failed',
        );
      },
    );

    test('asks for a key-protected version with its key', () async {
      final org = FakeOrg(wanted: (0, 1, 0, 33));

      await execute(
        planOf(
          '{"schemaVersion": 1, "steps": [{"kind": "installPackage", "name": "Prose", '
          '"packageVersionId": "04tPl000000SgqjIAC", "requiresInstallationKey": true}]}',
        ),
        org,
        config: configOf(keys: {0: 'sekrit'}),
      );

      expect(
        Uri.decodeQueryComponent(org.queries.first),
        contains("InstallationKey = 'sekrit'"),
      );
    });

    test('gives up on an install that never finishes', () async {
      final org = FakeOrg(statuses: ['IN_PROGRESS']);
      final (events, ok) = await execute(
        planOf(onePackage),
        org,
        timeout: Duration.zero,
      );

      expect(ok, isFalse);
      expect(
        events.firstWhere((e) => e['event'] == 'step.failed')['message'],
        contains('still installing'),
      );
    });
  });
}
