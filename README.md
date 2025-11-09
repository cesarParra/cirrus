# Cirrus CLI

A lean command-line interface tool for Salesforce development automation.

The Cirrus CLI streamlines repetitive Salesforce tasks by allowing you to automate flows of commonly run commands.
Whether you're initializing new scratch orgs, deploying code, installing dependencies, or importing data, 
Cirrus lets you automate these processes with simple, reusable configurations.

It is intended to be a lightweight alternative to CumulusCI. 
Unlike CumulusCI, Cirrus is distributed as a standalone binary—so no Python or pip required—so you can get started instantly without extra dependencies.

Cirrus aims to provide a straightforward experience that is powerful enough for most use cases.

## Installation

### Using npm (recommended)

```bash
npm install -g cirrus-for-sfdx
```

### Using npx (no installation required)

```bash
npx cirrus-for-sfdx <command>
```

## Quick Start

1. Initialize a `cirrus.toml` configuration file in your project:
   ```bash
   cirrus init
   ```

2. Edit `cirrus.toml` to define your scratch orgs, commands, and flows

3. Run commands or flows:
   ```bash
   cirrus run <command_name>
   cirrus flow <flow_name>
   ```

## Usage

After installation, you can use the `cirrus` command from anywhere in your terminal:

```bash
cirrus <command> [options]
```

### Available Commands

#### Global Commands

```bash
cirrus --help    # Show help information
cirrus --version # Show version information
```

#### `cirrus init`

Initializes a new `cirrus.toml` configuration file in the current directory.

```bash
cirrus init
```

This creates a `cirrus.toml` file with commented examples to help you get started.

#### `cirrus run`

Executes predefined commands from your `cirrus.toml` file.

```bash
cirrus run <subcommand> [options]
```

##### Built-in Subcommands

###### `create_scratch`

Creates a Salesforce scratch org based on definitions in your `cirrus.toml` file.

```bash
cirrus run create_scratch -n <org_name>
```

Options:
- `-n, --name` (required): The name of the scratch org definition to create

Example:
```bash
cirrus run create_scratch -n default -a my-scratch-org
```

##### Custom Commands

Any command defined in the `[commands]` section of your `cirrus.toml` can be run:

```bash
cirrus run <custom_command_name>
```

#### `cirrus flow`

Executes predefined flows from your `cirrus.toml` file.

```bash
cirrus flow <flow_name>
```

Flows allow you to orchestrate multiple commands and actions in sequence. Each step in a flow is executed one after another, and the flow stops if any step fails.

Example:
```bash
cirrus flow setup
cirrus flow deploy-and-test
```

#### `cirrus package create`

Creates a new package version for Salesforce managed or unlocked packages.

```bash
cirrus package create -p <package_name> [options]
```

This command automates the package versioning process by:
1. Reading your `sfdx-project.json` file
2. Automatically incrementing the version number based on the version type
3. Updating the `sfdx-project.json` with the new version
4. Running `sf package version create` with your specified options

Options:
- `-p, --package` (required): The name of the package to release, as defined in the sfdx-project.json file
- `-t, --version-type`: The version type to increment (default: `minor`)
  - `major`: Increments X.0.0 (for breaking changes)
  - `minor`: Increments 0.X.0 (for new features)
  - `patch`: Increments 0.0.X (for bug fixes)
