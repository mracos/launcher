#!/usr/bin/env bats
# bats file_tags=integration

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  mkdir -p "$LAUNCHER_DIR"

  # Fake launchctl that logs every invocation
  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/launchctl" <<SCRIPT
#!/bin/bash
echo "launchctl \$*" >> "$BATS_TEST_TMPDIR/launchctl.log"
exit 0
SCRIPT
  chmod +x "$fake_bin/launchctl"
  export PATH="$fake_bin:$PATH"
}

DISABLE_BIN="$PROJECT_ROOT/lib/launcher-disable"
ENABLE_BIN="$PROJECT_ROOT/lib/launcher-enable"

create_agent() {
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.$1.plist"
}

@test "launcher-disable fails for unknown agent" {
  run "$DISABLE_BIN" nonexistent
  assert_failure
  assert_output --partial "Not found: nonexistent"
}

@test "launcher-disable boots out and persistently disables the agent" {
  create_agent myagent

  run "$DISABLE_BIN" myagent
  assert_success
  assert_output --partial "Disabled: myagent"

  run cat "$BATS_TEST_TMPDIR/launchctl.log"
  assert_output --partial "launchctl bootout gui/$(id -u)/com.test.myagent"
  assert_output --partial "launchctl disable gui/$(id -u)/com.test.myagent"
}

@test "launcher-disable succeeds when agent is not currently loaded" {
  create_agent idle
  # bootout fails for unloaded jobs; disable must still go through
  cat > "$fake_bin/launchctl" <<SCRIPT
#!/bin/bash
echo "launchctl \$*" >> "$BATS_TEST_TMPDIR/launchctl.log"
[[ "\$1" == "bootout" ]] && exit 3
exit 0
SCRIPT
  chmod +x "$fake_bin/launchctl"

  run "$DISABLE_BIN" idle
  assert_success
  assert_output --partial "Disabled: idle"
}

@test "launcher-disable fails when launchctl disable fails" {
  create_agent myagent
  cat > "$fake_bin/launchctl" <<SCRIPT
#!/bin/bash
echo "launchctl \$*" >> "$BATS_TEST_TMPDIR/launchctl.log"
[[ "\$1" == "disable" ]] && exit 1
exit 0
SCRIPT
  chmod +x "$fake_bin/launchctl"

  run "$DISABLE_BIN" myagent
  assert_failure
  assert_output --partial "Failed to disable: myagent"
}

@test "launcher-disable --all disables every agent" {
  create_agent one
  create_agent two

  run "$DISABLE_BIN" --all
  assert_success
  assert_output --partial "Disabled: one"
  assert_output --partial "Disabled: two"
}

@test "launcher-enable fails for unknown agent" {
  run "$ENABLE_BIN" nonexistent
  assert_failure
  assert_output --partial "Not found: nonexistent"
}

@test "launcher-enable enables and loads the agent" {
  create_agent myagent

  run "$ENABLE_BIN" myagent
  assert_success
  assert_output --partial "Enabled: myagent"

  run cat "$BATS_TEST_TMPDIR/launchctl.log"
  assert_output --partial "launchctl enable gui/$(id -u)/com.test.myagent"
  assert_output --partial "launchctl load $LAUNCHER_DIR/com.test.myagent.plist"
}
