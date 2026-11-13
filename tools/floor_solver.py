"""Floor solver: proves a floor is beatable and measures how hard each jump is.

Usage:  python tools/floor_solver.py levels/floor_02_tunnel.tscn [--verbose]

It reads the .tscn, then simulates shots from every surface the player can stand on,
using the game's numbers (580 px/s full shot, 380 px/s tap, gravity 880, 60 physics
steps a second, player radius 12). From each surface it tries:
  - one shot (full, half or tap power) in 72 directions (216 tries),
  - two shots: the first in 19 upward directions, the second in 36 directions,
    0.2 to 1.7 s later (7524 tries).
Flying through a refill ring keeps your speed and gives shells back; from a ring the
next shot can wait 0 to 0.45 s.

It reports:
  - the cheapest route from Start to the goal (Exit hole, finish platform or orb room),
  - the intended path, if surfaces are named in order: P01_..., P02_..., and so on,
  - every jump's fewest shells and its "ways": how many of the tried shots make it.
    2-shell jumps: under 15 ways is precise, 15-60 fair, 60+ easy.
    1-shell jumps (216 tries): under 6 ways is precise, 6-20 fair, 20+ easy.
  - dead ends: surfaces you can land on but can't get out of toward the goal.

Not simulated: moving platforms move (they're tried at both ends of their path),
crumble timing, turret bolts, mouth timing, the flood, and the barrel wiggle.
Collision treats the player as a 24x24 square, a little stricter than the real
circle at corners, so "reachable" here should be reachable in the game.
"""
import heapq
import math
import re
import sys
from dataclasses import dataclass, field

import numpy as np

GRAVITY = 880.0
FULL = 580.0
TAP = 380.0
MID = 480.0
DT = 1.0 / 60.0
R = 12.0
MAX_TIME = 2.8
SPIKE_GROW = 12.0  # spikes' kill area grows by the player radius
RING_RADIUS = 14.0

UP_DIRS = [math.radians(a) for a in range(180, 361, 10)]  # 19 directions, upper half
ALL_DIRS = [math.radians(a) for a in range(0, 360, 10)]  # 36 directions
FINE_DIRS = [math.radians(a) for a in range(0, 360, 5)]  # 72 directions, for single shots
SECOND_DELAYS = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.85, 1.0, 1.2, 1.45, 1.7]
RING_WAITS = [0.0, 0.15, 0.3, 0.45]


@dataclass
class Rect:
    name: str
    x0: float
    y0: float
    x1: float
    y1: float
    kind: str  # solid, bouncy
    strength: float = 1.0
    min_speed: float = 420.0
    stand: bool = True


@dataclass
class Floor:
    title: str = ""
    bounds: tuple = (0, -20000, 1280, 20720)
    solids: list = field(default_factory=list)
    spikes: list = field(default_factory=list)
    rings: list = field(default_factory=list)  # (name, x, y, amount)
    start: tuple = None
    exit: tuple = None
    entry: tuple = None
    finish: list = field(default_factory=list)
    notes: list = field(default_factory=list)


def _vec(s):
    m = re.search(r"Vector2\(([-\d.e]+),\s*([-\d.e]+)\)", s)
    return (float(m.group(1)), float(m.group(2))) if m else None


