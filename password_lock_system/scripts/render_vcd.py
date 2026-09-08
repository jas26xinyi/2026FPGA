#!/usr/bin/env python3
"""Render selected signals from a Vivado XSim VCD as a review-friendly PNG."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


STATE_NAMES = {
    0: "BOOT",
    1: "WAIT/PASS",
    2: "USER",
    3: "ERROR",
    4: "OPEN",
    5: "ADMIN/SET",
    6: "SAVE",
    7: "ALARM",
    8: "TEMP",
}


def load_font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/consolab.ttf" if bold else "C:/Windows/Fonts/consola.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def parse_vcd(path: Path):
    scopes: list[str] = []
    by_code: dict[str, list[tuple[str, int]]] = {}
    transitions: dict[str, list[tuple[int, str]]] = {}
    current_time = 0
    max_time = 0
    timescale = "1 ps"
    in_header = True
    timescale_parts: list[str] | None = None

    with path.open("r", encoding="utf-8", errors="replace") as stream:
        for raw in stream:
            line = raw.strip()
            if not line:
                continue
            if in_header:
                if timescale_parts is not None:
                    if "$end" in line:
                        timescale_parts.append(line.replace("$end", "").strip())
                        timescale = " ".join(part for part in timescale_parts if part)
                        timescale_parts = None
                    else:
                        timescale_parts.append(line)
                    continue
                if line.startswith("$timescale"):
                    body = line[len("$timescale") :].replace("$end", "").strip()
                    if "$end" in line:
                        timescale = body
                    else:
                        timescale_parts = [body]
                elif line.startswith("$scope"):
                    parts = line.split()
                    if len(parts) >= 3:
                        scopes.append(parts[2])
                elif line.startswith("$upscope"):
                    if scopes:
                        scopes.pop()
                elif line.startswith("$var"):
                    parts = line.split()
                    if len(parts) >= 6:
                        width = int(parts[2])
                        code = parts[3]
                        reference = parts[4].lstrip("\\")
                        full_name = ".".join(scopes + [reference])
                        by_code.setdefault(code, []).append((full_name, width))
                        transitions.setdefault(code, [])
                elif line.startswith("$enddefinitions"):
                    in_header = False
                continue

            if line.startswith("#"):
                current_time = int(line[1:])
                max_time = max(max_time, current_time)
            elif line[0] in "01xXzZ":
                code = line[1:]
                if code in transitions:
                    value = line[0].lower()
                    if not transitions[code] or transitions[code][-1][1] != value:
                        transitions[code].append((current_time, value))
            elif line[0] in "bBrR":
                parts = line.split()
                if len(parts) == 2 and parts[1] in transitions:
                    value = parts[0][1:].lower()
                    if not transitions[parts[1]] or transitions[parts[1]][-1][1] != value:
                        transitions[parts[1]].append((current_time, value))
    return by_code, transitions, max_time, timescale


def choose_signals(by_code, requested: list[str]):
    result = []
    for wanted in requested:
        candidates = []
        for code, aliases in by_code.items():
            for full_name, width in aliases:
                base = full_name.rsplit(".", 1)[-1]
                if full_name == wanted or full_name.endswith("." + wanted) or base == wanted:
                    candidates.append((full_name.count("."), full_name, width, code))
        if not candidates:
            raise ValueError(f"signal not found in VCD: {wanted}")
        _, full_name, width, code = min(candidates)
        result.append((wanted, full_name, width, code))
    return result


def value_text(name: str, value: str, width: int) -> str:
    if any(ch not in "01" for ch in value):
        return value.upper()
    number = int(value, 2)
    if name == "state":
        return f"{number}:{STATE_NAMES.get(number, '?')}"
    if width <= 4:
        return f"{number:X}"
    digits = max(1, math.ceil(width / 4))
    return f"0x{number:0{digits}X}"


def time_label(value: int, timescale: str) -> str:
    compact = timescale.replace(" ", "") or "1ps"
    match = re.fullmatch(r"(\d+)([a-zA-Z]+)", compact)
    if not match:
        return f"{value} ({timescale})"
    factor, unit = int(match.group(1)), match.group(2)
    absolute = value * factor
    conversions = {"ps": (1000, "ns"), "ns": (1000, "us"), "us": (1000, "ms")}
    if unit in conversions and absolute >= conversions[unit][0] * 10:
        divisor, next_unit = conversions[unit]
        return f"{absolute/divisor:g} {next_unit}"
    return f"{absolute:g} {unit}"


def render(vcd: Path, output: Path, title: str, requested: list[str]) -> None:
    by_code, transitions, max_time, timescale = parse_vcd(vcd)
    signals = choose_signals(by_code, requested)
    width = 1900
    left = 300
    right = 50
    top = 130
    row_h = 72
    bottom = 90
    height = top + row_h * len(signals) + bottom
    image = Image.new("RGB", (width, height), "#111827")
    draw = ImageDraw.Draw(image)
    title_font = load_font(30, bold=True)
    label_font = load_font(20, bold=True)
    value_font = load_font(16)
    small_font = load_font(15)
    grid = "#334155"
    trace = "#22d3ee"
    vector = "#a3e635"
    text = "#f8fafc"
    muted = "#94a3b8"

    draw.text((32, 24), title, font=title_font, fill=text)
    draw.text((32, 72), f"Vivado XSim 2023.2 · {vcd.name} · timescale {timescale}", font=small_font, fill=muted)
    plot_w = width - left - right
    duration = max(max_time, 1)
    for tick in range(11):
        x = left + plot_w * tick / 10
        draw.line((x, top - 16, x, height - bottom + 12), fill=grid, width=1)
        draw.text((x - 24, height - bottom + 24), time_label(int(duration * tick / 10), timescale), font=small_font, fill=muted)

    for index, (wanted, full_name, signal_width, code) in enumerate(signals):
        y0 = top + index * row_h
        y_mid = y0 + row_h // 2
        draw.line((0, y0 + row_h - 1, width, y0 + row_h - 1), fill="#1e293b", width=1)
        draw.text((24, y0 + 18), wanted, font=label_font, fill=text)
        draw.text((24, y0 + 45), full_name, font=small_font, fill=muted)
        events = transitions.get(code, [])
        if not events:
            draw.text((left + 8, y_mid - 8), "no transitions", font=value_font, fill="#f97316")
            continue
        if events[0][0] > 0:
            events = [(0, "x" if signal_width == 1 else "x" * signal_width)] + events
        events = events + [(duration, events[-1][1])]
        for event_index in range(len(events) - 1):
            start_time, value = events[event_index]
            end_time = events[event_index + 1][0]
            x1 = left + plot_w * start_time / duration
            x2 = left + plot_w * end_time / duration
            if signal_width == 1:
                if value == "1":
                    y = y0 + 14
                elif value == "0":
                    y = y0 + row_h - 16
                else:
                    y = y_mid
                color = trace if value in ("0", "1") else "#fb923c"
                draw.line((x1, y, x2, y), fill=color, width=3)
                if event_index:
                    previous = events[event_index - 1][1]
                    py = y0 + 14 if previous == "1" else y0 + row_h - 16 if previous == "0" else y_mid
                    draw.line((x1, py, x1, y), fill=color, width=2)
            else:
                draw.line((x1, y_mid, x2, y_mid), fill=vector, width=4)
                draw.line((x1, y0 + 14, x1, y0 + row_h - 16), fill="#65a30d", width=1)
                label = value_text(wanted, value, signal_width)
                if x2 - x1 > max(46, len(label) * 9):
                    draw.text((x1 + 6, y0 + 13), label, font=value_font, fill=text)

    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("vcd", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--title", required=True)
    parser.add_argument("--signals", required=True, help="comma-separated signal names")
    args = parser.parse_args()
    render(args.vcd, args.output, args.title, [item.strip() for item in args.signals.split(",") if item.strip()])


if __name__ == "__main__":
    main()
