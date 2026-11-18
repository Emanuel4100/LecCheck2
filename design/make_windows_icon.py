#!/usr/bin/env python3
"""Builds app/windows/runner/resources/app_icon.ico from icon_rounded.svg.

Windows picks the size it needs (16 px in the title bar, 24-48 px on the
taskbar and in Explorer, 256 px for large icons), so the .ico holds each one
drawn from the SVG rather than one big image scaled down. The 256 px image is
stored as PNG, the smaller ones as 32-bit bitmaps (what every Windows tool,
Inno Setup included, reads).

Needs rsvg-convert and ImageMagick (`magick`). Run from anywhere:

    python3 design/make_windows_icon.py
"""

import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / "design" / "app-icon" / "icon_rounded.svg"
OUT = ROOT / "app" / "windows" / "runner" / "resources" / "app_icon.ico"
SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]


def bitmap(png: Path, size: int, work: Path) -> bytes:
    """The image of a one-image .ico ImageMagick writes from |png|."""
    ico = work / f"{size}.ico"
    subprocess.run(["magick", str(png), str(ico)], check=True)
    raw = ico.read_bytes()
    (count,) = struct.unpack("<H", raw[4:6])
    assert count == 1, f"{ico} has {count} images"
    *_, length, offset = struct.unpack("<BBBBHHII", raw[6:22])
    return raw[offset : offset + length]


def main() -> None:
    images = []
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        for size in SIZES:
            png = work / f"{size}.png"
            subprocess.run(
                ["rsvg-convert", "-w", str(size), "-h", str(size), str(SVG),
                 "-o", str(png)],
                check=True,
            )
            data = png.read_bytes() if size == 256 else bitmap(png, size, work)
            images.append((size, data))

    out = bytearray(struct.pack("<HHH", 0, 1, len(images)))
    offset = 6 + 16 * len(images)
    for size, data in images:
        # 0 means 256 in an .ico directory entry.
        out += struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32,
                           len(data), offset)
        offset += len(data)
    for _, data in images:
        out += data
    OUT.write_bytes(out)
    print(f"{OUT.relative_to(ROOT)}: {len(images)} sizes, {len(out)} bytes")


if __name__ == "__main__":
    main()
