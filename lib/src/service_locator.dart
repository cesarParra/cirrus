import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:yaml/yaml.dart';
import 'config.dart';
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

  getIt.registerLazySingleton<Either<String, Config>>(
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
    getIt.get<Either<String, Config>>().getRight().toNullable();

Either<String, Config> loadConfig(ConfigParser parser) {
  return Either.tryCatch(() {
    final unparsed = parser();
    return Config.parse(unparsed);
  }, (error, _) => "Was not able to load the $configFileName file.\r\n$error");
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

class CliRunner {
  Future<void> run(String command) async => await cli.run(command);
  Future<String> output(String command) async => await cli.output(command);
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
