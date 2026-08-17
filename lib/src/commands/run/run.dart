import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';

import '../../config.dart';
import '../../execution.dart';
import '../../service_locator.dart';

/// Every subcommand here comes out of the config file, and nothing else ever does. A built-in
/// sharing this namespace is a name a config file can collide with, and `args` refuses a duplicate
/// while the runner is being built - before any command is dispatched, so the collision takes
/// `--version` and `init` down with it.
class RunCommand extends Command implements ReadsConfig {
  @override
  final name = 'run';

  @override
  String get description => 'Runs a command defined in the config file.';

  RunCommand() {
    // A config that did not load is reported before any command is dispatched, so there are simply
    // no configured commands to offer here.
    final config = loadedConfig();
    if (config == null) {
      return;
    }

    for (final namedCommand in config.commands) {
      addSubcommand(RunNamedCommand(config, namedCommand));
    }
  }

  // Every subcommand comes out of the config file, so a config naming no commands leaves this a
  // leaf - and `args` demands a `run()` from a leaf. Reached only then: with subcommands to offer,
  // `args` reports the missing one itself and never calls this.
  @override
  Either<String, String> run() =>
      Left('No commands are defined in $configFileName.');
}

class RunNamedCommand extends Command {
  final Config config;
  final NamedCommand command;

  @override
  String get name => command.name;

  @override
  String get description => command.description ?? 'Execute the $name command.';

  RunNamedCommand(this.config, this.command);

  @override
  Future<Either<String, String>> run() async {
    // Empty on success: a command that worked says nothing, the way it always has.
    return (await Execution(config).step(
      command.name,
      arguments: argResults?.rest ?? const [],
    )).map((_) => '');
  }
}
