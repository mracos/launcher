# Launcher: Migrate to Standalone with Subcommands

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Convert the `launcher` zsh plugin into a standalone bash CLI with subcommands, as a step toward extracting to its own repo.

**Architecture:** Thin bash dispatcher at `files/shell/bin/launcher` with `# USAGE:` header (autodiscovery completions). Subcommand scripts in `lib/shell/launcher/launcher-*`. Shared libs in `lib/shell/launcher/lib-*.bash`. Reuses `lib-cli.bash` pattern from notes (copied, not shared).

**Tech Stack:** Bash, bats (testing), launchctl/PlistBuddy (macOS)

**Future:** Cross-platform support (Linux systemd, Windows Task Scheduler) - the `lib-launchd.bash` split makes backend-swapping natural without touching subcommands.

---

### Task 1: Scaffold lib directory and lib-cli.bash

**Files:**
- Create: `lib/shell/launcher/lib-cli.bash`

**Step 1: Create directory and copy lib-cli.bash from notes**

```bash
mkdir -p lib/shell/launcher
```

Copy `lib/shell/notes/lib-cli.bash` to `lib/shell/launcher/lib-cli.bash`. The file is identical - shared CLI helpers for usage display, help detection, subcommand dispatch, and symlink resolution.

**Step 2: Verify the copy**

Run: `diff lib/shell/notes/lib-cli.bash lib/shell/launcher/lib-cli.bash`
Expected: no output (identical)

**Step 3: Commit**

```
launcher: scaffold lib directory with lib-cli.bash
```

---

### Task 2: Create lib-plist.bash (path helpers and config)

**Files:**
- Create: `lib/shell/launcher/lib-plist.bash`
- Test: `test/lib/shell/launcher/lib-plist.bats`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"
  source "$PROJECT_ROOT/lib/shell/launcher/lib-plist.bash"
}

@test "launcher_plist returns correct path" {
  run launcher_plist "myagent"
  assert_success
  assert_output "$BATS_TEST_TMPDIR/agents/com.test.myagent.plist"
}

@test "launcher_bin returns correct path" {
  run launcher_bin "myagent"
  assert_success
  assert_output "$BATS_TEST_TMPDIR/agents/com.test.myagent"
}

@test "launcher_installed_bin returns correct path" {
  run launcher_installed_bin "myagent"
  assert_success
  assert_output "$BATS_TEST_TMPDIR/installed/com.test.myagent"
}

@test "LAUNCHER_PREFIX defaults to br.com.mracos" {
  unset LAUNCHER_PREFIX
  source "$PROJECT_ROOT/lib/shell/launcher/lib-plist.bash"
  run launcher_plist "test"
  assert_output --partial "br.com.mracos.test.plist"
}

@test "LAUNCHER_DIR defaults to ~/Library/LaunchAgents" {
  unset LAUNCHER_DIR
  unset DOTFILES_REPO
  source "$PROJECT_ROOT/lib/shell/launcher/lib-plist.bash"
  [[ "$LAUNCHER_DIR" == "$HOME/Library/LaunchAgents" ]]
}

@test "LAUNCHER_DIR uses DOTFILES_REPO when set" {
  unset LAUNCHER_DIR
  export DOTFILES_REPO="/fake/dotfiles"
  source "$PROJECT_ROOT/lib/shell/launcher/lib-plist.bash"
  [[ "$LAUNCHER_DIR" == "/fake/dotfiles/files/mac/Library/LaunchAgents" ]]
}
```

**Step 2: Run test to verify it fails**

Run: `PROJECT_ROOT=$PWD bats test/lib/shell/launcher/lib-plist.bats`
Expected: FAIL (file not found)

**Step 3: Write lib-plist.bash**

```bash
#!/usr/bin/env bash
# Plist path helpers and configuration for launcher

LAUNCHER_PREFIX="${LAUNCHER_PREFIX:-br.com.mracos}"

if [[ -z "${LAUNCHER_DIR:-}" ]]; then
  if [[ -n "${DOTFILES_REPO:-}" ]]; then
    LAUNCHER_DIR="$DOTFILES_REPO/files/mac/Library/LaunchAgents"
  else
    LAUNCHER_DIR="$HOME/Library/LaunchAgents"
  fi
