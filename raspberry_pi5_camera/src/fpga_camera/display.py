from __future__ import annotations

from PIL import Image


class HdmiDisplay:
    """用 OpenCV 窗口把 PIL 图像显示到树莓派 HDMI 桌面。"""

    def __init__(self, fullscreen: bool = True):
        import cv2

        self._cv2 = cv2
        self._name = "FPGA Alarm Camera"
        cv2.namedWindow(self._name, cv2.WINDOW_NORMAL)
        # fullscreen=True 用于课程演示；--windowed 可覆盖为普通窗口便于调试。
        if fullscreen:
            cv2.setWindowProperty(self._name, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)

    def show(self, image: Image.Image) -> None:
        import numpy as np

        # PIL 使用 RGB，OpenCV imshow 使用 BGR，显示前必须交换通道。
        rgb = np.asarray(image.convert("RGB"))
        self._cv2.imshow(self._name, self._cv2.cvtColor(rgb, self._cv2.COLOR_RGB2BGR))
        self._cv2.waitKey(1)

    def poll_quit(self) -> bool:
        key = self._cv2.waitKey(1) & 0xFF
        # Esc 或 q 安全退出主循环。
        return key in (27, ord("q"))

    def close(self) -> None:
        self._cv2.destroyAllWindows()


class HeadlessDisplay:
    """无桌面/自动化测试时的空显示器，实现与 HdmiDisplay 相同接口但不打开窗口。"""

    def show(self, image: Image.Image) -> None:
        return None

    def poll_quit(self) -> bool:
        return False

    def close(self) -> None:
        return None
