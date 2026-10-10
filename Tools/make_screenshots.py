"""README / CurseForge images from in-game screenshots (owner's, 1.60.1.70338).

Crops the demon wheel and the bar, and blurs every player and pet name in the
full-UI shot: nameplates (found by their blue/green text colour, then
dilated), plus the chat box and the unit and party frames by rectangle.
Run from the repo root:  python Tools/make_screenshots.py
Writes docs/screenshots/*.jpg (not packaged: docs/ is ignored by .pkgmeta).
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SHOTS = Path(r"C:\Program Files (x86)\World of Warcraft\_classic_beta_\Screenshots")
OUT = Path(__file__).resolve().parents[1] / "docs" / "screenshots"
S = 1.92  # the shots are 3840x2160; boxes below were measured on a 2000-wide view


def box(x0, y0, x1, y1):
    return tuple(int(round(v * S)) for v in (x0, y0, x1, y1))


def shot(name):
    return Image.open(SHOTS / f"WoWScrnShot_101026_{name}.jpg").convert("RGB")


def save(img, name, width=None):
    if width and img.width > width:
        img = img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.jpg", quality=88, optimize=True)
    print(name, img.size)


def blur_rect(img, rect, radius=14):
    region = img.crop(rect).filter(ImageFilter.GaussianBlur(radius))
    img.paste(region, rect[:2])


def blur_names(img, area):
    """Blur nameplate text inside `area`: saturated blue/purple (players,
    pets) and bright green (party, friendly NPCs) pixels, dilated so whole
    words are covered."""
    a = np.asarray(img.crop(area)).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    blue = (b > 170) & (b - r > 40) & (b - g > 40)
    green = (g > 170) & (g - r > 70) & (g - b > 70)
    mask = Image.fromarray(((blue | green) * 255).astype(np.uint8))
    mask = mask.filter(ImageFilter.MaxFilter(31)).filter(ImageFilter.GaussianBlur(6))
    region = img.crop(area)
    blurred = region.filter(ImageFilter.GaussianBlur(16))
    region.paste(blurred, (0, 0), mask)
    img.paste(region, area[:2])


def main():
    # The wheel in three states: Succubus, Voidwalker, Imp in the centre.
    crops = [shot(n).crop(box(1128, 240, 1542, 800)) for n in ("171227", "171257", "171306")]
    w = sum(c.width for c in crops)
    strip = Image.new("RGB", (w, crops[0].height))
    x = 0
    for c in crops:
        strip.paste(c, (x, 0))
        x += c.width
    save(strip, "wheels", 1920)

    # Hero: the gnome and the wheel, Voidwalker in the centre.
    save(shot("171257").crop(box(380, 200, 1600, 1060)), "hero", 1920)

    # The bar alone (no names on it).
    save(shot("170805").crop(box(800, 925, 1255, 995)), "bar")

    # The full game UI, every name blurred.
    ui = shot("170805")
    blur_names(ui, box(0, 40, 1660, 900))
    for rect in (
        box(30, 885, 548, 1090),     # chat
        box(612, 786, 888, 812),     # player frame name
        box(584, 842, 760, 860),     # pet frame name
        box(126, 605, 288, 660),     # party/raid frames (Morphisto, Geltog)
    ):
        blur_rect(ui, rect)
    save(ui, "ui", 1920)


if __name__ == "__main__":
    main()
