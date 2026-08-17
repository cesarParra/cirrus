import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:yaml/yaml.dart';
import 'config.dart';
import 'failure.dart';
import 'package:cli_script/cli_script.dart' as cli;

typedef ConfigParser = Map<String, dynamic> Function();

abstract class Logger {
  void error(String errorMessage);
  void log(String messageToPrint, {Chalk? chalk, bool separator = false});
  void success(String message);
}

const separatror = '----------------------------------------';

class StdIOLogger implements Logger {
  const StdIOLogger();

  @override
  error(String errorMessage) {
    stderr.writeln(errorMessage.red.bold);
    log("");
  }

  @override
  log(String messageToPrint, {Chalk? chalk, separator = false}) {
    if (separator) {
      _print(separatror, chalk: chalk);
    }
    _print(messageToPrint, chalk: chalk);
    if (separator) {
      _print(separatror, chalk: chalk);
    }
  }

  @override
  success(String message) {
    print(message.green.bold);
  }

  void _print(String message, {Chalk? chalk}) {
    if (chalk != null) {
      print(chalk(message));
    } else {
      print(message);
    }
  }
}

final getIt = GetIt.instance;

void registerDependencies(String configFileName) {
  getIt.registerSingleton<CliRunner>(CliRunner());

  getIt.registerLazySingleton<ConfigParser>(
    () => buildConfigParser(configFileName),
  );

  getIt.registerLazySingleton<Either<Failure, Config>>(
    () => loadConfig(getIt.get<ConfigParser>()),
  );

  getIt.registerLazySingleton<Logger>(() => StdIOLogger());

  getIt.registerFactoryParam<FileSystem, String, void>(
    (String path, _) => FileSystem.open(path),
  );
}

/// The config, when it loaded. Null when it did not - which is reported before any command that
/// needs one is dispatched, so a caller building subcommands has nothing to add and nothing to say.
Config? loadedConfig() =>
    getIt.get<Either<Failure, Config>>().getRight().toNullable();

Either<Failure, Config> loadConfig(ConfigParser parser) {
  return Either.tryCatch(
    () {
      final unparsed = parser();
      return Config.parse(unparsed);
    },
    (error, _) =>
        Failure("Was not able to load the $configFileName file.\r\n$error"),
  );
}

ConfigParser buildConfigParser(String filename) {
  return () {
    final file = File(filename);

    // Cirrus read TOML up to 0.2.x. Left to itself the message would be that the file is missing,
    // which is true and useless to the one person it happens to.
    if (!file.existsSync() && File('cirrus.toml').existsSync()) {
      throw 'Found a cirrus.toml. Cirrus reads $configFileName as of 0.3.0 - see '
          'https://github.com/cesarParra/cirrus#configuration for the same file in YAML.';
    }

    return asPlainMap(loadYaml(file.readAsStringSync()));
  };
}

/// Everything cirrus shells out through.
///
/// A command that exits non-zero has already answered the only question a caller had, so its status
/// is turned into a [Failure] here rather than at each call site. `cli_script` throws a
/// `ScriptException` carrying the status; catching that in one place is what keeps every path from
/// having to remember, and what makes "the status is passed through unchanged" true rather than
/// true of whichever path was written last.
class CliRunner {
  Future<void> run(String command) async => await _carrying(cli.run(command));
  Future<String> output(String command) async =>
      await _carrying(cli.output(command));

  Future<T> _carrying<T>(Future<T> running) async {
    try {
      return await running;
    } on cli.ScriptException catch (error) {
      throw Failure.fromCommand('$error', error.exitCode);
    }
  }
}

class FileSystem {
  final File _file;

  FileSystem._(this._file);

  factory FileSystem.open(String path) {
    return FileSystem._(File(path));
  }

  bool exists() => _file.existsSync();

  String readAsStringSync() => _file.readAsStringSync();

  void write(String content) {
    _file.writeAsStringSync(content);
  }
}
