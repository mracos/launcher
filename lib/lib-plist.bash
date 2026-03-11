#!/usr/bin/env bash
# Plist path helpers and configuration for launcher

LAUNCHER_PREFIX="${LAUNCHER_PREFIX:-br.com.mracos}"

LAUNCHER_DIR="${LAUNCHER_DIR:-$HOME/Library/LaunchAgents}"

LAUNCHER_INSTALL_DIR="${LAUNCHER_INSTALL_DIR:-$HOME/Library/LaunchAgents}"

launcher_plist() { echo "${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.${1}.plist"; }
launcher_bin() { echo "${LAUNCHER_DIR}/${LAUNCHER_PREFIX}.${1}"; }
launcher_installed_bin() { echo "${LAUNCHER_INSTALL_DIR}/${LAUNCHER_PREFIX}.${1}"; }
