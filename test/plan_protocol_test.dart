import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// The org here does not exist, so the install fails at the first call - which is the point. A step
/// that could not be reached is still a step that failed, and the events say so.
void main() {
  late Directory temporary;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('cirrus-plan');
  });

  tearDown(() {
    temporary.deleteSync(recursive: true);
  });

  Future<ProcessResult> execute(String plan, String config) async {
    final file = File('${temporary.path}/plan.json')..writeAsStringSync(plan);
    final process = await Process.start('dart', [
      'run',
      'bin/cirrus.dart',
      'plan',
      'execute',
      '--plan',
      file.path,
    ]);
    process.stdin.writeln(config);
    await process.stdin.close();

    final out = await process.stdout.transform(utf8.decoder).join();
    final error = await process.stderr.transform(utf8.decoder).join();
    return ProcessResult(process.pid, await process.exitCode, out, error);
  }

  const plan = '''
{
  "schemaVersion": 1,
  "product": "prose",
  "version": "0.1.0",
  "steps": [{"kind": "installPackage", "name": "Prose", "packageVersionId": "04t1"}]
}
''';

  test('narrates an unreachable org and exits one', () async {
    final result = await execute(
      plan,
      jsonEncode({
        'instanceUrl': 'https://cirrus-no-such-org.invalid',
        'accessToken': 'token',
      }),
    );

    final events = const LineSplitter()
        .convert(result.stdout as String)
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();

    expect(events.first, containsPair('event', 'started'));
    expect(events.first, containsPair('product', 'prose'));
    expect(events.map((e) => e['event']), contains('step.failed'));
    expect(events.last, {'event': 'finished', 'status': 'failed'});
    expect(result.exitCode, 1);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('writes nothing to stdout when it never started', () async {
    final result = await execute(plan, 'not json');

    expect(result.stdout, isEmpty);
    expect(result.stderr, contains('not JSON'));
    expect(result.exitCode, 2);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