fi

LAUNCHER_INSTALL_DIR="${LAUNCHER_INSTALL_DIR:-$HOME/Library/LaunchAgents}"

launcher_plist() { echo "${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.${1}.plist"; }
launcher_bin() { echo "${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.${1}"; }
launcher_installed_bin() { echo "${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${1}"; }
```

**Step 4: Run test to verify it passes**

Run: `PROJECT_ROOT=$PWD bats test/lib/shell/launcher/lib-plist.bats`
Expected: all PASS

**Step 5: Commit**

```
launcher: add lib-plist.bash with path helpers and config
```

---

### Task 3: Create lib-launchd.bash (launchd query helpers)

**Files:**
- Create: `lib/shell/launcher/lib-launchd.bash`
- Test: `test/lib/shell/launcher/lib-launchd.bats`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"

  # Fake launchctl
  export fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  export PATH="$fake_bin:$PATH"

  source "$PROJECT_ROOT/lib/shell/launcher/lib-plist.bash"
  source "$PROJECT_ROOT/lib/shell/launcher/lib-launchd.bash"
}

create_fake_launchctl() {
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "list" ]]; then
  cat <<'OUT'
PID	Status	Label
-	0	com.test.myagent
123	0	com.test.running
OUT
  exit 0
fi
if [[ "$1" == "print" ]]; then
  case "$2" in
    gui/*/com.test.running)
      cat <<'OUT'
	runs = 5
	last exit code = 0
	state = running
OUT
      ;;
    gui/*/com.test.myagent)
      cat <<'OUT'
	runs = 3
	last exit code = 1
	stdout path = /tmp/myagent.log
	stderr path = /tmp/myagent.err
	state = waiting
OUT
      ;;
  esac
  exit 0
fi
exit 1
SCRIPT
  chmod +x "$fake_bin/launchctl"
}

@test "launcher_loaded_names lists names matching prefix" {
  create_fake_launchctl
  run launcher_loaded_names
  assert_success
  assert_line "myagent"
  assert_line "running"
}

@test "launcher_loaded_names excludes non-matching labels" {
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "list" ]]; then
  cat <<'OUT'
PID	Status	Label
-	0	com.apple.something
-	0	com.test.mine
OUT
fi
SCRIPT
  chmod +x "$fake_bin/launchctl"

  run launcher_loaded_names
  assert_success
  assert_line "mine"
  refute_line --partial "apple"
}

@test "launcher_launchd_info returns key=value pairs" {
  create_fake_launchctl
  run launcher_launchd_info "myagent"
  assert_success
  assert_line "runs=3"
  assert_line "last_exit=1"
  assert_line "loaded=true"
  assert_line --partial "stdout_path=/tmp/myagent.log"
}

@test "launcher_launchd_info detects running state" {
  create_fake_launchctl
  run launcher_launchd_info "running"
  assert_success
  assert_line "state=running"
  assert_line "pid=123"
}
```

**Step 2: Run test to verify it fails**

Run: `PROJECT_ROOT=$PWD bats test/lib/shell/launcher/lib-launchd.bats`
Expected: FAIL

**Step 3: Write lib-launchd.bash**

Port `_launcher_launchd_info` and `_launcher_loaded_names` from the zsh plugin to bash. Key conversions:
- Remove zsh-specific string manipulation
- Use bash `while read` loops instead of zsh array syntax
- Function names: `_launcher_launchd_info` → `launcher_launchd_info`, `_launcher_loaded_names` → `launcher_loaded_names`

The logic stays the same: parse `launchctl list` and `launchctl print` output into key=value pairs.

**Step 4: Run test to verify it passes**

Run: `PROJECT_ROOT=$PWD bats test/lib/shell/launcher/lib-launchd.bats`
Expected: all PASS

**Step 5: Commit**

```
launcher: add lib-launchd.bash with launchd query helpers
```

---

### Task 4: Create entry point dispatcher

**Files:**
- Create: `files/shell/bin/launcher`
- Test: `test/files/shell/bin/launcher.bats`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

BIN="$PROJECT_ROOT/files/shell/bin/launcher"

@test "launcher exists and is executable" {
  assert [ -f "$BIN" ]
  assert [ -x "$BIN" ]
}

