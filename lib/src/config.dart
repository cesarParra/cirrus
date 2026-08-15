import 'package:yaml/yaml.dart';

/// The file cirrus reads. Named once, so that every message about it agrees.
const configFileName = 'cirrus.yaml';

/// A command whose subcommands are read out of the config file, and which therefore has nothing to
/// offer when that file did not load.
abstract interface class ReadsConfig {}

/// The document as plain Dart collections. `package:yaml` hands back `YamlMap` and `YamlList`,
/// which are `Map<dynamic, dynamic>` and therefore match none of the patterns below - and nothing
/// past this point should know which parser produced the configuration.
///
/// A document with nothing in it is a config with nothing in it, not an error: that is what
/// `cirrus init` writes, and what a file holding only comments parses as.
Map<String, dynamic> asPlainMap(dynamic document) {
  final plain = _plain(document);
  return switch (plain) {
    Map<String, dynamic> map => map,
    null => <String, dynamic>{},
    _ =>
      throw "The $configFileName file describes 'orgs', 'commands' and 'flows'.",
  };
}

dynamic _plain(dynamic node) => switch (node) {
  YamlMap map => {
    for (final entry in map.entries) '${entry.key}': _plain(entry.value),
  },
  YamlList list => list.map(_plain).toList(),
  _ => node,
};

class ScratchOrgDefinition {
  final String name;
  final String definitionFile;
  final int? duration;

  /// What the org is called in the CLI once it exists, which is the name it is keyed by unless the
  /// definition says otherwise.
  final String alias;

  /// The org `cirrus run create_scratch` creates when it is not told which one.
  final bool isDefault;

  ScratchOrgDefinition(
    this.name,
    this.definitionFile, {
    this.duration,
    String? alias,
    this.isDefault = false,
  }) : alias = alias ?? name;

  factory ScratchOrgDefinition.parse(MapEntry<String, dynamic> entry) {
    return switch (entry.value) {
      {'definitionFile': String definitionFile} => ScratchOrgDefinition(
        entry.key,
        definitionFile,
        duration: _typed<int>(entry.value['duration'], 'duration', entry.key),
        alias: _typed<String>(entry.value['alias'], 'alias', entry.key),
        isDefault:
            _typed<bool>(entry.value['default'], 'default', entry.key) ?? false,
      ),
      _ => throw "The org '${entry.key}' needs a 'definitionFile'.",
    };
  }
}

/// A field of the type it is declared as, or a sentence naming what is wrong with it. Without this
/// a mistyped `duration: "30"` reaches the user as a Dart type error naming neither the field nor
/// the org it is in.
T? _typed<T>(dynamic value, String field, String owner) {
  return switch (value) {
    null => null,
    T typed => typed,
    _ =>
      throw "'$field' of '$owner' is a ${value.runtimeType} where cirrus expects $T: $value",
  };
}

class NamedCommand {
  final String name;
  final String run;
  final String? description;

  NamedCommand(this.name, this.run, {this.description});

  /// A command is either the command line itself, or a mapping carrying it alongside anything else
  /// worth saying about the command.
  factory NamedCommand.parse(MapEntry<String, dynamic> entry) {
    return switch (entry.value) {
      String run => NamedCommand(entry.key, run),
      {'run': String run} => NamedCommand(
        entry.key,
        run,
        description: entry.value['description'],
      ),
      _ => throw "The command '${entry.key}' has no 'run'.",
    };
  }
}

/// A step names its kind with its first key: `command: deploy` rather than a `type` beside a
/// `name`. What the step needs is the value, and what it does is the key.
sealed class FlowStep {
  FlowStep();

  factory FlowStep.parse(String flowName, dynamic unparsed) {
    if (unparsed is Map<String, dynamic> &&
        unparsed.containsKey('createScratch') &&
        unparsed.containsKey('command')) {
      throw "A step of the '$flowName' flow is both a 'createScratch' and a 'command'. A step is "
          "one thing; two steps are two entries in the list.";
    }

    return switch (unparsed) {
      {'createScratch': String orgName} => CreateScratchFlowStep(
        orgName,
        _typed<bool>(unparsed['setDefault'], 'setDefault', flowName) ?? true,
      ),
      {'command': String commandName} => RunCommandFlowStep(commandName),
      Map<String, dynamic> step =>
        throw "'${step.keys.join(', ')}' in the '$flowName' flow is not a kind of step cirrus "
            "knows. A step is 'createScratch' or 'command'.",
      _ => throw "A step of the '$flowName' flow is not a mapping: $unparsed",
    };
  }

  String printable();
}

class CreateScratchFlowStep extends FlowStep {
  final String orgName;

  /// Whether the created org becomes the CLI's default, which it does unless the step says
  /// otherwise. Defaulted here so that no reader has to know what absent means.
  final bool setDefault;

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

  factory Flow.parse(MapEntry<String, dynamic> entry) {
    final steps = switch (entry.value) {
      {'steps': List<dynamic> steps} when steps.isNotEmpty =>
        steps.map((step) => FlowStep.parse(entry.key, step)).toList(),
      _ => throw "The flow '${entry.key}' needs 'steps'.",
    };

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

  /// The org to create when the command line does not name one. Null when no org is marked, which
  /// is a question for whoever asked rather than a guess made here.
  final ScratchOrgDefinition? defaultOrg;

  Config({
    required this.scratchOrgDefinitions,
    required this.commands,
    required this.flows,
    this.defaultOrg,
  });

  /// The config as cirrus reads it from a file.
  factory Config.fromYaml(String source) =>
      Config.parse(asPlainMap(loadYaml(source)));

  factory Config.parse(Map<String, dynamic> unparsed) {
    final orgs = _section(unparsed, 'orgs', ScratchOrgDefinition.parse);

    // Found once, so that the uniqueness this rejects and the org the CLI later creates come from
    // the same expression rather than agreeing by coincidence.
    final defaults = orgs.where((org) => org.isDefault).toList();
    if (defaults.length > 1) {
      throw "Only one org is the default one, and ${defaults.map((org) => "'${org.name}'").join(' and ')} both say they are.";
    }

    return Config(
      scratchOrgDefinitions: orgs,
      commands: _section(unparsed, 'commands', NamedCommand.parse),
      flows: _section(unparsed, 'flows', Flow.parse),
      defaultOrg: defaults.firstOrNull,
    );
  }

  /// Every section is a mapping keyed by the name of the thing it describes, so an absent one is
  /// an empty list and a malformed one says which section it is rather than quietly matching no
  /// pattern.
  static List<T> _section<T>(
    Map<String, dynamic> unparsed,
    String name,
    T Function(MapEntry<String, dynamic>) parse,
  ) {
    return switch (unparsed[name]) {
      null => <T>[],
      Map<String, dynamic> entries => entries.entries.map(parse).toList(),
      _ => throw "'$name' is a mapping keyed by name.",
    };
  }
}
