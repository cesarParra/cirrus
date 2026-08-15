const configContent = """
# yaml-language-server: \$schema=https://raw.githubusercontent.com/cesarParra/cirrus/main/schema/cirrus.schema.json
#
# The line above is what gives an editor completion and validation for this file. VS Code needs the
# YAML extension; JetBrains IDEs read it as is.

# The scratch orgs this project creates, keyed by the name you refer to them by.
#
# orgs:
#   dev:
#     definitionFile: config/project-scratch-def.json
#     duration: 30
#     # Created under this alias. Defaults to the name above.
#     alias: my-scratch-org
#     # `cirrus run create_scratch` with no --name creates this one.
#     default: true

# The commands you run. A command is the command line itself, or a mapping when there is more to
# say about it.
#
# Commands are not run through a shell, so `&&`, pipes and \$VARIABLES are arguments rather than
# syntax. A sequence of commands is a flow.
#
# commands:
#   deploy: sf project deploy start
#   test:
#     description: Run every local test with coverage.
#     run: sf apex test run --test-level RunLocalTests --code-coverage --wait 20

# The flows: a sequence of steps, run in order, stopping at the first one that fails. Each step
# names its kind with its first key.
#
# flows:
#   setup:
#     description: A fresh scratch org with the project deployed into it.
#     steps:
#       - createScratch: dev
#         setDefault: true
#       - command: deploy
#       - command: test
""";
