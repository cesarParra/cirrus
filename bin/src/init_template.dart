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

# Uncomment the following lines to define commands that can be run with `cirrus run <command>`.
# Each command should have a unique name and a shell command to execute.
# You can define multiple commands by adding more entries to the [commands] section.

#[commands]
#hello = "echo 'Hello'"
""";