@test "launcher shows usage when called without args" {
  run "$BIN"
  assert_failure
  assert_output --partial "Usage:"
}

@test "launcher --help shows usage" {
  run "$BIN" --help
  assert_success
  assert_output --partial "launcher"
}

@test "launcher -h shows usage" {
  run "$BIN" -h
  assert_success
  assert_output --partial "launcher"
}

@test "launcher unknown command fails" {
  run "$BIN" nonexistent
  assert_failure
  assert_output --partial "Unknown command"
}
```

**Step 2: Run test to verify it fails**

Run: `PROJECT_ROOT=$PWD bats test/files/shell/bin/launcher.bats`
Expected: FAIL

**Step 3: Write the dispatcher**

```bash
#!/usr/bin/env bash
# launcher - Manage macOS launch agents
#
# USAGE:
#   launcher ls [-v]                      List agents (verbose with -v)
#   launcher info <name>                  Show agent details
#   launcher logs <name> [-f]             Show agent logs (follow with -f)
#   launcher new [-d dir] <name> <cmd> [interval]  Create an agent
#   launcher rm <name>                    Remove an agent
#   launcher show <name>                  Show agent plist
#   launcher edit <name>                  Edit agent plist
#   launcher link <name|--all>            Symlink to ~/Library/LaunchAgents
#   launcher unlink <name|--all>          Remove symlink
#   launcher reload <name>                Reload agent
#   launcher run <name>                   Run agent command manually
#   launcher load <name>                  Load agent
#   launcher unload <name>                Unload agent
#
# CONFIGURATION:
#   LAUNCHER_PREFIX    Label prefix (default: br.com.mracos)
#   LAUNCHER_DIR       Plist storage dir (default: ~/Library/LaunchAgents,
#                      or $DOTFILES_REPO/files/mac/Library/LaunchAgents)
#   LAUNCHER_INSTALL_DIR  Symlink target (default: ~/Library/LaunchAgents)

set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../../lib/shell/launcher"
source "$LIB_DIR/lib-cli.bash"

usage() {
  notes_cli_usage_until_blank "$0" "${1:-1}"
}

cmd="${1:-}"
notes_cli_is_help "$cmd" && usage 0
[[ -z "$cmd" ]] && usage 1

notes_cli_exec_subcommand "$LIB_DIR" "launcher-" "$cmd" "$@" || {
  echo "Unknown command: $cmd"
  usage
}
```

**Step 4: Make executable and run tests**

```bash
chmod +x files/shell/bin/launcher
```

Run: `PROJECT_ROOT=$PWD bats test/files/shell/bin/launcher.bats`
Expected: all PASS

**Step 5: Commit**

```
launcher: add entry point dispatcher with USAGE header
```

---

### Task 5: Extract simple subcommands (show, edit, run)

**Files:**
- Create: `lib/shell/launcher/launcher-show`
- Create: `lib/shell/launcher/launcher-edit`
- Create: `lib/shell/launcher/launcher-run`
- Test: `test/lib/shell/launcher/launcher-show.bats`
- Test: `test/lib/shell/launcher/launcher-edit.bats`
- Test: `test/lib/shell/launcher/launcher-run.bats`

These are the simplest subcommands - they check a file exists and do one thing.

**Step 1: Write failing tests for all three**

`launcher-show.bats`:
```bash
#!/usr/bin/env bats
load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"
}

BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-show"

@test "launcher-show fails without args" {
  run "$BIN"
  assert_failure
  assert_output --partial "Usage:"
}

@test "launcher-show fails for non-existent agent" {
  run "$BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}

@test "launcher-show displays plist content" {
  echo "<plist>test</plist>" > "$LAUNCHER_DIR/com.test.myagent.plist"
  run "$BIN" myagent
  assert_success
  assert_output --partial "<plist>test</plist>"
}
```

`launcher-edit.bats`:
```bash
#!/usr/bin/env bats
load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  mkdir -p "$LAUNCHER_DIR"
}

BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-edit"

@test "launcher-edit fails for non-existent agent" {
  run "$BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}
```

`launcher-run.bats`:
```bash
#!/usr/bin/env bats
load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  mkdir -p "$LAUNCHER_DIR"
}

BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-run"

