#!/usr/bin/env python3
"""Convert the pinned ST OV5640 tables into a synthesizable Verilog ROM.

Usage: python generate_ov5640_rom.py <stm32-ov5640 checkout> <output.v>
The checkout must be at 52c727ac10a427fe7a400d3a4783adc814ee075e.
"""
from pathlib import Path
import re
import subprocess
import sys

PINNED = "52c727ac10a427fe7a400d3a4783adc814ee075e"


def parse_defines(text: str) -> dict[str, int]:
    values: dict[str, int] = {}
    for name, value in re.findall(r"#define\s+(OV5640_[A-Z0-9_]+)\s+(0x[0-9A-Fa-f]+)U?", text):
        values[name] = int(value, 16)
    return values


def array_body(text: str, marker: str) -> str:
    start = text.index(marker)
    start = text.index("{", start)
    end = text.index("};", start)
    return text[start + 1 : end]


def parse_pairs(body: str, defines: dict[str, int]) -> list[tuple[int, int]]:
    pairs: list[tuple[int, int]] = []
    for left, right in re.findall(r"\{\s*([A-Za-z0-9_x]+)\s*,\s*(0x[0-9A-Fa-f]+|[0-9]+)\s*\}", body):
        address = int(left, 16) if left.startswith("0x") else defines[left]
        pairs.append((address, int(right, 0)))
    return pairs


def main() -> None:
    source = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    commit = subprocess.check_output(
        ["git", "-C", str(source), "rev-parse", "HEAD"], text=True
    ).strip()
    if commit != PINNED:
        raise SystemExit(f"expected {PINNED}, found {commit}")

    c_text = (source / "ov5640.c").read_text(encoding="utf-8")
    defines = parse_defines((source / "ov5640_reg.h").read_text(encoding="utf-8"))
    entries = parse_pairs(array_body(c_text, "OV5640_Common[][2]"), defines)
    entries += parse_pairs(array_body(c_text, "static const uint16_t regs[10][2]"), defines)
    entries += parse_pairs(array_body(c_text, "OV5640_QQVGA[][2]"), defines)
    entries += parse_pairs(array_body(c_text, "OV5640_PF_RGB565[][2]"), defines)
    # Explicit high-active PCLK/HREF/VSYNC value produced by ST SetPolarities.
    entries.append((defines["OV5640_POLARITY_CTRL"], 0x22))

    lines = [
        "`timescale 1ns/1ps",
        "",
        "// Generated from STMicroelectronics/stm32-ov5640 commit",
        f"// {PINNED}. Do not edit by hand.",
        "module ov5640_reg_table (",
        "    input  wire [8:0] index,",
        "    output reg  [15:0] address,",
        "    output reg  [7:0] value,",
        "    output wire       last",
        ");",
        f"    localparam integer ENTRY_COUNT = {len(entries)};",
        "    assign last = (index == ENTRY_COUNT-1);",
        "    always @(*) begin",
        "        address = 16'h3008; value = 8'h02;",
        "        case (index)",
    ]
    lines += [f"            9'd{i}: begin address=16'h{a:04X}; value=8'h{v:02X}; end" for i, (a, v) in enumerate(entries)]
    lines += ["            default: ;", "        endcase", "    end", "endmodule", ""]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="ascii")
    print(f"wrote {len(entries)} entries to {output}")


if __name__ == "__main__":
    main()
