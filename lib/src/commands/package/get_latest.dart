import 'dart:convert';
import 'package:ansix/ansix.dart';

import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';

import 'package:cirrus/src/failure.dart';
import 'versions.dart';

class GetLatest extends Command {
  @override
  String get description =>
      'Get information about the latest version of a package.';

  @override
  String get name => 'get_latest';

  // TODO: --released flag support to filter only released versions.
  GetLatest() {
    argParser
      ..addOption(
        'package',
        abbr: 'p',
        mandatory: true,
        help:
            'The name of the package to to get the version for. It must either be a package Id (starts with 0Ho) '
            'or the alias of the package Id as defined in the sfdx-project.json.',
      )
      ..addOption(
        'sfdx-project-json-path',
        abbr: 'j',
        help:
            'Path to the sfdx-project.json file. Defaults to looking for it in the current directory.',
        defaultsTo: 'sfdx-project.json',
      )
      ..addFlag(
        'json',
        negatable: false,
        help:
            'Emit the version as JSON, so that another command can read it rather than a person.',
      );
  }

  @override
  Future<Either<Failure, String>> run() async {
    final packageId = PackageVersions.idFor(
      argResults!['package'] as String,
      argResults!['sfdx-project-json-path'] as String,
    );

    return switch (packageId) {
      Left(:final value) => Left(value),
      Right(:final value) => (await PackageVersions.of(
        value,
      )).map((versions) => reported(PackageVersions.latestOf(versions))),
    };
  }

  String reported(Option<PackageVersion> latest) {
    final asJson = argResults!.flag('json');
    return switch (latest) {
      None() =>
        asJson
            ? jsonEncode({'result': null})
            : 'No versions found for the specified package.',
      Some(value: final version) =>
        asJson ? jsonEncode({'result': version.toJson()}) : asGrid(version),
    };
  }

  String asGrid(PackageVersion latestVersion) {
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
        headerTextTheme: AnsiTextTheme(
          style: AnsiTextStyle(bold: true),
          foregroundColor: AnsiColor.green,
        ),
        keepSameWidth: false,
        orientation: AnsiOrientation.horizontal,
      ),
    );

    return verticalGrid.formattedText;
  }
}
