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
  assert_output --partial "Removed: todelete"
}
