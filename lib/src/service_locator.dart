import 'dart:io';

import 'package:chalkdart/chalkstrings.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:toml/toml.dart';
import 'config.dart';
import 'package:cli_script/cli_script.dart' as cli;

typedef ConfigParser = Map<String, dynamic> Function();

abstract class Logger {
  void error(String errorMessage);
  void log(String messageToPrint);
  void success(String message);
}

class StdIOLogger implements Logger {
  const StdIOLogger();

  @override
  error(String errorMessage) {
    stderr.writeln(errorMessage.red.bold);
    log("");
  }

  @override
  log(String messageToPrint) {
    print(messageToPrint);
  }

  @override
  success(String message) {
    print(message.green.bold);
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

Either<String, Config> loadConfig(ConfigParser parser) {
  return Either.tryCatch(() {
    final unparsed = parser();
    return Config.parse(unparsed);
  }, (error, _) => "Was not able to load the cirrus.toml file.\r\n$error'");
}

ConfigParser buildConfigParser(String filename) {
  return () => TomlDocument.loadSync(filename).toMap();
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
