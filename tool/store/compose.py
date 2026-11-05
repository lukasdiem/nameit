#!/usr/bin/env python3
"""Frames the raw store screenshots with a caption for Google Play.

Input:  build/store/<lang>/<name>.png   (1080 × 1920, from the screenshot test
                                         with --dart-define=SHOT_SET=store)
Output: fastlane/metadata/android/<locale>/images/phoneScreenshots/<n>_<name>.png
        1080 × 1920, 24-bit PNG without alpha (Play rejects alpha).

    python3 tool/store/compose.py --font path/to/Roboto-Bold.ttf

Captions describe what the app does – no other brands, no claims (Play's
metadata policy). Change them here.
"""
import argparse
import glob
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "build" / "store"
META = ROOT / "fastlane" / "metadata" / "android"

LOCALES = {"de": "de-DE", "en": "en-US"}

# Same order as storeShots in screenshot_test/screenshots_test.dart.
CAPTIONS = {
    "de": {
        "class": "Lerne die Namen\ndeiner Klassen",
        "game-millionaire": "Sieben Spiele –\nz. B. das Millionenquiz",
        "game-who-is-it": "Name gegeben?\nFinde das Gesicht",
        "game-type": "Eintippen trainiert\necht Erinnern",
        "result": "Nach jeder Runde: wen\ndu nochmal ansehen solltest",
        "stats": "Fortschritt, Serien\nund Abzeichen",
        "import-file": "Klassen importieren\noder eintippen",
    },
    "en": {
        "class": "Learn the names\nof your classes",
        "game-millionaire": "Seven games –\nlike Million Quiz",
        "game-who-is-it": "Given a name?\nFind the face",
        "game-type": "Typing trains\nreal recall",
        "result": "After each round: the\nfaces worth another look",
        "stats": "Progress, streaks\nand badges",
        "import-file": "Import classes\nor type them in",
    },
}

W, H = 1080, 1920
VIOLET, VIOLET_DARK, INK, MINT = (124, 42, 214), (74, 22, 140), (30, 20, 51), (79, 224, 176)
SHOT_W, SHOT_TOP, RADIUS, BORDER = 820, 420, 56, 14


def find_font(explicit: str | None) -> str:
    candidates = [explicit] if explicit else []
    flutter = os.environ.get("FLUTTER_ROOT")
    if flutter:
        candidates += glob.glob(f"{flutter}/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf")
    candidates += glob.glob("/usr/share/fonts/**/Roboto-Bold.ttf", recursive=True)
    candidates += glob.glob("/usr/share/fonts/**/Inter-Bold.otf", recursive=True)
    candidates += glob.glob("/usr/share/fonts/**/DejaVuSans-Bold.ttf", recursive=True)
    for c in candidates:
        if c and Path(c).exists():
            return c
    raise SystemExit("No bold font found – pass --font")


def background() -> Image.Image:
    bg = Image.new("RGB", (W, H), VIOLET)
    d = ImageDraw.Draw(bg)
    for y in range(H):  # vertical gradient violet → dark violet
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(VIOLET, VIOLET_DARK)))
    # the logo's mint "head" as a soft accent
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W - 330, -150, W + 150, 330), fill=110)
    bg.paste(Image.new("RGB", (W, H), MINT), (0, 0), glow.filter(ImageFilter.GaussianBlur(60)))
    return bg


def rounded(img: Image.Image, r: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *img.size), r, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def compose(raw: Path, caption: str, font: str) -> Image.Image:
    img = background()
    draw = ImageDraw.Draw(img)

    f = ImageFont.truetype(font, 78)
    draw.multiline_text((W // 2, 210), caption, font=f, fill="white", anchor="mm", align="center", spacing=18)

    shot = Image.open(raw).convert("RGB")
    h = round(shot.height * SHOT_W / shot.width)
    shot = shot.resize((SHOT_W, h), Image.LANCZOS)
    x = (W - SHOT_W) // 2

    # shadow, dark "phone" frame, screen
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x - BORDER, SHOT_TOP - BORDER + 24, x + SHOT_W + BORDER, SHOT_TOP + h + BORDER + 24), RADIUS + BORDER, fill=120
    )
    img.paste(Image.new("RGB", (W, H), (20, 10, 40)), (0, 0), shadow.filter(ImageFilter.GaussianBlur(28)))
    ImageDraw.Draw(img).rounded_rectangle(
        (x - BORDER, SHOT_TOP - BORDER, x + SHOT_W + BORDER, SHOT_TOP + h + BORDER), RADIUS + BORDER, fill=INK
    )
    framed = rounded(shot, RADIUS)
    img.paste(framed, (x, SHOT_TOP), framed)
    return img.convert("RGB")  # no alpha channel


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--font")
    args = ap.parse_args()
    font = find_font(args.font)

    for lang, locale in LOCALES.items():
        out_dir = META / locale / "images" / "phoneScreenshots"
        out_dir.mkdir(parents=True, exist_ok=True)
        for old in out_dir.glob("*.png"):
            old.unlink()
        for i, (name, caption) in enumerate(CAPTIONS[lang].items(), start=1):
            raw = RAW / lang / f"{name}.png"
            if not raw.exists():
                raise SystemExit(f"Missing {raw} – run the screenshot test with SHOT_SET=store first")
            compose(raw, caption, font).save(out_dir / f"{i}_{name}.png", optimize=True)
        print(f"{locale}: {len(CAPTIONS[lang])} screenshots")


if __name__ == "__main__":
    main()
