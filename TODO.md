Misc and initialization
- [x] Ability to run an `init` command that initializes the cirrus.toml file.
- [x] Have flows in the init template.
- [x] Ability to run `--version`. This should be runnable regardless of wether the toml exists or not.
- [ ] Environment variable support.

Scratch ORgs
- [x] Ability to define and create orgs
- [x] Ability to define and run any random command
- [ ] Ability to define the target dev hub


Commands
- [x] Ability to define commands
- [ ] Ability to define caches for commands

Flows
- [x] Ability to run a sequence of commands
- [ ] Ability to "pipe" things in the flows using the information from the previous result.
      For example, release a new version of the package, and get the packageId to then promote it
- [ ] Ability to conditionally run commands based on different context, including the output of the previous command
- [ ] Ability to run commands in parallel
- [ ] Ability to run string commands directly from flow
- [ ] Ability to run other flows from flow
- [ ] Validate that the flow is valid before running it. E.g. commands and org exist, etc.

Packaging
- [ ] Ability to release new versions of packages
- [ ] Ability to promote versions of packages
