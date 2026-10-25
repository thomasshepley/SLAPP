#!/usr/bin/env python3
"""Draws TitanDeck Host's icon: the TitanDeck app icon (4 x 4 keys) with the
bottom row's three grey keys joined into one that says HOST. Writes
src/App/Assets/TitanDeckHost.ico (16-256 px) and a 1024 px PNG to check it.

    python3 tools/make_icon.py        (needs Pillow)
"""
import pathlib
from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent / "src" / "App" / "Assets"
SIZE = 1024
BACKGROUND = (14, 13, 17)
GREEN, RED, BLUE, GREY = (32, 124, 51), (176, 58, 30), (44, 80, 162), (42, 42, 42)
GRID = [
    [GREEN, GREEN, GREEN, BLUE],
    [RED, RED, RED, BLUE],
    [GREEN, RED, BLUE, GREEN],
]
KEY, GAP, START, RADIUS = 155, 35, 150, 34
FONTS = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "C:/Windows/Fonts/segoeuib.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
]


def font(size):
    for path in FONTS:
        if pathlib.Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def draw():
    image = Image.new("RGBA", (SIZE, SIZE), BACKGROUND + (255,))
    pen = ImageDraw.Draw(image)
    step = KEY + GAP
    for row, colours in enumerate(GRID):
        for column, colour in enumerate(colours):
            x, y = START + column * step, START + row * step
            pen.rounded_rectangle([x, y, x + KEY, y + KEY], RADIUS, fill=colour)
    # Bottom row: one wide key with HOST on it, then the blue key.
    y = START + 3 * step
    left, right = START, START + 2 * step + KEY
    pen.rounded_rectangle([left, y, right, y + KEY], RADIUS, fill=GREY)
    x = START + 3 * step
    pen.rounded_rectangle([x, y, x + KEY, y + KEY], RADIUS, fill=BLUE)
    text = "HOST"
    size = 150
    while True:
        face = font(size)
        box = pen.textbbox((0, 0), text, font=face)
        if box[2] - box[0] <= (right - left) - 70 and box[3] - box[1] <= KEY - 50:
            break
        size -= 4
    width, height = box[2] - box[0], box[3] - box[1]
    pen.text(((left + right - width) / 2 - box[0], y + (KEY - height) / 2 - box[1]), text,
             font=face, fill=(255, 255, 255))
    return image


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    image = draw()
    image.save(OUT / "TitanDeckHost.png")
    image.save(OUT / "TitanDeckHost.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("Wrote", OUT / "TitanDeckHost.ico")
