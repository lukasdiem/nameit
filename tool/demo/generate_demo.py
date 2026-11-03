#!/usr/bin/env python3
"""Generates the nameIT demo data: comic-style avatars and a class list CSV.

Everything here is made up – no real students. The output is used for the
documentation screenshots (see screenshot_test/) and can be imported into the
app by hand (CSV import, then a photo per student from the gallery).

    python3 tool/demo/generate_demo.py          # needs rsvg-convert (librsvg)

Writes:
    docs/demo/avatars/<firstname>-<lastname>.jpg
    docs/demo/demo-classes.csv
    docs/demo/avatars.zip (all JPGs, for copying to a phone in one go)
"""
import csv
import random
import shutil
import subprocess
import unicodedata
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "demo"
INK = "#1E1433"

# (class, first, last, look) – look: g = girl, b = boy
STUDENTS = [
    ("3B", "Lena", "Gruber", "g"), ("3B", "Felix", "Huber", "b"), ("3B", "Anna", "Berger", "g"),
    ("3B", "Jonas", "Wagner", "b"), ("3B", "Sophie", "Pichler", "g"), ("3B", "Elias", "Moser", "b"),
    ("3B", "Emma", "Steiner", "g"), ("3B", "Paul", "Hofer", "b"), ("3B", "Zeynep", "Yılmaz", "g"),
    ("3B", "David", "Bauer", "b"), ("3B", "Hannah", "Fuchs", "g"), ("3B", "Luca", "Eder", "b"),
    ("3B", "Marie", "Schwarz", "g"), ("3B", "Noah", "Brunner", "b"), ("3B", "Amara", "Okafor", "g"),
    ("3B", "Tobias", "Winkler", "b"), ("3B", "Clara", "Haas", "g"), ("3B", "Nikola", "Petrović", "b"),
    ("4A", "Laura", "Mayr", "g"), ("4A", "Ben", "Aigner", "b"), ("4A", "Mia", "Leitner", "g"),
    ("4A", "Amir", "Kaya", "b"), ("4A", "Valentina", "Rossi", "g"), ("4A", "Jakob", "Lehner", "b"),
    ("4A", "Lea", "Wimmer", "g"), ("4A", "Matteo", "Fischer", "b"), ("4A", "Ida", "Schmid", "g"),
    ("4A", "Simon", "Egger", "b"),
]

SKIN = [("#FFE0C7", "#F2BE9C"), ("#F9CFA8", "#E6AE83"), ("#E8B48A", "#D09468"),
        ("#C98B5E", "#AE7246"), ("#9C6440", "#82502F"), ("#6E4329", "#58331D")]
HAIR = ["#2B1B12", "#4A2C1A", "#7A4A24", "#B5712F", "#E8B94A", "#F0D48A", "#C2452D", "#1A1A2E"]
SHIRT = ["#7C2AD6", "#4FE0B0", "#FFB627", "#2A8BD6", "#E5484D", "#0E9F74", "#C2409A", "#5B5FE0", "#F08C00"]
BG = ["#FFE8A3", "#C9F5E4", "#E3D1F7", "#CFE5FF", "#FFD6D6", "#FFE0B8", "#D9F2C2", "#F7D1EC"]

GIRL_HAIR = ["long", "bob", "bun", "ponytail", "curly_long", "braids", "pixie"]
BOY_HAIR = ["short", "spiky", "side", "curly", "buzz", "quiff", "messy"]


def slug(s: str) -> str:
    s = s.replace("ı", "i")
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return s.lower().replace(" ", "-")


def back_hair(style, c):
    """Hair behind the head (long styles)."""
    o = f'fill="{c}" stroke="{INK}" stroke-width="8" stroke-linejoin="round"'
    if style == "long":
        return f'<path {o} d="M110 190 Q100 90 200 80 Q300 90 290 190 L300 330 Q250 345 200 330 Q150 345 100 330 Z"/>'
    if style == "curly_long":
        bumps = "".join(f'<circle {o} cx="{x}" cy="{y}" r="34"/>' for x, y in
                        [(105, 300), (110, 240), (115, 180), (295, 300), (290, 240), (285, 180)])
        return bumps
    if style == "ponytail":
        return f'<path {o} d="M285 150 Q350 170 335 250 Q325 300 300 315 Q315 250 280 200 Z"/>'
    if style == "braids":
        braid = lambda x: "".join(f'<ellipse {o} cx="{x}" cy="{y}" rx="20" ry="22"/>' for y in (215, 255, 295))
        return braid(118) + braid(282)
    if style == "bun":
        return f'<circle {o} cx="200" cy="62" r="38"/>'
    if style == "bob":
        return f'<path {o} d="M112 200 Q95 85 200 78 Q305 85 288 200 L292 262 Q250 272 200 262 Q150 272 108 262 Z"/>'
    return ""


