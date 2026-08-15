const configContent = """
# yaml-language-server: \$schema=https://raw.githubusercontent.com/cesarParra/cirrus/main/schema/cirrus.schema.json
#
# That line is what gives an editor completion and validation for this file, from the same schema
# that documents every key below. VS Code needs the YAML extension; JetBrains IDEs read it as is.
#
# https://github.com/cesarParra/cirrus#configuration

# orgs:
#   dev:
#     definitionFile: config/project-scratch-def.json
#     duration: 30
#     alias: my-scratch-org
#     default: true

# Commands are not run through a shell, so `&&`, pipes and \$VARIABLES reach the program as
# arguments rather than syntax. A sequence of commands is a flow.
#
# commands:
#   deploy: sf project deploy start
#   test:
#     description: Run every local test with coverage.
#     run: sf apex test run --test-level RunLocalTests --code-coverage --wait 20

# flows:
#   setup:
#     description: A fresh scratch org with the project deployed into it.
#     steps:
#       - createScratch: dev
#         setDefault: true
#       - command: deploy
#       - command: test
""";