@test "launcher-run fails without args" {
  run "$BIN"
  assert_failure
  assert_output --partial "Usage:"
}

@test "launcher-run fails for non-existent agent" {
  run "$BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}

@test "launcher-run executes the wrapper script" {
  echo '#!/bin/bash' > "$LAUNCHER_DIR/com.test.myagent"
  echo 'echo hello-from-agent' >> "$LAUNCHER_DIR/com.test.myagent"
  chmod +x "$LAUNCHER_DIR/com.test.myagent"
  run "$BIN" myagent
  assert_success
  assert_output --partial "hello-from-agent"
}
```

**Step 2: Run tests to verify they fail**

Run: `PROJECT_ROOT=$PWD bats test/lib/shell/launcher/launcher-show.bats test/lib/shell/launcher/launcher-edit.bats test/lib/shell/launcher/launcher-run.bats`
Expected: FAIL

**Step 3: Write the three subcommands**

Each follows the same pattern: shebang, source libs, validate args, do one thing.

`launcher-show`:
```bash
#!/usr/bin/env bash
# Show agent plist contents
# USAGE: launcher show <name>

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-cli.bash" --auto "$@"
source "$SCRIPT_DIR/lib-plist.bash"

name="${1:?$(usage)}"
plist="$(launcher_plist "$name")"

if [[ ! -f "$plist" ]]; then
  echo "Not found: $name"
  exit 1
fi

cat "$plist"
```

`launcher-edit`:
```bash
#!/usr/bin/env bash
# Edit agent plist in $EDITOR
# USAGE: launcher edit <name>

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-cli.bash" --auto "$@"
source "$SCRIPT_DIR/lib-plist.bash"

name="${1:?$(usage)}"
plist="$(launcher_plist "$name")"

if [[ ! -f "$plist" ]]; then
  echo "Not found: $name"
  exit 1
fi

${EDITOR:-vim} "$plist"
```

`launcher-run`:
```bash
#!/usr/bin/env bash
# Run agent command manually
# USAGE: launcher run <name>

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-cli.bash" --auto "$@"
source "$SCRIPT_DIR/lib-plist.bash"

name="${1:?$(usage)}"
bin="$(launcher_bin "$name")"

if [[ ! -f "$bin" ]]; then
  echo "Not found: $name"
  exit 1
fi

"$bin"
```

Make all executable: `chmod +x lib/shell/launcher/launcher-{show,edit,run}`

**Step 4: Run tests**

Run: `PROJECT_ROOT=$PWD bats test/lib/shell/launcher/launcher-show.bats test/lib/shell/launcher/launcher-edit.bats test/lib/shell/launcher/launcher-run.bats`
Expected: all PASS

**Step 5: Commit**

```
launcher: extract show, edit, run subcommands
```

---

### Task 6: Extract launcher-new

**Files:**
- Create: `lib/shell/launcher/launcher-new`
- Test: `test/lib/shell/launcher/launcher-new.bats`

**Step 1: Write failing test**

```bash
#!/usr/bin/env bats
load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"
}

BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-new"

@test "launcher-new fails without args" {
  run "$BIN"
  assert_failure
  assert_output --partial "Usage:"
}

@test "launcher-new creates wrapper script and plist" {
  run "$BIN" testjob 'echo hello'
  assert_success

  assert [ -f "$LAUNCHER_DIR/com.test.testjob.plist" ]
  assert [ -f "$LAUNCHER_DIR/com.test.testjob" ]
  assert [ -x "$LAUNCHER_DIR/com.test.testjob" ]
}

@test "launcher-new creates bash wrapper script" {
  run "$BIN" testjob 'echo hello'
  assert_success

  run head -1 "$LAUNCHER_DIR/com.test.testjob"
  assert_output "#!/bin/bash"
}

@test "launcher-new creates valid plist with label and RunAtLoad" {
  run "$BIN" testjob 'echo hello'
  assert_success

  run cat "$LAUNCHER_DIR/com.test.testjob.plist"
  assert_output --partial "<key>Label</key><string>com.test.testjob</string>"
  assert_output --partial "<string>$LAUNCHER_INSTALL_DIR/com.test.testjob</string>"
  assert_output --partial "<key>RunAtLoad</key><true/>"
}

