#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

BIN="$PROJECT_ROOT/bin/launcher"

@test "launcher exists and is executable" {
  assert [ -f "$BIN" ]
  assert [ -x "$BIN" ]
}

@test "launcher shows usage when called without args" {
  run "$BIN"
  assert_failure
  assert_output --partial "USAGE:"
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
