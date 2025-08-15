import 'package:cirrus/src/service_locator.dart';
import 'package:cirrus/src/commands/runner.dart';

const configFileName = "cirrus.toml";

Future<void> main(List<String> arguments) async {
  registerDependencies(configFileName);
  await run(arguments, configFileName: configFileName);
}
