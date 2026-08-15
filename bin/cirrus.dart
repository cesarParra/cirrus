import 'dart:async';
import 'dart:io';

import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:cirrus/src/utils.dart';

/// What a process that took SIGPIPE reports: 128 plus the signal. `seq`, `cat` and everything else
/// piped into a reader that stops reading exit with this, and so does cirrus.
const _sigpipe = 141;

Future<void> main(List<String> arguments) async {
  registerDependencies(configFileName);

  // The command's output is written to stdout as it arrives, so a reader that stops reading -
  // `cirrus run x | head` - fails a write cirrus never sees returned.
  await runZonedGuarded(
    () async {
      exitCode = await run(arguments, configFileName: configFileName);
    },
    (error, stack) async {
      // Nothing is wrong: whatever was reading has stopped. Ending quietly, with the status every
      // other tool ends with, rather than the Dart stack trace and 255 this replaces. Not zero: the
      // run was cut short, and reporting success for a command that may have failed is worse than
      // the trace was.
      if (isBrokenPipe(error)) {
        exit(_sigpipe);
      }

      // Anything else here escaped the runner, which reports every failure it knows about - so this
      // is cirrus itself going wrong, and the trace is the part worth keeping.
      getIt.get<Logger>().error('$error');
      stderr.writeln(stack);
      await stderr.flush();
      exit(1);
    },
  );
}
