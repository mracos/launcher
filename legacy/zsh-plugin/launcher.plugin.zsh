# mracos/launcher - launchd agents for dotfiles
#
# DESCRIPTION:
#   Create, manage, and version-control macOS launch agents.
#   Agents are stored in dotfiles for syncing across machines.
#   Sends macOS notification on failure (no silent failures).
#
# USAGE:
#   launcher ls                           List your agents
#   launcher new [-d dir] <name> <cmd> [interval]  Create an agent
#   launcher rm <name>                    Remove an agent
#   launcher edit <name>                  Edit agent plist in $EDITOR
#   launcher link <name|--all>            Symlink agent to ~/Library/LaunchAgents
#   launcher unlink <name|--all>          Remove symlink from ~/Library/LaunchAgents
#   launcher reload <name>                Reload an agent
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
    ls)     _launcher_ls ;;
    new)    _launcher_new "$@" ;;
    rm)     _launcher_rm "$@" ;;
    edit)   _launcher_edit "$@" ;;
    link)   _launcher_link "$@" ;;
    unlink) _launcher_unlink "$@" ;;
    reload) _launcher_reload "$@" ;;
    load)   _launcher_load "$@" ;;
    unload) _launcher_unload "$@" ;;
    *)
      echo "Usage: launcher <command> [args]"
      echo ""
      echo "Commands:"
      echo "  ls                           List agents"
      echo "  new [-d dir] <name> <cmd> [interval]  Create agent"
      echo "  rm <name>                    Remove agent"
      echo "  edit <name>                  Edit agent plist"
      echo "  link <name|--all>            Symlink to ~/Library/LaunchAgents"
      echo "  unlink <name|--all>          Remove symlink"
      echo "  reload <name>                Reload agent"
      echo "  load <name>                  Load agent"
      echo "  unload <name>                Unload agent"
      return 1
      ;;
  esac
}

_launcher_ls() {
  ls ${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.*.plist 2>/dev/null | while read f; do
    local name=$(basename "$f" .plist | sed "s/${LAUNCHER_PREFIX}\.//")
    local installed_plist="${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${name}.plist"
    local linked=$([[ -L "$installed_plist" ]] && echo "linked" || echo "unlinked")
    local state=$([[ "$linked" == "linked" ]] && launchctl list | grep -q "${LAUNCHER_PREFIX}.${name}" && echo "running" || echo "stopped")
    echo "$name ($linked, $state)"
  done
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
  local installed_plist="${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${name}.plist"

  if [[ ! -f "$installed_plist" ]]; then
    echo "Not linked: $name"
    return 1
  fi

  launchctl unload "$installed_plist" 2>/dev/null
  echo "Unloaded: $name"
}