def parse(path):
    text = open(path, encoding="utf-8").read().replace("\r\n", "\n")
    ids = {i: n for n, i in re.findall(r'path="res://(?:hazards/)?(\w+)\.gd" id="(\w+)"', text)}
    f = Floor()
    for block in text.split("\n[node ")[1:]:
        lines = block.strip().split("\n")
        name = re.search(r'name="([^"]+)"', lines[0]).group(1)
        parent = re.search(r'parent="([^"]*)"', lines[0])
        props = {}
        for line in lines[1:]:
            if " = " in line:
                k, v = line.split(" = ", 1)
                props[k] = v
        script = re.search(r'"(\w+)"', props.get("script", ""))
        kind = ids.get(script.group(1)) if script else None
        if parent is None:
            f.title = props.get("title", "").strip('"')
            b = re.search(r"Rect2\(([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)\)", props.get("bounds", ""))
            if b:
                f.bounds = tuple(float(x) for x in b.groups())
            continue
        if parent.group(1) != ".":
            continue
        pos = _vec(props.get("position", "Vector2(0, 0)"))
        rot = float(props.get("rotation", "0"))
        if name == "Start":
            f.start = pos
        elif name == "Exit":
            f.exit = pos
        elif name == "Entry":
            f.entry = pos
        elif kind in ("block", "checkpoint", "crumble", "bouncy", "mover"):
            size = _vec(props.get("size", "Vector2(160, 16)"))
            if abs(rot) > 0.01:
                f.notes.append(f"{name}: rotated {kind} not simulated")
                continue
            positions = [pos]
            if kind == "mover":
                travel = _vec(props.get("travel", "Vector2(0, -200)"))
                positions = [pos, (pos[0] + travel[0], pos[1] + travel[1])]
            for i, p in enumerate(positions):
                rname = name if len(positions) == 1 else f"{name}@{'start' if i == 0 else 'end'}"
                f.solids.append(Rect(rname, p[0] - size[0] / 2, p[1] - size[1] / 2, p[0] + size[0] / 2,
                                     p[1] + size[1] / 2, "bouncy" if kind == "bouncy" else "solid",
                                     float(props.get("strength", 1.0)), float(props.get("min_speed", 420.0)),
                                     stand=kind != "bouncy"))
            if kind == "checkpoint" and props.get("is_finish") == "true":
                f.finish.append(name)
        elif kind == "spikes":
            w = float(props.get("width", 60))
            h = float(props.get("height", 26))
            x, y = pos
            r = round(rot / (math.pi / 2)) % 4
            box = [(x, y - h, x + w, y), (x, y, x + h, y + w), (x - w, y, x, y + h), (x - h, y - w, x, y)][r]
            f.spikes.append((name, *box))
        elif kind == "refill":
            f.rings.append((name, pos[0], pos[1], int(props.get("amount", 2))))
        elif kind == "orb":
            f.notes.append("orb: the goal is standing in the orb room (hits are not simulated)")
    return f


