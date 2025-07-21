import 'src/service_locator.dart';
import 'src/run.dart';

const configFileName = "cirrus.toml";

Future<void> main(List<String> arguments) async {
  registerDependencies(configFileName);
  await run(arguments, configFileName: configFileName);
}
