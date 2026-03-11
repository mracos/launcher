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
