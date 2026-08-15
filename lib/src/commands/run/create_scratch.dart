import 'package:cirrus/src/utils.dart';
import 'package:cli_script/cli_script.dart' as cli;
import 'package:fpdart/fpdart.dart';
import '../../config.dart';
import '../../service_locator.dart';

Future<Either<String, String>> runCreateScratch(
  String? orgDefinitionName, {
  required bool setDefault,
}) async {
  final config = getIt.get<Either<String, Config>>();

  switch (config) {
    case Left(:final value):
      return Left(value);
    case Right(:final value):
      final orgs = value.scratchOrgDefinitions;

      // The org named on the command line, or the one the config marks as the default. Passing
      // `-n` every time for the org a project almost always creates is what a default is for.
      if (orgDefinitionName == null) {
        final fallback = value.defaultOrg;

        if (fallback == null) {
          return Left(
            "No org to create. Name one with --name, or mark an org 'default: true' in "
            "$configFileName.\r\n${_available(orgs)}",
          );
        }

        return await _create(fallback, setDefault: setDefault);
      }

      final named = orgs.firstWhereOrOption(
        (def) => def.name == orgDefinitionName,
      );

      return switch (named) {
        Some(:final value) => await _create(value, setDefault: setDefault),
        None() => Left(
          "The org '$orgDefinitionName' is not defined in the $configFileName "
          "file.\r\n${_available(orgs)}",
        ),
      };
  }
}

Future<Either<String, String>> _create(
  ScratchOrgDefinition orgDefinition, {
  required bool setDefault,
}) async {
  await getIt.get<CliRunner>().run(_build(orgDefinition, setDefault));
  return Right('Scratch org created successfully.');
}

String _build(ScratchOrgDefinition orgDefinition, bool setDefault) {
  // The definition file and the alias come out of the config, and cli_script parses this string
  // back into arguments - so a path or an alias with a space in it has to say it is one argument.
  return [
    'sf org scratch create',
    '--definition-file=${cli.arg(orgDefinition.definitionFile)}',
    '--alias=${cli.arg(orgDefinition.alias)}',
    if (setDefault) '--set-default',
    if (orgDefinition.duration != null)
      '--duration-days=${orgDefinition.duration}',
    if (!orgDefinition.namespace) '--no-namespace',
    if (orgDefinition.wait != null) '--wait=${orgDefinition.wait}',
  ].join(' ');
}

String _available(List<ScratchOrgDefinition> orgDefinitions) {
  if (orgDefinitions.isEmpty) {
    return 'No orgs are defined.';
  }

  return 'These are the available orgs: ${orgDefinitions.map((e) => e.name).join(', ')}';
}
