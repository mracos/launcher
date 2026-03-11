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
  assert_output --partial "Linked:"
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
  assert_output --partial "Unlinked:"
}

@test "launcher-unlink fails without args" {
  run "$UNLINK_BIN"
  assert_failure
}
