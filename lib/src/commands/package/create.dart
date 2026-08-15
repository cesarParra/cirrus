import 'package:args/command_runner.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:cirrus/src/sfdx_project_json.dart';
import 'package:cirrus/src/utils.dart';
import 'package:fpdart/fpdart.dart';
import 'dart:convert';

import 'package:cli_script/cli_script.dart' as cli;

class Create extends Command {
  @override
  String get description => 'Creates a new package version.';

  @override
  String get name => 'create';

  Create() {
    argParser
      ..addOption(
        'package',
        abbr: 'p',
        mandatory: true,
        help:
            'The name of the package to release, as defined in the sfdx-project.json file.',
      )
      ..addOption(
        'sfdx-project-json-path',
        abbr: 'j',
        help:
            'Path to the sfdx-project.json file. Defaults to looking for it in the current directory.',
        defaultsTo: 'sfdx-project.json',
      )
      ..addOption(
        'version-type',
        abbr: 't',
        help:
            'The version type to increment the package to. `none` leaves the version number as '
            'it is, for a project that lets Salesforce choose the build number.',
        defaultsTo: 'minor',
        allowed: ['major', 'minor', 'patch', 'none'],
      )
      ..addFlag(
        'promote',
        negatable: false,
        help: 'Whether to promote the package version.',
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
    final packageJson = SfdxProjectJson.fromJson(projectData);
    final packageName = argResults!['package'];

    // Loop through the "packageDirectories" array and find a "package" with the given name
    final packageDirectory = packageJson.packageDirectories.firstWhereOrOption(
      (dir) => dir.package == packageName,
    );

    switch (packageDirectory) {
      case None():
        return Left('Package "$packageName" not found in sfdx-project.json.');
      case Some(value: var dir):
        // Increment the version based on the provided version type
        final versionType = argResults!['version-type'] as String;

        // Increment the version name and the version number
        final versionName = argResults?['name'] as String?;
        final packageVersion = dir.versionNumber;

        if (packageVersion == null || packageVersion.isEmpty) {
          return Left('No versionName found for package "$packageName".');
        }

        // A `.NEXT` version number means Salesforce owns the build number, so `none` leaves the
        // file as it was found.
        final bumped = versionType == 'none'
            ? null
            : incrementVersion(packageVersion, versionType);
        final newVersion = bumped ?? packageVersion;

        if (bumped != null || versionName != null) {
          dir = dir.cloneWith(versionName: versionName, versionNumber: bumped);

          // Write the updated project data back to the file
          projectData['packageDirectories'] = packageJson.packageDirectories
              .map((e) {
                if (e.package == packageName) {
                  return dir.toJson();
                }
                return e.toJson();
              })
              .toList();
          projectFile.write(getPrettyJSONString(projectData));
        }

        final cliRunner = getIt.get<CliRunner>();

        // Run the command to create the package version
        // Every value a user chose goes through `cli.arg`: the command line is parsed back into
        // arguments by cli_script, and a package name or a path with a space in it becomes two
        // arguments without it.
        final command = [
          'sf package version create',
          '--json',
          '--package=${cli.arg(packageName)}',
          if (argResults?['code-coverage'] case true) '--code-coverage',
          if (argResults?['definition-file'] case String file)
            '--definition-file=${cli.arg(file)}',
          if (argResults?['installation-key'] case String key)
            '--installation-key=${cli.arg(key)}',
          if (argResults?['installation-key-bypass'] case true)
            '--installation-key-bypass',
          if (argResults?['target-dev-hub'] case String target)
            '--target-dev-hub=${cli.arg(target)}',
          if (argResults?['wait'] case String wait) '--wait=${cli.arg(wait)}',
          if (argResults?['async-validation'] case true) '--async-validation',
          if (argResults?['skip-validation'] case true) '--skip-validation',
          if (argResults?['verbose'] case true) '--verbose',
        ];

        String versionCreateOutput = await cliRunner.output(command.join(' '));
        print(versionCreateOutput);

        if (argResults?['promote'] case true) {
          // Parse the output to get the package version ID
          final versionCreateJson = jsonDecode(versionCreateOutput);
          final packageVersionId =
              versionCreateJson['result']['SubscriberPackageVersionId']
                  as String?;

          if (packageVersionId == null || packageVersionId.isEmpty) {
            return Left(
              'Failed to create package version. No SubscriberPackageVersionId found in the output.',
            );
          }

          // Run the command to promote the package version
          final promoteCommand = [
            'sf package version promote',
            '--no-prompt',
            '--package=${cli.arg(packageVersionId)}',
            if (argResults?['target-dev-hub'] case String target)
              '--target-dev-hub=${cli.arg(target)}',
          ];
          await cliRunner.run(promoteCommand.join(' '));
        }

        // Under `none` the build number is Salesforce's to choose, so there is no version number
        // here to name - the one that was created is in the output above.
        final created = bumped == null
            ? 'A new version of package "$packageName"'
            : 'Package "$packageName" version $newVersion';

        String message = switch (argResults?['promote']) {
          true => '$created created and promoted successfully.',
          _ => '$created created successfully.',
        };
        return Right(message);
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
