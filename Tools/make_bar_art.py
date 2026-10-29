"""Deterministic compact-bar art. Run: python Tools/make_bar_art.py.

Uses the wheel pipeline's existing numpy/Pillow dependencies and TGA writer.
Frame/rim display at 40 px around a 36 px icon; glow displays at 56 px.
All light layers are white RGB, with shape in alpha for runtime tinting.
"""
import numpy as np
from PIL import Image

from make_wheel_art import grid, light, save


def rounded_distance(x, y, half, radius):
    qx, qy = np.abs(x) - half + radius, np.abs(y) - half + radius
    return (np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
            + np.minimum(np.maximum(qx, qy), 0) - radius)


def main():
    x, y, _, _ = grid(64)
    outer = rounded_distance(x, y, .98, .18)
    inner = rounded_distance(x, y, .84, .12)
    coverage = np.clip(.5 - outer * 32, 0, 1) * np.clip(.5 + inner * 32, 0, 1)
    bevel = np.exp(-((outer + .035) / .025) ** 2)
    bevel += .65 * np.exp(-((inner - .025) / .020) ** 2)
    shade = np.clip(.16 + bevel * (.42 + .20 * y - .12 * x), 0, 1)
    rgba = np.zeros((64, 64, 4), dtype=np.uint8)
    rgba[:, :, :3] = (shade[:, :, None] * 255).astype(np.uint8)
    rgba[:, :, 3] = (coverage * 255).astype(np.uint8)
    save("Bar_Frame_64", Image.fromarray(rgba))
    rim = .65 * np.exp(-((outer + .025) / .022) ** 2)
    rim += np.exp(-((inner - .015) / .022) ** 2)
    save("Bar_RimLight_64", light(rim))

    x, y, _, _ = grid(128)
    distance = rounded_distance(x, y, .66, .13)
    halo = np.exp(-(distance / .14) ** 2)
    halo *= np.clip((1 - np.maximum(np.abs(x), np.abs(y))) / .12, 0, 1)
    save("Bar_Glow_128", light(halo))

    x, y, _, _ = grid(32)
    dots = np.zeros_like(x)
    for cx in (-.22, .22):
        for cy in (-.72, -.36, 0, .36, .72):
            dots = np.maximum(dots, np.clip((.075 - np.hypot(x-cx, y-cy)) * 16 + .5, 0, 1))
    save("Bar_Grip_32", light(dots))
    y, x = np.mgrid[:64, :8].astype(float)
    fade = np.sin(np.pi * (y + .5) / 64) ** 1.5
    save("Bar_Divider_8x64", light(np.exp(-((x - 3.5) / .7) ** 2) * fade))


if __name__ == "__main__":
    main()
