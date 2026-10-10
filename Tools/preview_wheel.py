"""Offline art/motion study using the shipped TGAs, not a WoW render.

python Tools/preview_wheel.py -> .release/wheel-preview.png and .gif
The seven portraits and centre are labelled placeholders: the game supplies
the live models. Use /123 wheel in game for final material and motion approval.
"""
from pathlib import Path
import math
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ".release"
OUT.mkdir(exist_ok=True)
ART = {p.stem: Image.open(p).convert("RGBA") for p in (ROOT / "Media").glob("Wheel_*.tga")}
SCALE = 1.55
W, H = 860, 1060
CX, CY = W // 2, 560
TAU = math.tau


def smooth(x):
    x = max(0, min(1, x))
    return x * x * (3 - 2 * x)


def font(size, title=False):
    name = "georgia.ttf" if title else "arial.ttf"
    return ImageFont.truetype("C:/Windows/Fonts/" + name, round(size * SCALE))


def text(im, value, x, y, size, color, title=False):
    d = ImageDraw.Draw(im)
    d.text((x + 1, y + 1), value, font=font(size, title), fill=(0, 0, 0), anchor="mm")
    d.text((x, y), value, font=font(size, title), fill=color, anchor="mm")


def paste(im, key, x, y, w, h=None, alpha=1, tint=None, additive=False, angle=0):
    tex = ART[key].resize((max(1, round(w * SCALE)), max(1, round((h or w) * SCALE))), Image.Resampling.BICUBIC)
    if angle:
        tex = tex.rotate(math.degrees(angle), Image.Resampling.BICUBIC)
    rgba = np.asarray(tex).astype(float)
    if tint:
        rgba[:, :, :3] *= np.array(tint)
    rgba[:, :, 3] *= max(0, min(1, alpha))
    tex = Image.fromarray(np.uint8(np.clip(rgba, 0, 255)))
    xx, yy = round(x - tex.width / 2), round(y - tex.height / 2)
    if additive:
        bg = np.asarray(im.crop((xx, yy, xx + tex.width, yy + tex.height))).astype(float)
        bg[:, :, :3] += rgba[:, :, :3] * rgba[:, :, 3:4] / 255
        bg[:, :, 3] = np.maximum(bg[:, :, 3], rgba[:, :, 3])
        im.paste(Image.fromarray(np.uint8(np.clip(bg, 0, 255))), (xx, yy))
    else:
        im.alpha_composite(tex, (xx, yy))


