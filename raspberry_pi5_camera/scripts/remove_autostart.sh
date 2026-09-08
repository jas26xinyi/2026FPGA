#!/usr/bin/env bash
set -euo pipefail

DESKTOP_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/autostart/fpga-alarm-camera.desktop"
rm -f -- "${DESKTOP_FILE}"
printf 'Removed %s\n' "${DESKTOP_FILE}"
