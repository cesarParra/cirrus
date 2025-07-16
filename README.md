# Cirrus CLI

A powerful command-line interface tool for Salesforce development automation.

## Installation

### Using npm (recommended)

```bash
npm install -g cirrus-for-sfdx
```

### Using npx (no installation required)

```bash
npx cirrus-for-sfdx <command>
```

## Usage

After installation, you can use the `cirrus` command from anywhere in your terminal:

```bash
cirrus <command> [options]
```

### Available Commands

```bash
cirrus hello    # Prints "World!"
cirrus --help   # Show help information
cirrus --version # Show version information
```

## Platform Support

Cirrus CLI supports the following platforms:
- Linux (x64)
- macOS (x64, arm64)
- Windows (x64)

## Development

This CLI is built with Dart and distributed as platform-specific binaries through npm.