class Sim:
    def __init__(self, f: Floor):
        self.f = f
        s = f.solids
        self.sx0 = np.array([r.x0 - R for r in s])
        self.sy0 = np.array([r.y0 - R for r in s])
        self.sx1 = np.array([r.x1 + R for r in s])
        self.sy1 = np.array([r.y1 + R for r in s])
        self.bouncy = np.array([r.kind == "bouncy" for r in s])
        self.strength = np.array([r.strength for r in s])
        self.minspd = np.array([r.min_speed for r in s])
        k = f.spikes
        self.kx0 = np.array([b[1] - SPIKE_GROW for b in k])
        self.ky0 = np.array([b[2] - SPIKE_GROW for b in k])
        self.kx1 = np.array([b[3] + SPIKE_GROW for b in k])
        self.ky1 = np.array([b[4] + SPIKE_GROW for b in k])
        bx, by, bw, bh = f.bounds
        self.left, self.right, self.bottom = bx - 24, bx + bw + 24, by + bh + 20

    def run(self, x, y, v0, shots, skip_ring=-1):
        """shots: rows of (t1, vx1, vy1, t2, vx2, vy2); t2 < 0 means no second shot.
        Returns landed index, died, exited, ring index, ring velocity x/y per row."""
        a = np.array(shots, dtype=float).reshape(len(shots), 6)
        n = len(a)
        px, py = np.full(n, x), np.full(n, y)
        vx, vy = np.full(n, v0[0]), np.full(n, v0[1])
        t1, t2 = a[:, 0], a[:, 3]
        fired1 = np.zeros(n, bool)
        fired2 = t2 < 0
        alive = np.ones(n, bool)
        landed = np.full(n, -1)
        ring_hit = np.full(n, -1)
        ring_v = np.zeros((n, 2))
        died = np.zeros(n, bool)
        exited = np.zeros(n, bool)
        f = self.f
        if f.exit is not None:
            ex0, ex1, ey = f.exit[0] - 96 + R, f.exit[0] + 96 - R, f.exit[1] - 24
        ns = len(self.sx0)
        for step in range(int(MAX_TIME / DT)):
            t = step * DT
            go = alive.copy()
            if not go.any():
                break
            for fired, tt, c in ((fired1, t1, 1), (fired2, t2, 4)):
                fire = go & ~fired & (t >= tt)
                if c == 4:
                    fire &= fired1
                if fire.any():
                    vx[fire] = a[fire, c]
                    vy[fire] = a[fire, c + 1]
                    fired |= fire
            vy[go] += GRAVITY * DT
            nx = px + vx * DT
            ny = py + vy * DT
            if ns:
                ov = (nx[:, None] > self.sx0) & (nx[:, None] < self.sx1) & (ny[:, None] > self.sy0) & (ny[:, None] < self.sy1)
                ov &= go[:, None]
                rows = np.where(ov.any(axis=1))[0]
                for i in rows:
                    for jj in np.where(ov[i])[0]:
                        above = py[i] <= self.sy0[jj] + 0.5
                        below = py[i] >= self.sy1[jj] - 0.5
                        if self.bouncy[jj]:
                            if above or below:
                                out = max(abs(vy[i]) * self.strength[jj], self.minspd[jj])
                                vy[i] = -out if above else out
                                ny[i] = py[i]
                            else:
                                out = max(abs(vx[i]) * self.strength[jj], self.minspd[jj])
                                vx[i] = -out if px[i] < (self.sx0[jj] + self.sx1[jj]) / 2 else out
                                nx[i] = px[i]
                            break
                        if above and vy[i] >= 0:
                            ny[i] = self.sy0[jj]
                            landed[i] = jj
                            alive[i] = False
                            break
                        if below and vy[i] < 0:
                            ny[i] = self.sy1[jj]
                            vy[i] = 0.0
                        else:
                            nx[i] = px[i]
                            vx[i] = 0.0
            px, py = np.where(go, nx, px), np.where(go, ny, py)
            if len(self.kx0):
                kill = ((px[:, None] > self.kx0) & (px[:, None] < self.kx1) & (py[:, None] > self.ky0) & (py[:, None] < self.ky1)).any(axis=1)
                kill &= go
                died |= kill
                alive &= ~kill
                landed[kill] = -1
            out = go & ((px < self.left) | (px > self.right) | (py > self.bottom))
            died |= out
            alive &= ~out
            landed[out] = -1
            if f.exit is not None:
                ex = go & alive & (py < ey) & (px > ex0) & (px < ex1)
                exited |= ex
                alive &= ~ex
            for ri, (_, rx, ry, _amount) in enumerate(f.rings):
                if ri == skip_ring:
                    continue
                # Only counts once a shot was spent, so the ring gives something back.
                near = go & alive & fired1 & ((px - rx) ** 2 + (py - ry) ** 2 <= (RING_RADIUS + R) ** 2)
                if near.any():
                    ring_hit[near] = ri
                    ring_v[near, 0] = vx[near]
                    ring_v[near, 1] = vy[near]
                    alive &= ~near
        return landed, died, exited, ring_hit, ring_v


def plans(shells, waits=(0.0,)):
    out = []
    for w in waits:
        for power in (FULL, MID, TAP):
            for d in FINE_DIRS:
                out.append((w, power * math.cos(d), power * math.sin(d), -1, 0, 0))
    singles = len(out)
    if shells >= 2:
        for w in waits:
            for d1 in UP_DIRS if w == 0 else ALL_DIRS[::2]:
                for t2 in SECOND_DELAYS:
                    for d2 in ALL_DIRS:
                        out.append((w, FULL * math.cos(d1), FULL * math.sin(d1), w + t2, FULL * math.cos(d2), FULL * math.sin(d2)))
    return out, singles


def standing_spots(sim, i):
    """Places to stand on surface i. The player can't walk, but taps reposition them."""
    r = sim.f.solids[i]
    w = r.x1 - r.x0
    xs = [(r.x0 + r.x1) / 2]
    if w > 60:
        xs += [r.x0 + 18, r.x1 - 18]
    if w > 300:
        xs += [r.x0 + w * 0.3, r.x0 + w * 0.7]
    spots = []
    for x in xs:
        y = r.y0 - R - 0.5
        inside = len(sim.sx0) and ((x > sim.sx0) & (x < sim.sx1) & (y > sim.sy0) & (y < sim.sy1)).any()
        in_spike = len(sim.kx0) and ((x > sim.kx0) & (x < sim.kx1) & (y > sim.ky0) & (y < sim.ky1)).any()
        if not inside and not in_spike:
            spots.append((x, y))
    return spots


