# mracos/launcher - launchd agents for dotfiles
#
# DESCRIPTION:
#   Create, manage, and version-control macOS launch agents.
#   Agents are stored in dotfiles for syncing across machines.
#   Sends macOS notification on failure (no silent failures).
#
# USAGE:
#   launcher ls [-v]                      List agents (verbose with -v)
#   launcher info <name>                  Show agent details (runs, exit, logs)
#   launcher logs <name> [-f]             Show agent logs (follow with -f)
#   launcher new [-d dir] <name> <cmd> [interval]  Create an agent
#   launcher rm <name>                    Remove an agent
#   launcher show <name>                  Show agent plist
#   launcher edit <name>                  Edit agent plist in $EDITOR
#   launcher link <name|--all>            Symlink agent to ~/Library/LaunchAgents
#   launcher unlink <name|--all>          Remove symlink from ~/Library/LaunchAgents
#   launcher reload <name>                Reload an agent
#   launcher run <name>                   Run agent command manually
#   launcher load <name>                  Load an agent
#   launcher unload <name>                Unload an agent
#
# EXAMPLES:
#   launcher new env-refresh 'launchctl setenv FOO bar' 3600
#   launcher new backup 'rsync -a ~/docs /backup'
#   launcher ls
#   launcher rm env-refresh
#
# CONFIGURATION:
#   LAUNCHER_PREFIX - Label prefix (default: "br.com.mracos")
#   LAUNCHER_DIR    - Plist directory (default: dotfiles/files/mac/Library/LaunchAgents)
#
# NOTES:
#   - Agents run at login (RunAtLoad) by default
#   - Optional interval (seconds) adds StartInterval for periodic execution
#   - Sends macOS notification on failure (no silent failures)
#
# MISE SHIMS:
#   Launchd runs in a minimal environment. To use mise-managed tools,
#   edit the plist to add EnvironmentVariables:
#
#     PATH=/Users/marcos/.local/share/mise/shims:/opt/homebrew/bin:/usr/bin:/bin
#     HOME=/Users/marcos
#     USER=marcos
#     MISE_DATA_DIR=/Users/marcos/.local/share/mise
#
#   Also requires: mise use -g <tool>@<version>

LAUNCHER_PREFIX="${LAUNCHER_PREFIX:-br.com.mracos}"

# Get dotfiles root - works in both zsh and bash
if [[ -n "${ZSH_VERSION:-}" ]]; then
    _launcher_root="${${0:A}%/shell/*}"
else
    _launcher_root="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../../../.." && pwd)"
fi
LAUNCHER_DIR="${LAUNCHER_DIR:-${_launcher_root}/mac/Library/LaunchAgents}"
unset _launcher_root

LAUNCHER_INSTALL_DIR="${LAUNCHER_INSTALL_DIR:-$HOME/Library/LaunchAgents}"

_launcher_plist() { echo "${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.${1}.plist"; }
_launcher_bin() { echo "${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.${1}"; }
_launcher_installed_bin() { echo "${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${1}"; }

launcher() {
  local cmd="$1"
  shift 2>/dev/null

  case "$cmd" in
    ls)     _launcher_ls "$@" ;;
    info)   _launcher_info "$@" ;;
    logs)   _launcher_logs "$@" ;;
    new)    _launcher_new "$@" ;;
    rm)     _launcher_rm "$@" ;;
    show)   _launcher_show "$@" ;;
    edit)   _launcher_edit "$@" ;;
    link)   _launcher_link "$@" ;;
    unlink) _launcher_unlink "$@" ;;
    run)    _launcher_run "$@" ;;
    reload) _launcher_reload "$@" ;;
    load)   _launcher_load "$@" ;;
    unload) _launcher_unload "$@" ;;
    *)
      echo "Usage: launcher <command> [args]"
      echo ""
      echo "Commands:"
      echo "  ls [-v]                      List agents (verbose with -v)"
      echo "  info <name>                  Show agent details"
      echo "  logs <name> [-f]             Show agent logs (follow with -f)"
      echo "  new [-d dir] <name> <cmd> [interval]  Create agent"
      echo "  rm <name>                    Remove agent"
      echo "  show <name>                  Show agent plist"
      echo "  edit <name>                  Edit agent plist"
      echo "  link <name|--all>            Symlink to ~/Library/LaunchAgents"
      echo "  unlink <name|--all>          Remove symlink"
      echo "  run <name>                   Run agent command manually"
      echo "  reload <name>                Reload agent"
      echo "  load <name>                  Load agent"
      echo "  unload <name>                Unload agent"
      return 1
      ;;
  esac
}

