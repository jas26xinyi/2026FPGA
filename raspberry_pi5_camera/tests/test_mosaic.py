from pathlib import Path
import sys
import unittest

from PIL import Image

# 测试直接引用 src 中当前代码，避免误测到系统里旧版本的软件包。
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from fpga_camera.mosaic import build_mosaic  # noqa: E402


class MosaicTests(unittest.TestCase):
    """验证四帧顺序、输出尺寸和必须恰好四帧的输入约束。"""

    def test_quadrants_keep_frame_order(self) -> None:
        colours = ((255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0))
        frames = [Image.new("RGB", (32, 24), colour) for colour in colours]
        mosaic = build_mosaic(frames, (640, 480))
        self.assertEqual(mosaic.size, (640, 480))
        self.assertEqual(mosaic.getpixel((100, 100)), colours[0])
        self.assertEqual(mosaic.getpixel((500, 100)), colours[1])
        self.assertEqual(mosaic.getpixel((100, 380)), colours[2])
        self.assertEqual(mosaic.getpixel((500, 380)), colours[3])

    def test_requires_exactly_four_frames(self) -> None:
        with self.assertRaises(ValueError):
            build_mosaic([Image.new("RGB", (1, 1))] * 3)


if __name__ == "__main__":
    unittest.main()
