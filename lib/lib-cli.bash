#!/usr/bin/env bash
# Shared CLI helpers for notes command dispatchers

# Return success if token is a standard help flag.
notes_cli_is_help() {
  local token="${1:-}"
  [[ "$token" == "-h" || "$token" == "--help" || "$token" == "help" ]]
}

# Print a comment block from a script file and exit.
# Usage: notes_cli_usage_range <script-file> <start-line> <end-line> [exit-code]
notes_cli_usage_range() {
  local file="$1"
  local start_line="$2"
  local end_line="$3"
  local code="${4:-1}"

  awk -v start="$start_line" -v end="$end_line" '
    NR >= start && NR <= end {
      sub(/^# /, "")
      sub(/^#/, "")
      print
    }
  ' "$file"
  exit "$code"
}

# Print initial comment block until first blank comment separator and exit.
# Usage: notes_cli_usage_until_blank <script-file> [exit-code]
notes_cli_usage_until_blank() {
  local file="$1"
  local code="${2:-1}"

  awk 'NR>1 && /^$/{exit} NR>1{sub(/^# /, ""); sub(/^#/, ""); print}' "$file"
  exit "$code"
}

# --- Auto-help (source-time) ---
# Capture caller and define usage(). Pass --auto to opt into help checking.
#
#   source "$SCRIPT_DIR/lib-cli.bash" --auto "$@"  # usage() + auto --help
#   source "$SCRIPT_DIR/lib-cli.bash"               # usage() only
#
# Scripts can override usage() after sourcing if they need custom behavior.
_NOTES_CLI_SCRIPT="${BASH_SOURCE[1]}"

usage() {
  awk 'NR>1 && /^$/{exit} NR>1{sub(/^# /, ""); sub(/^#/, ""); print}' "$_NOTES_CLI_SCRIPT"
  exit "${1:-1}"
}

if [[ "${1:-}" == "--auto" ]]; then
  shift
  notes_cli_is_help "${1:-}" && usage 0
fi

# Resolve script directory, following symlinks.
# Usage: dir=$(notes_cli_resolve_script_dir)
notes_cli_resolve_script_dir() {
  local source="${1:-${BASH_SOURCE[1]}}"
  while [[ -L "$source" ]]; do
    local dir
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    source="$(readlink "$source")"
    [[ "$source" != /* ]] && source="$dir/$source"
  done
  cd -P "$(dirname "$source")" && pwd
}

# Exec subcommand script if it exists/executable.
# Callers pass raw "$@" (unshifted) - the function safely consumes the cmd.
# Usage: notes_cli_exec_subcommand <base-dir> <prefix> <cmd> "$@"
# Example: notes_cli_exec_subcommand "$SCRIPT_DIR" "notes-daily-" "$cmd" "$@"
notes_cli_exec_subcommand() {
  local base_dir="$1"
  local prefix="$2"
  local cmd="$3"
  shift 3
  [[ $# -gt 0 ]] && shift

  local subcmd="$base_dir/${prefix}${cmd}"
  if [[ -x "$subcmd" ]]; then
    exec "$subcmd" "$@"
  fi
  return 1
}

# Return success when arg matches YYYY-MM-DD.
notes_cli_is_date() {
  local value="${1:-}"
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}
