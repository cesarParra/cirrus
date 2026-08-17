import 'dart:convert';

import 'package:chalkdart/chalk.dart';
import 'package:cli_script/cli_script.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:cirrus/src/sfdx_project_json.dart';
import 'package:fpdart/fpdart.dart';

/// The recording doubles a command test runs against: a logger that keeps what it was told instead
/// of printing it, and a runner that keeps the command line instead of running it.
({TestLogger logger, TestRunner runner}) registerDoubles({
  bool failing = false,
  int failsWith = 1,
}) {
  final logger = TestLogger();
  final runner = TestRunner(fails: failing, failsWith: failsWith);
  getIt.registerSingleton<Logger>(logger);
  getIt.registerSingleton<CliRunner>(runner);
  return (logger: logger, runner: runner);
}

/// The doubles and the config together, which is what a test of a command needs.
({TestLogger logger, TestRunner runner}) withConfig(
  String yaml, {
  bool failing = false,
  int failsWith = 1,
}) {
  final doubles = registerDoubles(failing: failing, failsWith: failsWith);
  registerConfig(yaml);
  return doubles;
}

/// The config the command under test reads.
void registerConfig(String yaml) {
  getIt.registerSingleton<Either<String, Config>>(Right(Config.fromYaml(yaml)));
}

/// A config that could not be read, and why.
void registerConfigFailure(String reason) {
  getIt.registerSingleton<Either<String, Config>>(Left(reason));
}

class TestLogger implements Logger {
  final List<String> errors = [];
  final List<String> messages = [];
  final List<String> successes = [];

  @override
  error(String errorMessage) {
    errors.add(errorMessage);
  }

  @override
  log(String messageToPrint, {Chalk? chalk, bool separator = false}) {
    messages.add(messageToPrint);
  }

  @override
  success(String message) {
    successes.add(message);
  }
}

class TestRunner implements CliRunner {
  /// The command lines it was asked to run, whole and in order - which is what a test about
  /// ordering, or about running something once, needs to see.
  final List<String> commands = [];

  /// The same calls as individual arguments, for tests asserting that a flag was passed.
  List<String> get args =>
      commands.expand((command) => command.toArguments()).toList();
  final String simulatedOutput;

  /// Behaves like a command that exited non-zero. cli_script throws in that case, which is how a
  /// real failure reaches cirrus.
  final bool fails;

  /// The status the simulated command exits with, since propagating it is the whole point of
  /// distinguishing one failure from another.
  final int failsWith;

  TestRunner({String? simulatedOutput, this.fails = false, this.failsWith = 1})
    : simulatedOutput = simulatedOutput ?? 'Simulated output';

  @override
  Future<void> run(String command) async {
    commands.add(command);
    if (fails) {
      throw ScriptException(command, failsWith);
    }
  }

  @override
  Future<String> output(String command) async {
    commands.add(command);
    if (fails) {
      throw ScriptException(command, failsWith);
    }
    // Simulate output for testing purposes
    return simulatedOutput;
  }
}

extension CliExtensions on String {
  List<String> toArguments() {
    final List<String> args = [];
    final StringBuffer currentArg = StringBuffer();
    bool inQuotes = false;
    bool inSingleQuotes = false;
    bool escapeNext = false;

    for (int i = 0; i < length; i++) {
      final char = this[i];

      if (escapeNext) {
        currentArg.write(char);
        escapeNext = false;
        continue;
      }

      if (char == '\\') {
        escapeNext = true;
        continue;
      }

      if (char == '"' && !inSingleQuotes) {
        inQuotes = !inQuotes;
        continue;
      }

      if (char == "'" && !inQuotes) {
        inSingleQuotes = !inSingleQuotes;
        continue;
      }

      if (char == ' ' && !inQuotes && !inSingleQuotes) {
        if (currentArg.isNotEmpty) {
          args.add(currentArg.toString());
          currentArg.clear();
        }
        continue;
      }

      currentArg.write(char);
    }

    if (currentArg.isNotEmpty) {
      args.add(currentArg.toString());
    }

    return args;
  }
}

/// An `sfdx-project.json` a package test can read and write without a disk. It starts out holding
/// one package, since that is what every test about a version number needs.
class FakeFileSystem implements FileSystem {
  final String path;
  final bool _exists;
  String contents = SfdxProjectJson(
    packageDirectories: [
      PackageDirectory(
        package: 'SamplePackage',
        versionNumber: '2.30.0.NEXT',
        extra: {'path': 'packages/SamplePackage'},
      ),
    ],
  ).toJson().encoded();

  FakeFileSystem(this.path, this._exists);

  @override
  bool exists() => _exists;

  @override
  String readAsStringSync() => contents;

  @override
  void write(String content) {
    contents = content;
  }
}

extension JsonEncoding on Map<String, dynamic> {
  String encoded() => jsonEncode(this);
}

/// The doubles a `package create` test runs against: an `sfdx-project.json` it can read and write,
/// registered where the command will look for it, and no config - `package` never reads one.
FakeFileSystem registerSfdxProject({bool exists = true}) {
  final fileSystem = FakeFileSystem('sfdx-project.json', exists);
  registerConfigFailure('No config available');
  getIt.registerFactoryParam<FileSystem, String, void>(
    (String path, _) => fileSystem,
  );
  return fileSystem;
}
