import 'dart:convert';
import 'package:ansix/ansix.dart';

import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';

import '../../service_locator.dart';

class GetLatest extends Command {
  @override
  String get description =>
      'Get information about the latest version of a package.';

  @override
  String get name => 'get_latest';

  // TODO: If there are no versions, return some kind of message indicating so.
  // TODO: --json flag support.
  // TODO: --released flag support to filter only released versions.
  GetLatest() {
    argParser
      ..addOption(
        'package',
        abbr: 'p',
        mandatory: true,
        help:
            'The name of the package to to get the version for. It must either be a package Id (starts with 0Ho) '
            'the alias of the package Id as defined in the sfdx-project.json.',
      )
      ..addOption(
        'sfdx-project-json-path',
        abbr: 'j',
        help:
            'Path to the sfdx-project.json file. Defaults to looking for it in the current directory.',
        defaultsTo: 'sfdx-project.json',
      );
  }

  @override
  Future<Either<String, String>> run() async {
    final packageId = getPackageId(argResults!['package'] as String);
    return switch (packageId) {
      Left() => packageId,
      Right(:final value) => getPackageInfo(value),
    };
  }

  Either<String, String> getPackageId(String package) {
    if (package.startsWith('0Ho')) {
      return Right(package);
    }

    final sfdxProjectJsonPath = argResults!['sfdx-project-json-path'] as String;
    // Look for the "sfdx-project.json" file in the current directory
    final projectFile = getIt.get<FileSystem>(param1: sfdxProjectJsonPath);

    if (!projectFile.exists()) {
      return Left(
        '$sfdxProjectJsonPath file not found in the current directory.',
      );
    }

    // Parse the project file and get the package information
    final projectContent = projectFile.readAsStringSync();
    // Parse the JSON content
    final projectData = jsonDecode(projectContent) as Map<String, dynamic>;

    // Look for the package name in the aliases.
    final aliases = projectData['packageAliases'];
    if (aliases == null) {
      return Left('$package was not found in the packageAliases');
    }

    final packageId = aliases[package];
    return packageId != null
        ? Right(packageId)
        : Left('$package was not found in the packageAliases');
  }

  Future<Either<String, String>> getPackageInfo(String packageId) async {
    final packageVersionListOutput = await runPackageVersionList(packageId);
    return switch (packageVersionListOutput) {
      Left() => Left(
        'An error occurred when running the "sf package version list" command. Make sure that "$packageId" is a valid package Id.',
      ),
      Right(:final value) => Right(getLatest(value)),
    };
  }

  Future<Either<String, String>> runPackageVersionList(String packageId) async {
    final cliRunner = getIt.get<CliRunner>();
    try {
      final output = await cliRunner.output(
        'sf package version list -p $packageId --json',
      );
      return Right(output);
    } catch (e) {
      return Left(e.toString());
    }
  }

  String getLatest(String serializedVersions) {
    final decodedPayload = jsonDecode(serializedVersions);
    final versions = (decodedPayload['result'] as List<dynamic>)
        .map((e) => PackageVersion.fromJson(e as Map<String, dynamic>))
        .toList();

    // Sort to get the latest version. Versions are sorted by major, minor, patch, and build number,
    // where priority is given to major, then minor, then patch, and finally build number.
    versions.sort((a, b) {
      if (a.majorVersion != b.majorVersion) {
        return b.majorVersion.compareTo(a.majorVersion);
      } else if (a.minorVersion != b.minorVersion) {
        return b.minorVersion.compareTo(a.minorVersion);
      } else if (a.patchVersion != b.patchVersion) {
        return b.patchVersion.compareTo(a.patchVersion);
      } else {
        return b.buildNumber.compareTo(a.buildNumber);
      }
    });

    if (versions.isEmpty) {
      return 'No versions found for the specified package.';
    }

    final latestVersion = versions.first;

    final List<List<Object?>> rows = <List<Object?>>[
      <Object?>[
        'Major Version',
        'Minor Version',
        'Patch Version',
        'Build Number',
        'Subscriber Package Version Id',
        'Name',
        'Namespace Prefix',
        'Description',
        'Is Password Protected',
        'Is Released',
        'Install URL',
      ],
      <Object?>[
        latestVersion.majorVersion,
        latestVersion.minorVersion,
        latestVersion.patchVersion,
        latestVersion.buildNumber,
        latestVersion.subscriberPackageVersionId,
        latestVersion.name,
        latestVersion.namespacePrefix,
        latestVersion.description,
        latestVersion.isPasswordProtected,
        latestVersion.isReleased,
        latestVersion.installUrl,
      ],
    ];

    final AnsiGrid verticalGrid = AnsiGrid.fromRows(
      rows,
      theme: AnsiGridTheme(
        headerTextTheme: AnsiTextTheme(style: AnsiTextStyle(bold: true), foregroundColor: AnsiColor.green),
        keepSameWidth: false,
        orientation: AnsiOrientation.horizontal,
      ),
    );

    return verticalGrid.formattedText;
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
  });

  factory PackageVersion.fromJson(Map<String, dynamic> json) {
    return PackageVersion(
      majorVersion: json['MajorVersion'] as int,
      minorVersion: json['MinorVersion'] as int,
      patchVersion: json['PatchVersion'] as int,
      buildNumber: json['BuildNumber'] as int,
      subscriberPackageVersionId: json['SubscriberPackageVersionId'] as String,
      name: json['Name'] as String,
      namespacePrefix: json['NamespacePrefix'] as String,
      description: json['Description'] as String,
      isPasswordProtected: json['IsPasswordProtected'] as bool,
      isReleased: json['IsReleased'] as bool,
      installUrl: json['InstallUrl'] as String,
    );
  }
}
