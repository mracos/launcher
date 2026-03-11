#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

BIN="$PROJECT_ROOT/bin/launcher-run"

@test "launcher-run exists and is executable" {
  assert [ -f "$BIN" ]
  assert [ -x "$BIN" ]
}

@test "launcher-run runs successful command" {
  run "$BIN" test-agent echo "hello world"
  assert_success
}

@test "launcher-run exits with failure code on command failure" {
  run "$BIN" test-agent false
  assert_failure
}

@test "launcher-run passes arguments to command" {
  run "$BIN" test-agent echo "arg1" "arg2"
  assert_success
  assert_output --partial "arg1 arg2"
}

@test "launcher-run --no-notify skips notification on failure" {
  # Can't easily test notification wasn't shown, but can verify the flag is accepted
  run "$BIN" --no-notify test-agent false
  assert_failure
}

@test "launcher-run --no-notify still runs command successfully" {
  run "$BIN" --no-notify test-agent echo "success"
  assert_success
  assert_output --partial "success"
}
