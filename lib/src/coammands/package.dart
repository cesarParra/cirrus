import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:cirrus/src/create_scratch.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:fpdart/fpdart.dart';

class PackageCommand extends Command {
  @override
  String get name => 'package';

  @override
  String get description => 'Releases a new package version.';

  PackageCommand() {
    argParser
      ..addOption(
        'package',
        abbr: 'p',
        mandatory: true,
        help:
            'The name of the package to release, as defined in the sfdx-project.json file.',
      )
      ..addOption(
        'version-type',
        abbr: 't',
        help: 'The version type to increment the package to.',
        defaultsTo: 'minor',
        allowed: ['major', 'minor', 'patch'],
      )
      ..addOption(
        'name',
        abbr: 'a',
        help: 'The name of the new version to create.',
      )
      ..addFlag(
        'code-coverage',
        abbr: 'c',
        help:
            'Calculate and store the code coverage percentage by running the packaged Apex tests included in this package version.',
      )
      ..addOption(
        'definition-file',
        abbr: 'f',
        help:
            'Path to a definition file similar to scratch org definition file that contains the list of features and org preferences that the metadata of the package version depends on.',
      )
      ..addOption(
        'installation-key',
        abbr: 'k',
        help:
            'Installation key for key-protected package. (either --installation-key or --installation-key-bypass is required)',
      )
      ..addOption(
        'target-dev-hub',
        abbr: 'v',
        help:
            'Username or alias of the Dev Hub org. Not required if the `target-dev-hub` configuration variable is already set.',
      )
      ..addOption(
        'wait',
        abbr: 'w',
        help:
            'Number of minutes to wait for the package version to be created.',
      )
      ..addFlag(
        'installation-key-bypass',
        abbr: 'x',
        negatable: false,
        help:
            'Bypass the installation key requirement. (either --installation-key or --installation-key-bypass is required)',
      )
      ..addFlag(
        'async-validation',
        negatable: false,
        help:
            'Return a new package version before completing package validations.',
      )
      ..addFlag(
        'skip-validation',
        negatable: false,
        help:
            'Skip validation during package version creation; you can’t promote unvalidated package versions.',
      )
      ..addFlag(
        'verbose',
        negatable: false,
        help: 'Display verbose command output.',
      );
  }

  @override
  Future<Either<String, String>> run() async {
    // Look for the "sfdx-project.json" file in the current directory
    final projectFile = getIt.get<FileSystem>(param1: 'sfdx-project.json');

    if (!projectFile.exists()) {
      return Left('sfdx-project.json file not found in the current directory.');
    }

    // Parse the project file and get the package information
    final projectContent = projectFile.readAsStringSync();
    // Parse the JSON content
    final projectData = jsonDecode(projectContent) as Map<String, dynamic>;

    // Loop through the "packageDirectories" array and find a "package" with the given name
    final packageName = argResults!['package'] as String;

    final packageDirectories =
        projectData['packageDirectories'] as List<dynamic>?;
    if (packageDirectories == null || packageDirectories.isEmpty) {
      return Left('No package directories found in sfdx-project.json.');
    }

    final packageDirectory = packageDirectories.firstWhereOrOption(
      (dir) => (dir as Map<String, dynamic>)['package'] == packageName,
    );

    switch (packageDirectory) {
      case None():
        return Left('Package "$packageName" not found in sfdx-project.json.');
      case Some(value: final dir):
        // Increment the version based on the provided version type
        final versionType = argResults!['version-type'] as String;

        // Increment the version name and the version number
        final versionName = argResults?['name'] as String?;
        final packageVersion =
            (dir as Map<String, dynamic>)['versionNumber'] as String?;

        if (packageVersion == null || packageVersion.isEmpty) {
          return Left('No versionName found for package "$packageName".');
        }

        final newVersion = incrementVersion(packageVersion, versionType);

        if (versionName != null) {
          (dir)['versionName'] = versionName;
        }
        (dir)['versionNumber'] = newVersion;
        // Write the updated project data back to the file
        projectData['packageDirectories'] = packageDirectories;
        projectFile.write(getPrettyJSONString(projectData));

        final cliRunner = getIt.get<CliRunner>();

        // Run the command to create the package version
        final command = [
          'sf package version create',
          '--package=$packageName',
          if (argResults?['code-coverage'] case true) '--code-coverage',
          if (argResults?['definition-file'] case String file)
            '--definition-file=$file',
          if (argResults?['installation-key'] case String key)
            '--installation-key=$key',
          if (argResults?['installation-key-bypass'] case true)
            '--installation-key-bypass',
          if (argResults?['target-dev-hub'] case String target)
            '--target-dev-hub=$target',
          if (argResults?['wait'] case String wait) '--wait=$wait',
          if (argResults?['async-validation'] case true) '--async-validation',
          if (argResults?['skip-validation'] case true) '--skip-validation',
          if (argResults?['verbose'] case true) '--verbose',
        ];

        await cliRunner(command.join(' '));

        return Right('Package "$packageName" version updated to $newVersion.');
    }
  }

  String incrementVersion(String version, String type) {
    final parts = version.split('.');
    if (parts.length != 3 && parts.length != 4) {
      // Versions might have a trailing "build" number. This can be a number
      // or the string "NEXT".
      throw ArgumentError(
        'Invalid version format. Expected format is "major.minor.patch" or "major.minor.patch.build".',
      );
    }

    final major = int.parse(parts[0]);
    final minor = int.parse(parts[1]);
    final patch = int.parse(parts[2]);

    return switch (type) {
      'major' => '${major + 1}.0.0.NEXT',
      'minor' => '$major.${minor + 1}.0.NEXT',
      'patch' => '$major.$minor.${patch + 1}.NEXT',
      _ => throw ArgumentError('Invalid version type: $type'),
    };
  }

  String getPrettyJSONString(dynamic jsonObject) {
    final encoder = JsonEncoder.withIndent("  ");
    return encoder.convert(jsonObject);
  }
}
