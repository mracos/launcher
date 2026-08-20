# 0002: launcher works on one dir; stow owns installation

**Date:** 2026-08-19
**Status:** Accepted
**Deciders:** Marcos

## Context

launcher had a two-dir worldview: `LAUNCHER_DIR` (plist + wrapper storage, in dotfiles pointed at `files/mac/Library/LaunchAgents/`) and `LAUNCHER_INSTALL_DIR` (always `~/Library/LaunchAgents`, the only dir launchd auto-scans at login). `launcher link`/`unlink` bridged the two with absolute symlinks, and `hooks/post-link/mac.sh` ran `launcher link --all`.

That made launcher a second linking mechanism next to stow, with its own drift surface:

- `files/mac/.stow-local-ignore` had to exclude `Library/LaunchAgents` so the two mechanisms wouldn't fight.
- A new agent added to the repo was invisible until someone remembered `launcher link` (bit us on 2026-08-19 with `dotfiles-doctor`).
- `link.sh --doctor` couldn't own the whole home-dir story: agent links were created and repaired by a different tool.

`launchctl` itself has no install step: `load`/`bootstrap` accept any path but only for the current session; persistence requires the file (or a symlink) sitting in `~/Library/LaunchAgents`. Copying instead of linking was rejected: copies go stale when the repo plist changes (the exact stale-code class the sync hooks exist to kill) and `link.sh --doctor` would flag the copy as a conflict forever.

## Decision

**launcher operates on a single directory, `LAUNCHER_DIR`, defaulting to `~/Library/LaunchAgents`. `link`/`unlink` and `LAUNCHER_INSTALL_DIR` are removed. Installation in dotfiles is stow's job.**

- A plist not present in `LAUNCHER_DIR` does not exist for launcher. "Ours" is determined by convention: the `LAUNCHER_PREFIX` filename filter (`br.com.mracos.*`), exactly as `ls` already did.
- launcher neither knows nor cares that the files are stow symlinks into `files/mac/Library/LaunchAgents/`. `load`, `ls`, `info`, `enable`, `disable` all just see files in the dir.
- Standalone (mirror) users get the simplest story: default dir IS the launchd dir, files created in place, zero install step. Anyone storing plists elsewhere overrides `LAUNCHER_DIR` and owns persistence themselves.

### dotfiles integration

- `Library/LaunchAgents` removed from `files/mac/.stow-local-ignore`; `./link.sh mac` links plists + wrapper scripts like any other config.
- `LAUNCHER_DIR` export removed from `.zshenv` (default is now correct).
- `hooks/post-link/mac.sh` runs `launcher load --all` instead of `link --all` (load is idempotent; fresh machines get agents active without re-login).
- **Adoption drift:** `launcher new` now creates real files in `~/Library/LaunchAgents`. The `.doctor-untracked` sweep guards this (same pattern as Claude memory files): `files/mac/.doctor-untracked` claims `Library/LaunchAgents/br.com.mracos.*`, so `link.sh --doctor` (and the weekly `dotfiles-doctor` agent) flags unadopted agents. The sweep learned file globs for this; a dir-only glob would flag every third-party plist in the folder.
- Adoption flow: `mv` the two files into `files/mac/Library/LaunchAgents/`, `./link.sh mac`.

### Removal semantics

`launcher rm` deletes what is in `LAUNCHER_DIR`. When that is a stow symlink, the repo file survives; doctor then reports the missing link until the repo file is removed and mac restowed (stow statelessness, documented in CLAUDE.md).

## Consequences

- One linking mechanism; `--doctor` covers agents end to end.
- launcher loses two subcommands, one config var, and the `linked/unlinked` state split; `ls` states reduce to running/stopped/disabled/unloaded plus orphan detection.
- Existing machines migrate by deleting launcher's absolute symlinks and restowing mac; launchd keeps loaded agents (label-based) across the swap.
- Supersedes the link workflow described in [0001](0001-launcher-back-into-dotfiles-and-mirror.md); the mirror README drops the link/unlink docs.
