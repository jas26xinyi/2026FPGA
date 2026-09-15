from pathlib import Path
import sys
import tempfile
import time
import unittest

from PIL import Image

# 测试启动恢复逻辑，不初始化真实串口、摄像头或 HDMI 窗口。
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from app import load_latest_mosaic  # noqa: E402


class StartupImageTests(unittest.TestCase):
    """验证只恢复最新完整事件，并忽略 .partial 临时目录及不存在的目录。"""

    def test_latest_completed_mosaic_is_restored(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            older = root / "20260908_120000_000000"
            newer = root / "20260908_120001_000000"
            partial = root / ".20260908_120002_000000.partial"
            for path in (older, newer, partial):
                path.mkdir()
            Image.new("RGB", (8, 8), "red").save(older / "mosaic.jpg")
            time.sleep(0.01)
            Image.new("RGB", (8, 8), "blue").save(newer / "mosaic.jpg")
            Image.new("RGB", (8, 8), "green").save(partial / "mosaic.jpg")

            image = load_latest_mosaic({"output_directory": str(root)})

            self.assertIsNotNone(image)
            assert image is not None
            self.assertEqual(image.getpixel((0, 0)), (0, 0, 254))

    def test_missing_capture_directory_returns_none(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "missing"
            self.assertIsNone(load_latest_mosaic({"output_directory": str(missing)}))


if __name__ == "__main__":
    unittest.main()
