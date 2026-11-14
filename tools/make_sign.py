# Draws the wooden signpost used for tutorial and mechanic signs (original art, castle palette).
# Usage: python -I tools/make_sign.py assets/sprites/props/sign_wood.png
import sys

from PIL import Image

OUTLINE = (42, 18, 32, 255)
WOOD = (138, 74, 42, 255)
LIGHT = (184, 106, 58, 255)
DARK = (107, 58, 34, 255)
POST = (90, 48, 32, 255)
NAIL = (232, 192, 112, 255)
INK = (58, 26, 20, 255)

W, H = 22, 24
im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = im.load()

# Post first, so the board sits over it.
for y in range(12, H):
    for x in range(9, 13):
        px[x, y] = OUTLINE if x in (9, 12) or y == H - 1 else POST
# Board: 22 x 13 with a 1 px outline.
for y in range(0, 13):
    for x in range(W):
        edge = x in (0, W - 1) or y in (0, 12)
        px[x, y] = OUTLINE if edge else WOOD
for x in range(1, W - 1):
    px[x, 1] = LIGHT          # top highlight
    px[x, 11] = DARK          # bottom shade
# Carved "writing": three short lines.
for y, (x0, x1) in ((4, (4, 17)), (6, (4, 14)), (8, (4, 16))):
    for x in range(x0, x1 + 1):
        if (x + y) % 5 != 0:
            px[x, y] = INK
# Nails.
px[2, 2] = NAIL
px[W - 3, 2] = NAIL
im.save(sys.argv[1])
