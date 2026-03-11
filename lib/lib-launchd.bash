#!/usr/bin/env bash
# Launchd query helpers for launcher

launcher_loaded_names() {
  local label
  while IFS= read -r label; do
    [[ -z "$label" ]] && continue
    label="${label%\"}"
    label="${label#\"}"
    [[ "$label" == "Label" ]] && continue
    [[ "$label" == ${LAUNCHER_PREFIX}.* ]] || continue
    local name="${label#${LAUNCHER_PREFIX}.}"
    name="${name%\"}"
    name="${name#\"}"
    [[ -n "$name" ]] && echo "$name"
  done < <(launchctl list 2>/dev/null | awk '{print $3}')
}

launcher_launchd_info() {
  local name="$1"
  local label="${LAUNCHER_PREFIX}.${name}"
  local uid
  uid=$(id -u)

  local list_line
  list_line=$(launchctl list 2>/dev/null | grep "	${label}$")
  local pid="-"
  local exit_code="-"

  if [[ -n "$list_line" ]]; then
    pid=$(echo "$list_line" | awk '{print $1}')
    exit_code=$(echo "$list_line" | awk '{print $2}')
  fi

  local print_info
  print_info=$(launchctl print "gui/${uid}/${label}" 2>/dev/null)
  local runs="-"
  local last_exit="-"
  local stdout_path=""
  local stderr_path=""
  local interval="-"
  local state="stopped"
  local loaded="false"

  if [[ -n "$print_info" ]]; then
    loaded="true"
    runs=$(echo "$print_info" | grep "^	runs = " | awk '{print $3}')
    last_exit=$(echo "$print_info" | grep "^	last exit code = " | awk '{print $5}')
    stdout_path=$(echo "$print_info" | grep "^	stdout path = " | sed 's/.*stdout path = //')
    stderr_path=$(echo "$print_info" | grep "^	stderr path = " | sed 's/.*stderr path = //')
    interval=$(echo "$print_info" | grep "^	run interval = " | sed 's/.*run interval = //' | sed 's/ seconds/s/')
    if echo "$print_info" | grep -q "state = running"; then
      state="running"
    fi
  elif [[ -n "$list_line" ]]; then
    loaded="true"
  fi

  # Fallback to plist for log paths if not running
  if [[ -z "$stdout_path" ]]; then
    local plist
    plist="$(launcher_plist "$name")"
    if [[ -f "$plist" ]]; then
      stdout_path=$(/usr/libexec/PlistBuddy -c "Print :StandardOutPath" "$plist" 2>/dev/null || echo "")
      stderr_path=$(/usr/libexec/PlistBuddy -c "Print :StandardErrorPath" "$plist" 2>/dev/null || echo "")
    fi
  fi

  echo "pid=${pid}"
  echo "exit_code=${exit_code}"
  echo "runs=${runs:-0}"
  echo "last_exit=${last_exit:--}"
  echo "stdout_path=${stdout_path}"
  echo "stderr_path=${stderr_path}"
  echo "interval=${interval}"
  echo "state=${state}"
  echo "loaded=${loaded}"
}
