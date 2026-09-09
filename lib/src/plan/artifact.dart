import 'dart:convert';

import 'package:fpdart/fpdart.dart';

import '../failure.dart';

class Plan {
  static const supportedSchemaVersion = 1;

  final String product;
  final String version;
  final String title;
  final List<PlanStep> steps;

  const Plan({
    required this.product,
    required this.version,
    required this.title,
    required this.steps,
  });

  static Either<Failure, Plan> parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      return Left(Failure('The plan is not JSON: ${error.message}'));
    }

    if (decoded is! Map<String, dynamic>) {
      return Left(Failure('The plan must be a JSON object.'));
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion != supportedSchemaVersion) {
      return Left(
        Failure(
          'This plan is schemaVersion $schemaVersion; this cirrus reads '
          '$supportedSchemaVersion.',
        ),
      );
    }

    final rawSteps = decoded['steps'];
    if (rawSteps is! List || rawSteps.isEmpty) {
      return Left(Failure('The plan has no steps.'));
    }

    final steps = <PlanStep>[];
    for (var index = 0; index < rawSteps.length; index++) {
      final parsed = PlanStep.parse(rawSteps[index], index);
      if (parsed is Left<Failure, PlanStep>) {
        return Left(parsed.value);
      }
      steps.add((parsed as Right<Failure, PlanStep>).value);
    }

    return Right(
      Plan(
        product: decoded['product'] as String? ?? '',
        version: decoded['version'] as String? ?? '',
        title: decoded['title'] as String? ?? '',
        steps: steps,
      ),
    );
  }
}

/// A kind cirrus cannot run is refused before the install starts: a plan half-run is the one
/// outcome with no clean recovery.
sealed class PlanStep {
  final String name;

  const PlanStep(this.name);

  static Either<Failure, PlanStep> parse(Object? raw, int index) {
    if (raw is! Map<String, dynamic>) {
      return Left(Failure('Step $index is not an object.'));
    }

    final name = raw['name'] as String? ?? 'Step ${index + 1}';
    switch (raw['kind']) {
      case 'installPackage':
        final packageVersionId = raw['packageVersionId'];
        if (packageVersionId is! String || packageVersionId.isEmpty) {
          return Left(Failure('Step $index ($name) has no packageVersionId.'));
        }
        return Right(
          InstallPackage(
            name: name,
            packageVersionId: packageVersionId,
            requiresInstallationKey:
                raw['requiresInstallationKey'] as bool? ?? false,
          ),
        );
      case final kind:
        return Left(
          Failure(
            'Step $index ($name) is a $kind, which this cirrus cannot run.',
          ),
        );
    }
  }
}

class InstallPackage extends PlanStep {
  final String packageVersionId;
  final bool requiresInstallationKey;

  const InstallPackage({
    required String name,
    required this.packageVersionId,
    required this.requiresInstallationKey,
  }) : super(name);
}
