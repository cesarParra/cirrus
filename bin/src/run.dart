import 'package:args/command_runner.dart';
import 'package:chalkdart/chalkdart.dart';
import 'package:cli_script/cli_script.dart' as cli;
import 'package:fpdart/fpdart.dart';

class RunCommand extends Command {
  @override
  final name = 'run';

  @override
  String get description => 'Runs a standalone command';

  RunCommand(Map<String, dynamic> config) {
    // Parse the config file to pass the necessary information
    // each individual command needs

    final orgDefinitions = switch (config) {
      {'orgs': List<dynamic> orgs} =>
        orgs.map(ScratchOrgDefinition.parse).toList(),
      _ => <ScratchOrgDefinition>[],
    };

    addSubcommand(CreateScratchCommand(orgDefinitions));
  }
}

// Default run commands

// TODO: Alias support
// TODO: Set default support
// TODO: Target devhub support
class ScratchOrgDefinition {
  final String name;
  final String definitionFile;
  final int? duration;

  ScratchOrgDefinition(this.name, this.definitionFile, [this.duration]);

  static ScratchOrgDefinition parse(dynamic def) {
    return switch (def) {
      {"name": String name, "definitionFile": String definitionFile} =>
        ScratchOrgDefinition(name, definitionFile, def['duration']),
      _ => throw 'Could not parse scratch org definition.',
    };
  }
}

class CreateScratchCommand extends Command {
  final List<ScratchOrgDefinition> definitions;

  @override
  final name = 'create_scratch';

  @override
  String get description => 'Creates a scratch org.';

  CreateScratchCommand(this.definitions) {
    argParser.addOption(
      'name',
      abbr: 'n',
      mandatory: true,
      help: 'The name of the scratch org definition to create',
    );
  }

  @override
  Future<void> run() async {
    final orgName = argResults?.option('name') ?? '';
    final orgDefinition = definitions.firstWhereOrOption(
      (def) => def.name == orgName,
    );

    switch (orgDefinition) {
      case Some(:final value):
        final command = build(value);
        print(chalk.green('Running: $command'));
        await cli.run(command);
      case None():
        throw 'The org "$orgName" is not defined in the cirrus.toml file.';
    }
  }

  String build(ScratchOrgDefinition orgDefinition) {
    final root =
        'sf org scratch create --definition-file=${orgDefinition.definitionFile}';

    if (orgDefinition.duration == null) {
      return root;
    }

    return '$root --duration-days=${orgDefinition.duration}';
  }
}

extension IterableExtestons<T> on Iterable<T> {
  Option<T> firstWhereOrOption(Function(T) f) {
    for (final current in this) {
      if (f(current)) return Some(current);
    }

    return None();
  }
}
