import '../../config.dart';

const configContent =
    """
# yaml-language-server: \$schema=$schemaUrl
#
# That line is what gives an editor completion and validation for this file, from the same schema
# that documents every key below. VS Code needs the YAML extension; JetBrains IDEs read it as is.
#
# https://github.com/cesarParra/cirrus#configuration

# Paths in this file are relative to the directory holding it.
#
# defaultOrg: dev

# orgs:
#   dev:
#     definitionFile: config/project-scratch-def.json
#     duration: 30
#     alias: my-scratch-org

# Commands are not run through a shell, so `&&`, pipes and \$VARIABLES reach the program as
# arguments rather than syntax. A sequence of commands is a flow.
#
# `dependsOn` names commands that must have run first. Each runs once however many times it is
# named, and a command with only `dependsOn` is a name for its prerequisites.
#
# commands:
#   deploy: sf project deploy start
#   test:
#     description: Run every local test with coverage.
#     run: sf apex test run --test-level RunLocalTests --code-coverage --wait 20
#     dependsOn: [deploy]

# flows:
#   setup:
#     description: A fresh scratch org with the project deployed into it.
#     steps:
#       - createScratch: dev
#         setDefault: true
#       - command: deploy
#       - command: test
""";