@test "launcher-new with interval adds StartInterval" {
  run "$BIN" periodic 'echo tick' 300
  assert_success

  run cat "$LAUNCHER_DIR/com.test.periodic.plist"
  assert_output --partial "<key>StartInterval</key><integer>300</integer>"
}

@test "launcher-new with -d uses custom directory" {
  local custom="$BATS_TEST_TMPDIR/custom"
  mkdir -p "$custom"
  run "$BIN" -d "$custom" testjob 'echo hello'
  assert_success
  assert [ -f "$custom/com.test.testjob.plist" ]
}
```

**Step 2: Run test, verify fail**

Run: `PROJECT_ROOT=$PWD bats test/lib/shell/launcher/launcher-new.bats`

**Step 3: Write launcher-new**

Port `_launcher_new` from zsh plugin. Same logic: parse `-d` flag, create wrapper script with notification on failure, create plist XML. Use `launcher-run` (the bin script from `files/shell/bin/`) for the wrapper's notification logic rather than inline osascript.

**Step 4: Run test, verify pass**

Run: `PROJECT_ROOT=$PWD bats test/lib/shell/launcher/launcher-new.bats`

**Step 5: Commit**

```
launcher: extract new subcommand
```

---

### Task 7: Extract launcher-rm

**Files:**
- Create: `lib/shell/launcher/launcher-rm`
- Test: `test/lib/shell/launcher/launcher-rm.bats`

**Step 1: Write failing test**

```bash
#!/usr/bin/env bats
load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  mkdir -p "$LAUNCHER_DIR"
}

BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-rm"

@test "launcher-rm fails for non-existent agent" {
  run "$BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}

@test "launcher-rm removes plist and bin" {
  echo "<plist></plist>" > "$LAUNCHER_DIR/com.test.todelete.plist"
  echo "#!/bin/bash" > "$LAUNCHER_DIR/com.test.todelete"

  run "$BIN" todelete
  assert_success
  assert [ ! -f "$LAUNCHER_DIR/com.test.todelete.plist" ]
  assert [ ! -f "$LAUNCHER_DIR/com.test.todelete" ]
}
```

**Step 2-4: Red-green cycle**

Port `_launcher_rm` - unload via launchctl, remove plist and bin.

**Step 5: Commit**

```
launcher: extract rm subcommand
```

---

### Task 8: Extract launcher-link and launcher-unlink

**Files:**
- Create: `lib/shell/launcher/launcher-link`
- Create: `lib/shell/launcher/launcher-unlink`
- Test: `test/lib/shell/launcher/launcher-link.bats`

**Step 1: Write failing test**

```bash
#!/usr/bin/env bats
load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"
}

LINK_BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-link"
UNLINK_BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-unlink"

@test "launcher-link fails without args" {
  run "$LINK_BIN"
  assert_failure
  assert_output --partial "Usage:"
}

