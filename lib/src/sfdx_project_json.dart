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

  PackageDirectory({this.package, this.versionName, this.versionNumber});

  factory PackageDirectory.fromJson(Map<String, dynamic> json) {
    return PackageDirectory(
      package: json['package'] as String?,
      versionName: json['versionName'] as String?,
      versionNumber: json['versionNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'package': package,
      'versionName': versionName,
      'versionNumber': versionNumber,
    };
  }

  PackageDirectory cloneWith({String? versionName, String? versionNumber}) {
    return PackageDirectory(
      package: package,
      versionName: versionName ?? this.versionName,
      versionNumber: versionNumber ?? this.versionNumber,
    );
  }
}
