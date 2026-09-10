import 'artifact.dart';
import 'events.dart';
import 'org.dart';
import 'package_version.dart';
import 'run_config.dart';

/// A step that fails stops the plan where it stands. Nothing is rolled back, and the events are
/// the record of how far it got.
class PlanExecution {
  final Plan plan;
  final RunConfig config;
  final Org org;
  final Events events;
  final Duration pollInterval;
  final Duration timeout;

  const PlanExecution({
    required this.plan,
    required this.config,
    required this.org,
    required this.events,
    this.pollInterval = const Duration(seconds: 5),
    this.timeout = const Duration(minutes: 20),
  });

  Future<bool> run() async {
    events.started(
      product: plan.product,
      version: plan.version,
      steps: plan.steps.length,
    );

    for (var index = 0; index < plan.steps.length; index++) {
      final step = plan.steps[index];
      events.stepStarted(index, step.name);
      final startedAt = DateTime.now();

      final outcome = await _run(step, index);
      final seconds = DateTime.now().difference(startedAt).inSeconds;

      switch (outcome) {
        case _Failed(:final message, :final detail):
          events.stepFailed(index, message, detail);
          events.finished('failed');
          return false;
        case _Skipped(:final because):
          events.stepSkipped(index, because, seconds);
        case _Ran():
          events.stepFinished(index, seconds);
      }
    }

    events.finished('ok');
    return true;
  }

  /// A step that threw is a step that failed, not a cirrus that crashed: the org may already have
  /// been touched.
  Future<_Outcome> _run(PlanStep step, int index) async {
    try {
      switch (step) {
        case InstallPackage():
          return await _installPackage(step, index);
      }
    } catch (error) {
      return _Failed('${step.name} could not be reached.', {'error': '$error'});
    }
  }

  Future<_Outcome> _installPackage(InstallPackage step, int index) async {
    final key = config.installationKeys[index];
    if (step.requiresInstallationKey && (key == null || key.isEmpty)) {
      return _Failed(
        'No installation key was supplied for ${step.name}.',
        const {},
      );
    }

    final present = await _installedVersion(step, index);
    if (present != null) {
      return _Skipped('${step.name} $present is already installed.');
    }

    final requested = await org.post('$_tooling/sobjects/PackageInstallRequest', {
      'SubscriberPackageVersionKey': step.packageVersionId,
      // ponytail: `None` installs for administrators only, which is what the spike verified.
      // A plan-level securityType is the upgrade when a product needs all users at install time.
      'SecurityType': 'None',
      'NameConflictResolution': 'Block',
      if (key != null && key.isNotEmpty) 'Password': key,
    });

    if (!requested.ok) {
      return _Failed(
        'Salesforce refused the install of ${step.name}.',
        requested.body,
      );
    }

    final id = requested.body['id'];
    if (id is! String) {
      return _Failed(
        'Salesforce accepted the install of ${step.name} without returning a request id.',
        requested.body,
      );
    }
    events.log(index, 'PackageInstallRequest $id');

    return _awaitInstall(id, step, index);
  }

  /// Null when the check cannot answer: a broken query is not evidence a package is absent.
  Future<PackageVersion?> _installedVersion(
    InstallPackage step,
    int index,
  ) async {
    final asked = await _one(
      'SELECT SubscriberPackageId, MajorVersion, MinorVersion, PatchVersion, BuildNumber '
      "FROM SubscriberPackageVersion WHERE Id = '${step.packageVersionId}'",
    );

    final wanted = PackageVersion.from(asked);
    final packageId = asked?['SubscriberPackageId'];
    if (wanted == null || packageId is! String) return null;

    final installed = PackageVersion.from(
      (await _one(
            'SELECT SubscriberPackageVersion.MajorVersion, SubscriberPackageVersion.MinorVersion, '
            'SubscriberPackageVersion.PatchVersion, SubscriberPackageVersion.BuildNumber '
            "FROM InstalledSubscriberPackage WHERE SubscriberPackageId = '$packageId'",
          ))?['SubscriberPackageVersion']
          as Map<String, dynamic>?,
    );

    if (installed == null || !installed.isAtLeast(wanted)) return null;

    events.log(index, 'Found $packageId at $installed, wanted $wanted');
    return installed;
  }

  Future<Map<String, dynamic>?> _one(String soql) async {
    final response = await org.get(
      '$_tooling/query?q=${Uri.encodeQueryComponent(soql)}',
    );
    if (!response.ok) return null;

    final records = response.body['records'];
    if (records is! List || records.isEmpty) return null;

    return records.first as Map<String, dynamic>;
  }

  Future<_Outcome> _awaitInstall(
    String id,
    InstallPackage step,
    int index,
  ) async {
    final deadline = DateTime.now().add(timeout);
    String? last;

    while (DateTime.now().isBefore(deadline)) {
      final polled = await org.get(
        '$_tooling/sobjects/PackageInstallRequest/$id',
      );
      if (!polled.ok) {
        return _Failed(
          'Lost track of the install of ${step.name}.',
          polled.body,
        );
      }

      final status = '${polled.body['Status']}';
      if (status != last) {
        last = status;
        events.stepProgress(index, status);
      }

      if (status == 'SUCCESS') return const _Ran();
      if (status == 'ERROR') {
        return _Failed('${step.name} failed to install.', {
          'errors': polled.body['Errors'],
        });
      }

      await Future.delayed(pollInterval);
    }

    return _Failed(
      '${step.name} was still installing after ${timeout.inMinutes} minutes.',
      {'status': last},
    );
  }

  String get _tooling => '/services/data/v${config.apiVersion}/tooling';
}

sealed class _Outcome {
  const _Outcome();
}

class _Ran extends _Outcome {
  const _Ran();
}

class _Skipped extends _Outcome {
  final String because;

  const _Skipped(this.because);
}

class _Failed extends _Outcome {
  final String message;
  final Map<String, dynamic> detail;

  const _Failed(this.message, this.detail);
}
