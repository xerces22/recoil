import sys, os
from PIL import Image, ImageDraw
src, dst, preview = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(dst, exist_ok=True)
H = lambda s: tuple(int(s[i:i+2], 16) for i in (0, 2, 4)) + (255,)
MAP = {
    (166, 166, 166): H("2a1238"),  # outline
    (220, 229, 236): H("8a3fd1"),  # body
    (237, 242, 245): H("b46cff"),  # sheen
    (255, 255, 255): H("f6e8ff"),  # highlight
    (193, 197, 201): H("4a1f66"),  # inside of the broken shell
}
CRACK = H("1a0a24")
CRACK_EDGE = H("e2c4ff")
CURSE = H("57e08f")
CURSE_DARK = H("2f9a5c")

def recolor(im):
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if p[3] and p[:3] in MAP:
                px[x, y] = MAP[p[:3]]
    return im

ball = recolor(Image.open(os.path.join(src, "ball_only.png")))
px = ball.load()
# Green curse swirl in the lower half, inside the glass.
import math
seen = []
for i in range(400):
    t = i / 399
    a = t * math.tau * 1.6 + 0.6
    r = 0.6 + t * 6.2
    q = (round(16.5 + math.cos(a) * r), round(19.5 + math.sin(a) * r * 0.8))
    if q not in seen:
        seen.append(q)
for i, q in enumerate(seen):
    px[q] = CURSE if i < len(seen) * 0.6 else CURSE_DARK
px[(16, 19)] = H("c8ffd9")

# Crack paths (art pixels), each starting at the rim. Stage n draws the first n.
CRACKS = [
    [(9,4),(10,6),(9,8),(11,10),(12,12)],
    [(28,12),(26,13),(24,12),(22,14),(21,15)],
    [(5,22),(7,21),(8,23),(10,22),(11,24),(12,23)],
    [(20,29),(19,27),(21,25),(20,23),(23,22),(25,24),(26,26)],
    [(3,13),(5,14),(6,12),(8,14),(7,16),(16,6),(17,8),(15,10),(16,12)],
]

def draw_crack(im, pts):
    d = ImageDraw.Draw(im)
    for a, b in zip(pts, pts[1:]):
        if abs(a[0]-b[0]) > 3 or abs(a[1]-b[1]) > 3:
            continue  # a jump to a new branch
        d.line([a, b], fill=CRACK)
    # light edge just below/right of each crack pixel, only on glass
    p = im.load()
    for a in pts:
        e = (a[0] + 1, a[1] + 1)
        if 0 <= e[0] < 32 and 0 <= e[1] < 32 and p[e][3] and p[e] != CRACK and p[e] != H("2a1238"):
            p[e] = CRACK_EDGE

stages = []
for n in range(len(CRACKS) + 1):
    im = ball.copy()
    for c in CRACKS[:n]:
        draw_crack(im, c)
    im.save(os.path.join(dst, f"orb_{n}.png"))
    stages.append(im)

shell = recolor(Image.open(os.path.join(src, "ball_only_broken.png")))
shell.save(os.path.join(dst, "orb_shell.png"))
stages.append(shell)

sc = 8
out = Image.new("RGBA", (len(stages) * (32 * sc + 16), 32 * sc + 16), (30, 22, 40, 255))
for i, im in enumerate(stages):
    out.alpha_composite(im.resize((32 * sc, 32 * sc), Image.NEAREST), (i * (32 * sc + 16) + 8, 8))
out.save(preview)
