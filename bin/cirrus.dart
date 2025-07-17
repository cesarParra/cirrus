import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'src/run.dart';

const String version = '0.0.3';

void printUsage(ArgParser argParser) {
  print('Usage: dart cirrus.dart <flags> [arguments]');
  print(argParser.usage);
}

void main(List<String> arguments) {
  CommandRunner(
      "cirrus",
      "A lean command-line interface tool for Salesforce development automation.",
    )
    ..addCommand(RunCommand())
    ..run(arguments);
}
