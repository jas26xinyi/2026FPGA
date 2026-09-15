from __future__ import annotations

# 树莓派 5 报警拍照服务主程序：监听 FPGA UART 的 ALARM\n，回复 ACK\n 后连拍四张、
# 合成四宫格并在 HDMI 显示。完成后回传 DONE\n，异常则回传 ERR\n。

import argparse
import json
import logging
import shutil
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from PIL import Image

from fpga_camera.camera import MockCamera, RaspberryPiCamera
from fpga_camera.display import HdmiDisplay, HeadlessDisplay
from fpga_camera.mosaic import build_mosaic, error_screen, test_pattern
from fpga_camera.protocol import ACK, ALARM, DONE, ERROR, decode_command

LOG = logging.getLogger("fpga-camera")
# config.json 中同名字段会覆盖这些默认值；两端 baud_rate 必须与 FPGA 参数一致。
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
    """载入 JSON 配置并校验课程要求固定为四张照片。"""
    config = dict(DEFAULTS)
    if path.exists():
        with path.open("r", encoding="utf-8") as stream:
            config.update(json.load(stream))
    if int(config["capture_count"]) != 4:
        raise ValueError("capture_count must remain 4 for the four-quadrant requirement")
    return config


def capture_incident(camera: Any, config: dict[str, Any]) -> tuple[Path, Any]:
    """拍摄四帧并原子提交事件目录，返回最终目录和四宫格图像。"""
    root = Path(config["output_directory"]).expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    # 先写隐藏的 .partial 目录；全部成功后 rename，避免掉电留下“看似完成”的半套照片。
    partial = root / f".{stamp}.partial"
    final = root / stamp
    partial.mkdir()
    frames = []
    started = time.monotonic()
    timeout = float(config["capture_timeout_seconds"])
    try:
        # 四帧依次保存为 frame_1.jpg~frame_4.jpg，并受总拍摄超时约束。
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
        # 同一文件系统内重命名是原子切换：其他逻辑只会看到完整事件目录。
        partial.rename(final)
        return final, mosaic
    except Exception:
        # 任意一帧、拼图或保存失败时删除临时目录，再把异常交给上层显示/回传。
        shutil.rmtree(partial, ignore_errors=True)
        raise


def make_camera(config: dict[str, Any], mock: bool) -> Any:
    """实机创建 Picamera2；--mock-camera 时创建不依赖摄像头的彩色测试帧源。"""
    size = (int(config["capture_width"]), int(config["capture_height"]))
    return MockCamera(size) if mock else RaspberryPiCamera(size)


def load_latest_mosaic(config: dict[str, Any]) -> Image.Image | None:
    """启动时恢复最新的完整四宫格；名称以点开头的 partial 目录会被忽略。"""
    root = Path(config["output_directory"]).expanduser().resolve()
    if not root.is_dir():
        return None
    candidates = [
        incident / "mosaic.jpg"
        for incident in root.iterdir()
        if incident.is_dir() and not incident.name.startswith(".")
    ]
    candidates = [path for path in candidates if path.is_file()]
    if not candidates:
        return None
    newest = max(candidates, key=lambda path: path.stat().st_mtime_ns)
    try:
        with Image.open(newest) as image:
            mosaic = image.convert("RGB")
            mosaic.load()
        LOG.info("restored latest mosaic from %s", newest)
        return mosaic
    except Exception:
        LOG.exception("could not restore latest mosaic from %s", newest)
        return None


def run_capture(camera: Any, display: Any, config: dict[str, Any]) -> bool:
    """执行一次拍照事务并更新屏幕；返回值决定串口发送 DONE 还是 ERR。"""
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
    """解析命令行、初始化显示，并进入 UART 命令循环。"""
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
    # 优先恢复上一次事件图片；首次运行没有历史图片时显示彩条 READY 测试图。
    startup_image = load_latest_mosaic(config)
    if startup_image is None:
        startup_image = test_pattern(
            (int(config["mosaic_width"]), int(config["mosaic_height"]))
        )
    display.show(startup_image)

    camera = None
    try:
        # 本地联调模式无需 FPGA：启动后立即拍摄一次并退出。
        if args.trigger_on_start:
            camera = make_camera(config, args.mock_camera)
            return 0 if run_capture(camera, display, config) else 1

        import serial

        # UART 格式固定为 115200 8N1、无流控；readline 以 \n 为一条命令边界。
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
                # 空行、乱码及未知命令由 decode_command 过滤，不触发任何外部动作。
                if command != ALARM:
                    continue
                # 先 ACK 停止 FPGA 重发，再初始化摄像头和保存照片；ACK 只代表“已接收”。
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
                # DONE/ERR 供树莓派侧日志或未来扩展使用；当前 FPGA 只解析 ACK。
                uart.write(DONE if run_capture(camera, display, config) else ERROR)
                uart.flush()
    except KeyboardInterrupt:
        return 0
    finally:
        # 无论正常退出、Ctrl+C 还是异常都释放摄像头和 OpenCV 窗口。
        if camera is not None:
            camera.close()
        display.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
