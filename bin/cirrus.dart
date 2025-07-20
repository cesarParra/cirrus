import 'package:toml/toml.dart';
import 'src/run.dart';

const configFileName = "cirrus.toml";

Future<void> main(List<String> arguments) async {
  await run(
    arguments,
    createTomlLoader(configFileName),
    configFileName: configFileName,
  );
}

ConfigParser createTomlLoader(String filename) {
  return () => TomlDocument.loadSync(filename).toMap();
}
