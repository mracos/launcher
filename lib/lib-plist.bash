#!/usr/bin/env bash
# Plist path helpers and configuration for launcher
#
# launcher operates on a single dir (ADR launcher/0002). The default is the
# dir launchd auto-loads at login; plists elsewhere don't persist across
# logins, so overriding LAUNCHER_DIR means owning persistence yourself.

LAUNCHER_PREFIX="${LAUNCHER_PREFIX:-local.launcher}"

LAUNCHER_DIR="${LAUNCHER_DIR:-$HOME/Library/LaunchAgents}"

launcher_plist() { echo "${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.${1}.plist"; }
launcher_bin() { echo "${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.${1}"; }
