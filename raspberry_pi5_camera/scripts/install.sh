#!/usr/bin/env bash
# 首次安装脚本：安装系统版相机/串口/图像依赖，把当前用户加入串口 dialout 组。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sudo apt update
# Picamera2 必须使用 Raspberry Pi OS 仓库版本，才能匹配 libcamera 驱动。
sudo apt install -y python3-picamera2 python3-serial python3-pil python3-opencv
sudo usermod -aG dialout "${USER}"

# 只在配置不存在时复制模板，重复安装不会覆盖用户修改的端口、分辨率等参数。
if [[ ! -f "${PROJECT_DIR}/config.json" ]]; then
    cp "${PROJECT_DIR}/config.example.json" "${PROJECT_DIR}/config.json"
fi

echo
echo "Software installed. Complete these UART steps once:"
echo "  1. sudo raspi-config"
echo "  2. Interface Options -> Serial Port"
echo "  3. Serial login shell: No; serial hardware: Yes"
echo "  4. Add dtoverlay=uart0-pi5 to /boot/firmware/config.txt if absent"
echo "  5. Reboot, then verify /dev/ttyAMA0 exists"
echo
echo "After reboot run: ${PROJECT_DIR}/scripts/run.sh"