@test "launcher-link fails for non-existent agent" {
  run "$LINK_BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}

@test "launcher-link creates symlinks for plist and bin" {
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.myagent.plist"
  echo "#!/bin/bash" > "$LAUNCHER_DIR/com.test.myagent"

  run "$LINK_BIN" myagent
  assert_success
  assert [ -L "$LAUNCHER_INSTALL_DIR/com.test.myagent.plist" ]
  assert [ -L "$LAUNCHER_INSTALL_DIR/com.test.myagent" ]
}

@test "launcher-link is idempotent" {
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.myagent.plist"
  echo "#!/bin/bash" > "$LAUNCHER_DIR/com.test.myagent"

  run "$LINK_BIN" myagent
  assert_output --partial "Linked:"

  run "$LINK_BIN" myagent
  assert_success
  refute_output --partial "Linked:"
}

@test "launcher-link --all links all agents" {
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.one.plist"
  echo "#!/bin/bash" > "$LAUNCHER_DIR/com.test.one"
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.two.plist"
  echo "#!/bin/bash" > "$LAUNCHER_DIR/com.test.two"

  run "$LINK_BIN" --all
  assert_success
  assert [ -L "$LAUNCHER_INSTALL_DIR/com.test.one.plist" ]
  assert [ -L "$LAUNCHER_INSTALL_DIR/com.test.two.plist" ]
}

@test "launcher-link is no-op when dirs are the same" {
  export LAUNCHER_INSTALL_DIR="$LAUNCHER_DIR"
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.myagent.plist"
  echo "#!/bin/bash" > "$LAUNCHER_DIR/com.test.myagent"

  run "$LINK_BIN" myagent
  assert_success
  assert_output --partial "already in place"
}

@test "launcher-unlink removes symlinks" {
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.myagent.plist"
  echo "#!/bin/bash" > "$LAUNCHER_DIR/com.test.myagent"
  ln -sf "$LAUNCHER_DIR/com.test.myagent.plist" "$LAUNCHER_INSTALL_DIR/com.test.myagent.plist"
  ln -sf "$LAUNCHER_DIR/com.test.myagent" "$LAUNCHER_INSTALL_DIR/com.test.myagent"

  run "$UNLINK_BIN" myagent
  assert_success
  assert [ ! -L "$LAUNCHER_INSTALL_DIR/com.test.myagent.plist" ]
  assert [ ! -L "$LAUNCHER_INSTALL_DIR/com.test.myagent" ]
}
```

**Step 2-4: Red-green cycle**

Port `_launcher_link` and `_launcher_unlink`. Key addition: when `LAUNCHER_DIR == LAUNCHER_INSTALL_DIR`, `link` prints "already in place" and returns 0. Convert zsh glob `${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.*.plist(N)` to bash `for f in "$LAUNCHER_DIR"/${LAUNCHER_PREFIX}.*.plist; do [[ -f "$f" ]] || continue`.

**Step 5: Commit**

```
launcher: extract link and unlink subcommands
```

---

### Task 9: Extract launcher-load, launcher-unload, launcher-reload

**Files:**
- Create: `lib/shell/launcher/launcher-load`
- Create: `lib/shell/launcher/launcher-unload`
- Create: `lib/shell/launcher/launcher-reload`
- Test: `test/lib/shell/launcher/launcher-load.bats`

**Step 1: Write failing test**

```bash
#!/usr/bin/env bats
load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"
}

LOAD_BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-load"
UNLOAD_BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-unload"
RELOAD_BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-reload"

@test "launcher-load fails for unlinked agent" {
  run "$LOAD_BIN" nonexistent
  assert_failure
  assert_output --partial "Not linked"
}

@test "launcher-unload fails for unlinked agent" {
  run "$UNLOAD_BIN" nonexistent
  assert_failure
  assert_output --partial "Not linked"
}

@test "launcher-reload fails for unlinked agent" {
  run "$RELOAD_BIN" nonexistent
  assert_failure
  assert_output --partial "Not linked"
}
```

**Step 2-4: Red-green cycle**

Port `_launcher_load`, `_launcher_unload`, `_launcher_reload`. The `unload` subcommand has the special bootout fallback for orphaned loaded jobs - port that too using `launcher_loaded_names` from `lib-launchd.bash`.

**Step 5: Commit**

```
launcher: extract load, unload, reload subcommands
```

---

### Task 10: Extract launcher-info

**Files:**
- Create: `lib/shell/launcher/launcher-info`
- Test: `test/lib/shell/launcher/launcher-info.bats`

**Step 1: Write failing test**

```bash
#!/usr/bin/env bats
load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"
}

BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-info"

@test "launcher-info fails without args" {
  run "$BIN"
  assert_failure
  assert_output --partial "Usage:"
}

@test "launcher-info fails for non-existent agent" {
  run "$BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}

@test "launcher-info shows agent details" {
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.myagent.plist"

  run "$BIN" myagent
  assert_success
  assert_output --partial "Agent: myagent"
  assert_output --partial "Label: com.test.myagent"
  assert_output --partial "Linked: no"
}
```

**Step 2-4: Red-green cycle**

Port `_launcher_info`. Sources both `lib-plist.bash` and `lib-launchd.bash`.

**Step 5: Commit**

```
launcher: extract info subcommand
```

---

### Task 11: Extract launcher-logs

**Files:**
- Create: `lib/shell/launcher/launcher-logs`
- Test: `test/lib/shell/launcher/launcher-logs.bats`

**Step 1: Write failing test**

```bash
#!/usr/bin/env bats
load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"
}

BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-logs"

