import 'package:args/command_runner.dart';
import 'package:cli_script/cli_script.dart' as cli;

class RunCommand extends Command {
  @override
  final name = 'run';

  @override
  String get description => 'Runs a standalone command';

  RunCommand(Map<String, dynamic> config) {
    addSubcommand(CreateScratchCommand());
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
      ..addFlag(
        'alias',
        abbr: 'a',
        negatable: false,
        help: 'The alias to assign to the scratch org.',
      )
      ..addFlag(
        'set-default',
        abbr: 'd',
        negatable: false,
        help: 'Sets the created scratch org as the default one',
      )
      ..addOption(
        'definition-file',
        abbr: 'f',
        mandatory: true,
        help: 'The definition file location',
      )
      ..addOption(
        'target-dev-hub',
        abbr: 'v',
        help: 'The definition file location',
      )
      ..addOption(
        'duration-days',
        abbr: 'y',
        help: 'Number of days before the org expires.',
      );
  }

  @override
  Future<void> run() async {
    //await cli.run('sf org scratch create', args: argResults?.arguments);
  }
}
