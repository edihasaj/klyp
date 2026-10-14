"""Frame native XCTest attachments for the Mac App Store.

uv run --with pillow scripts/frame-store-screenshots.py <attachments> <output>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def frame(source: Path, output: Path, title: str, detail: str) -> None:
    canvas = Image.new("RGB", (1440, 900), "#17131b")
    draw = ImageDraw.Draw(canvas)
    draw.ellipse((930, -260, 1700, 510), fill="#332030")
    draw.ellipse((-340, 650, 460, 1450), fill="#261d2d")
    for x in range(750, 1530, 60):
        draw.line((x, 0, x - 320, 900), fill="#211a26", width=1)
    fonts = "/System/Library/Fonts/Avenir Next.ttc"
    label = ImageFont.truetype(fonts, 21)
    heading = ImageFont.truetype(fonts, 62, index=1)
    body = ImageFont.truetype(fonts, 25)
    draw.text((84, 80), "KLYP  /  FOR MAC", font=label, fill="#ff7eaa")
    draw.multiline_text((80, 190), title, font=heading, fill="#fff4f8", spacing=8)
    draw.multiline_text((84, 440), detail, font=body, fill="#cfbfce", spacing=13)
    draw.text((84, 790), "SMALL APP. USEFUL COPIES.", font=label, fill="#ff7eaa")
    screenshot = Image.open(source).convert("RGBA")
    screenshot.thumbnail((640, 744), Image.Resampling.LANCZOS)
    x = 1440 - screenshot.width - 70
    y = (900 - screenshot.height) // 2
    draw.rounded_rectangle((x - 6, y - 6, x + screenshot.width + 6, y + screenshot.height + 6),
                           radius=18, fill="#534052")
    canvas.paste(screenshot, (x, y), screenshot)
    canvas.save(output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("attachments", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    manifest = json.loads((args.attachments / "manifest.json").read_text())
    sources = {
        attachment["suggestedHumanReadableName"].split("_")[0]:
            args.attachments / attachment["exportedFileName"]
        for test in manifest for attachment in test["attachments"]
    }
    args.output.mkdir(parents=True, exist_ok=True)
    for name, title, detail in [
        ("01-history", "Your copies,\nclose at hand.",
         "Search your history.\nPin the useful things.\nKeep everything on your Mac."),
        ("02-settings", "A little app.\nYour way.",
         "Choose how much to keep.\nClear the clutter.\nStart at login when you want."),
    ]:
        output = args.output / (name + ".png")
        frame(sources[name], output, title, detail)
        print(output)


if __name__ == "__main__":
    main()