@test "launcher-logs fails without args" {
  run "$BIN"
  assert_failure
  assert_output --partial "Usage:"
}

@test "launcher-logs fails for non-existent agent" {
  run "$BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}
```

**Step 2-4: Red-green cycle**

**Step 5: Commit**

```
launcher: extract logs subcommand
```

---

### Task 12: Extract launcher-ls (most complex)

**Files:**
- Create: `lib/shell/launcher/launcher-ls`
- Test: `test/lib/shell/launcher/launcher-ls.bats`

**Step 1: Write failing test**

```bash
#!/usr/bin/env bats
load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"

  export fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "list" ]]; then
  echo "PID	Status	Label"
fi
SCRIPT
  chmod +x "$fake_bin/launchctl"
  export PATH="$fake_bin:$PATH"
}

BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-ls"

@test "launcher-ls shows no agents when empty" {
  run "$BIN"
  assert_success
  assert_output --partial "No agents found"
}

@test "launcher-ls shows unlinked agent" {
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.myagent.plist"
  run "$BIN"
  assert_success
  assert_output --partial "myagent"
  assert_output --partial "unlinked"
}

@test "launcher-ls -v shows header row" {
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.myagent.plist"
  run "$BIN" -v
  assert_success
  assert_output --partial "NAME"
  assert_output --partial "STATUS"
}
```

**Step 2-4: Red-green cycle**

This is the biggest subcommand. Key bash conversions:
- `typeset -A loaded_names` → `declare -A loaded_names`
- `local plists=(${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.*.plist(N))` → loop with `-f` check
- `typeset -A plist_names` / `typeset -A seen_orphans` → `declare -A`

**Step 5: Commit**

```
launcher: extract ls subcommand
```

---

### Task 13: Add DOTFILES_REPO env var

**Files:**
- Identify: where PATH/env is configured for the shell (likely a zsh plugin or profile)
- Modify: add `export DOTFILES_REPO=...`

**Step 1: Find where shell env vars are set**

Check existing zsh plugins and profile files for where `PATH` is configured. The `prefs` plugin uses `${0:A}` to find dotfiles root at source time, but `launcher` now needs it at runtime from a bin script.

**Step 2: Add DOTFILES_REPO export**

Add to the appropriate shell config file:
```bash
export DOTFILES_REPO="$HOME/src/github.com/mracos/dotfiles"
```

**Step 3: Commit**

```
shell: add DOTFILES_REPO env var
```

---

### Task 14: Remove old zsh plugin

**Files:**
- Delete: `files/shell/.config/zsh/plugins/launcher/launcher.plugin.zsh`
- Delete: `files/shell/.config/zsh/plugins/launcher/` (directory)

**Step 1: Remove the plugin directory**

```bash
rm -rf files/shell/.config/zsh/plugins/launcher/
```

**Step 2: Remove old symlink manually**

The stow symlink at `~/.config/zsh/plugins/launcher/` won't auto-clean. Remove it:
```bash
rm -rf ~/.config/zsh/plugins/launcher
```

**Step 3: Commit**

```
launcher: remove zsh plugin (replaced by standalone CLI)
```

---

### Task 15: Update and migrate tests

**Files:**
- Delete: `test/files/shell/dot_config/zsh/plugins/launcher/launcher.bats`
- Keep: `test/files/shell/bin/launcher-run.bats` (still valid, `launcher-run` bin script unchanged)

**Step 1: Remove old plugin test**

The old test at `test/files/shell/dot_config/zsh/plugins/launcher/launcher.bats` tests the zsh plugin directly. All its test cases are now covered by the new per-subcommand bats files (Tasks 2-12).

**Step 2: Run full test suite**

Run: `npm test`
Expected: all pass, no references to the deleted plugin

**Step 3: Commit**

```
test: remove old launcher plugin tests (replaced by subcommand tests)
```

---

### Task 16: Stow and smoke test

Not automated - manual verification:

**Step 1: Re-stow shell**

```bash
./link.sh shell
```

**Step 2: Verify `launcher` is in PATH**

```bash
which launcher
launcher --help
launcher ls
```

**Step 3: Verify completions work**

Type `launcher <tab>` in a new shell - should show subcommands from `# USAGE:` header.

**Step 4: Run full test suite one more time**

```bash
npm test
```
