from __future__ import annotations

import argparse
import json
import logging
import shutil
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from fpga_camera.camera import MockCamera, RaspberryPiCamera
from fpga_camera.display import HdmiDisplay, HeadlessDisplay
from fpga_camera.mosaic import build_mosaic, error_screen, test_pattern
from fpga_camera.protocol import ACK, ALARM, DONE, ERROR, decode_command

LOG = logging.getLogger("fpga-camera")
DEFAULTS: dict[str, Any] = {
    "serial_port": "/dev/ttyAMA0",
    "baud_rate": 115200,
    "capture_width": 640,
    "capture_height": 480,
    "mosaic_width": 640,
    "mosaic_height": 480,
    "capture_count": 4,
    "capture_interval_seconds": 0.10,
    "capture_timeout_seconds": 2.0,
    "output_directory": "captures",
    "fullscreen": True,
}


def load_config(path: Path) -> dict[str, Any]:
    config = dict(DEFAULTS)
    if path.exists():
        with path.open("r", encoding="utf-8") as stream:
            config.update(json.load(stream))
    if int(config["capture_count"]) != 4:
        raise ValueError("capture_count must remain 4 for the four-quadrant requirement")
    return config


def capture_incident(camera: Any, config: dict[str, Any]) -> tuple[Path, Any]:
    root = Path(config["output_directory"]).expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    partial = root / f".{stamp}.partial"
    final = root / stamp
    partial.mkdir()
    frames = []
    started = time.monotonic()
    timeout = float(config["capture_timeout_seconds"])
    try:
        for index in range(4):
            frame = camera.capture().convert("RGB")
            frames.append(frame)
            frame.save(partial / f"frame_{index + 1}.jpg", quality=95)
            if time.monotonic() - started > timeout:
                raise TimeoutError(f"four-frame capture exceeded {timeout:.1f} seconds")
            if index != 3:
                time.sleep(float(config["capture_interval_seconds"]))
        mosaic = build_mosaic(
            frames,
            (int(config["mosaic_width"]), int(config["mosaic_height"])),
        )
        mosaic.save(partial / "mosaic.jpg", quality=95)
        partial.rename(final)
        return final, mosaic
    except Exception:
        shutil.rmtree(partial, ignore_errors=True)
        raise


def make_camera(config: dict[str, Any], mock: bool) -> Any:
    size = (int(config["capture_width"]), int(config["capture_height"]))
    return MockCamera(size) if mock else RaspberryPiCamera(size)


def run_capture(camera: Any, display: Any, config: dict[str, Any]) -> bool:
    try:
        incident, mosaic = capture_incident(camera, config)
        display.show(mosaic)
        LOG.info("four frames committed to %s", incident)
        return True
    except Exception as exc:
        LOG.exception("capture failed")
        display.show(
            error_screen(
                str(exc),
                (int(config["mosaic_width"]), int(config["mosaic_height"])),
            )
        )
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="FPGA alarm camera bridge for Raspberry Pi 5")
    parser.add_argument("--config", type=Path, default=Path("config.json"))
    parser.add_argument("--mock-camera", action="store_true")
    parser.add_argument("--trigger-on-start", action="store_true")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--windowed", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    config = load_config(args.config)
    display = HeadlessDisplay() if args.headless else HdmiDisplay(
        fullscreen=bool(config["fullscreen"]) and not args.windowed
    )
    display.show(test_pattern((int(config["mosaic_width"]), int(config["mosaic_height"]))))

    camera = None
    try:
        if args.trigger_on_start:
            camera = make_camera(config, args.mock_camera)
            return 0 if run_capture(camera, display, config) else 1

        import serial

        with serial.Serial(
            port=str(config["serial_port"]),
            baudrate=int(config["baud_rate"]),
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.10,
        ) as uart:
            LOG.info("waiting for FPGA on %s", config["serial_port"])
            while not display.poll_quit():
                command = decode_command(uart.readline())
                if command != ALARM:
                    continue
                uart.write(ACK)
                uart.flush()
                LOG.info("alarm acknowledged; capturing four frames")
                if camera is None:
                    try:
                        camera = make_camera(config, args.mock_camera)
                    except Exception as exc:
                        LOG.exception("camera initialisation failed")
                        display.show(error_screen(str(exc)))
                        uart.write(ERROR)
                        uart.flush()
                        continue
                uart.write(DONE if run_capture(camera, display, config) else ERROR)
                uart.flush()
    except KeyboardInterrupt:
        return 0
    finally:
        if camera is not None:
            camera.close()
        display.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