def solve(path, verbose=False):
    f = parse(path)
    sim = Sim(f)
    solids = f.solids
    EXIT = "EXIT"
    edges = {}  # (a, b) -> (fewest shells, ways with that many)
    both = {}  # (a, b) -> {shells: best ways}

    def add(a, b, shells, ways):
        d = both.setdefault((a, b), {})
        d[shells] = max(d.get(shells, 0), ways)
        old = edges.get((a, b))
        if old is None or shells < old[0] or (shells == old[0] and ways > old[1]):
            edges[(a, b)] = (shells, ways)

    ring_entry = {}  # ring index -> best (most upward) arrival velocity
    examples = {}  # (a, b) -> list of working plans, for tools/replay_floor.gd

    def keep(a, b, x, y, v0, shells, rows, shot_list, skip_ring):
        lst = examples.setdefault((a, b), [])
        if len(lst) >= 40:
            return
        step = max(1, len(rows) // 8)
        for k in rows[::step][:8]:
            lst.append({"src": a, "dst": b, "x": x, "y": y, "vx": float(v0[0]), "vy": float(v0[1]), "shells": shells,
                        "skip_ring": f.rings[skip_ring][0] if skip_ring >= 0 else "",
                        "plan": [float(v) for v in shot_list[k]]})

    def explore(name, x, y, v0, shells, waits, skip_ring=-1):
        shot_list, singles = plans(shells, waits)
        landed, died, exited, ring, ring_v = sim.run(x, y, v0, shot_list, skip_ring)
        for lo, hi, need in ((0, singles, 1), (singles, len(shot_list), 2)):
            if hi <= lo:
                continue
            seg_l, seg_e, seg_r = landed[lo:hi], exited[lo:hi], ring[lo:hi]
            for j in set(seg_l[seg_l >= 0].tolist()):
                if solids[j].name != name:
                    add(name, solids[j].name, need, int((seg_l == j).sum()))
                    keep(name, solids[j].name, x, y, v0, shells, (np.where(seg_l == j)[0] + lo).tolist(), shot_list, skip_ring)
            if seg_e.any():
                add(name, EXIT, need, int(seg_e.sum()))
                keep(name, EXIT, x, y, v0, shells, (np.where(seg_e)[0] + lo).tolist(), shot_list, skip_ring)
            for rj in set(seg_r[seg_r >= 0].tolist()):
                add(name, f.rings[rj][0], need, int((seg_r == rj).sum()))
                keep(name, f.rings[rj][0], x, y, v0, shells, (np.where(seg_r == rj)[0] + lo).tolist(), shot_list, skip_ring)
                vs = ring_v[lo:hi][seg_r == rj]
                best = vs[vs[:, 1].argmin()]
                if rj not in ring_entry or best[1] < ring_entry[rj][1]:
                    ring_entry[rj] = best

    for i, r in enumerate(solids):
        if r.stand:
            for (x, y) in standing_spots(sim, i):
                explore(r.name, x, y, (0.0, 0.0), 2, (0.0,))
    # Riding a moving platform carries you between the two ends of its path.
    for r in solids:
        if r.name.endswith("@start"):
            base = r.name[: -len("@start")]
            add(r.name, base + "@end", 0, 999)
            add(base + "@end", r.name, 0, 999)
    # Rings: explore from each ring reached, repeating while new rings get reached.
    done = set()
    while True:
        todo = [ri for ri in ring_entry if ri not in done]
        if not todo:
            break
        for ri in todo:
            done.add(ri)
            name, x, y, amount = f.rings[ri]
            explore(name, x, y, tuple(ring_entry[ri]), amount, RING_WAITS, skip_ring=ri)

    start = None
    if f.start:
        best = None
        for r in solids:
            if r.x0 - 4 <= f.start[0] <= r.x1 + 4 and r.y0 >= f.start[1]:
                d = r.y0 - f.start[1]
                if best is None or d < best[0]:
                    best = (d, r.name)
        start = best[1] if best else None
    goals = set(f.finish)
    if f.exit:
        goals = {EXIT}

    adj = {}
    for (a, b), (sh, ways) in edges.items():
        adj.setdefault(a, []).append((b, sh * 10 + 9.0 / (1.0 + ways)))
    dist, prev, pq = {start: 0.0}, {}, [(0.0, start)]
    while pq:
        d, u = heapq.heappop(pq)
        if d > dist.get(u, 1e9):
            continue
        for v, c in adj.get(u, []):
            if d + c < dist.get(v, 1e9):
                dist[v] = d + c
                prev[v] = u
                heapq.heappush(pq, (d + c, v))
    reach = set(dist)
    route = []
    hit = [g for g in goals if g in reach]
    if hit:
        g = min(hit, key=lambda x: dist[x])
        while g != start:
            route.append(g)
            g = prev[g]
        route.append(start)
        route.reverse()

    radj = {}
    for (a, b) in edges:
        radj.setdefault(b, []).append(a)
    can_finish, stack = set(goals), list(goals)
    while stack:
        u = stack.pop()
        for v in radj.get(u, []):
            if v not in can_finish:
                can_finish.add(v)
                stack.append(v)
    dead = sorted(x for x in reach if x not in can_finish and x not in goals)

    via_key = {}

    def show(a, b, e, via=""):
        if e is None:
            return f"     {a:>24} -> {b:<24} !! NOT POSSIBLE"
        if e[0] == 0:
            return f"     {a:>24} -> {b:<24} ride the platform"
        d = both.get((a, b)) or both.get(via_key.get((a, b)), {}) or {e[0]: e[1]}
        one = f"1 shell {d[1]:4d} ways" if 1 in d else "1 shell   --     "
        two = f"2 shells {d[2]:5d} ways" if 2 in d else "2 shells    --    "
        return f"     {a:>24} -> {b:<24} {one}   {two}{via}"

    print(f"== {path}  ({f.title})")
    for note in f.notes:
        print("   note:", note)
    print(f"   start: {start}   goal: {sorted(goals)}")
    if route:
        print("   CHEAPEST ROUTE:")
        for a, b in zip(route, route[1:]):
            print(show(a, b, edges[(a, b)]))
    else:
        print("   !! NO ROUTE to the goal")
    numbered = list(dict.fromkeys(sorted((r.name.split("@")[0] for r in solids if re.match(r"P\d\d", r.name)))))
    numbered += [r[0] for r in f.rings if re.match(r"P\d\d", r[0])]
    numbered = sorted(set(numbered), key=lambda s: s[:3])
    if numbered:
        print("   INTENDED PATH:")
        chain = [start] + [x for x in numbered if x != start] + (sorted(goals)[:1])

        def best_edge(a, b):
            cands = [(k, v) for k, v in edges.items() if k[0].split("@")[0] == a and k[1].split("@")[0] == b]
            if not cands:
                return None
            k, v = min(cands, key=lambda kv: (kv[1][0], -kv[1][1]))
            via_key[(a, b)] = k
            return v

        for a, b in zip(chain, chain[1:]):
            print(show(a, b, best_edge(a, b)))
        if PLANS_OUT:
            import json
            hops = []
            for a, b in zip(chain, chain[1:]):
                key = via_key.get((a, b))
                cands = [k for k in examples if k[0].split("@")[0] == a and k[1].split("@")[0] == b]
                plans_ab = []
                for k in ([key] if key in examples else []) + [k for k in cands if k != key]:
                    plans_ab += examples[k]
                hops.append({"from": a, "to": b, "plans": plans_ab[:24]})
            with open(PLANS_OUT, "w") as fh:
                json.dump({"floor": path, "hops": hops}, fh)
            print(f"   plans for {len(hops)} hops written to {PLANS_OUT}")
    print(f"   dead ends: {dead if dead else 'none'}")
    unreached = sorted(r.name for r in solids if r.stand and r.name not in reach)
    print(f"   never landed on: {unreached if unreached else 'none'}")
    if verbose:
        print("   ALL JUMPS:")
        for (a, b), e in sorted(edges.items()):
            print(show(a, b, e))
    return bool(route), route, edges, dead


PLANS_OUT = None

if __name__ == "__main__":
    for a in sys.argv:
        if a.startswith("--plans="):
            PLANS_OUT = a.split("=", 1)[1]
    ok = True
    for p in [a for a in sys.argv[1:] if not a.startswith("--")]:
        found, *_ = solve(p, "--verbose" in sys.argv)
        ok &= found
    sys.exit(0 if ok else 1)
