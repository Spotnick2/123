"""Generate the wheel bead's ring textures (Media/Bead_*.tga), 128x128 RGBA.

A 3D model can't be masked (MaskTextures clip textures only), so a bead
hides its portrait's square edges under an opaque ring: the model is drawn
in the square inscribed in the bead and only the ring's hole shows it.

  Bead_Ring_128.tga  white, opaque between INNER and OUTER (tinted dark)
  Bead_Edge_128.tga  white, thin lines on both edges of the ring (tinted fel)

Placeholders until the Codex bead frames (#13). Run from the repo root:
    python Tools/make_bead_ring.py
"""
import math
import os
import struct

SIZE = 128
OUTER = 63.0                 # just inside the texture's edge
INNER = OUTER * 0.70         # the hole: the inscribed circle of the model's square
EDGE = 1.6                   # edge line half-width, px


def coverage(d, r0, r1):
    """Anti-aliased coverage of a pixel centre at distance d for r0 <= r <= r1."""
    return max(0.0, min(1.0, d - r0 + 0.5)) * max(0.0, min(1.0, r1 - d + 0.5))


def write_tga(path, alpha):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8 | 0x20)
    with open(path, "wb") as f:
        f.write(header)
        for y in range(SIZE):
            for x in range(SIZE):
                a = int(round(255 * alpha(x, y)))
                f.write(bytes((255, 255, 255, a)))


def dist(x, y):
    c = (SIZE - 1) / 2.0
    return math.hypot(x - c, y - c)


def main():
    os.makedirs("Media", exist_ok=True)
    write_tga("Media/Bead_Ring_128.tga", lambda x, y: coverage(dist(x, y), INNER, OUTER))
    write_tga("Media/Bead_Edge_128.tga", lambda x, y: max(
        coverage(dist(x, y), INNER - EDGE, INNER + EDGE),
        coverage(dist(x, y), OUTER - 2 * EDGE, OUTER)))


if __name__ == "__main__":
    main()
