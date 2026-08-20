#!/usr/bin/env bats
# bats file_tags=integration

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  mkdir -p "$LAUNCHER_DIR"
}

BIN="$PROJECT_ROOT/lib/launcher-info"

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
  assert_output --partial "Status:"
}

@test "launcher-info shows disabled status for disabled agent" {
  echo "<plist/>" > "$LAUNCHER_DIR/com.test.myagent.plist"

  fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "list" ]]; then
  echo "PID	Status	Label"
  exit 0
fi
if [[ "$1" == "print-disabled" ]]; then
  echo '		"com.test.myagent" => disabled'
  # Many trailing prefix-matching lines: a consumer that greps -q mid-stream
  # gets SIGPIPE from the lines after the match (regression: pipefail ate it)
  for i in $(seq 1 500); do
    echo "		\"com.test.filler$i\" => disabled"
  done
  exit 0
fi
exit 1
SCRIPT
  chmod +x "$fake_bin/launchctl"
  export PATH="$fake_bin:$PATH"

  run "$BIN" myagent
  assert_success
  assert_output --partial "Status: disabled"
}