def render(t=2, backdrop="warm"):
    y, x = np.mgrid[:H, :W]
    bg = np.zeros((H, W, 4), dtype=np.uint8)
    colors = (66, 54, 42) if backdrop == "warm" else (172, 183, 187)
    for c, value in enumerate(colors):
        bg[:, :, c] = np.clip(value + 8 * np.sin(x / 80) * np.cos(y / 110), 0, 255)
    bg[:, :, 3] = 255
    im = Image.fromarray(bg)
    if backdrop == "crowded":
        text(im, "Zangmoth", CX - 140, CY - 180, 48, (116, 102, 255))
        text(im, "<Zisha Hellspark's Minion>", CX - 80, CY - 105, 42, (116, 102, 255))
        text(im, "Warlock Trainer", CX + 30, CY + 45, 46, (20, 255, 15))
        text(im, "<Away> Player", CX + 40, CY + 180, 40, (116, 102, 255))
    opening = min(t, .58)
    closing = max(0, (t - 5.2) / .30)
    fade = 1 - smooth(closing)
    a = smooth(opening / .28) * fade
    paste(im, "Wheel_Shadow_512", CX, CY, 440, alpha=a)
    paste(im, "Wheel_Circle_512", CX, CY, 440, alpha=.85 * a, tint=(.63, .82, .30), additive=True)
    for i, (key, size, turn, opacity, phase) in enumerate([
        ("Wheel_Mist_512", 440, 47, .30, .2),
        ("Wheel_Flame_512", 435.6, -39, .40, 2.2),
        ("Wheel_Flame_512", 413.6, 61, .26, 4.5),
    ]):
        paste(im, key, CX, CY, size, alpha=a * opacity * (.85 + .15 * math.sin(t * .8 + (i + 1) * 2)),
              tint=(.31 if i == 0 else .50, .92, .07), additive=True, angle=phase + t * TAU / turn)
    paste(im, "Wheel_Runes_512", CX, CY, 440, alpha=a * (.57 + .09 * math.sin(t * .65)),
          tint=(.62, 1, .16), additive=True, angle=math.radians(2) * (1 - math.cos(TAU * t / 4)))
    if t < .58 or closing:
        p = smooth(t / .58) if not closing else 1 - .34 * smooth(closing)
        size = 440 * (.3 + .7 * p) if not closing else 440 * p
        pulse = .9 * math.sin(p * math.pi) if not closing else math.sin(min(1, closing) * math.pi)
        paste(im, "Wheel_Circle_512", CX, CY, size, alpha=pulse * a, tint=(.72, 1, .24), additive=True)
    for i in range(1, 15):
        angle = i * TAU / 14 + .14
        ex, ey = CX + math.cos(angle) * 440 * .438 * SCALE, CY - math.sin(angle) * 440 * .438 * SCALE
        p = (t / 2.6 + i * .317 % 1) % 1
        fall = min(1, p / .72)
        if p < .72:
            paste(im, "Wheel_Ember_64", ex + 4 * (1 - fall) * SCALE, ey - 32 * (1 - fall) * SCALE,
                  10, 36, alpha=math.sin(fall * math.pi) * .56 * a, tint=(.63, 1, .13), additive=True)
        else:
            paste(im, "Wheel_Glow_128", ex, ey, 22, 12, alpha=math.sin((p - .72) / .28 * math.pi) * .32 * a,
                  tint=(.66, 1, .13), additive=True)
    foreground = Image.new("RGBA", im.size)
    hy = CY - (220 + 2 + 28) * SCALE
    paste(foreground, "Wheel_Glow_128", CX, hy, 238, 90, alpha=.95, tint=(.02, .025, .02))
    paste(foreground, "Wheel_Crest_512", CX, hy - 10 * SCALE, 244, 122)
    text(foreground, "123", CX, hy - 9 * SCALE, 38, (235, 242, 224), True)
    text(foreground, "DEMON SUMMONING", CX, hy + 20 * SCALE, 12, (205, 210, 191))
    paste(foreground, "Wheel_Plate_256", CX, CY + 248 * SCALE, 380, 44)
    text(foreground, "0", CX - 140 * SCALE, CY + 248 * SCALE, 16, (206, 178, 245))
    text(foreground, "Select a demon to summon", CX + 30 * SCALE, CY + 248 * SCALE, 11, (224, 216, 238))
    paste(foreground, "Wheel_Glow_128", CX, CY - 16 * SCALE, 120, 112, alpha=.28, tint=(.37, .90, .05), additive=True)
    paste(foreground, "Wheel_Sigil_256", CX, CY + 20 * SCALE, 144, 34, alpha=.75, tint=(.49, 1, .09), additive=True)
    text(foreground, "Live demon", CX, CY - 28 * SCALE, 13, (174, 179, 166))
    text(foreground, "Imp", CX, CY + 37 * SCALE, 14, (240, 240, 240))
    text(foreground, "Geltog", CX, CY + 51 * SCALE, 11, (176, 143, 230))
    text(foreground, "Active", CX, CY + 64 * SCALE, 11, (143, 244, 55))
    foreground.putalpha(foreground.getchannel("A").point(lambda value: round(value * a)))
    im.alpha_composite(foreground)
    names = ["Voidwalker", "Felhunter", "Inferno", "Doomguard", "Imp", "Succubus", "Incubus"]
    for i, name in enumerate(names):
        angle = math.pi / 2 - i * TAU / 7
        nx, ny = CX + math.cos(angle) * 162 * SCALE, CY - math.sin(angle) * 162 * SCALE
        node = Image.new("RGBA", im.size)
        tint = (.48, 1, .12) if i == 4 else ((1, .23, .12) if i == 0 else (.4, .43, .37))
        paste(node, "Wheel_Glow_128", nx, ny, 76 * 1.45, alpha=.22 if i == 4 else .04, tint=tint, additive=True)
        d = ImageDraw.Draw(node)
        r = 76 * SCALE / 2
        d.ellipse((nx - r, ny - r, nx + r, ny + r), fill=(9, 13, 10, 245))
        paste(node, "Wheel_Node_256", nx, ny, 76)
        paste(node, "Wheel_NodeLight_256", nx, ny, 76, alpha=.79 if i == 4 else (.64 if i == 0 else .22), tint=tint, additive=True)
        text(node, "3D", nx, ny, 13, (99, 108, 95))
        paste(node, "Wheel_Plate_256", nx, ny + 42 * SCALE, 106, 20)
        text(node, name, nx, ny + 42 * SCALE, 12, (232, 232, 226))
        status = "Active" if i == 4 else ("No Soul Shard" if i == 0 else "Not learned")
        paste(node, "Wheel_Plate_256", nx, ny + 58.5 * SCALE, 100, 15, alpha=.90)
        text(node, status, nx, ny + 59 * SCALE, 10, tuple(round(v * 255) for v in tint) if i in (0, 4) else (199, 204, 189))
        na = smooth((opening - .04 - i * .035) / .26) * fade
        node.putalpha(node.getchannel("A").point(lambda value: round(value * na)))
        im.alpha_composite(node)
    text(im, "123 / FEL RITUAL", W / 2, 42, 15, (223, 223, 207))
    text(im, "Offline texture study - live models supplied by WoW", W / 2, H - 32, 11, (220, 220, 212))
    return im.convert("RGB")


if __name__ == "__main__":
    render().save(OUT / "wheel-preview.png")
    render(backdrop="light").save(OUT / "wheel-preview-light.png")
    render(backdrop="crowded").save(OUT / "wheel-preview-crowded.png")
    if "--still" not in sys.argv:
        frames = [render(i / 20).resize((645, 795), Image.Resampling.LANCZOS) for i in range(117)]
        frames[0].save(OUT / "wheel-preview.gif", save_all=True, append_images=frames[1:], duration=50, loop=0)
    print("Wrote previews to .release/ (warm, light, crowded; --still skips the GIF)")
