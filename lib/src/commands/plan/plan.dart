import 'package:args/command_runner.dart';

import 'execute.dart';
import 'resolve.dart';

class PlanCommand extends Command {
  @override
  String get name => 'plan';

  @override
  String get description => 'Runs and publishes install plans.';

  PlanCommand() {
    addSubcommand(Execute());
    addSubcommand(Resolve());
  }
}
