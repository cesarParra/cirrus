import 'package:cirrus/src/utils.dart';
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
      return Left('Error parsing the $configFileName file: $value');
    case Right(:final value):
      // The org named on the command line, or the one the config marks as the default. Passing
      // `-n` every time for the org a project almost always creates is what a default is for.
      final requested = orgDefinitionName ?? value.defaultOrg?.name;

      if (requested == null) {
        return Left(
          "No org to create. Name one with --name, or mark an org 'default: true' in "
          "$configFileName.\r\n${_available(value.scratchOrgDefinitions)}",
        );
      }

      return await _execute(value.scratchOrgDefinitions, requested, setDefault);
  }
}

Future<Either<String, String>> _execute(
  List<ScratchOrgDefinition> orgDefinitions,
  String orgDefinitionName,
  bool setDefault,
) async {
  final orgDefinition = orgDefinitions.firstWhereOrOption(
    (def) => def.name == orgDefinitionName,
  );

  switch (orgDefinition) {
    case Some(:final value):
      final additionalArguments = <(String, String)>[('alias', value.orgAlias)];

      final command = _build(
        value,
        additionalArguments,
        setDefault: setDefault,
      );

      final cliRunner = getIt.get<CliRunner>();
      await cliRunner.run(command);
      return Right('Scratch org created successfully.');
    case None():
      return Left(
        "The org '$orgDefinitionName' is not defined in the $configFileName file.\r\n${_available(orgDefinitions)}",
      );
  }
}

String _available(List<ScratchOrgDefinition> orgDefinitions) {
  if (orgDefinitions.isEmpty) {
    return 'No orgs are defined.';
  }

  return 'These are the available orgs: ${orgDefinitions.map((e) => e.name).join(', ')}';
}

String _build(
  ScratchOrgDefinition orgDefinition,
  List<(String, String)> additionalArguments, {
  required bool setDefault,
}) {
  var root =
      'sf org scratch create --definition-file=${orgDefinition.definitionFile}';

  for (final additionalArgument in additionalArguments) {
    root = '$root --${additionalArgument.$1}=${additionalArgument.$2}';
  }

  if (setDefault) {
    root = '$root --set-default';
  }

  if (orgDefinition.duration == null) {
    return root;
  }

  return '$root --duration-days=${orgDefinition.duration}';
}
