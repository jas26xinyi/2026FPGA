#!/usr/bin/env bash
# HDMI 桌面自启动包装脚本：补齐 OpenCV 在 Raspberry Pi OS Wayland/Xwayland 下需要的会话变量。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# OpenCV 通过 Xwayland 创建窗口；已有环境变量时保留原值，否则采用默认桌面会话。
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

cd "${PROJECT_DIR}"
exec "${PROJECT_DIR}/scripts/run.sh"
