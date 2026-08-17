import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';

import '../../config.dart';
import 'create_scratch.dart';

/// The orgs the config file describes. A topic of its own rather than a subcommand of `run`: `run`
/// offers what the config file names, and a built-in sharing that namespace makes one config key
/// able to take the whole CLI down.
class OrgCommand extends Command implements ReadsConfig {
  @override
  final name = 'org';

  @override
  String get description => 'Creates the orgs the config file describes.';

  OrgCommand() {
    addSubcommand(CreateOrgCommand());
  }
}

class CreateOrgCommand extends Command {
  @override
  final name = 'create';

  @override
  String get description => 'Creates a scratch org.';

  @override
  String get invocation => 'cirrus org create [org]';

  CreateOrgCommand() {
    // `sf org create scratch` spends `-d` on `--duration-days`, so this one has no abbreviation:
    // a habit carried over from `sf` would otherwise mean something else here without saying so.
    argParser.addFlag(
      'set-default',
      defaultsTo: true,
      negatable: true,
      help: 'Set the created scratch org as the default org.',
    );
  }

  @override
  Future<Either<String, String>> run() async {
    final named = argResults!.rest;

    if (named.length > 1) {
      return Left(
        'One org is created at a time, and this names ${named.length}: '
        '${named.join(', ')}.',
      );
    }

    return await runCreateScratch(
      named.firstOrNull,
      setDefault: argResults!.flag('set-default'),
    );
  }
}
