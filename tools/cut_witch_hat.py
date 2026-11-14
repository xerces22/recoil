# Cuts the witch's hat out of the Whimsy Hallow atlas (CC0, Crumpaloo) for Mrs. Sandwitch.
# Usage: python -I tools/cut_witch_hat.py <atlas.png> <out.png>
import sys
from PIL import Image

atlas = Image.open(sys.argv[1]).convert("RGBA")
frame = atlas.crop((343, 1721, 361, 1746))  # first idle frame of the purple-hat witch
hat = Image.new("RGBA", (18, 9), (0, 0, 0, 0))
OUTLINE = (0x15, 0, 0, 255)
for y in range(7):
    for x in range(18):
        hat.putpixel((x, y), frame.getpixel((x, y)))
# Row 7: keep the brim ends, close the underside where her hair was.
for x in range(16):
    p = frame.getpixel((x, 7))
    hat.putpixel((x, 7), p if x < 4 or x >= 14 else OUTLINE)
# Row 8: the left tip of the brim.
for x in range(2):
    hat.putpixel((x, 8), frame.getpixel((x, 8)))
hat.save(sys.argv[2])
