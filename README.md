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

1. Initialize a `cirrus.yaml` configuration file in your project:
   ```bash
   cirrus init
   ```

2. Edit `cirrus.yaml` to define your scratch orgs, commands, and flows

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

Initializes a new `cirrus.yaml` configuration file in the current directory.

```bash
cirrus init
```

This creates a `cirrus.yaml` file with a schema reference and commented examples to help you get started.

#### `cirrus org create`

Creates a Salesforce scratch org from the definitions in your `cirrus.yaml` file.

```bash
cirrus org create <org_name>
```

The org to create is named as an argument. Leave it out and cirrus creates the one named by the
root `defaultOrg`, so a project with one never names an org at all.

Options:
- `--set-default` / `--no-set-default`: Set the created org as the CLI's default. On by default

The alias the org is created under comes from the org definition's `alias`, and defaults to the
name it is keyed by.

Examples:
```bash
cirrus org create dev
cirrus org create                    # the org named by `defaultOrg`
cirrus org create ci --no-set-default
```

#### `cirrus run`

Runs a command defined under `commands:` in your `cirrus.yaml` file.

```bash
cirrus run <command_name>
```

Every subcommand of `run` comes out of your config file, and none is built in - so no command you
name can collide with one of cirrus's own.

##### Passing arguments through

Anything after `--` is appended to the command line:

```bash
cirrus run e2e -- --project=chromium --workers=1
```

The arguments reach the command that was named and nothing else - a prerequisite dragged in behind
it runs as written. This is what lets one `e2e` command serve a pull-request build that runs one
browser and a merge build that runs them all.

#### `cirrus flow`

Executes predefined flows from your `cirrus.yaml` file.

```bash
cirrus flow <flow_name>
```

Flows allow you to orchestrate multiple commands and actions in sequence. Each step in a flow is executed one after another, and the flow stops if any step fails.

A flow takes no arguments of its own: there is no one step for them to belong to. Pass them to the
command that wants them with `cirrus run <command> -- ...`.

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
- `-t, --version-type`: Which part of the version number to increment (default: `minor`). Every
  type leaves the build number as `.NEXT`, which is Salesforce choosing it
  - `major`: Increments X.0.0 (for breaking changes)
  - `minor`: Increments 0.X.0 (for new features)
  - `patch`: Increments 0.0.X (for bug fixes)
- `--no-bump`: Leave the version number alone, for a project that lets Salesforce choose the build
  number. `sfdx-project.json` is then left as it was found, unless `--version-name` is given - that
  is a label, and setting it still writes the file
- `--promote`: Whether to promote the package version after creation (default: false)
- `-a, --version-name`: The name/label for the new version
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

## Configuration (cirrus.yaml)

`cirrus.yaml` describes three things: the scratch **orgs** a project creates, the **commands** it
runs, and the **flows** that sequence them. Each is a mapping keyed by the name you refer to it by.

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/cesarParra/cirrus/main/schema/cirrus.schema.json

defaultOrg: dev

orgs:
  dev:
    definitionFile: config/project-scratch-def.json
    duration: 30

commands:
  deploy: sf project deploy start
  test:
    description: Run every local test with coverage.
    run: sf apex test run --test-level RunLocalTests --code-coverage --wait 20

flows:
  setup:
    description: A fresh scratch org with the project deployed into it.
    steps:
      - createScratch: dev
        setDefault: true
      - command: deploy
      - command: test
```

That first line is worth keeping. It points editors at cirrus's JSON Schema, which gives completion
and validation as you type - VS Code needs the YAML extension, JetBrains IDEs read it as is.
`cirrus init` writes it for you.

### Moving from cirrus.toml

Cirrus read TOML up to 0.2.x. Running 0.3 in a project that still has a `cirrus.toml` tells you so.
The shape changed with the format:

| 0.2.x (TOML) | 0.3 (YAML) |
|---|---|
| `[[orgs]]` with a `name = "dev"` field | `orgs:` keyed by `dev:` |
| `[commands]` `deploy = "sf ..."` | `commands:` `deploy: sf ...` |
| `[flow.setup]` | `flows:` keyed by `setup:` |
| `{ type = "create_scratch", org = "dev" }` | `- createScratch: dev` |
| `{ type = "command", name = "deploy" }` | `- command: deploy` |
| `set-default = true` | `setDefault: true` |

### Names

Orgs, commands and flows are keyed by a name you type on the command line, so a name is letters,
digits, `-` and `_`, starting with a letter or a digit. Anything else is a config error, reported
with the key that has it.

### Keys and paths

**A key cirrus does not read is an error, not a shrug.** `durationDays` reads exactly like
`duration` to whoever wrote it, and silently getting the default instead is the failure a config
file cannot afford. The message names the key, what it is on, and the keys that section does take.

**Paths are relative to the directory holding `cirrus.yaml`**, not to wherever you happened to run
`cirrus` from.

**`${{ }}` is reserved** and refused today. Cirrus does not interpolate anything yet, and a later
release that pipes one step's output into the next will need a syntax - one that cannot be
introduced without breaking every config already using those characters. A `$VARIABLE` or
`${BRACED}` still reaches the program as written and is unaffected.

### The default org

`defaultOrg` names the org `cirrus org create` creates when it is given none:

```yaml
defaultOrg: dev

