import 'package:fpdart/fpdart.dart';

import '../failure.dart';
import '../sfdx_project_json.dart';
import '../version.dart';
import 'artifact.dart';
import 'package_version.dart';

/// What the artifact records as its plan when the repository named none.
const derivedPlanName = 'derived';

class ResolvedFrom {
  final String? repo;
  final String? commit;

  const ResolvedFrom({required this.repo, required this.commit});
}

/// One entry under a plan's `steps:`. Exactly one of [installPackage] and [requirePackages] is set;
/// the config parser is what holds that true.
class PlanStepDefinition {
  final String? installPackage;
  final String? requirePackages;
  final List<String> packages;
  final String? description;

  const PlanStepDefinition({
    this.installPackage,
    this.requirePackages,
    this.packages = const [],
    this.description,
  });

  /// Stated here and in the schema's `$defs/planStep`; a test holds the two together.
  static const keys = {
    'installPackage',
    'requirePackages',
    'packages',
    'description',
  };
}

class PlanDefinition {
  final String name;
  final String? title;
  final List<PlanStepDefinition> steps;

  const PlanDefinition({required this.name, this.title, required this.steps});

  /// Stated here and in the schema's `$defs/plan`; a test holds the two together.
  static const keys = {'title', 'steps'};
}

class ResolvedStep {
  final String kind;
  final String name;
  final String? description;
  final String? packageVersionId;
  final List<String> packages;

  const ResolvedStep.install({
    required this.name,
    required this.description,
    required String this.packageVersionId,
  }) : kind = 'installPackage',
       packages = const [];

  const ResolvedStep.require({
    required this.name,
    required this.description,
    required this.packages,
  }) : kind = 'requirePackages',
       packageVersionId = null;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'name': name,
    if (description != null) 'description': description,
    if (packageVersionId != null) 'packageVersionId': packageVersionId,
    if (kind == 'requirePackages') 'packages': packages,
  };
}

class ResolvedPlan {
  final String product;
  final String version;
  final String title;
  final List<ResolvedStep> steps;
  final ResolvedFrom from;

  /// The plan's name, or `derived` when the repository named none. Recorded so that "why does this
  /// install check for Fonteva" is answerable from the artifact alone.
  final String plan;

