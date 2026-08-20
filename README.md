# launcher

Manage macOS launch agents from the command line.

Create, load, and inspect `launchd` agents without touching XML by hand.

## Install

**npm**

```sh
npm i -g github:mracos/launcher
```

**zinit**

```sh
# as command (in a `zinit for as"command"` block)
pick"bin/*" mracos/launcher

# or standalone
zinit ice as"command" pick"bin/*"
zinit light mracos/launcher
```

**Clone + PATH**

```sh
git clone https://github.com/mracos/launcher.git
export PATH="$PWD/launcher/bin:$PATH"
```

## Usage

```
launcher ls [-v]                      List agents (verbose with -v)
launcher info <name>                  Show agent details
launcher logs <name> [-f]             Show agent logs (follow with -f)
launcher new [-d dir] <name> <cmd> [interval]  Create an agent
launcher rm <name>                    Remove an agent
launcher show <name>                  Show agent plist
launcher edit <name>                  Edit agent plist
launcher load <name>                  Load agent
launcher unload <name>                Unload agent
launcher disable <name|--all>         Stop + disable persistently (survives reboots)
launcher enable <name|--all>          Re-enable and load
launcher reload <name>                Reload agent
launcher run <name>                   Run agent command manually
```

## Quick start

```sh
# Create an agent that runs every 5 minutes
launcher new my-task 'echo "hello" >> /tmp/my-task.log' 300

# Load it
launcher load my-task

# Check status
launcher ls -v
launcher info my-task
launcher logs my-task -f
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `LAUNCHER_PREFIX` | `local.launcher` | Label prefix for agents |
| `LAUNCHER_DIR` | `~/Library/LaunchAgents` | The agent dir launcher operates on |

launcher works on a single directory. The default is `~/Library/LaunchAgents` because it is the only dir launchd auto-loads at login; agents there are the ones that exist, and "yours" are the files matching `LAUNCHER_PREFIX`.

For dotfiles setups where plists are tracked in git, keep the default dir and let your dotfiles manager (stow, etc.) symlink the tracked plists into `~/Library/LaunchAgents`; launcher treats the symlinks like any other agent. If you point `LAUNCHER_DIR` elsewhere, launchd won't auto-load from it, so persistence across logins is on you.

## Architecture

Thin bash dispatcher (`bin/launcher`) with subcommand scripts in `lib/`. The launchd interaction is isolated in `lib/lib-launchd.bash`, making it possible to swap backends (e.g. systemd) without touching subcommands.

**Tech:** Bash (3.2+ compatible), bats for testing, launchctl/PlistBuddy for macOS integration.

## Testing

```sh
npm install
npm test
```

## Design

Started as a zsh plugin in [dotfiles](https://github.com/mracos/dotfiles), extracted to standalone bash CLI. The `lib-launchd.bash` split makes backend-swapping natural - subcommands talk to plist helpers, not launchctl directly. Future: Linux systemd, Windows Task Scheduler.

## License

MIT

## Provenance

Read-only mirror, generated and kept in sync by CI. PRs here are cherry-picked upstream and synced back, so open a PR rather than editing directly.
