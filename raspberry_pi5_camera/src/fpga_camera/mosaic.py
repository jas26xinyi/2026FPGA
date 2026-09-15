from __future__ import annotations

from collections.abc import Sequence

from PIL import Image, ImageDraw, ImageOps


def build_mosaic(
    frames: Sequence[Image.Image], output_size: tuple[int, int] = (640, 480)
) -> Image.Image:
    """按拍摄顺序把四帧放到左上、右上、左下、右下，输出指定大小的 RGB 图。"""
    if len(frames) != 4:
        raise ValueError("exactly four frames are required")
    width, height = output_size
    if width < 2 or height < 2:
        raise ValueError("output size is too small")
    left_width = width // 2
    top_height = height // 2
    # 奇数宽高时把多出的 1 像素分给右列/下行，保证四格严密覆盖整张画布。
    cell_sizes = (
        (left_width, top_height),
        (width - left_width, top_height),
        (left_width, height - top_height),
        (width - left_width, height - top_height),
    )
    positions = (
        (0, 0),
        (left_width, 0),
        (0, top_height),
        (left_width, top_height),
    )
    canvas = Image.new("RGB", output_size, "black")
    for frame, size, position in zip(frames, cell_sizes, positions, strict=True):
        # fit 等比例缩放后居中裁剪，填满格子而不拉伸；LANCZOS 保证缩放质量。
        fitted = ImageOps.fit(frame.convert("RGB"), size, method=Image.Resampling.LANCZOS)
        canvas.paste(fitted, position)
    return canvas


def test_pattern(output_size: tuple[int, int] = (640, 480)) -> Image.Image:
    """无历史报警图片时显示的彩条与 READY 字样，也用于检查 HDMI 色彩和分辨率。"""
    colours = (
        "white",
        "#f4d03f",
        "#45b8ac",
        "#58d68d",
        "#af7ac5",
        "#e74c3c",
        "#3498db",
        "black",
    )
    width, height = output_size
    image = Image.new("RGB", output_size, "black")
    draw = ImageDraw.Draw(image)
    for index, colour in enumerate(colours):
        x0 = index * width // len(colours)
        x1 = (index + 1) * width // len(colours)
        draw.rectangle((x0, 0, x1, height), fill=colour)
    draw.rectangle((0, height - 48, width, height), fill="black")
    draw.text((16, height - 34), "FPGA CAMERA READY", fill="white")
    return image


def error_screen(message: str, output_size: tuple[int, int] = (640, 480)) -> Image.Image:
    """摄像头或保存失败时生成红色错误画面，最多显示异常文本前 80 个字符。"""
    image = Image.new("RGB", output_size, "#8b0000")
    draw = ImageDraw.Draw(image)
    draw.text((24, 24), "CAMERA ERROR", fill="white")
    draw.text((24, 56), message[:80], fill="white")
    return image
