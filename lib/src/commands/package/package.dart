import 'package:args/command_runner.dart';
import 'package:cirrus/src/commands/package/create.dart';
import 'get_latest.dart';

class PackageCommand extends Command {
  @override
  String get name => 'package';

  @override
  String get description => 'Releases a new package version.';

  PackageCommand() {
    addSubcommand(Create());
    addSubcommand(GetLatest());
  }
}
