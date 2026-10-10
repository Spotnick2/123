"""Reproducible fel-wheel layers for #13. Run: python Tools/make_wheel_art.py

Pillow + numpy (also used by the sibling addons' art tools). The crest source
is generated art under Tools/Art/Crest; all other layers are procedural.
Uncompressed, bottom-origin RGBA TGAs; power-of-two sizes. Light layers carry
white RGB with shape in alpha. The metal node MUST cover the portrait corners:
its opaque band is 0.70..0.985 of the radius, matching make_bead_ring.py.
"""
from pathlib import Path
import math
import struct

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "Media"
TAU = math.tau


def save(name, image):
    image = image.convert("RGBA")
    w, h = image.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    rgba = np.asarray(image)[::-1, :, [2, 1, 0, 3]].copy()
    (MEDIA / (name + ".tga")).write_bytes(header + rgba.tobytes())
    return image


def grid(size):
    y, x = np.mgrid[:size, :size].astype(float)
    x = (x + .5 - size / 2) / (size / 2)
    y = (size / 2 - y - .5) / (size / 2)
    return x, y, np.hypot(x, y), np.arctan2(y, x)


def light(alpha):
    rgba = np.full((*alpha.shape, 4), 255, dtype=np.uint8)
    rgba[:, :, 3] = np.uint8(np.clip(alpha, 0, 1) * 255)
    return Image.fromarray(rgba)


def ring(r, radius, width):
    return np.exp(-((r - radius) / width) ** 2)


def noise(x, y, seed):
    """Smooth deterministic value noise; no thin contour isolines."""
    ix, iy = np.floor(x), np.floor(y)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    def value(xx, yy):
        return np.mod(np.sin(xx * 127.1 + yy * 311.7 + seed * 74.7) * 43758.5453, 1)
    low = value(ix, iy) * (1 - fx) + value(ix + 1, iy) * fx
    high = value(ix, iy + 1) * (1 - fx) + value(ix + 1, iy + 1) * fx
    return low * (1 - fy) + high * fy


def rune_band(size=512):
    # Invented angular sigils; separate groups leave the seven portraits clear.
    s = 2
    im = Image.new("L", (size * s, size * s))
    d = ImageDraw.Draw(im)
    glyphs = [
        [[(-3, -5), (2, -5), (3, 0), (-2, 1), (-3, 5)], [(0, -2), (4, 3)]],
        [[(-3, 4), (2, 2), (-1, -2), (3, -5)], [(-3, -4), (0, -1), (4, -1)]],
        [[(-3, -4), (2, -2), (0, 4), (-3, 1)], [(0, 4), (4, 3)]],
        [[(-2, -5), (2, -1), (-2, 2), (3, 5)], [(-4, 0), (0, 0)]],
        [[(-3, -3), (3, -3), (0, 0), (3, 4)], [(0, 0), (-3, 4)]],
    ]
    for sector in range(7):
        for j in range(4):
            a = math.pi / 2 - (sector + .30 + j * .13) * TAU / 7
            cx, cy = size / 2 + math.cos(a) * size * .451, size / 2 - math.sin(a) * size * .451
            for stroke in glyphs[(sector * 3 + j) % len(glyphs)]:
                pts = [(s * (cx + u * math.sin(a) + v * math.cos(a)),
                        s * (cy + u * math.cos(a) - v * math.sin(a))) for u, v in stroke]
                d.line(pts, fill=200 + j * 15, width=3, joint="curve")
    im = im.resize((size, size), Image.Resampling.LANCZOS)
    return light(np.asarray(im) / 255)


def field():
    x, y, r, a = grid(512)
    # The backdrop is smoked charcoal, no flat green fill or bright glass grain.
    body = np.zeros((512, 512, 4), dtype=np.uint8)
    body[:, :, :3] = (9, 14, 10)
    # Crowded-scene capture: world names pierced the old 76% body. Protect
    # the centre more strongly, while letting the outer flame edge dissolve.
    opacity = (.86 + .09 * np.exp(-(r / .65) ** 2)) * np.clip((.995 - r) / .11, 0, 1)
    body[:, :, 3] = np.uint8(opacity * 255)
    save("Wheel_Shadow_512", Image.fromarray(body))
    rim = ring(r, .965, .003) * (.45 + .4 * (y + 1) / 2)
    rim += ring(r, .846, .0025) * .26
    rim += ring(r, .63, .002) * .10
    save("Wheel_Circle_512", light(rim))
    save("Wheel_Runes_512", rune_band())
    # Curl a cloudy density field. The first pass traced constant-density
    # contours and read as electric wires in game, rather than smoke.
    warp = a + 1.6 * r + .46 * (noise(x * 3, y * 3, 3) - .5)
    u, v = r * np.cos(warp), r * np.sin(warp)
    u = u + .19 * (noise(u * 5, v * 5, 5) - .5)
    v = v + .19 * (noise(u * 5, v * 5, 7) - .5)
    cloud = (noise(u * 7, v * 7, 11) * .55 + noise(u * 15, v * 15, 13) * .28
             + noise(u * 33, v * 33, 17) * .12 + noise(u * 65, v * 65, 19) * .05)
    envelope = np.clip((1 - r) / .14, 0, 1) * np.clip((r - .24) / .3, 0, 1)
    smoke = np.clip((cloud - .26) * 2.2, 0, 1) ** 1.5 * envelope
    save("Wheel_Mist_512", light(smoke))
    tongues = np.clip((cloud - .48) * 4.3, 0, 1) ** 1.7
    tongues *= .35 + .65 * noise(u * 13, v * 3, 23)
    save("Wheel_Flame_512", light(tongues * envelope))