- `--promote`: Whether to promote the package version after creation (default: false)
- `-a, --name`: The name/label for the new version
- `-c, --code-coverage`: Calculate and store code coverage percentage
- `-f, --definition-file`: Path to a definition file with required features and org preferences
- `-k, --installation-key`: Installation key for key-protected packages
- `-x, --installation-key-bypass`: Bypass the installation key requirement
- `-v, --target-dev-hub`: Username or alias of the Dev Hub org
- `-w, --wait`: Number of minutes to wait for package version creation
- `--async-validation`: Return immediately without waiting for validation
- `--skip-validation`: Skip validation during creation (can't promote unvalidated versions)
- `--verbose`: Display verbose command output

Please be aware that at least one of `--installation-key` or `--installation-key-bypass` must be provided.

Examples:
```bash
# Create a minor version update
cirrus package create -p MyPackage

# Create a major version with a specific name
cirrus package create -p MyPackage -t major -a "Summer 2024 Release"

# Create a patch version with code coverage
cirrus package create -p MyPackage -t patch -c

# Create version with installation key and wait 30 minutes
cirrus package create -p MyPackage -k MySecretKey123 -w 30
```

#### `cirrus package get_latest`

Retrieves information about the latest package version for a 2GP package.

```bash
cirrus package get_latest -p <package_name> [options]
```

Options:
- `-p, --package` (required): The name of the package to get the version for. It must either be a package Id (starts with 0Ho), or the alias of the package Id as defined in the sfdx-project.json.
- `-j, --sfdx-project-json-path`: Path to the sfdx-project.json file (default: current directory)

## Configuration (cirrus.toml)

The `cirrus.toml` file uses [TOML format](https://toml.io/) to define scratch org configurations, custom commands, and automation flows.

### Scratch Org Definitions

Define scratch orgs using the `[[orgs]]` array notation. Each org must have:
- `name`: A unique identifier for the org configuration
- `definitionFile`: Path to the Salesforce scratch org definition JSON file
- `duration` (optional): Number of days the scratch org should last (1-30)

```toml
[[orgs]]
name = "default"
definitionFile = "config/project-scratch-def.json"
duration = 30

[[orgs]]
name = "dev"
definitionFile = "config/dev-scratch-def.json"
duration = 7

[[orgs]]
name = "testing"
definitionFile = "config/test-scratch-def.json"
# duration is optional, defaults to Salesforce default
```

### Flow Definitions

Flows allow you to execute a sequence of steps one after another.

Define flows using the `[flow]` syntax. Each flow should have:
- `name`: A unique name for the flow
- `description` (optional): A brief description of what the flow does
- `steps`: A list of steps present in the flow

Supported step types:
- `create_scratch`: Creates a scratch org
- `command`: Runs a predefined command

Examples:

```toml
# Simple flow to setup and deploy
[flow.setup]
description = "Create scratch org and deploy metadata"
steps = [
  { type = "create_scratch", org = "default" },
  { type = "command", name = "deploy" }
]

# More complex flow with multiple commands
[flow.complete-setup]
description = "Full environment setup with data and tests"
steps = [
  { type = "create_scratch", org = "dev", set-default = true },
  { type = "command", name = "deploy" },
  { type = "command", name = "load-sample-data" },
  { type = "command", name = "run-tests" }
]

# Testing flow
[flow.test]
description = "Run all tests with coverage"
steps = [
  { type = "command", name = "compile" },
  { type = "command", name = "test" },
  { type = "command", name = "coverage-report" }
]
```

### Custom Commands

Define custom commands in the `[commands]` section. Each command is a key-value pair where:
- Key: The command name (used with `cirrus run <name>`)
- Value: The shell command to execute

```toml
[commands]
# Simple commands
hello = "echo 'Hello, World!'"
status = "sf org list"

# Complex commands with multiple steps
deploy = "sf deploy source --target-org my-org"
test = "sf apex test run --test-level RunLocalTests --code-coverage"

# Commands can use shell features like pipes and redirects
backup = "sf data export --target-org prod --output-dir ./backups"
format = "prettier --write 'force-app/**/*.{cls,trigger,js}'"
```

## Platform Support

Cirrus CLI supports the following platforms:
- Linux (x64)
- macOS (x64, arm64)
- Windows (x64)

## Development

This CLI is built with Dart and distributed as platform-specific binaries through npm.

### Setting Up for Development

1. Install Dart SDK (if not already installed)
2. Clone the repository
3. Install dependencies:
   ```bash
   dart pub get
   ```

### Running Tests

```bash
dart test
```

### Building

```bash
dart compile exe bin/cirrus.dart -o bin/cirrus
```
