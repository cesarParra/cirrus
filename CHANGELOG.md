## 0.10.0

- **The schema moved to a host this project controls**, at
  `https://cesarparra.github.io/cirrus/schema/v1/cirrus.schema.json`. It was served from
  `raw.githubusercontent.com`, which is rate limited, serves `text/plain`, and put an account name
  into every repository that ran `cirrus init` - a line cirrus writes once and can never edit
  again. Existing configs keep working; the old URL still resolves.
- **The URL carries the schema major.** A config written against `v1` keeps being validated against
  `v1` once a `v2` exists, rather than against whatever landed since.
- **`schemaVersion` at the root**, so cirrus itself - not only an editor - can say a file needs a
  newer cirrus, instead of failing on the first key this version does not know. Absent means the
  version cirrus reads.

## 0.9.0

- The cause of a config that did not load is reported however the arguments reach the command. It
  was found by looking at the first argument, which is the command only while nothing can precede
  it - so the first global option taking a value would have silently turned the cause back into the
  missing-subcommand symptom it exists to replace.

## 0.8.0

- **The exit status says which kind of failure it was**, on every path that shells out - `run`,
  a flow, `org create`, `package create` and `package get-latest` alike. Every failure exited 1, so a build server
  could not tell "your tests failed" from "your cirrus.yaml is invalid" - and the failing command's
  own status was available and thrown away. Now: `0` success, *n* passed through unchanged from the
  command that exited *n*, `2` when cirrus could not do what was asked, `141` on a closed pipe.

## 0.7.0

Breaking changes to the config file, ahead of 1.0 freezing it.

- **A key cirrus does not read is now an error.** It used to be dropped: `durationDays` instead of
  `duration` changed nothing and said nothing, and the org quietly got the default. Checked at the
  root and on every org, command, flow and flow step; the message names the key, what it is on, and
  the keys that section does take. This can never be turned on after 1.0 without breaking configs
  that were relying on the silence.
- **`defaultOrg` at the root replaces `default: true` on an org.** One key, so two orgs cannot both
  claim to be the default - there is nowhere to write it twice. An org still carrying `default` is
  told where it went.
- **`${{ }}` is reserved and refused.** Cirrus interpolates nothing today and the README promises a
  command line reaches the program as written; a later release that pipes one step's output into
  the next needs a syntax, and it cannot be introduced once a config in the wild uses those
  characters for their own sake. `$VARIABLE` and `${BRACED}` are unaffected.
- **`dependsOn` no longer promises siblings run in the order written.** What is promised is that a
  prerequisite completes before the command naming it starts, and runs once - which leaves an
  independent prerequisite graph free to run in parallel later.
- **Paths in the config file are relative to the directory holding it**, not to where `cirrus` was
  run from. Those are the same directory today, and this is which one it stays.
- The schema states "a command has a `run` or a `dependsOn`" without an `anyOf`, so an editor stops
  reporting a command that has both as validating against more than one variant.

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

