#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  mkdir -p "$LAUNCHER_DIR"
}

BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-edit"

@test "launcher-edit fails without args" {
  run "$BIN"
  assert_failure
}

@test "launcher-edit fails for non-existent agent" {
  run "$BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}
