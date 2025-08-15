import 'package:args/command_runner.dart';

class GetLatest extends Command {
  @override
  String get description => 'Get information about the latest version of a package.';

  @override
  String get name => 'get_latest';

  @override
  void run() {
    print('This command is not implemented yet.');
  }
}