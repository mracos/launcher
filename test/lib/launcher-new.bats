#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"
}

BIN="$PROJECT_ROOT/lib/launcher-new"

@test "launcher-new fails without args" {
  run "$BIN"
  assert_failure
}

@test "launcher-new fails with only name" {
  run "$BIN" testjob
  assert_failure
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
