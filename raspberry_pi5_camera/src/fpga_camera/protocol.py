from __future__ import annotations

ALARM = "ALARM"
ACK = b"ACK\n"
DONE = b"DONE\n"
ERROR = b"ERR\n"


def decode_command(raw: bytes) -> str | None:
    """Return a supported ASCII command, ignoring noise and blank lines."""
    try:
        command = raw.decode("ascii", errors="strict").strip().upper()
    except UnicodeDecodeError:
        return None
    return command if command == ALARM else None
