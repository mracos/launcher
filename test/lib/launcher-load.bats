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
  # Fake launchctl that returns empty list
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "list" ]]; then
  echo "PID	Status	Label"
fi
exit 1
SCRIPT
  chmod +x "$fake_bin/launchctl"
  export PATH="$fake_bin:$PATH"

  run "$UNLOAD_BIN" nonexistent
  assert_failure
  assert_output --partial "Not linked"
}

@test "launcher-reload fails for unlinked agent" {
  run "$RELOAD_BIN" nonexistent
  assert_failure
  assert_output --partial "Not linked"
}

@test "launcher-unload succeeds for loaded but unlinked agent" {
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "list" ]]; then
  cat <<'OUT'
PID	Status	Label
-	0	com.test.stale
OUT
  exit 0
fi
if [[ "$1" == "bootout" && "$2" == "gui/"*"/com.test.stale" ]]; then
  exit 0
fi
exit 1
SCRIPT
  chmod +x "$fake_bin/launchctl"
  export PATH="$fake_bin:$PATH"

  run "$UNLOAD_BIN" stale
  assert_success
  assert_output --partial "Unloaded: stale"
}
