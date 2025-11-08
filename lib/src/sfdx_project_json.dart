class SfdxProjectJson {
  final List<PackageDirectory> packageDirectories;
  final Map<String, String>? packageAliases;

  SfdxProjectJson({required this.packageDirectories, this.packageAliases});

  factory SfdxProjectJson.fromJson(Map<String, dynamic> json) {
    return SfdxProjectJson(
      packageDirectories:
          (json['packageDirectories'] as List<dynamic>?)
              ?.map((e) => PackageDirectory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      packageAliases: (json['packageAliases'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packageDirectories': packageDirectories.map((e) => e.toJson()).toList(),
      'packageAliases': packageAliases,
    };
  }

  SfdxProjectJson cloneWith({List<PackageDirectory>? packageDirectories, Map<String, String>? packageAliases}) {
    return SfdxProjectJson(
      packageDirectories: packageDirectories ?? this.packageDirectories,
      packageAliases: packageAliases ?? this.packageAliases,
    );
  }
}

class PackageDirectory {
  final String? package;
  final String? versionName;
  final String? versionNumber;
  final Map<String, dynamic> extra;

  PackageDirectory({
    this.package,
    this.versionName,
    this.versionNumber,
    Map<String, dynamic>? extra,
  }) : extra = extra ?? {};

  factory PackageDirectory.fromJson(Map<String, dynamic> json) {
    final knownKeys = {'package', 'versionName', 'versionNumber'};
    final extra = Map<String, dynamic>.from(json)
      ..removeWhere((k, _) => knownKeys.contains(k));
    return PackageDirectory(
      package: json['package'] as String?,
      versionName: json['versionName'] as String?,
      versionNumber: json['versionNumber'] as String?,
      extra: extra,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (package != null) 'package': package,
      if (versionName != null) 'versionName': versionName,
      if (versionNumber != null) 'versionNumber': versionNumber,
      ...extra,
    };
  }

  PackageDirectory cloneWith({
    String? versionName,
    String? versionNumber,
    Map<String, dynamic>? extra,
  }) {
    return PackageDirectory(
      package: package,
      versionName: versionName ?? this.versionName,
      versionNumber: versionNumber ?? this.versionNumber,
      extra: extra ?? Map<String, dynamic>.from(this.extra),
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('PackageDirectory(');
    if (package != null) buffer.writeln('  package: $package,');
    if (versionName != null) buffer.writeln('  versionName: $versionName,');
    if (versionNumber != null) buffer.writeln('  versionNumber: $versionNumber,');
    if (extra.isNotEmpty) buffer.writeln('  extra: $extra,');
    buffer.write(')');
    return buffer.toString();
  }
}
