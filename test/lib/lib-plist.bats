#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"
  source "$PROJECT_ROOT/lib/lib-plist.bash"
}

@test "launcher_plist returns correct path" {
  run launcher_plist "myagent"
  assert_success
  assert_output "$BATS_TEST_TMPDIR/agents/com.test.myagent.plist"
}

@test "launcher_bin returns correct path" {
  run launcher_bin "myagent"
  assert_success
  assert_output "$BATS_TEST_TMPDIR/agents/com.test.myagent"
}

@test "launcher_installed_bin returns correct path" {
  run launcher_installed_bin "myagent"
  assert_success
  assert_output "$BATS_TEST_TMPDIR/installed/com.test.myagent"
}

@test "LAUNCHER_PREFIX defaults to br.com.mracos" {
  unset LAUNCHER_PREFIX
  source "$PROJECT_ROOT/lib/lib-plist.bash"
  run launcher_plist "test"
  assert_output --partial "br.com.mracos.test.plist"
}

@test "LAUNCHER_DIR defaults to ~/Library/LaunchAgents" {
  unset LAUNCHER_DIR
  source "$PROJECT_ROOT/lib/lib-plist.bash"
  [[ "$LAUNCHER_DIR" == "$HOME/Library/LaunchAgents" ]]
}
