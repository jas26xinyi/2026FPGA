#!/usr/bin/env bash
# 树莓派命令行启动入口：切换到工程目录，使用 config.json 并透传额外命令行参数。
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"
# exec 让 Python 接管进程，Ctrl+C、退出码和系统自启动监督都能正确传递。
exec python3 src/app.py --config config.json "$@"
