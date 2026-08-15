import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';

import '../../config.dart';
import '../../execution.dart';
import '../../service_locator.dart';
import 'create_scratch.dart';

class RunCommand extends Command implements ReadsConfig {
  @override
  final name = 'run';

  @override
  String get description => 'Runs a standalone command';

  RunCommand() {
    addSubcommand(CreateScratchCommand());

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
}

// Default run commands

class CreateScratchCommand extends Command {
  @override
  final name = 'create_scratch';

  @override
  String get description => 'Creates a scratch org.';

  CreateScratchCommand() {
    argParser
      ..addOption(
        'name',
        abbr: 'n',
        help:
            'The name of the scratch org definition to create. Defaults to the org marked '
            "'default: true' in the configuration file.",
      )
      ..addFlag(
        'set-default',
        abbr: 'd',
        defaultsTo: true,
        negatable: true,
        help: 'Set the created scratch org as the default org.',
      );
  }

  @override
  Future<Either<String, String>> run() async {
    return await runCreateScratch(
      argResults?.option('name'),
      setDefault: argResults?.flag('set-default') ?? true,
    );
  }
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
