#!/usr/bin/env bats
# bats file_tags=integration

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  mkdir -p "$LAUNCHER_DIR"
}

LOAD_BIN="$PROJECT_ROOT/lib/launcher-load"
UNLOAD_BIN="$PROJECT_ROOT/lib/launcher-unload"
RELOAD_BIN="$PROJECT_ROOT/lib/launcher-reload"

@test "launcher-load fails when the plist is missing" {
  run "$LOAD_BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}

@test "launcher-unload fails when the plist is missing" {
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
  assert_output --partial "Not found"
}

@test "launcher-reload fails when the plist is missing" {
  run "$RELOAD_BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}

@test "launcher-unload cleans up dangling symlinks" {
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "list" ]]; then
  echo "PID	Status	Label"
fi
exit 0
SCRIPT
  chmod +x "$fake_bin/launchctl"
  export PATH="$fake_bin:$PATH"

  # Create dangling symlinks (target doesn't exist, e.g. removed repo file
  # behind a stow link)
  ln -s "$BATS_TEST_TMPDIR/gone/com.test.old.plist" "$LAUNCHER_DIR/com.test.old.plist"
  ln -s "$BATS_TEST_TMPDIR/gone/com.test.old" "$LAUNCHER_DIR/com.test.old"

  run "$UNLOAD_BIN" old
  assert_success
  assert_output --partial "Unloaded (dangling): old"
  assert [ ! -L "$LAUNCHER_DIR/com.test.old.plist" ]
  assert [ ! -L "$LAUNCHER_DIR/com.test.old" ]
}

@test "launcher-load --all loads all agents in the dir" {
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
  chmod +x "$fake_bin/launchctl"
  export PATH="$fake_bin:$PATH"

  echo "<plist/>" > "$LAUNCHER_DIR/com.test.one.plist"
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.two.plist"

  run "$LOAD_BIN" --all
  assert_success
  assert_output --partial "Loaded: one"
  assert_output --partial "Loaded: two"
}

@test "launcher-load loads a symlinked plist like a regular one" {
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
  chmod +x "$fake_bin/launchctl"
  export PATH="$fake_bin:$PATH"

  # Stow-style: real file elsewhere, symlink in the agent dir
  mkdir -p "$BATS_TEST_TMPDIR/repo"
  echo "<plist/>" > "$BATS_TEST_TMPDIR/repo/com.test.stowed.plist"
  ln -s "$BATS_TEST_TMPDIR/repo/com.test.stowed.plist" "$LAUNCHER_DIR/com.test.stowed.plist"

  run "$LOAD_BIN" stowed
  assert_success
  assert_output --partial "Loaded: stowed"
}

@test "launcher-unload --all unloads all agents in the dir" {
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
  chmod +x "$fake_bin/launchctl"
  export PATH="$fake_bin:$PATH"

  echo "<plist/>" > "$LAUNCHER_DIR/com.test.one.plist"
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.two.plist"

  run "$UNLOAD_BIN" --all
  assert_success
  assert_output --partial "Unloaded: one"
  assert_output --partial "Unloaded: two"
}

@test "launcher-reload --all reloads all agents in the dir" {
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
  chmod +x "$fake_bin/launchctl"
  export PATH="$fake_bin:$PATH"

  echo "<plist/>" > "$LAUNCHER_DIR/com.test.one.plist"
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.two.plist"

  run "$RELOAD_BIN" --all
  assert_success
  assert_output --partial "Reloaded: one"
  assert_output --partial "Reloaded: two"
}

@test "launcher-unload succeeds for loaded agent with no plist" {
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
