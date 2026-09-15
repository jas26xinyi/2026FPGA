from __future__ import annotations

# 串口文本协议（ASCII、以换行结尾）：FPGA→Pi 为 ALARM，Pi→FPGA 关键确认为 ACK。
# DONE/ERR 表示树莓派拍照最终结果；当前 FPGA 不解析它们，不影响请求确认机制。
ALARM = "ALARM"
ACK = b"ACK\n"
DONE = b"DONE\n"
ERROR = b"ERR\n"


def decode_command(raw: bytes) -> str | None:
    """严格按 ASCII 解码，仅接受忽略大小写和首尾空白后的 ALARM，其余噪声返回 None。"""
    try:
        command = raw.decode("ascii", errors="strict").strip().upper()
    except UnicodeDecodeError:
        return None
    return command if command == ALARM else None
