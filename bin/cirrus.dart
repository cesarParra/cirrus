import 'dart:async';
import 'dart:io';

import 'package:cirrus/src/commands/runner.dart';
import 'package:cirrus/src/config.dart';
import 'package:cirrus/src/service_locator.dart';
import 'package:cirrus/src/utils.dart';

Future<void> main(List<String> arguments) async {
  registerDependencies(configFileName);

  // The command's output is written to stdout as it arrives, so a reader that stops reading -
  // `cirrus run x | head` - fails a write cirrus never sees returned. Uncaught, that is a Dart
  // stack trace in the user's terminal and an exit status of 255 in their pipeline.
  await runZonedGuarded(
    () async {
      exitCode = await run(arguments, configFileName: configFileName);
    },
    (error, stack) {
      if (isBrokenPipe(error)) {
        exit(0);
      }

      stderr.writeln(error);
      exit(1);
    },
  );
}
