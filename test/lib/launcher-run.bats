#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  mkdir -p "$LAUNCHER_DIR"
}

BIN="$PROJECT_ROOT/lib/shell/launcher/launcher-run"

@test "launcher-run fails without args" {
  run "$BIN"
  assert_failure
}

@test "launcher-run fails for non-existent agent" {
  run "$BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}

@test "launcher-run executes the wrapper script" {
  cat > "$LAUNCHER_DIR/com.test.myagent" <<'EOF'
#!/bin/bash
echo "hello-from-agent"
EOF
  chmod +x "$LAUNCHER_DIR/com.test.myagent"
  run "$BIN" myagent
  assert_success
  assert_output --partial "hello-from-agent"
}
