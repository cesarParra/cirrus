import 'package:args/command_runner.dart';
import 'package:fpdart/fpdart.dart';
import 'package:toml/toml.dart';
import 'src/run.dart';
import 'dart:io';

const String version = '0.0.3';

Future<void> main(List<String> arguments) async {
  final runner =
      Either.tryCatch(
        () => TomlDocument.loadSync("cirrus.toml").toMap(),
        (_, _) =>
            "Was not able to load the cirrus.toml file. Make sure it exists",
      ).map(
        (document) => CommandRunner(
          "cirrus",
          "A lean command-line interface tool for Salesforce development automation.",
        )..addCommand(RunCommand(document)),
      );

  switch (runner) {
    case Right(:final value):
      try {
        await value.run(arguments);
      } on UsageException catch (e) {
        stderr.writeln(e.message);
        print('');
        value.printUsage();
      }

    case Left(:final value):
      stderr.writeln(value);
      print("");
  }
}
