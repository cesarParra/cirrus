import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../config.dart';
import '../failure.dart';
import '../sfdx_project_json.dart';
import 'resolve.dart';

const sfdxProjectFileName = 'sfdx-project.json';

/// What a repository offers to resolve with, so that a caller can put the choice in front of
/// someone before it is made.
typedef Offered = ({List<String> names, bool derives});

Either<Failure, Offered> plansIn(String directory) {
  final read = _plansOf(directory);
  if (read is Left<Failure, List<PlanDefinition>>) return Left(read.value);

  final plans = (read as Right<Failure, List<PlanDefinition>>).value;
  return Right((
    names: plans.map((plan) => plan.name).toList(),
    derives: plans.isEmpty,
  ));
}

Either<Failure, ResolvedPlan> resolveIn(
  String directory, {
  required String? planName,
}) {
  final read = _projectIn(directory);
  if (read is Left<Failure, SfdxProjectJson>) return Left(read.value);

  final plans = _plansOf(directory);
  if (plans is Left<Failure, List<PlanDefinition>>) return Left(plans.value);

  final chosen = _chosen(
    (plans as Right<Failure, List<PlanDefinition>>).value,
    planName,
  );
  if (chosen is Left<Failure, PlanDefinition?>) return Left(chosen.value);

  return resolve(
    project: (read as Right<Failure, SfdxProjectJson>).value,
    plan: (chosen as Right<Failure, PlanDefinition?>).value,
    from: gitIn(directory),
  );
}

Either<Failure, PlanDefinition?> _chosen(
  List<PlanDefinition> plans,
  String? named,
) {
  if (named != null) {
    final wanted = plans.where((plan) => plan.name == named).firstOrNull;
    return wanted == null
        ? Left(
            Failure(
              plans.isEmpty
                  ? "This repository names no plans, so there is no '$named' to "
                        'resolve.'
                  : "This repository names no plan called '$named'. It has "
                        '${_and(plans.map((plan) => "'${plan.name}'").toList())}.',
            ),
          )
        : Right(wanted);
  }

  if (plans.isEmpty) return const Right(null);
  if (plans.length == 1) return Right(plans.single);

  final byConvention = plans.where((plan) => plan.name == 'install').firstOrNull;
  if (byConvention != null) return Right(byConvention);

  return Left(
    Failure(
      'This repository names ${_and(plans.map((plan) => "'${plan.name}'").toList())}, '
      'and none of them is called install. Name the one to resolve with --plan.',
    ),
  );
}

Either<Failure, SfdxProjectJson> _projectIn(String directory) {
  final file = File('$directory/$sfdxProjectFileName');
  if (!file.existsSync()) {
    return Left(
      Failure('There is no $sfdxProjectFileName in $directory.'),
    );
  }

  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      return Left(Failure('$sfdxProjectFileName is not a JSON object.'));
    }
    return Right(SfdxProjectJson.fromJson(decoded));
  } catch (error) {
    return Left(Failure('$sfdxProjectFileName could not be read: $error'));
  }
}

Either<Failure, List<PlanDefinition>> _plansOf(String directory) {
  final file = File('$directory/$configFileName');
  if (!file.existsSync()) return const Right([]);

  try {
    return Right(Config.fromYaml(file.readAsStringSync()).plans);
  } catch (error) {
    return Left(Failure('$configFileName could not be read: $error'));
  }
}

/// What the checkout can say about itself. Absent rather than fatal: a directory that is not a
/// clone still resolves, and the artifact simply records less.
ResolvedFrom gitIn(String directory) => ResolvedFrom(
  repo: _git(directory, ['remote', 'get-url', 'origin']),
  commit: _git(directory, ['rev-parse', 'HEAD']),
);

String? _git(String directory, List<String> arguments) {
  try {
    final result = Process.runSync(
      'git',
      ['-C', directory, ...arguments],
      runInShell: false,
    );
    if (result.exitCode != 0) return null;

    final said = '${result.stdout}'.trim();
    return said.isEmpty ? null : said;
  } catch (_) {
    return null;
  }
}

String _and(List<String> parts) => switch (parts.length) {
  0 || 1 => parts.join(),
  _ => '${parts.take(parts.length - 1).join(', ')} and ${parts.last}',
};
