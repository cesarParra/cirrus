import 'dart:convert';

import 'package:fpdart/fpdart.dart';

import '../failure.dart';

/// On stdin rather than argv or the environment: an access token in argv is readable out of `ps`
/// by anything running as the same user.
class RunConfig {
  final String instanceUrl;
  final String accessToken;
  final String apiVersion;

  /// Keyed by step index, matching how the plan addresses its steps.
  final Map<int, String> installationKeys;

  const RunConfig({
    required this.instanceUrl,
    required this.accessToken,
    required this.apiVersion,
    required this.installationKeys,
  });

  static const defaultApiVersion = '67.0';

  static Either<Failure, RunConfig> parse(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException catch (error) {
      return Left(
        Failure('The configuration on stdin is not JSON: ${error.message}'),
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return Left(Failure('The configuration on stdin must be a JSON object.'));
    }

    final instanceUrl = decoded['instanceUrl'];
    if (instanceUrl is! String || instanceUrl.isEmpty) {
      return Left(Failure('The configuration has no instanceUrl.'));
    }

    final accessToken = decoded['accessToken'];
    if (accessToken is! String || accessToken.isEmpty) {
      return Left(Failure('The configuration has no accessToken.'));
    }

    final keys = <int, String>{};
    final rawKeys = decoded['installationKeys'];
    if (rawKeys is Map) {
      for (final entry in rawKeys.entries) {
        final index = int.tryParse('${entry.key}');
        if (index == null) {
          return Left(
            Failure(
              'installationKeys is keyed by step index; "${entry.key}" is not one.',
            ),
          );
        }
        keys[index] = '${entry.value}';
      }
    }

    return Right(
      RunConfig(
        instanceUrl: instanceUrl.replaceAll(RegExp(r'/+$'), ''),
        accessToken: accessToken,
        apiVersion: decoded['apiVersion'] as String? ?? defaultApiVersion,
        installationKeys: keys,
      ),
    );
  }
}
