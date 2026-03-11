# Launcher

Bash CLI for managing macOS launch agents. Extracted from [dotfiles](https://github.com/mracos/dotfiles).

## Structure

- `bin/` - Entry points (`launcher` dispatcher + `launcher-run` wrapper)
- `lib/` - Subcommands (`launcher-*`) and shared libs (`lib-*.bash`)
- `test/` - Bats tests mirroring source structure
- `lib/lib-cli.bash` - Shared CLI helpers (dispatch, usage, symlink resolution)

## Commands

```sh
npm test                    # Run all tests
npm test -- test/lib/       # Run lib tests only
```

## Conventions

- Bash 3.2+ compatible (macOS stock bash)
- Subcommands source `lib-cli.bash` with `--auto "$@"` for help detection
- Tests use bats + bats-assert + bats-support
- Test structure: AAA (arrange/act/assert), `PROJECT_ROOT` env var for paths
- Commits: present tense imperative, `<scope>: <what>`

## Architecture

Thin dispatcher (`bin/launcher`) resolves symlinks to find `lib/` relative to itself. Subcommands in `lib/launcher-*` source shared libs from the same directory. `lib-launchd.bash` isolates all launchctl/PlistBuddy calls - swap this for systemd support.

## Shared libs

`lib-cli.bash` is shared with [dotfiles/notes](https://github.com/mracos/dotfiles). Changes here should be synced back.
