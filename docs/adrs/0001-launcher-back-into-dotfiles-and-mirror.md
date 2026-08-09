# 0001: launcher back into dotfiles as source, published to mracos/launcher via GitHub Action

**Date:** 2026-08-09
**Status:** Accepted
**Deciders:** Marcos

## Context

`launcher` (a CLI for managing macOS launch agents) was the last tool still living as an independent standalone repo under the multi-repo model of [tools/0001](../tools/0001-tools-multirepo.md). nbx ([nbx/0011](../nbx/0011-nbx-extraction-mirror.md)) and mcp ([mcp/0002](../mcp/0002-mcp-back-into-dotfiles-and-mirror.md)) already came back into dotfiles as canonical sources with generated read-only mirrors. launcher was explicitly the remaining hand-sync consumer of `lib-cli.bash` (CLAUDE.md "Shared Code Across Repos").

Two reasons to finish the job now:

1. **`lib-cli.bash` drift, again.** launcher shipped the old 92-line copy with the `--auto` API; dotfiles is 285 lines with `--auto-help`. Same drift mcp had.
2. **mcp depends on launcher.** mcp's launchd backend shells out to `launcher` ([mcp/0001](../mcp/0001-mcp-backend-abstraction.md)). With mcp now canonical in dotfiles, keeping its runtime dependency in a separate hand-synced repo is the odd one out. Bringing launcher in puts the whole daemon story in one place.

## Decision

**Bring `launcher` source back into dotfiles as canonical, and publish `mracos/launcher` as a generated, read-only mirror** using the same append-only mechanism as nbx/mcp. This **completes the supersession of [tools/0001](../tools/0001-tools-multirepo.md)**: no tool is a hand-synced `lib-cli.bash` consumer anymore.

### Layout in dotfiles

| Standalone (old) | dotfiles (canonical) |
|---|---|
| `bin/launcher` | `files/shell/bin/launcher` |
| `bin/launcher-run` | `files/shell/bin/launcher-run` |
| `lib/launcher-*`, `lib/lib-plist.bash`, `lib/lib-launchd.bash`, `lib/_launcher` | `lib/shell/launcher/` |
| `lib/lib-cli.bash` (vendored, drifted) | dropped; uses `lib/shell/shared/lib-cli.bash` |
| `test/bin/*.bats`, `test/lib/*.bats` | `test/files/shell/bin/*.bats`, `test/lib/shell/launcher/*.bats` |

Two transforms beyond the mcp playbook:

- **`launcher-run` resolution.** Subcommands built the wrapper path as `$(dirname …)/../bin/launcher-run` (repo `bin/`). In the split dotfiles layout the wrapper lives in `files/shell/bin/`, not `lib/shell/../bin`, so `launcher-new` and `launcher-doctor` now resolve `${SCRIPT_DIR%/lib/shell/launcher}/files/shell/bin/launcher-run`. Verified: a generated agent wrapper `exec`s the correct absolute path.
- **Completions.** `_launcher` (zsh completion helpers referenced by `# COMPLETE:` headers) moves to `lib/shell/launcher/_launcher`. The dotfiles completion parser (`_usage_header`) already auto-sources `lib/shell/<cmd>/_<cmd>` when a `# COMPLETE:` line names an undefined function, so no header changes are needed. Same shape as `lib/shell/hooks/_hooks`.

Everything else follows mcp: subcommands source `$LIB_ROOT/shared/lib-cli.bash --auto-help` (was `$SCRIPT_DIR/lib-cli.bash --auto`), `cd -P` path discovery becomes parameter expansion, and the dispatcher keeps its `cli_usage_until_blank` override (present in the shared lib-cli).

### Mechanism

- **`scripts/extract-launcher.sh <build-dir>`** (later folded into the generic `scripts/extract.sh launcher`, ADR [tools/0003](../tools/0003-generic-extraction-engine.md)): offline assembler. Vendors `lib-cli.bash`, reverses the three path rewrites (dispatcher, subcommand lib-cli, `launcher-run`) plus the test-path rewrite, and emits `README.md`, `launcher.plugin.zsh`, `package.json`, `.gitignore`, `LICENSE`, `.github/workflows/ci.yml` (macOS, since launchd is macOS-only).
- **`.github/workflows/launcher.yml`**: assemble -> run the extracted suite on macOS -> publish (append one `sync dotfiles@<sha>` commit) only on push. Reuses `DOTFILES_PUBLISH_REPOS`.

## Consequences

**Positive:**

- Every dotfiles CLI now has one source of truth; `lib-cli.bash` drift is structurally impossible across all mirrors. CLAUDE.md's manual-sync note has no remaining consumers.
- mcp + launcher (the daemon stack) develop together in one repo, one test flow. All 76 launcher bats pass in dotfiles and against the assembled tree.

**Negative:**

- `mracos/launcher` becomes generated: no PRs-as-source, history turns into a publish log going forward. Its prior history is preserved but frozen.
- The assembler carries one more rewrite than mcp (the `launcher-run` path). Kept to a single sed rule and covered by the offline extraction run.

## Setup required (one-time, by the operator)

1. `mracos/launcher` already exists; nothing to create.
2. Ensure the `DOTFILES_PUBLISH_REPOS` PAT scope includes `mracos/launcher` (contents:write).
3. Remove the `pick"bin/*" mracos/launcher` zinit line so the stow-linked `~/bin/launcher` is the only one on PATH.

## Related Decisions

- [nbx/0011](../nbx/0011-nbx-extraction-mirror.md), [mcp/0002](../mcp/0002-mcp-back-into-dotfiles-and-mirror.md): the POC and first replication this follows.
- [tools/0001](../tools/0001-tools-multirepo.md): the multi-repo decision this finishes superseding.
- [mcp/0001](../mcp/0001-mcp-backend-abstraction.md): mcp's launchd backend, the runtime consumer of this CLI.
