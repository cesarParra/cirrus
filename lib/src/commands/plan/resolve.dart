import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';

import '../../failure.dart';
import '../../plan/project.dart';

class Resolve extends Command {
  @override
  String get name => 'resolve';

  @override
  String get description =>
      'Pins a repository into a plan artifact, reading only the checkout.';

  Resolve() {
    argParser
      ..addOption(
        'plan',
        help: 'The plan in cirrus.yaml to resolve. One is derived without it.',
      )
      ..addOption(
        'directory',
        abbr: 'C',
        defaultsTo: '.',
        help: 'The checkout to read.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Where to write the artifact. Standard output without it.',
      )
      ..addFlag(
        'list',
        negatable: false,
        help: 'Report the plans this repository offers, and resolve nothing.',
      );
  }

  @override
  Future<Either<Failure, String>> run() async {
    final directory = argResults!['directory'] as String;

    if (argResults!['list'] as bool) {
      return _write(
        plansIn(directory).map(
          (offered) => {'plans': offered.names, 'derives': offered.derives},
        ),
      );
    }

    return _write(
      resolveIn(
        directory,
        planName: argResults!['plan'] as String?,
      ).map((resolved) => resolved.toJson()),
    );
  }

  /// Machine-readable on stdout, so that a caller can pipe it. Nothing else is written there.
  Either<Failure, String> _write(Either<Failure, Map<String, dynamic>> result) {
    if (result is Left<Failure, Map<String, dynamic>>) {
      return Left(result.value);
    }

    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert((result as Right<Failure, Map<String, dynamic>>).value);

    final path = argResults!['output'] as String?;
    if (path == null) {
      stdout.writeln(json);
      return const Right('');
    }

    File(path).writeAsStringSync('$json\n');
    return Right('Wrote $path.');
  }
}
