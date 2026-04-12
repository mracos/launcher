#!/usr/bin/env bats

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  export LAUNCHER_INSTALL_DIR="$BATS_TEST_TMPDIR/installed"
  mkdir -p "$LAUNCHER_DIR" "$LAUNCHER_INSTALL_DIR"
}

BIN="$PROJECT_ROOT/lib/launcher-logs"

@test "launcher-logs fails without args" {
  run "$BIN"
  assert_failure
}

@test "launcher-logs fails for non-existent agent" {
  run "$BIN" nonexistent
  assert_failure
  assert_output --partial "Not found"
}

@test "launcher-logs suggests the default log path when plist has no log keys" {
  cat > "$LAUNCHER_DIR/com.test.legacy.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.test.legacy</string>
  <key>ProgramArguments</key>
  <array>
    <string>/tmp/com.test.legacy</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF

  run "$BIN" legacy
  assert_failure
  assert_output --partial "No log path configured for legacy"
  assert_output --partial "default: /tmp/legacy.log"
}
