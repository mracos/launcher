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

@test "launcher-ls shows loaded orphan labels missing source plist" {
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "list" ]]; then
  cat <<'OUT'
PID	Status	Label
-	0	com.test.orphan
OUT
  exit 0
fi
if [[ "$1" == "print" ]]; then
  case "$2" in
    gui/*/com.test.orphan)
      cat <<'OUT'
	runs = 9
	last exit code = 0
	state = running
OUT
      ;;
  esac
  exit 0
fi
SCRIPT
  chmod +x "$fake_bin/launchctl"

  run "$BIN"
  assert_success
  assert_output --partial "orphan"
  assert_output --partial "missing source plist"
}
