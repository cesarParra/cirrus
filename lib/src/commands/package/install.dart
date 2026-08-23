import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:cli_script/cli_script.dart' as cli;
import 'package:fpdart/fpdart.dart';

import '../../failure.dart';
import '../../service_locator.dart';
import 'versions.dart';

/// Installs a package into an org.
///
/// The counterpart to `package create`: cirrus could build a version and not put one anywhere,
/// which left every project writing the same script - resolve the newest version, install the
/// dependencies it names, then install it.
class Install extends Command {
  @override
  String get name => 'install';

  @override
  String get description => 'Installs a package version into an org.';

  Install() {
    argParser
      ..addOption(
        'package',
        abbr: 'p',
        mandatory: true,
        help:
            'The package to install. A subscriber package version id (starts with 04t) installs '
            'that version; a package id (starts with 0Ho) or an alias from sfdx-project.json '
            'installs the latest version of it.',
      )
      ..addOption(
        'target-org',
        abbr: 'o',
        help:
            'Username or alias of the org to install into. The CLI\'s default target org is used '
            'without it.',
      )
      ..addFlag(
        'with-dependencies',
        negatable: false,
        help:
            'Install the dependencies the package directory names in sfdx-project.json first. A '
            'package refuses to install without them.',
      )
      ..addOption(
        'sfdx-project-json-path',
        abbr: 'j',
        help:
            'Path to the sfdx-project.json file. Defaults to looking for it in the current directory.',
        defaultsTo: 'sfdx-project.json',
      )
      ..addOption(
        'installation-key',
        abbr: 'k',
        help: 'Installation key for a key-protected package.',
      )
      ..addOption(
        'security-type',
        help:
            'Which profiles the package is installed for. `sf`\'s own default applies without it.',
        allowed: ['AllUsers', 'AdminsOnly'],
      )
      ..addOption(
        'wait',
        abbr: 'w',
        help: 'Number of minutes to wait for the install to complete.',
        defaultsTo: '30',
      );
  }

  @override
  Future<Either<Failure, String>> run() async {
    final projectPath = argResults!['sfdx-project-json-path'] as String;
    final package = argResults!['package'] as String;

    if (argResults!.flag('with-dependencies')) {
      final dependencies = dependenciesOf(package, projectPath);
      switch (dependencies) {
        case Left(:final value):
          return Left(value);
        case Right(:final value):
          for (final dependency in value) {
            final installed = await install(dependency);
            if (installed case Left(:final value)) {
              return Left(value);
            }
          }
      }
    }

    final versionId = await versionIdFor(package, projectPath);
    return switch (versionId) {
      Left(:final value) => Left(value),
      Right(:final value) => (await install(value)).map((_) => ''),
    };
  }

  /// What to install: an `04t` is already a version, anything else names a package whose latest
  /// version this resolves - the same answer `package get_latest` gives.
  Future<Either<Failure, String>> versionIdFor(
    String package,
    String projectPath,
  ) async {
    if (package.startsWith('04t')) {
      return Right(package);
    }

    final packageId = PackageVersions.idFor(package, projectPath);
    if (packageId case Left(:final value)) {
      return Left(value);
    }

    final versions = await PackageVersions.of((packageId as Right).value);
    return switch (versions) {
      Left(:final value) => Left(value),
      Right(:final value) => switch (PackageVersions.latestOf(value)) {
        None() => Left(
          Failure(
            'No versions of "$package" exist yet. Build one with `cirrus package create`.',
          ),
        ),
        Some(value: final latest) => Right(latest.subscriberPackageVersionId),
      },
    };
  }

  /// The `dependencies` the package's own directory names, read rather than restated so it moves
  /// when the project's does.
  Either<Failure, List<String>> dependenciesOf(
    String package,
    String projectPath,
  ) {
    final projectFile = getIt.get<FileSystem>(param1: projectPath);
    if (!projectFile.exists()) {
      return Left(
        Failure('$projectPath file not found in the current directory.'),
      );
    }

    final projectData =
        jsonDecode(projectFile.readAsStringSync()) as Map<String, dynamic>;
    final directories =
        projectData['packageDirectories'] as List<dynamic>? ?? [];
    final aliases = projectData['packageAliases'] as Map<String, dynamic>?;

    final named = <String>[];
    for (final directory in directories.cast<Map<String, dynamic>>()) {
      // Every directory's dependencies when the package is named by id rather than by its own
      // entry: an id says which version to install, not which directory declared it.
      final belongsToPackage =
          directory['package'] == package || package.startsWith('0');
      if (!belongsToPackage) {
        continue;
      }

      for (final dependency
          in (directory['dependencies'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()) {
        final dependencyPackage = dependency['package'] as String?;
        if (dependencyPackage == null) {
          continue;
        }

        final resolved = dependencyPackage.startsWith('04t')
            ? dependencyPackage
            : aliases?[dependencyPackage] as String?;
        if (resolved == null) {
          return Left(
            Failure(
              '"$dependencyPackage" is named as a dependency but is not a version id and is not '
              'in the packageAliases.',
            ),
          );
        }
        named.add(resolved);
      }
    }

    return Right(named);
  }

  Future<Either<Failure, String>> install(String versionId) async {
    // Every value a user chose goes through `cli.arg`: the command line is parsed back into
    // arguments by cli_script, and an alias with a space in it becomes two arguments without it.
    final command = [
      'sf package install',
      '--package=${cli.arg(versionId)}',
      '--no-prompt',
      if (argResults?['target-org'] case String org)
        '--target-org=${cli.arg(org)}',
      if (argResults?['installation-key'] case String key)
        '--installation-key=${cli.arg(key)}',
      if (argResults?['security-type'] case String security)
        '--security-type=${cli.arg(security)}',
      if (argResults?['wait'] case String wait) '--wait=${cli.arg(wait)}',
    ];

    try {
      await getIt.get<CliRunner>().run(command.join(' '));
      return const Right('');
    } on Failure catch (failure) {
      return Left(failure);
    }
  }
}
