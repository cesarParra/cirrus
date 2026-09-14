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
        case RequirePackages():
          return await _requirePackages(step, index);
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

    final present = await _installedVersion(step, index, key);
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
        _saying(
          'Salesforce refused the install of ${step.name}',
          requested.body,
        ),
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

  /// Nothing is installed and nothing is posted: the answer arrives in seconds, before a
  /// `PackageInstallRequest` has been spent on an org that was never eligible.
  Future<_Outcome> _requirePackages(RequirePackages step, int index) async {
    final absent = <String>[];
    final tooOld = <String>[];
    final unanswerable = <String>[];

    for (final packageVersionId in step.packages) {
      final wanted = await _versionBehind(
        packageVersionId,
        index,
        key: config.installationKeys[index],
      );
      if (wanted == null) {
        unanswerable.add(packageVersionId);
        continue;
      }

      final asked = await _installedVersionOf(wanted.packageId);

      Future<String> naming() async =>
          await _nameOf(wanted.packageId, index) ?? packageVersionId;

      if (!asked.answered) {
        unanswerable.add(await naming());
      } else if (asked.version == null) {
        absent.add(await naming());
      } else if (!asked.version!.isAtLeast(wanted.version)) {
        tooOld.add(
          '${await naming()} is at ${asked.version}, and ${wanted.version} '
          'is needed',
        );
      } else {
        events.log(
          index,
          '${wanted.packageId} ${asked.version} satisfies ${wanted.version}',
        );
      }
    }

    final clauses = [
      if (absent.isNotEmpty)
        '${_and(absent)} ${absent.length == 1 ? 'is' : 'are'} not installed',
      ...tooOld,
      if (unanswerable.isNotEmpty)
        'this org could not be asked about ${_and(unanswerable)}',
    ];

    if (clauses.isEmpty) return const _Ran();

    return _Failed('This org is not ready: ${clauses.join('; ')}.', {
      'absent': absent,
      'tooOld': tooOld,
      'unanswerable': unanswerable,
    });
  }

  /// Null when the check cannot answer: a broken query is not evidence a package is absent.
  Future<PackageVersion?> _installedVersion(
    InstallPackage step,
    int index,
    String? key,
  ) async {
    try {
      return await _lookUpInstalled(step, index, key);
    } catch (error) {
      events.log(index, 'Could not check what is installed: $error');
      return null;
    }
  }

  Future<PackageVersion?> _lookUpInstalled(
    InstallPackage step,
    int index,
    String? key,
  ) async {
    final wanted = await _versionBehind(step.packageVersionId, index, key: key);
    if (wanted == null) return null;

    final installed = (await _installedVersionOf(wanted.packageId)).version;
    if (installed == null || !installed.isAtLeast(wanted.version)) return null;

    events.log(
      index,
      'Found ${wanted.packageId} at $installed, wanted ${wanted.version}',
    );
    return installed;
  }

  /// The package a version id belongs to, and the version it is.
  Future<({String packageId, PackageVersion version})?> _versionBehind(
    String packageVersionId,
    int index, {
    String? key,
  }) async {
    // A key-protected version answers nothing without its key in the filter.
    final protectedBy = key == null || key.isEmpty
        ? ''
        : " AND InstallationKey = '${_soql(key)}'";

    final asked = await _one(
      'SELECT SubscriberPackageId, MajorVersion, MinorVersion, PatchVersion, BuildNumber '
      "FROM SubscriberPackageVersion WHERE Id = '$packageVersionId'$protectedBy",
    );

    final version = PackageVersion.from(asked);
    final packageId = asked?['SubscriberPackageId'];
    if (version == null || packageId is! String) return null;

    return (packageId: packageId, version: version);
  }

  /// `answered: false` is a query that broke, which is not evidence a package is absent.
  Future<({bool answered, PackageVersion? version})> _installedVersionOf(
    String packageId,
  ) async {
    final asked = await _ask(
      'SELECT SubscriberPackageVersion.MajorVersion, SubscriberPackageVersion.MinorVersion, '
      'SubscriberPackageVersion.PatchVersion, SubscriberPackageVersion.BuildNumber '
      "FROM InstalledSubscriberPackage WHERE SubscriberPackageId = '$packageId'",
    );

    return (
      answered: asked.ok,
      version: PackageVersion.from(
        asked.record?['SubscriberPackageVersion'] as Map<String, dynamic>?,
      ),
    );
  }

  /// Salesforce's own name for the package, so the message says "Fonteva PagesApi" and not an id.
  Future<String?> _nameOf(String packageId, int index) async {
    try {
      final found = await _one(
        "SELECT Name FROM SubscriberPackage WHERE Id = '$packageId'",
      );
      final name = found?['Name'];
      return name is String && name.isNotEmpty ? name : null;
    } catch (error) {
      events.log(index, 'Could not read the name of $packageId: $error');
      return null;
    }
  }

  static String _saying(String summary, Object? reported) {
    final said = _messagesIn(reported).toSet().join('; ');
    return said.isEmpty ? '$summary.' : '$summary: $said';
  }

  static Iterable<String> _messagesIn(Object? reported) sync* {
    switch (reported) {
      case Map<String, dynamic> fields:
        final message = fields['message'];
        if (message is String && message.isNotEmpty) yield message;
        for (final value in fields.values) {
          if (value is Map || value is List) yield* _messagesIn(value);
        }
      case List<dynamic> items:
        for (final item in items) {
          yield* _messagesIn(item);
        }
    }
  }

  static String _and(List<String> parts) => switch (parts.length) {
    1 => parts.single,
    _ => '${parts.take(parts.length - 1).join(', ')} and ${parts.last}',
  };

  Future<Map<String, dynamic>?> _one(String soql) async =>
      (await _ask(soql)).record;

  Future<({bool ok, Map<String, dynamic>? record})> _ask(String soql) async {
    final response = await org.get(
      '$_tooling/query?q=${Uri.encodeQueryComponent(soql)}',
    );
    if (!response.ok) return (ok: false, record: null);

    final records = response.body['records'];
    if (records is! List || records.isEmpty) return (ok: true, record: null);

    return (ok: true, record: records.first as Map<String, dynamic>);
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
        final errors = polled.body['Errors'];
        return _Failed(_saying('${step.name} failed to install', errors), {
          'errors': errors,
        });
      }

      await Future.delayed(pollInterval);
    }

    return _Failed(
      '${step.name} was still installing after ${timeout.inMinutes} minutes.',
      {'status': last},
    );
  }

  static String _soql(String literal) =>
      literal.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

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
