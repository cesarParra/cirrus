class PackageVersion implements Comparable<PackageVersion> {
  final int major;
  final int minor;
  final int patch;
  final int build;

  const PackageVersion(this.major, this.minor, this.patch, this.build);

  static PackageVersion? from(Map<String, dynamic>? record) {
    if (record == null) return null;

    final parts = [
      'MajorVersion',
      'MinorVersion',
      'PatchVersion',
      'BuildNumber',
    ].map((field) => record[field]).toList();
    if (parts.any((part) => part is! int)) return null;

    return PackageVersion(
      parts[0] as int,
      parts[1] as int,
      parts[2] as int,
      parts[3] as int,
    );
  }

  /// A `packageAliases` label: `0.1.0-33`, or `1.52.0` for one carrying no build number.
  static PackageVersion? parse(String label) {
    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)(?:[-.](\d+))?$',
    ).firstMatch(label.trim());
    if (match == null) return null;

    int at(int group) => int.parse(match.group(group) ?? '0');
    return PackageVersion(at(1), at(2), at(3), at(4));
  }

  @override
  int compareTo(PackageVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
      (build, other.build),
    ]) {
      final difference = pair.$1.compareTo(pair.$2);
      if (difference != 0) return difference;
    }
    return 0;
  }

  bool isAtLeast(PackageVersion other) => compareTo(other) >= 0;

  @override
  String toString() => '$major.$minor.$patch.$build';

  @override
  bool operator ==(Object other) =>
      other is PackageVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);
}
