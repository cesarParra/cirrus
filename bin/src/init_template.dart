const configContent = """
# Uncomment the following lines to define a scratch org.
# You can define multiple scratch orgs by adding more entries to the [[orgs]]
# section. Each org must have a unique name and a definition file.
# The definition file should be a valid Salesforce scratch org definition file.
# The duration is optional.

#[[orgs]]
#name = "default"
#definitionFile = "config/project-scratch-def.json"
#duration = 30

# Uncomment the following lines to define flows that can orchestrate multiple commands.
# Each flow should have a unique name and a list of steps.
# Flows are executed using `cirrus flow <flow_name>`
#
# [flow.setup]
# description = "Create scratch org and deploy"
# steps = [
#   { type = "create_scratch", org = "default" },
#   { type = "command", name = "deploy" }
# ]
#
# [flow.test]
# description = "Run all tests"
# steps = [
#   { type = "command", name = "compile" },
#   { type = "command", name = "test" }
# ]

# Uncomment the following lines to define commands that can be run with `cirrus run <command>`.
# Each command should have a unique name and a shell command to execute.
# You can define multiple commands by adding more entries to the [commands] section.

#[commands]
#hello = "echo 'Hello, Cirrus!'"
#deploy = "sf project deploy start"
#test = "sf apex test run --test-level RunLocalTests --wait 20"
""";
