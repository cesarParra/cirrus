import 'package:args/command_runner.dart';
import 'package:chalkdart/chalkdart.dart';
import 'package:fpdart/fpdart.dart';
import 'package:toml/toml.dart';
import 'src/run.dart';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final runner =
      Either.tryCatch(
        () => TomlDocument.loadSync("cirrus.toml").toMap(),
        (_, _) =>
            "Was not able to load the cirrus.toml file. Make sure it exists",
      ).flatMap(
        (document) => Either.tryCatch(
          () => CommandRunner(
            "cirrus",
            "A lean command-line interface tool for Salesforce development automation.",
          )..addCommand(RunCommand(document)),
          (error, _) => 'Unexpected error: $error',
        ),
      );

  switch (runner) {
    case Right(:final value):
      try {
        await value.run(arguments);
      } on UsageException catch (e) {
        stderr.writeln(chalk.red(e.message));
        print('');
        value.printUsage();
      } catch (e) {
        stderr.write(chalk.red('$e'));
      }

    case Left(:final value):
      stderr.writeln(chalk.red(value));
      print("");
  }
}