def node():
    x, y, r, a = grid(256)
    coverage = np.clip((r - .686) * 128 + .5, 0, 1) * np.clip((.985 - r) * 128 + .5, 0, 1)
    # An opaque carved band, with raised bevels and dark recesses. Never punch
    # holes into this band: the square model behind it cannot be masked.
    bevel = ring(r, .728, .019) * .58 + ring(r, .930, .023) * .66
    bevel += ring(r, .964, .006) * .38
    directional = np.clip(.45 + .40 * y - .20 * x, .1, 1)
    grain = .012 * np.sin(100 * x + 19 * np.sin(17 * y)) * np.cos(90 * y)
    shade = .085 + bevel * directional + grain
    rgba = np.zeros((256, 256, 4), dtype=np.uint8)
    for c, mul in enumerate((.93, 1, .89)):
        rgba[:, :, c] = np.uint8(np.clip(shade * mul, 0, 1) * 255)
    rgba[:, :, 3] = np.uint8(coverage * 255)
    im = Image.fromarray(rgba)
    d = ImageDraw.Draw(im)
    # Four blade-shaped clasps on the band, faceted instead of neon circles.
    for angle in (0, math.pi / 2, math.pi, math.pi * 1.5):
        def p(u, v):
            return (128 + 128 * (u * math.cos(angle) - v * math.sin(angle)),
                    128 - 128 * (u * math.sin(angle) + v * math.cos(angle)))
        d.polygon([p(.98, 0), p(.86, .072), p(.755, 0), p(.86, -.042)], fill=(27, 34, 25, 255))
        d.line([p(.98, 0), p(.86, .072), p(.755, 0)], fill=(131, 144, 109, 255), width=2)
        d.line([p(.98, 0), p(.86, -.042), p(.755, 0)], fill=(3, 6, 3, 255), width=3)
        d.polygon([p(.90, 0), p(.853, .023), p(.818, 0), p(.853, -.02)], fill=(144, 218, 51, 255))
    save("Wheel_Node_256", im)
    edge = ring(r, .708, .010) * (.50 + .5 * directional)
    edge += ring(r, .714, .030) * .25
    edge += ring(r, .946, .010) * np.clip(np.sin(a * 4 + .3), 0, 1) * .9
    save("Wheel_NodeLight_256", light(edge))


def crest():
    # Format conversion only: retain the generated source and its alpha.
    # Live title/subtitle text is drawn by Wheel.lua, never baked into art.
    im = Image.open(ROOT / "Tools/Art/Crest/crest-fel-v2.png").convert("RGBA")
    save("Wheel_Crest_512", im.resize((512, 256), Image.Resampling.LANCZOS))


def details():
    x, y, r, a = grid(256)
    sigil = ring(r, .88, .012) * .85 + ring(r, .74, .007) * .65
    sigil += ring(r, .60, .006) * .3
    sigil += ring(r, .80, .06) * np.maximum(0, np.cos(a * 12)) ** 20 * .75
    # A seven-point ritual star beneath the pet's feet.
    im = light(sigil)
    alpha = im.getchannel("A")
    d = ImageDraw.Draw(alpha)
    pts = [(128 + 75 * math.cos(math.pi / 2 + i * 3 * TAU / 7),
            128 - 75 * math.sin(math.pi / 2 + i * 3 * TAU / 7)) for i in range(8)]
    d.line(pts, fill=125, width=2)
    im.putalpha(alpha)
    save("Wheel_Sigil_256", im)
    x, y, r, a = grid(128)
    save("Wheel_Glow_128", light(np.exp(-r * r * 6) * np.clip((1 - r) * 8, 0, 1)))
    x, y, r, a = grid(64)
    ember = np.exp(-(x / (.07 + .13 * (y + 1) / 2)) ** 2) * np.exp(-((y + .25) / .52) ** 2)
    save("Wheel_Ember_64", light(ember))
    # A neutral obsidian plate; its round ends remain clean when stretched.
    im = Image.new("RGBA", (512, 128))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((2, 2, 509, 125), 58, fill=(14, 13, 18, 242), outline=(117, 121, 109, 230), width=3)
    d.rounded_rectangle((8, 8, 503, 119), 52, outline=(35, 39, 31, 255), width=2)
    save("Wheel_Plate_256", im.resize((256, 64), Image.Resampling.LANCZOS))


def main():
    MEDIA.mkdir(exist_ok=True)
    field()
    node()
    crest()
    details()
    print("Generated 12 wheel layers in Media/ (deterministic, RGBA TGA).")


if __name__ == "__main__":
    main()