  const ResolvedPlan({
    required this.product,
    required this.version,
    required this.title,
    required this.steps,
    required this.from,
    required this.plan,
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': Plan.supportedSchemaVersion,
    'product': product,
    'version': version,
    'title': title,
    'resolvedAt': DateTime.now().toUtc().toIso8601String(),
    'resolvedFrom': {
      if (from.repo != null) 'repo': from.repo,
      if (from.commit != null) 'commit': from.commit,
      'cirrus': appVersion,
      'plan': plan,
    },
    'steps': steps.map((step) => step.toJson()).toList(),
  };
}

/// A concrete `04t`, and the version alias it came from when resolution picked one.
typedef Pinned = ({String id, String? version});

const _subscriberPackageVersion = '04t';
const _package = '0Ho';

Either<Failure, Pinned> pinned(SfdxProjectJson project, String alias) {
  if (alias.startsWith(_subscriberPackageVersion)) {
    return Right((id: alias, version: null));
  }

  final aliases = project.packageAliases ?? const {};
  final named = aliases[alias];
  if (named == null) {
    return Left(
      Failure(
        "'$alias' is not a packageAlias in sfdx-project.json, and is not a "
        'subscriber package version id.',
      ),
    );
  }

  if (named.startsWith(_package)) return _highestVersionOf(aliases, alias);

  final at = alias.indexOf('@');
  return Right((id: named, version: at < 0 ? null : alias.substring(at + 1)));
}

/// Sorted on the parsed version, because `0.1.0-4` is above `0.1.0-33` as a string and publishing
/// the wrong package version is the expensive mistake in this system.
Either<Failure, Pinned> _highestVersionOf(
  Map<String, String> aliases,
  String package,
) {
  final built = <(PackageVersion, String, String)>[];

  for (final entry in aliases.entries) {
    if (!entry.key.startsWith('$package@')) continue;
    final label = entry.key.substring(package.length + 1);
    final version = PackageVersion.parse(label);
    if (version != null) built.add((version, label, entry.value));
  }

  if (built.isEmpty) {
    return Left(
      Failure(
        "'$package' names a package with no version built from it. "
        'sfdx-project.json has no $package@… alias.',
      ),
    );
  }

  built.sort((one, other) => one.$1.compareTo(other.$1));
  final highest = built.last;
  return Right((id: highest.$3, version: highest.$2));
}

Either<Failure, ResolvedPlan> resolve({
  required SfdxProjectJson project,
  required PlanDefinition? plan,
  required ResolvedFrom from,
}) {
  final own = _packageThisRepoBuilds(project);
  if (own == null) {
    return Left(
      Failure(
        'sfdx-project.json has no packageDirectory naming a package, so there '
        'is nothing to install.',
      ),
    );
  }

  final built = pinned(project, own);
  if (built is Left<Failure, Pinned>) return Left(built.value);
  final version = (built as Right<Failure, Pinned>).value.version;

  final steps = plan == null
      ? _derived(project, own)
      : _asWritten(project, plan);
  if (steps is Left<Failure, List<ResolvedStep>>) return Left(steps.value);

  return Right(
    ResolvedPlan(
      product: own.toLowerCase(),
      version: version ?? '',
      title: plan?.title ?? own,
      steps: (steps as Right<Failure, List<ResolvedStep>>).value,
      from: from,
      plan: plan?.name ?? derivedPlanName,
    ),
  );
}

/// What a repository means when it says nothing: install what this repository builds, and check for
/// everything it depends on without ever installing it.
Either<Failure, List<ResolvedStep>> _derived(
  SfdxProjectJson project,
  String own,
) {
  final steps = <ResolvedStep>[];
  final required = <String>[];

  for (final dependency in _dependenciesOf(project)) {
    final found = pinned(project, dependency);
    if (found is Left<Failure, Pinned>) return Left(found.value);
    required.add((found as Right<Failure, Pinned>).value.id);
  }

  if (required.isNotEmpty) {
    steps.add(
      ResolvedStep.require(
        name: 'Requirements',
        description:
            'Packages $own needs, which this install checks for but never installs.',
        packages: required,
      ),
    );
  }

  final built = pinned(project, own);
  if (built is Left<Failure, Pinned>) return Left(built.value);

  steps.add(
    ResolvedStep.install(
      name: own,
      description: null,
      packageVersionId: (built as Right<Failure, Pinned>).value.id,
    ),
  );

  return Right(steps);
}

Either<Failure, List<ResolvedStep>> _asWritten(
  SfdxProjectJson project,
  PlanDefinition plan,
) {
  final steps = <ResolvedStep>[];

  for (final step in plan.steps) {
    final requires = step.requirePackages;
    if (requires != null) {
      steps.add(
        ResolvedStep.require(
          name: requires,
          description: step.description,
          packages: step.packages,
        ),
      );
      continue;
    }

    final installs = step.installPackage;
    if (installs == null) {
      return Left(
        Failure(
          "A step of the plan '${plan.name}' names neither installPackage nor "
          'requirePackages.',
        ),
      );
    }

    final found = pinned(project, installs);
    if (found is Left<Failure, Pinned>) return Left(found.value);

    steps.add(
      ResolvedStep.install(
        name: installs,
        description: step.description,
        packageVersionId: (found as Right<Failure, Pinned>).value.id,
      ),
    );
  }

  return Right(steps);
}

String? _packageThisRepoBuilds(SfdxProjectJson project) {
  final directories = project.packageDirectories.where(
    (directory) => directory.package != null,
  );
  if (directories.isEmpty) return null;

  final byDefault = directories.where(
    (directory) => directory.extra['default'] == true,
  );
  return (byDefault.firstOrNull ?? directories.first).package;
}

Iterable<String> _dependenciesOf(SfdxProjectJson project) sync* {
  for (final directory in project.packageDirectories) {
    final declared = directory.extra['dependencies'];
    if (declared is! List) continue;

    for (final dependency in declared) {
      final named = dependency is Map ? dependency['package'] : null;
      if (named is String) yield named;
    }
  }
}
