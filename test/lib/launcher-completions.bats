#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  mkdir -p "$LAUNCHER_DIR"
}

@test "_launcher_agent_names lists managed agent names from plists" {
  touch "$LAUNCHER_DIR/com.test.alpha.plist"
  touch "$LAUNCHER_DIR/com.test.bravo.plist"

  run zsh -c "
    export LAUNCHER_PREFIX='$LAUNCHER_PREFIX'
    export LAUNCHER_DIR='$LAUNCHER_DIR'
    source '$PROJECT_ROOT/lib/_launcher'
    _describe() { shift; local -a items=(\"\${(@P)1}\"); printf '%s\n' \"\${items[@]}\"; }
    _launcher_agent_names
  "
  assert_success
  assert_output --partial "alpha"
  assert_output --partial "bravo"
}

@test "_launcher_agent_names_or_all includes --all and managed names" {
  touch "$LAUNCHER_DIR/com.test.alpha.plist"

  run zsh -c "
    export LAUNCHER_PREFIX='$LAUNCHER_PREFIX'
    export LAUNCHER_DIR='$LAUNCHER_DIR'
    source '$PROJECT_ROOT/lib/_launcher'
    _describe() { shift; local -a items=(\"\${(@P)1}\"); printf '%s\n' \"\${items[@]}\"; }
    _launcher_agent_names_or_all
  "
  assert_success
  assert_output --partial "--all"
  assert_output --partial "alpha"
}

@test "launcher name-taking subcommands advertise COMPLETE metadata" {
  run rg -n '^# COMPLETE:|^#   1 _launcher_agent_names(_or_all)?$' \
    "$PROJECT_ROOT/lib/launcher-logs" \
    "$PROJECT_ROOT/lib/launcher-info" \
    "$PROJECT_ROOT/lib/launcher-show" \
    "$PROJECT_ROOT/lib/launcher-run" \
    "$PROJECT_ROOT/lib/launcher-edit" \
    "$PROJECT_ROOT/lib/launcher-rm" \
    "$PROJECT_ROOT/lib/launcher-load" \
    "$PROJECT_ROOT/lib/launcher-unload" \
    "$PROJECT_ROOT/lib/launcher-reload" \
    "$PROJECT_ROOT/lib/launcher-link" \
    "$PROJECT_ROOT/lib/launcher-unlink"

  assert_success
  assert_output --partial "launcher-logs:5:# COMPLETE:"
  assert_output --partial "launcher-link:6:#   1 _launcher_agent_names_or_all"
  assert_output --partial "launcher-info:6:#   1 _launcher_agent_names"
}
