import 'package:args/command_runner.dart';
import 'src/run.dart';
import 'dart:io';

const String version = '0.0.3';

Future<void> main(List<String> arguments) async {
  final runner = CommandRunner(
    "cirrus",
    "A lean command-line interface tool for Salesforce development automation.",
  )..addCommand(RunCommand());

  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    print('');
    runner.printUsage();
  }
}
