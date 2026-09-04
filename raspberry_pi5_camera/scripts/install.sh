#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sudo apt update
sudo apt install -y python3-picamera2 python3-serial python3-pil python3-opencv
sudo usermod -aG dialout "${USER}"

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
