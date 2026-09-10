import 'package:cirrus/src/plan/package_version.dart';
import 'package:test/test.dart';

void main() {
  group('comparing package versions', () {
    test('orders on the first part that differs', () {
      expect(
        PackageVersion(1, 0, 0, 1).isAtLeast(PackageVersion(0, 9, 9, 9)),
        isTrue,
      );
      expect(
        PackageVersion(0, 1, 0, 32).isAtLeast(PackageVersion(0, 1, 0, 33)),
        isFalse,
      );
      expect(
        PackageVersion(0, 2, 0, 1).isAtLeast(PackageVersion(0, 1, 0, 99)),
        isTrue,
      );
    });

    test('counts the same version as at least itself', () {
      expect(
        PackageVersion(1, 52, 0, 1).isAtLeast(PackageVersion(1, 52, 0, 1)),
        isTrue,
      );
    });

    test('sorts on the build number, which is what a beta moves', () {
      expect(
        PackageVersion(0, 1, 0, 33).isAtLeast(PackageVersion(0, 1, 0, 28)),
        isTrue,
      );
    });

    test('reads a record Salesforce answered with', () {
      expect(
        PackageVersion.from({
          'MajorVersion': 1,
          'MinorVersion': 52,
          'PatchVersion': 0,
          'BuildNumber': 1,
        }).toString(),
        '1.52.0.1',
      );
    });

    test('answers nothing for a record it cannot read', () {
      expect(PackageVersion.from(null), isNull);
      expect(PackageVersion.from({}), isNull);
      expect(PackageVersion.from({'MajorVersion': '1'}), isNull);
    });
  });
}
