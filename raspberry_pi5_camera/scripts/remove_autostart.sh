#!/usr/bin/env bash
# 删除当前用户的自启动条目，不删除工程、配置或已经拍摄的照片。
set -euo pipefail

DESKTOP_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/autostart/fpga-alarm-camera.desktop"
rm -f -- "${DESKTOP_FILE}"
printf 'Removed %s\n' "${DESKTOP_FILE}"
