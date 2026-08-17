## 0.6.0

Breaking changes to the command line, ahead of 1.0 freezing it.

- `cirrus run create_scratch` is now `cirrus org create <org>`. `run` holds only what your config
  file defines, so a command named after a built-in no longer takes the whole CLI down - previously
  `cirrus --version`, `cirrus init` and every other command failed with `Duplicate command`.
- The org to create is an argument rather than `-n/--name`.
- `--set-default` on `cirrus org create` loses its `-d` abbreviation, which `sf` spends on
  `--duration-days`.
- `-v` is no longer `--version`. `sf` spends it on `--target-dev-hub`, which is what it means on
  `cirrus package create`. `--version` is unchanged.
- `cirrus package create --name` is now `--version-name`, matching `sf`. `-a` is unchanged.
- `cirrus package create --version-type=none` is now the `--no-bump` flag. `--version-type` says
  which part to increment; `--no-bump` says whether to increment at all, and the two compose.
- `cirrus flow <name> -- <args>` reports that a flow takes no arguments instead of accepting them
  and dropping them.
- Org, command and flow names are checked when the config file is read: a name is letters, digits,
  `-` and `_`, starting with a letter or a digit.

## 1.0.0

- Initial version.
