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

  /// The command line to run. Null for a command that is only a name for its prerequisites, which
  /// is how `check` means "lint, then typecheck, then test" without running anything itself.
  final String? run;

  final String? description;

  /// The commands that must have run before this one, in the order written.
  final List<String> dependsOn;

  NamedCommand(
    this.name, {
    this.run,
    this.description,
    this.dependsOn = const [],
  });

  /// A command is either the command line itself, or a mapping carrying it alongside anything else
  /// worth saying about the command.
  factory NamedCommand.parse(MapEntry<String, dynamic> entry) {
    // Narrowed once, so that every read below is a plain read of a mapping.
    final definition = switch (entry.value) {
      String run => {'run': run},
      Map<String, dynamic> mapping => mapping,
      _ =>
        throw "The command '${entry.key}' is a command line, or a mapping carrying one, and this "
            "one is a ${entry.value.runtimeType}.",
    };

    final run = _typed<String>(definition['run'], 'run', entry.key);
    final dependsOn = _dependsOn(definition, entry.key);

    if (run == null && dependsOn.isEmpty) {
      throw "The command '${entry.key}' has no 'run' and no 'dependsOn', so there is nothing for "
          "it to do.";
    }

    return NamedCommand(
      entry.key,
      run: run,
      description: _typed<String>(
        definition['description'],
        'description',
        entry.key,
      ),
      dependsOn: dependsOn,
    );
  }
}

/// The prerequisites named by a command or a flow.
List<String> _dependsOn(Map<String, dynamic> definition, String owner) {
  final named = _typed<List<dynamic>>(
    definition['dependsOn'],
    'dependsOn',
    owner,
  );

  if (named == null) {
    return const [];
  }

  if (named.any((name) => name is! String)) {
    throw "'dependsOn' of '$owner' is a list of command names.";
  }

  return named.cast<String>();
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

  /// The commands that must have run before the first step, in the order written.
  final List<String> dependsOn;

  Flow(
    this.name, {
    this.description,
    required this.steps,
    this.dependsOn = const [],
  });

  factory Flow.parse(MapEntry<String, dynamic> entry) {
    final definition = switch (entry.value) {
      {'steps': List<dynamic> steps} when steps.isNotEmpty =>
        entry.value as Map<String, dynamic>,
      _ => throw "The flow '${entry.key}' needs 'steps'.",
    };

    return Flow(
      entry.key,
      description: _typed<String>(
        definition['description'],
        'description',
        entry.key,
      ),
      steps: (definition['steps'] as List<dynamic>)
          .map((step) => FlowStep.parse(entry.key, step))
          .toList(),
      dependsOn: _dependsOn(definition, entry.key),
    );
  }
}

class Config {
  List<ScratchOrgDefinition> scratchOrgDefinitions;
  List<NamedCommand> commands;
  List<Flow> flows;

  /// The commands by the name they are keyed by. Built once: every name in the file is resolved
  /// through this, when the config is checked and again when it runs.
  late final Map<String, NamedCommand> _byName = {
    for (final command in commands) command.name: command,
  };

  /// The org to create when the command line does not name one. Null when no org is marked, which
  /// is a question for whoever asked rather than a guess made here.
  final ScratchOrgDefinition? defaultOrg;

  /// The command called [name], if there is one.
  NamedCommand? command(String name) => _byName[name];

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

    final config = Config(
      scratchOrgDefinitions: orgs,
      commands: _section(unparsed, 'commands', NamedCommand.parse),
      flows: _section(unparsed, 'flows', Flow.parse),
      defaultOrg: defaults.firstOrNull,
    );

    config._checkNames();
    return config;
  }

  /// Every name in the file resolves to the thing it names, and no chain of prerequisites comes
  /// back round to where it started.
  ///
  /// Checked when the config is read rather than when it runs. A flow that discovers halfway
  /// through that its fourth step names nothing has already run the first three, and the first
  /// three are a scratch org and a deploy.
  void _checkNames() {
    for (final (owner, dependsOn) in [
      for (final command in commands) (command.name, command.dependsOn),
      for (final flow in flows) (flow.name, flow.dependsOn),
    ]) {
      for (final name in dependsOn) {
        if (!_byName.containsKey(name)) {
          throw "'$owner' depends on '$name', which is not a command.";
        }
      }
    }

    final orgNames = scratchOrgDefinitions.map((org) => org.name).toSet();

    for (final flow in flows) {
      for (final step in flow.steps) {
        switch (step) {
          case RunCommandFlowStep():
            if (!_byName.containsKey(step.commandName)) {
              throw "The '${flow.name}' flow runs '${step.commandName}', which is not a command.";
            }
          case CreateScratchFlowStep():
            if (!orgNames.contains(step.orgName)) {
              throw "The '${flow.name}' flow creates '${step.orgName}', which is not an org.";
            }
        }
      }
    }

    _checkForCycles();
  }

  /// Depth first, carrying the way in. The path is what makes a cycle readable - naming only the
  /// command it came back to leaves the reader to find the rest of it.
  void _checkForCycles() {
    final settled = <String>{};
    final path = <String>[];
    final onPath = <String>{};

    void walk(NamedCommand command) {
      path.add(command.name);
      onPath.add(command.name);

      for (final next in command.dependsOn) {
        if (onPath.contains(next)) {
          final cycle = [...path.sublist(path.indexOf(next)), next];
          throw "'$next' depends on itself: ${cycle.map((name) => "'$name'").join(' -> ')}.";
        }

        if (settled.add(next)) {
          walk(_byName[next]!);
        }
      }

      path.removeLast();
      onPath.remove(command.name);
    }

    for (final command in commands) {
      if (settled.add(command.name)) {
        walk(command);
      }
    }
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
