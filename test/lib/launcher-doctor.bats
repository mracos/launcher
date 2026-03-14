#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"
}

BIN="$PROJECT_ROOT/lib/launcher-doctor"
LAUNCHER_RUN="$PROJECT_ROOT/bin/launcher-run"

create_agent() {
  local name="$1"
  local launcher_run_path="${2:-$LAUNCHER_RUN}"

  cat > "$LAUNCHER_DIR/com.test.${name}" << SCRIPT
#!/bin/bash
# Launcher agent: ${name}

exec ${launcher_run_path} ${name} echo hello
SCRIPT
  chmod +x "$LAUNCHER_DIR/com.test.${name}"

  cat > "$LAUNCHER_DIR/com.test.${name}.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>Label</key><string>com.test.${name}</string>
  <key>ProgramArguments</key>
  <array><string>$LAUNCHER_INSTALL_DIR/com.test.${name}</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
}

@test "doctor reports healthy when no issues" {
  create_agent healthy
  run "$BIN"
  assert_success
  assert_output "All agents healthy"
}

@test "doctor detects stale launcher-run path" {
  create_agent stale "/old/path/to/launcher-run"
  run "$BIN"
  assert_failure
  assert_output --partial "stale launcher-run path"
  assert_output --partial "Run 'launcher doctor --fix' to fix"
}

@test "doctor --fix rewrites stale launcher-run path" {
  create_agent stale "/old/path/to/launcher-run"
  run "$BIN" --fix
  assert_success
  assert_output --partial "FIXED"

  run cat "$LAUNCHER_DIR/com.test.stale"
  assert_output --partial "$LAUNCHER_RUN"
  refute_output --partial "/old/path/to/launcher-run"
}

@test "doctor detects non-executable wrapper" {
  create_agent noexec
  chmod -x "$LAUNCHER_DIR/com.test.noexec"
  run "$BIN"
  assert_failure
  assert_output --partial "not executable"
}

@test "doctor --fix makes wrapper executable" {
  create_agent noexec
  chmod -x "$LAUNCHER_DIR/com.test.noexec"
  run "$BIN" --fix
  assert_success
  assert [ -x "$LAUNCHER_DIR/com.test.noexec" ]
}

@test "doctor detects missing wrapper script" {
  cat > "$LAUNCHER_DIR/com.test.ghost.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>Label</key><string>com.test.ghost</string>
</dict>
</plist>
EOF
  run "$BIN"
  assert_failure
  assert_output --partial "wrapper script missing"
}

@test "doctor warns about missing commands" {
  create_agent badcmd
  cat > "$LAUNCHER_DIR/com.test.badcmd" << SCRIPT
#!/bin/bash
exec $LAUNCHER_RUN badcmd /nonexistent/bin/foobar
SCRIPT
  chmod +x "$LAUNCHER_DIR/com.test.badcmd"

  run "$BIN"
  assert_failure
  assert_output --partial "WARN"
  assert_output --partial "/nonexistent/bin/foobar"
}