# Get launchd info for an agent (label without prefix)
_launcher_launchd_info() {
  local name="$1"
  local label="${LAUNCHER_PREFIX}.${name}"
  local uid=$(id -u)

  # Get basic info from launchctl list
  local list_line=$(launchctl list 2>/dev/null | grep "	${label}$")
  local pid="-"
  local exit_code="-"

  if [[ -n "$list_line" ]]; then
    pid=$(echo "$list_line" | awk '{print $1}')
    exit_code=$(echo "$list_line" | awk '{print $2}')
  fi

  # Get detailed info from launchctl print
  local print_info=$(launchctl print "gui/${uid}/${label}" 2>/dev/null)
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
    local plist="$(_launcher_plist "$name")"
    if [[ -f "$plist" ]]; then
      stdout_path=$(/usr/libexec/PlistBuddy -c "Print :StandardOutPath" "$plist" 2>/dev/null || echo "")
      stderr_path=$(/usr/libexec/PlistBuddy -c "Print :StandardErrorPath" "$plist" 2>/dev/null || echo "")
    fi
  fi

  # Output as key=value pairs
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

_launcher_loaded_names() {
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

_launcher_ls() {
  local verbose=false
  [[ "${1:-}" == "-v" ]] && verbose=true

  typeset -A loaded_names
  typeset -A plist_names
  local loaded_name
  while IFS= read -r loaded_name; do
    [[ -n "$loaded_name" ]] && loaded_names[$loaded_name]=1
  done < <(_launcher_loaded_names)

  local plists=(${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.*.plist(N))
  if [[ ${#plists[@]} -eq 0 && ${#loaded_names[@]} -eq 0 ]]; then
    echo "No agents found in ${LAUNCHER_DIR}"
    return 0
  fi

  if $verbose; then
    printf "%-18s %-8s %6s %6s %5s  %s\n" "NAME" "STATUS" "PID" "RUNS" "EXIT" "LAST LOG"
    printf "%-18s %-8s %6s %6s %5s  %s\n" "----" "------" "---" "----" "----" "--------"
  fi

  for f in "${plists[@]}"; do
    local name=$(basename "$f" .plist | sed "s/${LAUNCHER_PREFIX}\.//")
    plist_names[$name]=1
    local installed_plist="${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${name}.plist"
    local linked=$([[ -L "$installed_plist" ]] && echo true || echo false)
    local loaded=false
    [[ -n "${loaded_names[$name]:-}" ]] && loaded=true

    if ! $linked && ! $loaded; then
      if $verbose; then
        printf "%-18s %-8s %6s %6s %5s  %s\n" "$name" "unloaded" "-" "-" "-" "unlinked"
      else
        echo "◌ $name (unlinked, unloaded)"
      fi
      continue
    fi

    # Parse launchd info
    local info=$(_launcher_launchd_info "$name")
    local pid=$(echo "$info" | grep "^pid=" | cut -d= -f2)
    local runs=$(echo "$info" | grep "^runs=" | cut -d= -f2)
    local last_exit=$(echo "$info" | grep "^last_exit=" | cut -d= -f2)
    local stdout_path=$(echo "$info" | grep "^stdout_path=" | cut -d= -f2-)
    local state=$(echo "$info" | grep "^state=" | cut -d= -f2)
    local loaded_from_info=$(echo "$info" | grep "^loaded=" | cut -d= -f2)
    [[ "$loaded_from_info" == "true" ]] && loaded=true
    [[ "$loaded" != "true" ]] && state="unloaded"

    if $verbose; then
      # Get last log line
      local last_log="-"
      if [[ -n "$stdout_path" && -f "$stdout_path" ]]; then
        last_log=$(tail -1 "$stdout_path" 2>/dev/null | cut -c1-50)
        [[ ${#last_log} -eq 50 ]] && last_log="${last_log}..."
      fi
      [[ -z "$last_log" ]] && last_log="-"

      printf "%-18s %-8s %6s %6s %5s  %s\n" \
        "$name" "$state" "$pid" "${runs:-0}" "${last_exit:--}" "$last_log"
    else
      local status_icon="◌"
      [[ "$state" == "running" ]] && status_icon="●"
      [[ "$state" == "stopped" ]] && status_icon="○"
      [[ "$last_exit" != "0" && "$last_exit" != "-" ]] && status_icon="✗"
      if [[ "$linked" == "true" ]]; then
        printf "%s %s (%s, %s runs)\n" "$status_icon" "$name" "$state" "${runs:-0}"
      else
        printf "⚠ %s (%s, unlinked)\n" "$name" "$state"
      fi
    fi
  done

  typeset -A seen_orphans
  local orphan_name
  while IFS= read -r orphan_name; do
    [[ -z "$orphan_name" ]] && continue
    [[ -n "${seen_orphans[$orphan_name]:-}" ]] && continue
    seen_orphans[$orphan_name]=1
    [[ -n "${plist_names[$orphan_name]:-}" ]] && continue

    local info=$(_launcher_launchd_info "$orphan_name")
    local pid=$(echo "$info" | grep "^pid=" | cut -d= -f2)
    local runs=$(echo "$info" | grep "^runs=" | cut -d= -f2)
    local last_exit=$(echo "$info" | grep "^last_exit=" | cut -d= -f2)
    local state=$(echo "$info" | grep "^state=" | cut -d= -f2)

    if $verbose; then
      printf "%-18s %-8s %6s %6s %5s  %s\n" \
        "$orphan_name" "$state" "$pid" "${runs:-0}" "${last_exit:--}" "loaded, missing source plist"
    else
      printf "⚠ %s (loaded/%s, missing source plist)\n" "$orphan_name" "$state"
    fi
  done < <(_launcher_loaded_names)
}

_launcher_info() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Usage: launcher info <name>"
    return 1
  fi

  local plist="$(_launcher_plist "$name")"
  if [[ ! -f "$plist" ]]; then
    echo "Not found: $name"
    return 1
  fi

  local installed_plist="${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${name}.plist"
  local linked=$([[ -L "$installed_plist" ]] && echo "yes" || echo "no")

  echo "Agent: $name"
  echo "Label: ${LAUNCHER_PREFIX}.${name}"
  echo "Plist: $plist"
  echo "Linked: $linked"
  echo ""

  if [[ "$linked" == "no" ]]; then
    echo "Run 'launcher link $name' to enable"
    return 0
  fi

  local info=$(_launcher_launchd_info "$name")
  local pid=$(echo "$info" | grep "^pid=" | cut -d= -f2)
  local state=$(echo "$info" | grep "^state=" | cut -d= -f2)
  local runs=$(echo "$info" | grep "^runs=" | cut -d= -f2)
  local last_exit=$(echo "$info" | grep "^last_exit=" | cut -d= -f2)
  local interval=$(echo "$info" | grep "^interval=" | cut -d= -f2)
  local stdout_path=$(echo "$info" | grep "^stdout_path=" | cut -d= -f2-)
  local stderr_path=$(echo "$info" | grep "^stderr_path=" | cut -d= -f2-)

  echo "Status: $state"
  [[ "$pid" != "-" ]] && echo "PID: $pid"
  echo "Runs: ${runs:-0}"
  echo "Last exit: ${last_exit:--}"
  [[ "$interval" != "-" ]] && echo "Interval: $interval"
  echo ""

  if [[ -n "$stdout_path" ]]; then
    echo "Stdout: $stdout_path"
  fi
  if [[ -n "$stderr_path" && "$stderr_path" != "$stdout_path" ]]; then
    echo "Stderr: $stderr_path"
  fi

  # Show last few log lines
  if [[ -n "$stdout_path" && -f "$stdout_path" ]]; then
    echo ""
    echo "Last 5 log lines:"
    tail -5 "$stdout_path" 2>/dev/null | sed 's/^/  /'
  fi
}

_launcher_logs() {
  local name="$1"
  local follow=false
  shift 2>/dev/null || true
  [[ "${1:-}" == "-f" ]] && follow=true

  if [[ -z "$name" ]]; then
    echo "Usage: launcher logs <name> [-f]"
    return 1
  fi

  local plist="$(_launcher_plist "$name")"
  if [[ ! -f "$plist" ]]; then
    echo "Not found: $name"
    return 1
  fi

  # Get log path from plist or launchd
  local info=$(_launcher_launchd_info "$name")
  local stdout_path=$(echo "$info" | grep "^stdout_path=" | cut -d= -f2-)

  if [[ -z "$stdout_path" ]]; then
    # Fallback to plist
    stdout_path=$(/usr/libexec/PlistBuddy -c "Print :StandardOutPath" "$plist" 2>/dev/null || echo "")
  fi

  if [[ -z "$stdout_path" ]]; then
    echo "No log path configured for $name"
    echo "Add StandardOutPath/StandardErrorPath to the plist"
    return 1
  fi

  if [[ ! -f "$stdout_path" ]]; then
    echo "Log file not found: $stdout_path"
    return 1
  fi

  if $follow; then
    tail -f "$stdout_path"
  else
    tail -20 "$stdout_path"
  fi
}

_launcher_new() {
  local dir="$LAUNCHER_DIR"

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--dir)
        dir="$2"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  local name="$1"
  local cmd="$2"
  local interval="$3"

  if [[ -z "$name" || -z "$cmd" ]]; then
    echo "Usage: launcher new [-d|--dir <path>] <name> <command> [interval_seconds]"
    return 1
  fi

  local bin="${dir}/${LAUNCHER_PREFIX}.${name}"
  local plist="${dir}/${LAUNCHER_PREFIX}.${name}.plist"
  local installed_bin="$(_launcher_installed_bin "$name")"
  mkdir -p "$(dirname "$plist")"

  cat > "$bin" << SCRIPT
#!/bin/bash
# Launcher agent: ${name}

if ! ${cmd} 2>&1; then
  osascript -e 'display notification "${name} failed to start" with title "Launcher Error" sound name "Basso"'
  exit 1
fi
SCRIPT
  chmod +x "$bin"

  cat > "$plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LAUNCHER_PREFIX}.${name}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${installed_bin}</string>
  </array>
  <key>RunAtLoad</key><true/>
EOF

  if [[ -n "$interval" ]]; then
    echo "  <key>StartInterval</key><integer>${interval}</integer>" >> "$plist"
  fi

  printf '%s\n%s\n' "</dict>" "</plist>" >> "$plist"

  echo "Created: $name"
  echo "Run 'launcher link $name' then 'launcher load $name'"
}

_launcher_rm() {
  local name="$1"
  local bin="$(_launcher_bin "$name")"
  local plist="$(_launcher_plist "$name")"

  if [[ ! -f "$plist" ]]; then
    echo "Not found: $name"
    return 1
  fi

  launchctl unload "$plist" 2>/dev/null
  rm -f "$plist" "$bin"
  echo "Removed: $name"
}

_launcher_show() {
  local name="$1"

  if [[ -z "$name" ]]; then
    echo "Usage: launcher show <name>"
    return 1
  fi

  local plist="$(_launcher_plist "$name")"
  if [[ ! -f "$plist" ]]; then
    echo "Not found: $name"
    return 1
  fi

  cat "$plist"
}

_launcher_edit() {
  local name="$1"
  local plist="$(_launcher_plist "$name")"

  if [[ ! -f "$plist" ]]; then
    echo "Not found: $name"
    return 1
  fi

  ${EDITOR:-vim} "$plist"
}

_launcher_link() {
  local name="$1"

  if [[ "$name" == "--all" ]]; then
    ls ${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.*.plist 2>/dev/null | while read f; do
      local n=$(basename "$f" .plist | sed "s/${LAUNCHER_PREFIX}\.//")
      _launcher_link "$n"
    done
    return
  fi

  if [[ -z "$name" ]]; then
    echo "Usage: launcher link <name|--all>"
    return 1
  fi

  local bin="$(_launcher_bin "$name")"
  local plist="$(_launcher_plist "$name")"
  local installed_bin="$(_launcher_installed_bin "$name")"
  local installed_plist="${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${name}.plist"

  if [[ ! -f "$plist" ]]; then
    echo "Not found: $name"
    return 1
  fi

  # Skip if already linked correctly
  if [[ -L "$installed_plist" && "$(readlink "$installed_plist")" == "$plist" ]]; then
    return 0
  fi

  mkdir -p "$LAUNCHER_INSTALL_DIR"
  ln -sf "$bin" "$installed_bin"
  ln -sf "$plist" "$installed_plist"
  echo "Linked: $name"
}

_launcher_unlink() {
  local name="$1"

  if [[ "$name" == "--all" ]]; then
    ls ${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.*.plist 2>/dev/null | while read f; do
      local n=$(basename "$f" .plist | sed "s/${LAUNCHER_PREFIX}\.//")
      _launcher_unlink "$n"
    done
    return
  fi

  if [[ -z "$name" ]]; then
    echo "Usage: launcher unlink <name|--all>"
    return 1
  fi

  local installed_bin="$(_launcher_installed_bin "$name")"
  local installed_plist="${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${name}.plist"

  launchctl unload "$installed_plist" 2>/dev/null
  rm -f "$installed_bin" "$installed_plist"
  echo "Unlinked: $name"
}

_launcher_run() {
  local name="$1"

  if [[ -z "$name" ]]; then
    echo "Usage: launcher run <name>"
    return 1
  fi

  local bin="$(_launcher_bin "$name")"
  if [[ ! -f "$bin" ]]; then
    echo "Not found: $name"
    return 1
  fi

  "$bin"
}

_launcher_reload() {
  local name="$1"
  local installed_plist="${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${name}.plist"

  if [[ ! -f "$installed_plist" ]]; then
    echo "Not linked: $name (run 'launcher link $name' first)"
    return 1
  fi

  launchctl unload "$installed_plist" 2>/dev/null
  launchctl load "$installed_plist"
  echo "Reloaded: $name"
}

_launcher_load() {
  local name="$1"
  local installed_plist="${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${name}.plist"

  if [[ ! -f "$installed_plist" ]]; then
    echo "Not linked: $name (run 'launcher link $name' first)"
    return 1
  fi

  launchctl load "$installed_plist" 2>/dev/null
  echo "Loaded: $name"
}

_launcher_unload() {
  local name="$1"
  local label="${LAUNCHER_PREFIX}.${name}"
  local uid=$(id -u)
  local installed_plist="${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${name}.plist"

  if [[ -f "$installed_plist" ]]; then
    launchctl unload "$installed_plist" 2>/dev/null
    echo "Unloaded: $name"
    return 0
  fi

  if _launcher_loaded_names | grep -Fxq "$name"; then
    if launchctl bootout "gui/${uid}/${label}" 2>/dev/null || launchctl remove "$label" 2>/dev/null; then
      echo "Unloaded: $name"
      return 0
    fi

    echo "Failed to unload loaded job: $name"
    return 1
  fi

  echo "Not linked: $name"
  return 1
}
