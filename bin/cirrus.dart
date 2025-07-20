import 'package:toml/toml.dart';
import 'src/run.dart';

Future<void> main(List<String> arguments) async {
  await run(arguments, createTomlLoader("cirrus.toml"));
}

ConfigParser createTomlLoader(String filename) {
  return () => TomlDocument.loadSync(filename).toMap();
}