def front_hair(style, c):
    o = f'fill="{c}" stroke="{INK}" stroke-width="8" stroke-linejoin="round"'
    shine = f'<path d="M160 110 Q190 95 220 100" fill="none" stroke="#fff" stroke-opacity=".45" stroke-width="7" stroke-linecap="round"/>'
    if style in ("long", "bob", "ponytail", "braids", "bun"):
        return f'<path {o} d="M118 175 Q115 92 200 88 Q285 92 282 175 Q260 128 215 120 Q190 150 140 150 Q125 160 118 175 Z"/>' + shine
    if style == "curly_long" or style == "curly":
        pts = [(130, 150), (150, 115), (185, 100), (220, 100), (255, 115), (272, 150), (200, 92)]
        return "".join(f'<circle {o} cx="{x}" cy="{y}" r="30"/>' for x, y in pts)
    if style == "pixie":
        return f'<path {o} d="M120 170 Q112 88 200 85 Q290 88 282 165 Q255 120 200 132 Q170 150 150 130 Q135 150 120 170 Z"/>' + shine
    if style == "short":
        return f'<path {o} d="M122 165 Q118 90 200 86 Q282 90 278 165 Q270 125 200 122 Q130 125 122 165 Z"/>' + shine
    if style == "spiky":
        return (f'<path {o} d="M122 165 L115 110 L145 120 L150 75 L180 105 L200 62 L222 104 L252 72 '
                f'L258 118 L288 105 L278 165 Q260 125 200 122 Q140 125 122 165 Z"/>')
    if style == "side":
        return f'<path {o} d="M122 168 Q115 88 210 86 Q285 92 280 160 Q240 110 170 130 Q140 140 122 168 Z"/>' + shine
    if style == "buzz":
        return f'<path fill="{c}" fill-opacity=".85" stroke="{INK}" stroke-width="6" d="M126 150 Q130 92 200 90 Q270 92 274 150 Q240 118 200 118 Q160 118 126 150 Z"/>'
    if style == "quiff":
        return f'<path {o} d="M122 165 Q118 100 165 90 Q170 55 230 62 Q290 72 278 165 Q262 120 200 122 Q138 125 122 165 Z"/>' + shine
    if style == "messy":
        return (f'<path {o} d="M120 170 Q100 120 135 100 Q140 70 180 78 Q205 55 235 75 Q275 70 275 110 '
                f'Q300 130 280 170 Q265 130 230 135 Q215 115 190 132 Q160 120 145 140 Q128 145 120 170 Z"/>')
    return ""


