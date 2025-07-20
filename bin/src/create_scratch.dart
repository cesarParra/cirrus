import 'package:fpdart/fpdart.dart';
import 'config.dart';

Future<Either<String, String>> runCreateScratch(
  Future<void> Function(String) cliRunner,
  Either<String, Config> config,
  String orgDefinitionName, {
  required bool setDefault,
}) async {
  switch (config) {
    case Left(:final value):
      return Left('Error parsing the cirrus.toml file: $value');
    case Right(:final value):
      return await _execute(
        cliRunner,
        value.scratchOrgDefinitions,
        orgDefinitionName,
        setDefault,
      );
  }
}

Future<Either<String, String>> _execute(
  Future<void> Function(String) cliRunner,
  List<ScratchOrgDefinition> orgDefinitions,
  String orgDefinitionName,
  bool setDefault,
) async {
  final orgDefinition = orgDefinitions.firstWhereOrOption(
    (def) => def.name == orgDefinitionName,
  );

  switch (orgDefinition) {
    case Some(:final value):
      final additionalArguments = <(String, String)>[('alias', value.name)];

      final command = _build(
        value,
        additionalArguments,
        setDefault: setDefault,
      );
      await cliRunner(command);
      return Right('Scratch org created successfully.');
    case None():
      return Left(
        "The org '$orgDefinitionName' is not defined in the cirrus.toml file.\r\nThese are the available orgs: ${orgDefinitions.map((e) => e.name).join(', ')}",
      );
  }
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

extension IterableExtestons<T> on Iterable<T> {
  Option<T> firstWhereOrOption(Function(T) f) {
    for (final current in this) {
      if (f(current)) return Some(current);
    }

    return None();
  }
}
