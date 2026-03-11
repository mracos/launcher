#!/usr/bin/env bash
# Plist path helpers and configuration for launcher

LAUNCHER_PREFIX="${LAUNCHER_PREFIX:-br.com.mracos}"

if [[ -z "${LAUNCHER_DIR:-}" ]]; then
  if [[ -n "${DOTFILES_REPO:-}" ]]; then
    LAUNCHER_DIR="$DOTFILES_REPO/files/mac/Library/LaunchAgents"
  else
    LAUNCHER_DIR="$HOME/Library/LaunchAgents"
  fi
fi

LAUNCHER_INSTALL_DIR="${LAUNCHER_INSTALL_DIR:-$HOME/Library/LaunchAgents}"

launcher_plist() { echo "${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.${1}.plist"; }
launcher_bin() { echo "${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.${1}"; }
launcher_installed_bin() { echo "${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${1}"; }
