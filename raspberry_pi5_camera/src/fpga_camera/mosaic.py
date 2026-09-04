from __future__ import annotations

from collections.abc import Sequence

from PIL import Image, ImageDraw, ImageOps


def build_mosaic(
    frames: Sequence[Image.Image], output_size: tuple[int, int] = (640, 480)
) -> Image.Image:
    if len(frames) != 4:
        raise ValueError("exactly four frames are required")
    width, height = output_size
    if width < 2 or height < 2:
        raise ValueError("output size is too small")
    left_width = width // 2
    top_height = height // 2
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
        fitted = ImageOps.fit(frame.convert("RGB"), size, method=Image.Resampling.LANCZOS)
        canvas.paste(fitted, position)
    return canvas


def test_pattern(output_size: tuple[int, int] = (640, 480)) -> Image.Image:
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
    image = Image.new("RGB", output_size, "#8b0000")
    draw = ImageDraw.Draw(image)
    draw.text((24, 24), "CAMERA ERROR", fill="white")
    draw.text((24, 56), message[:80], fill="white")
    return image
