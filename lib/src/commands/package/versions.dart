import 'dart:convert';

import 'package:fpdart/fpdart.dart';

import '../../failure.dart';
import '../../service_locator.dart';

/// Resolving a package to its versions, shared by every command that has to ask which one to act
/// on - so `get_latest` and `install` can never disagree about which version is the latest.
class PackageVersions {
  /// A `0Ho` package id, whether one was given or an alias naming one was.
  static Either<Failure, String> idFor(
    String package,
    String sfdxProjectJsonPath,
  ) {
    if (package.startsWith('0Ho')) {
      return Right(package);
    }

    final projectFile = getIt.get<FileSystem>(param1: sfdxProjectJsonPath);
    if (!projectFile.exists()) {
      return Left(
        Failure(
          '$sfdxProjectJsonPath file not found in the current directory.',
        ),
      );
    }

    final projectData =
        jsonDecode(projectFile.readAsStringSync()) as Map<String, dynamic>;
    final aliases = projectData['packageAliases'] as Map<String, dynamic>?;
    final packageId = aliases?[package] as String?;

    return packageId != null
        ? Right(packageId)
        : Left(Failure('$package was not found in the packageAliases'));
  }

  static Future<Either<Failure, List<PackageVersion>>> of(
    String packageId,
  ) async {
    final cliRunner = getIt.get<CliRunner>();
    try {
      final output = await cliRunner.output(
        'sf package version list -p $packageId --json',
      );
      final decoded = jsonDecode(output);
      return Right(
        (decoded['result'] as List<dynamic>)
            .map((e) => PackageVersion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      return Left(
        Failure(
          'An error occurred when running the "sf package version list" command. '
          'Make sure that "$packageId" is a valid package Id.',
        ),
      );
    }
  }

  /// The most recently built version.
  ///
  /// By creation date rather than by version number, because a number only answers this while it
  /// has never gone down - and a project that moves off calendar versioning, or resets a major,
  /// makes its newest build the lowest-numbered one. The highest number then names a build from
  /// before the change, which is a stale answer that looks like a fresh one.
  ///
  /// The number breaks a tie, for two versions created in the same minute.
  static Option<PackageVersion> latestOf(List<PackageVersion> versions) {
    if (versions.isEmpty) {
      return const None();
    }

    final sorted = [...versions]
      ..sort((a, b) {
        final byDate = b.createdDate.compareTo(a.createdDate);
        return byDate != 0 ? byDate : b.number.compareTo(a.number);
      });

    return Some(sorted.first);
  }
}

class PackageVersion {
  int majorVersion;
  int minorVersion;
  int patchVersion;
  int buildNumber;
  String subscriberPackageVersionId;
  String name;
  String namespacePrefix;
  String description;
  bool isPasswordProtected;
  bool isReleased;
  String installUrl;
  String createdDate;

  PackageVersion({
    required this.majorVersion,
    required this.minorVersion,
    required this.patchVersion,
    required this.buildNumber,
    required this.subscriberPackageVersionId,
    required this.name,
    required this.namespacePrefix,
    required this.description,
    required this.isPasswordProtected,
    required this.isReleased,
    required this.installUrl,
    this.createdDate = '',
  });

  String get version =>
      '$majorVersion.$minorVersion.$patchVersion.$buildNumber';

  /// Zero-padded so a string comparison orders it, for the tie-break above.
  String get number => [
    majorVersion,
    minorVersion,
    patchVersion,
    buildNumber,
  ].map((part) => part.toString().padLeft(10, '0')).join('.');

  factory PackageVersion.fromJson(Map<String, dynamic> json) {
    return PackageVersion(
      majorVersion: json['MajorVersion'] as int,
      minorVersion: json['MinorVersion'] as int,
      patchVersion: json['PatchVersion'] as int,
      buildNumber: json['BuildNumber'] as int,
      subscriberPackageVersionId:
          json['SubscriberPackageVersionId'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      namespacePrefix: json['NamespacePrefix'] as String? ?? '',
      description: json['Description'] as String? ?? '',
      isPasswordProtected: json['IsPasswordProtected'] as bool? ?? false,
      isReleased: json['IsReleased'] as bool? ?? false,
      installUrl: json['InstallUrl'] as String? ?? '',
      createdDate: json['CreatedDate'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'MajorVersion': majorVersion,
    'MinorVersion': minorVersion,
    'PatchVersion': patchVersion,
    'BuildNumber': buildNumber,
    'SubscriberPackageVersionId': subscriberPackageVersionId,
    'Name': name,
    'NamespacePrefix': namespacePrefix,
    'Description': description,
    'IsPasswordProtected': isPasswordProtected,
    'IsReleased': isReleased,
    'InstallUrl': installUrl,
    'CreatedDate': createdDate,
  };
}