orgs:
  dev:
    definitionFile: config/dev-scratch-def.json
```

It is one key at the root rather than a flag on each org, so two orgs cannot both claim to be the
default - there is nowhere to write it twice.

### Scratch org definitions

Each org is keyed by the name you pass to `cirrus org create`, and takes:

- `definitionFile` (required): path to the Salesforce scratch org definition JSON file, relative
  to the directory holding `cirrus.yaml`
- `duration`: how many days the org lives, 1-30. Salesforce's own default applies without it
- `alias`: the alias the org is created under. Defaults to the name it is keyed by
- `namespace`: set `false` for an org that stands in for a subscriber's, which does not carry the
  package's namespace
- `wait`: minutes to wait for the org to be created

```yaml
defaultOrg: dev

orgs:
  dev:
    definitionFile: config/dev-scratch-def.json
    duration: 7

  ci:
    definitionFile: config/project-scratch-def.json
    duration: 1
    # Created as `scratch-org` rather than `ci`, which is what the pipeline expects to find.
    alias: scratch-org
```

With `defaultOrg` set, `cirrus org create` needs no arguments at all.

### Commands

A command is the command line to run, keyed by the name `cirrus run` takes. Give it a mapping
instead when there is more to say:

```yaml
commands:
  status: sf org list

  deploy:
    description: Deploy the source to the default org.
    run: sf project deploy start
```

**Commands are not run through a shell.** `&&`, `|`, `>` and `$VARIABLES` are passed to the program
as arguments rather than interpreted, so:

```yaml
commands:
  # Runs `echo` with the arguments `one && echo two`. Probably not what you wanted.
  chained: echo one && echo two
```

A sequence of commands is a flow, and anything genuinely needing a shell belongs in a script the
command calls.

### Prerequisites

`dependsOn` says what has to have happened before a command can run. Cirrus works out the order and
runs each prerequisite **once**, however many times it is named:

```yaml
commands:
  tw: npx tailwindcss -i input.css -o output.css
  compile: tsc -b

  build:
    description: Every deployable artifact.
    dependsOn: [tw, compile]

  lint:
    run: eslint .
    dependsOn: [build]
  test:
    run: vitest run
    dependsOn: [build]

  check:
    description: Am I done?
    dependsOn: [lint, test]
```

`cirrus run check` runs `tw`, `compile`, `lint`, `test` - and `build` happens once, though both
`lint` and `test` name it. A command with only `dependsOn` and no `run`, like `build`
and `check` above, is a name for its prerequisites and runs nothing itself.

What cirrus promises is that **a prerequisite has completed before the command that names it
starts, and that it runs once**. It does not promise that two prerequisites of the same command run
one after the other - `tw` and `compile` are independent, and a later cirrus may run them at the
same time.

Prerequisites are checked when the config is read, so a name that matches no command, or a chain
that comes back round to where it started, is reported before anything runs.

### Flows

A flow is a list of steps, run in order, stopping at the first one that fails. It can take
prerequisites of its own, which run before the first step:

```yaml
flows:
  release:
    dependsOn: [build]
    steps:
      - command: deploy
```

**Prerequisites and steps are different things.** A prerequisite says what must already have
happened, so it runs once. A step is an order you wrote down, so naming the same command twice runs
it twice.

Each step names its kind with its first key:

- `createScratch: <org>` creates one of the orgs defined above, and takes `setDefault` (true unless
  you say otherwise)
- `command: <name>` runs one of the commands defined above

```yaml
flows:
  setup:
    description: Create a scratch org and deploy into it.
    steps:
      - createScratch: dev
        setDefault: true
      - command: deploy

  release:
    description: Everything that has to pass before a release.
    steps:
      - command: compile
      - command: test
      - command: coverage-report
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
