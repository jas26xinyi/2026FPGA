from __future__ import annotations

import time

from PIL import Image, ImageDraw


class RaspberryPiCamera:
    def __init__(self, size: tuple[int, int], warmup_seconds: float = 1.0):
        from picamera2 import Picamera2

        self._camera = Picamera2()
        configuration = self._camera.create_preview_configuration(
            main={"format": "RGB888", "size": size}, buffer_count=4
        )
        self._camera.configure(configuration)
        self._camera.start()
        time.sleep(warmup_seconds)

    def capture(self) -> Image.Image:
        array = self._camera.capture_array("main")
        return Image.fromarray(array).convert("RGB")

    def close(self) -> None:
        self._camera.stop()
        self._camera.close()


class MockCamera:
    def __init__(self, size: tuple[int, int]):
        self._size = size
        self._index = 0

    def capture(self) -> Image.Image:
        colours = ("#1abc9c", "#3498db", "#9b59b6", "#e67e22")
        image = Image.new("RGB", self._size, colours[self._index % len(colours)])
        draw = ImageDraw.Draw(image)
        draw.text((24, 24), f"MOCK FRAME {self._index + 1}", fill="white")
        self._index += 1
        return image

    def close(self) -> None:
        return None
