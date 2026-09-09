import 'artifact.dart';
import 'events.dart';
import 'org.dart';
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

      final failure = await _run(step, index);
      if (failure != null) {
        events.stepFailed(index, failure.message, failure.detail);
        events.finished('failed');
        return false;
      }

      events.stepFinished(
        index,
        DateTime.now().difference(startedAt).inSeconds,
      );
    }

    events.finished('ok');
    return true;
  }

  /// A step that threw is a step that failed, not a cirrus that crashed: the org may already have
  /// been touched.
  Future<_StepFailure?> _run(PlanStep step, int index) async {
    try {
      switch (step) {
        case InstallPackage():
          return await _installPackage(step, index);
      }
    } catch (error) {
      return _StepFailure('${step.name} could not be reached.', {
        'error': '$error',
      });
    }
  }

  Future<_StepFailure?> _installPackage(InstallPackage step, int index) async {
    final key = config.installationKeys[index];
    if (step.requiresInstallationKey && (key == null || key.isEmpty)) {
      return _StepFailure(
        'No installation key was supplied for ${step.name}.',
        const {},
      );
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
      return _StepFailure(
        'Salesforce refused the install of ${step.name}.',
        requested.body,
      );
    }

    final id = requested.body['id'];
    if (id is! String) {
      return _StepFailure(
        'Salesforce accepted the install of ${step.name} without returning a request id.',
        requested.body,
      );
    }
    events.log(index, 'PackageInstallRequest $id');

    return _awaitInstall(id, step, index);
  }

  Future<_StepFailure?> _awaitInstall(
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
        return _StepFailure(
          'Lost track of the install of ${step.name}.',
          polled.body,
        );
      }

      final status = '${polled.body['Status']}';
      if (status != last) {
        last = status;
        events.stepProgress(index, status);
      }

      if (status == 'SUCCESS') return null;
      if (status == 'ERROR') {
        return _StepFailure('${step.name} failed to install.', {
          'errors': polled.body['Errors'],
        });
      }

      await Future.delayed(pollInterval);
    }

    return _StepFailure(
      '${step.name} was still installing after ${timeout.inMinutes} minutes.',
      {'status': last},
    );
  }

  String get _tooling => '/services/data/v${config.apiVersion}/tooling';
}

class _StepFailure {
  final String message;
  final Map<String, dynamic> detail;

  const _StepFailure(this.message, this.detail);
}