def avatar_svg(rnd: random.Random, look: str, idx: int) -> str:
    skin, shade = rnd.choice(SKIN)
    hair = rnd.choice(HAIR)
    shirt = SHIRT[idx % len(SHIRT)]
    bg = BG[idx % len(BG)]
    style = rnd.choice(GIRL_HAIR if look == "g" else BOY_HAIR)
    glasses = rnd.random() < 0.25
    freckles = rnd.random() < 0.3 and SKIN.index((skin, shade)) < 3
    mouth = rnd.choice(["smile", "grin", "smirk", "open"])
    brow_tilt = rnd.choice([-6, 0, 4])
    eye_y = 205
    o = f'stroke="{INK}" stroke-width="8" stroke-linejoin="round" stroke-linecap="round"'

    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="800" height="800">',
             '<defs>',
             f'<pattern id="dots" width="22" height="22" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">'
             f'<circle cx="11" cy="11" r="4" fill="{INK}" fill-opacity=".09"/></pattern>',
             '<clipPath id="face"><ellipse cx="200" cy="200" rx="82" ry="98"/></clipPath>',
             '</defs>',
             f'<rect width="400" height="400" fill="{bg}"/>',
             '<rect width="400" height="400" fill="url(#dots)"/>',
             # comic burst behind the head
             '<g fill="#fff" fill-opacity=".55">' + "".join(
                 f'<path d="M200 190 L{200 + 400 * __import__("math").cos(a / 8 * 3.1416 - .1):.0f} '
                 f'{190 + 400 * __import__("math").sin(a / 8 * 3.1416 - .1):.0f} '
                 f'L{200 + 400 * __import__("math").cos(a / 8 * 3.1416 + .1):.0f} '
                 f'{190 + 400 * __import__("math").sin(a / 8 * 3.1416 + .1):.0f} Z"/>' for a in range(16)) + '</g>',
             back_hair(style, hair),
             # shoulders
             f'<path fill="{shirt}" {o} d="M60 410 Q70 320 150 300 L250 300 Q330 320 340 410 Z"/>',
             f'<path fill="{skin}" {o} d="M170 270 L170 315 Q200 335 230 315 L230 270 Z"/>',
             f'<path fill="none" {o} d="M160 304 Q200 345 240 304"/>',
             # ears
             f'<ellipse fill="{skin}" {o} cx="118" cy="{eye_y + 5}" rx="16" ry="22"/>',
             f'<ellipse fill="{skin}" {o} cx="282" cy="{eye_y + 5}" rx="16" ry="22"/>',
             # head with cel shading
             f'<ellipse fill="{skin}" cx="200" cy="200" rx="82" ry="98"/>',
             f'<path clip-path="url(#face)" fill="{shade}" d="M240 90 Q300 200 230 300 L300 300 L300 90 Z"/>',
             f'<ellipse fill="none" {o} cx="200" cy="200" rx="82" ry="98"/>',
             ]
    # eyes: round, happy (closed arcs) or dots
    eyes = rnd.choice(["round", "round", "happy", "dot"])
    look_x = rnd.choice([-3, 0, 3])
    for x in (168, 232):
        if eyes == "round":
            parts.append(f'<ellipse fill="#fff" stroke="{INK}" stroke-width="6" cx="{x}" cy="{eye_y}" rx="15" ry="17"/>')
            parts.append(f'<circle fill="{INK}" cx="{x + look_x}" cy="{eye_y + 3}" r="8"/>')
            parts.append(f'<circle fill="#fff" cx="{x + look_x + 3}" cy="{eye_y - 1}" r="3"/>')
        elif eyes == "happy":
            parts.append(f'<path fill="none" stroke="{INK}" stroke-width="8" stroke-linecap="round" '
                         f'd="M{x - 13} {eye_y + 4} Q{x} {eye_y - 12} {x + 13} {eye_y + 4}"/>')
        else:
            parts.append(f'<ellipse fill="{INK}" cx="{x}" cy="{eye_y}" rx="7" ry="10"/>')
            parts.append(f'<circle fill="#fff" cx="{x + 2}" cy="{eye_y - 4}" r="2.5"/>')
    # brows
    parts.append(f'<path fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round" '
                 f'd="M150 {eye_y - 28 + brow_tilt} Q168 {eye_y - 36} 184 {eye_y - 28 - brow_tilt}"/>')
    parts.append(f'<path fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round" '
                 f'd="M216 {eye_y - 28 - brow_tilt} Q232 {eye_y - 36} 250 {eye_y - 28 + brow_tilt}"/>')
    # nose
    parts.append(f'<path fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round" d="M202 225 Q212 240 198 245"/>')
    # cheeks
    parts.append('<ellipse fill="#FF7A7A" fill-opacity=".35" cx="150" cy="245" rx="16" ry="9"/>')
    parts.append('<ellipse fill="#FF7A7A" fill-opacity=".35" cx="250" cy="245" rx="16" ry="9"/>')
    if freckles:
        for dx, dy in [(-8, 0), (4, -5), (6, 7), (-3, 9)]:
            parts.append(f'<circle fill="{shade}" cx="{152 + dx}" cy="{238 + dy}" r="2.5"/>')
            parts.append(f'<circle fill="{shade}" cx="{248 - dx}" cy="{238 + dy}" r="2.5"/>')
    # mouth
    if mouth == "smile":
        parts.append(f'<path fill="none" {o} d="M172 262 Q200 288 228 262"/>')
    elif mouth == "grin":
        parts.append(f'<path fill="#fff" {o} d="M168 258 Q200 300 232 258 Z"/>')
    elif mouth == "smirk":
        parts.append(f'<path fill="none" {o} d="M178 268 Q210 280 230 258"/>')
    else:
        parts.append(f'<path fill="{INK}" {o} d="M178 260 Q200 300 222 260 Z"/>')
        parts.append('<ellipse fill="#FF8A8A" cx="200" cy="280" rx="11" ry="6"/>')
    parts.append(front_hair(style, hair))
    if glasses:
        g = f'fill="#fff" fill-opacity=".25" stroke="{INK}" stroke-width="7"'
        parts.append(f'<rect {g} x="142" y="{eye_y - 22}" width="52" height="42" rx="12"/>')
        parts.append(f'<rect {g} x="206" y="{eye_y - 22}" width="52" height="42" rx="12"/>')
        parts.append(f'<path stroke="{INK}" stroke-width="7" d="M194 {eye_y - 4} L206 {eye_y - 4}"/>')
    parts.append("</svg>")
    return "\n".join(parts)


def main():
    if shutil.which("rsvg-convert") is None:
        raise SystemExit("rsvg-convert not found (apt install librsvg2-bin / brew install librsvg)")
    av = OUT / "avatars"
    av.mkdir(parents=True, exist_ok=True)
    rnd = random.Random(42)
    rows = []
    for i, (cls, first, last, look) in enumerate(STUDENTS):
        name = f"{slug(first)}-{slug(last)}"
        svg = av / f"{name}.svg"
        svg.write_text(avatar_svg(rnd, look, i), encoding="utf-8")
        png = av / f"{name}.png"
        subprocess.run(["rsvg-convert", "-w", "600", "-h", "600", "-o", str(png), str(svg)], check=True)
        subprocess.run(["convert", str(png), "-quality", "88", str(av / f"{name}.jpg")], check=True)
        png.unlink()
        svg.unlink()
        rows.append((cls, last, first, f"{name}.jpg"))

    # Same layout as a WebUntis student list export: German headers, semicolons.
    # "Foto" is ignored by the app; it tells you which picture belongs to whom.
    with open(OUT / "demo-classes.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["Klasse", "Nachname", "Vorname", "Foto"])
        w.writerows(rows)

    with zipfile.ZipFile(OUT / "avatars.zip", "w") as z:
        for jpg in sorted(av.glob("*.jpg")):
            z.write(jpg, jpg.name)
    print(f"{len(rows)} students → {OUT}")


if __name__ == "__main__":
    main()
