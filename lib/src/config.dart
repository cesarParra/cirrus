class ScratchOrgDefinition {
  final String name;
  final String definitionFile;
  final int? duration;

  ScratchOrgDefinition(this.name, this.definitionFile, [this.duration]);

  factory ScratchOrgDefinition.parse(dynamic def) {
    return switch (def) {
      {"name": String name, "definitionFile": String definitionFile} =>
        ScratchOrgDefinition(name, definitionFile, def['duration']),
      _ => throw 'Could not parse scratch org definition.',
    };
  }
}

class NamedCommand {
  final String name;
  final String command;

  NamedCommand(this.name, this.command);

  factory NamedCommand.parse(MapEntry entry) {
    return NamedCommand(entry.key, entry.value);
  }
}

sealed class FlowStep {
  FlowStep();

  factory FlowStep.parse(dynamic unparsed) {
    return switch (unparsed) {
      {'type': 'create_scratch', 'org': String orgName} =>
        CreateScratchFlowStep(orgName, unparsed['set-default']),
      {'type': 'command', 'name': String commandName} => RunCommandFlowStep(
        commandName,
      ),
      _ => throw 'Unable to determine the type of flow step $unparsed',
    };
  }

  String printable();
}

class CreateScratchFlowStep extends FlowStep {
  final String orgName;
  final bool? setDefault;

  CreateScratchFlowStep(this.orgName, this.setDefault);

  @override
  String printable() {
    return 'Create scratch org $orgName.';
  }
}

class RunCommandFlowStep extends FlowStep {
  final String commandName;

  RunCommandFlowStep(this.commandName);

  @override
  String printable() {
    return 'Command $commandName.';
  }
}

class Flow {
  final String name;
  final String? description;
  final List<FlowStep> steps;

  Flow(this.name, {this.description, required this.steps});

  factory Flow.parse(MapEntry entry) {
    final steps = (entry.value['steps'] ?? [])
        .map(FlowStep.parse)
        .toList()
        .cast<FlowStep>();
    return Flow(
      entry.key,
      description: entry.value['description'],
      steps: steps,
    );
  }
}

class Config {
  List<ScratchOrgDefinition> scratchOrgDefinitions;
  List<NamedCommand> commands;
  List<Flow> flows;

  Config({
    required this.scratchOrgDefinitions,
    required this.commands,
    required this.flows,
  });

  factory Config.parse(Map<String, dynamic> unparsed) {
    return Config(
      scratchOrgDefinitions: parseScratchOrgs(unparsed),
      commands: parseCommands(unparsed),
      flows: parseFlows(unparsed),
    );
  }

  static List<ScratchOrgDefinition> parseScratchOrgs(
    Map<String, dynamic> unparsed,
  ) {
    return switch (unparsed) {
      {'orgs': List<dynamic> orgs} =>
        orgs.map(ScratchOrgDefinition.parse).toList(),
      _ => <ScratchOrgDefinition>[],
    };
  }

  static List<NamedCommand> parseCommands(Map<String, dynamic> unparsed) {
    return switch (unparsed) {
      {'commands': Map<String, dynamic> commands} =>
        commands.entries.map(NamedCommand.parse).toList(),
      _ => [],
    };
  }

  static List<Flow> parseFlows(Map<String, dynamic> unparsed) {
    return switch (unparsed) {
      {'flow': Map<String, dynamic> flowMap} =>
        flowMap.entries.map(Flow.parse).toList(),
      _ => [],
    };
  }
}
