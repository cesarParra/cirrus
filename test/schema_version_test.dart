import 'package:cirrus/src/config.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// The schema is served from a URL cirrus writes into other people's config files and can never
/// edit again, so what that URL is, and what it points at, are pinned here.
void main() {
  final schema = schemaDocument();

  test('the schema is published where cirrus says it is', () {
    expect(schema[r'$id'], schemaUrl);
  });

  test('the URL carries the schema major, so v2 can exist beside it', () {
    expect(schemaUrl, contains('/v$schemaVersion/'));
  });

  test('the schema declares the same version cirrus knows', () {
    expect(schema['properties']['schemaVersion']['const'], schemaVersion);
  });

  group('a config written for a newer cirrus', () {
    test('is refused, saying what it needs rather than what it lacks', () {
      expect(
        () => Config.fromYaml('schemaVersion: ${schemaVersion + 1}\n'),
        throwsA(allOf(contains('${schemaVersion + 1}'), contains('newer'))),
      );
    });

    test('and so is one written for a version that never existed', () {
      // The schema says `const: 1`, so anything else is invalid there. Dart accepting what the
      // schema rejects is the drift; the file declares a shape, and 0 is not one cirrus ever had.
      expect(
        () => Config.fromYaml('schemaVersion: 0\n'),
        throwsA(contains('0')),
      );
    });

    test('is not confused with a config that declares this one', () {
      expect(
        () => Config.fromYaml('schemaVersion: $schemaVersion\n'),
        returnsNormally,
      );
    });

    test('or with one that declares nothing', () {
      expect(
        () => Config.fromYaml('commands:\n  a: echo b\n'),
        returnsNormally,
      );
    });
  });
}
