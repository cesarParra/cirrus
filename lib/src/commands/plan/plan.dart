import 'package:args/command_runner.dart';

import 'execute.dart';

class PlanCommand extends Command {
  @override
  String get name => 'plan';

  @override
  String get description => 'Runs and publishes install plans.';

  PlanCommand() {
    addSubcommand(Execute());
  }
}
