import 'package:args/command_runner.dart';

class RunCommand extends Command {
  @override
  final name = 'run';

  @override
  String get description => 'Runs a standalone command';

  RunCommand() {
    argParser.addFlag('wepa', negatable: false, help: 'Hello');
  }

  @override
  void run() {
    print('Run wepa!');
  }
}
