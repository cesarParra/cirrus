import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';

import '../../config.dart';
import '../../service_locator.dart';
import 'create_scratch.dart';

class RunCommand extends Command {
  @override
  final name = 'run';

  @override
  String get description => 'Runs a standalone command';

  RunCommand() {
    // Parse the config file to pass the necessary information
    // each individual command need

    addCreateScratchSubcommand();
    addConfiguredSubcommands();
  }

  void addCreateScratchSubcommand() {
    addSubcommand(CreateScratchCommand());
  }

  void addConfiguredSubcommands() {
    final config = getIt.get<Either<String, Config>>();
    switch (config) {
      case Left():
        return;
      case Right(:final value):
        for (final namedCommand in value.commands) {
          addSubcommand(RunNamedCommand(namedCommand));
        }
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
        mandatory: true,
        help: 'The name of the scratch org definition to create',
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
      argResults?.option('name') ?? '',
      setDefault: argResults?.flag('set-default') ?? true,
    );
  }
}

class RunNamedCommand extends Command {
  final NamedCommand command;

  @override
  String get name => command.name;

  @override
  String get description => 'Execute the $name command.';

  RunNamedCommand(this.command);

  @override
  Future<void> run() async {
    final cliRunner = getIt.get<CliRunner>();
    await cliRunner.run(command.command);
  }
}