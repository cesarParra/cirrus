import 'dart:io';

import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';

Future<void> main(List<String> arguments) async {
  registerDependencies(configFileName);
  exitCode = await run(arguments, configFileName: configFileName);
}
