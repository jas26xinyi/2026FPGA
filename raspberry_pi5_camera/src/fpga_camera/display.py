from __future__ import annotations

from PIL import Image


class HdmiDisplay:
    def __init__(self, fullscreen: bool = True):
        import cv2

        self._cv2 = cv2
        self._name = "FPGA Alarm Camera"
        cv2.namedWindow(self._name, cv2.WINDOW_NORMAL)
        if fullscreen:
            cv2.setWindowProperty(self._name, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)

    def show(self, image: Image.Image) -> None:
        import numpy as np

        rgb = np.asarray(image.convert("RGB"))
        self._cv2.imshow(self._name, self._cv2.cvtColor(rgb, self._cv2.COLOR_RGB2BGR))
        self._cv2.waitKey(1)

    def poll_quit(self) -> bool:
        key = self._cv2.waitKey(1) & 0xFF
        return key in (27, ord("q"))

    def close(self) -> None:
        self._cv2.destroyAllWindows()


class HeadlessDisplay:
    def show(self, image: Image.Image) -> None:
        return None

    def poll_quit(self) -> bool:
        return False

    def close(self) -> None:
        return None
