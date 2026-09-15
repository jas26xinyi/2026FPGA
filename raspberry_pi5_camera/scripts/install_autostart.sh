#!/usr/bin/env bash
# 为当前桌面用户创建 XDG autostart 项，登录 Raspberry Pi OS 后自动运行 HDMI 拍照服务。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/autostart"
DESKTOP_FILE="${AUTOSTART_DIR}/fpga-alarm-camera.desktop"

# 生成标准 .desktop 文件；Exec 使用工程绝对路径，工程移动后需重新安装自启动。
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
