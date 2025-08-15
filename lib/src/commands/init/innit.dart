import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';

import 'init_template.dart';
import '../../service_locator.dart';

class InitCommand extends Command {
  final String configFileName;

  @override
  String get name => 'init';

  @override
  String get description => 'Initializes the cirrus.toml file.';

  InitCommand(this.configFileName);

  @override
  Either<String, String> run() {
    final configFile = getIt.get<FileSystem>(param1: configFileName);

    if (configFile.exists()) {
      return Left('$configFileName already exists in the current directory');
    }

    configFile.write(configContent);
    return Right('$configFileName created successfully');
  }
}