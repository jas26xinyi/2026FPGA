#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/autostart"
DESKTOP_FILE="${AUTOSTART_DIR}/fpga-alarm-camera.desktop"

mkdir -p "${AUTOSTART_DIR}"
printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    'Name=FPGA Alarm Camera' \
    'Comment=Show FPGA alarm captures on the HDMI display' \
    "Exec=${PROJECT_DIR}/scripts/run_gui.sh" \
    'Terminal=false' \
    'X-GNOME-Autostart-enabled=true' \
    >"${DESKTOP_FILE}"

chmod 0644 "${DESKTOP_FILE}"
printf 'Installed %s\n' "${DESKTOP_FILE}"
