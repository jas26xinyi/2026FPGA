from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from fpga_camera.protocol import ALARM, decode_command  # noqa: E402


class ProtocolTests(unittest.TestCase):
    def test_alarm_line(self) -> None:
        self.assertEqual(decode_command(b"ALARM\n"), ALARM)
        self.assertEqual(decode_command(b" alarm\r\n"), ALARM)

    def test_noise_is_ignored(self) -> None:
        self.assertIsNone(decode_command(b""))
        self.assertIsNone(decode_command(b"DONE\n"))
        self.assertIsNone(decode_command(b"\xff\xfe"))


if __name__ == "__main__":
    unittest.main()
