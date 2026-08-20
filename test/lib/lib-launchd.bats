#!/usr/bin/env bats
# bats file_tags=integration

load "$PROJECT_ROOT/test/test_helper"

setup() {
  export LAUNCHER_PREFIX="com.test"
  export LAUNCHER_DIR="$BATS_TEST_TMPDIR/agents"
  mkdir -p "$LAUNCHER_DIR"

  # Fake launchctl
  export fake_bin="$BATS_TEST_TMPDIR/fake-bin"
  mkdir -p "$fake_bin"
  export PATH="$fake_bin:$PATH"

  source "$PROJECT_ROOT/lib/lib-plist.bash"
  source "$PROJECT_ROOT/lib/lib-launchd.bash"
}

create_fake_launchctl() {
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "list" ]]; then
  cat <<'OUT'
PID	Status	Label
-	0	com.test.myagent
123	0	com.test.running
OUT
  exit 0
fi
if [[ "$1" == "print" ]]; then
  case "$2" in
    gui/*/com.test.running)
      cat <<'OUT'
	runs = 5
	last exit code = 0
	state = running
OUT
      ;;
    gui/*/com.test.myagent)
      cat <<'OUT'
	runs = 3
	last exit code = 1
	stdout path = /tmp/myagent.log
	stderr path = /tmp/myagent.err
	state = waiting
OUT
      ;;
  esac
  exit 0
fi
exit 1
SCRIPT
  chmod +x "$fake_bin/launchctl"
}

@test "launcher_loaded_names lists names matching prefix" {
  create_fake_launchctl
  run launcher_loaded_names
  assert_success
  assert_line "myagent"
  assert_line "running"
}

@test "launcher_loaded_names excludes non-matching labels" {
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "list" ]]; then
  cat <<'OUT'
PID	Status	Label
-	0	com.apple.something
-	0	com.test.mine
OUT
fi
SCRIPT
  chmod +x "$fake_bin/launchctl"

  run launcher_loaded_names
  assert_success
  assert_line "mine"
  refute_line --partial "apple"
}

@test "launcher_launchd_info returns key=value pairs" {
  create_fake_launchctl
  run launcher_launchd_info "myagent"
  assert_success
  assert_line "runs=3"
  assert_line "last_exit=1"
  assert_line "loaded=true"
  assert_line --partial "stdout_path=/tmp/myagent.log"
}

@test "launcher_launchd_info detects running state" {
  create_fake_launchctl
  run launcher_launchd_info "running"
  assert_success
  assert_line "state=running"
  assert_line "pid=123"
}

@test "launcher_launchd_info normalizes '(never exited)' to '-'" {
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "list" ]]; then
  cat <<'OUT'
PID	Status	Label
-	0	com.test.pending
OUT
  exit 0
fi
if [[ "$1" == "print" ]]; then
  cat <<'OUT'
	runs = 0
	last exit code = (never exited)
	state = waiting
OUT
  exit 0
fi
exit 1
SCRIPT
  chmod +x "$fake_bin/launchctl"

  run launcher_launchd_info "pending"
  assert_success
  assert_line "runs=0"
  assert_line "last_exit=-"
}

@test "launcher_disabled_names lists disabled names matching prefix" {
  cat > "$fake_bin/launchctl" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "print-disabled" ]]; then
  cat <<'OUT'
disabled services = {
		"com.test.myagent" => disabled
		"com.other.thing" => disabled
		"com.test.active" => enabled
	}
OUT
  exit 0
fi
exit 1
SCRIPT
  chmod +x "$fake_bin/launchctl"

  run launcher_disabled_names
  assert_success
  assert_line "myagent"
  refute_line "thing"
  refute_line "active"
}
