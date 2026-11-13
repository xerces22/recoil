"""Floor kit: write tower floors (.tscn) from short Python descriptions.

Coordinates are the game's: x right, y down, the ground slab's top at y = 560.
Ledges are given by their TOP edge and centre x, because that's what you measure jumps from.

Naming: surfaces and rings on the intended route are named P01_, P02_, ... in order, so
tools/floor_solver.py can check the intended path jump by jump.

Usage from tools/build_floors.py:
    f = Floor("Chimney", title=..., hint=..., bounds=(x, y, w, h))
    f.ledge("P01_Step", cx=400, top=440, w=160)
    ...
    f.write("levels/level_02_chimney.tscn")
"""
import math

SCRIPTS = {
    "level": "res://hazards/level.gd",
    "block": "res://hazards/block.gd",
    "checkpoint": "res://hazards/checkpoint.gd",
    "spikes": "res://hazards/spikes.gd",
    "bouncy": "res://hazards/bouncy.gd",
    "mover": "res://hazards/mover.gd",
    "crumble": "res://hazards/crumble.gd",
    "shooter": "res://hazards/shooter.gd",
    "mouth": "res://hazards/mouth.gd",
    "rising": "res://hazards/rising.gd",
    "refill": "res://hazards/refill.gd",
    "orb": "res://hazards/orb.gd",
}

SLAB_TOP = 560
SLAB_H = 32
HOLE = 192
CEIL_H = 32


def _num(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    if isinstance(v, float):
        return f"{v:.4f}".rstrip("0").rstrip(".")
    return str(v)


def _val(v):
    if isinstance(v, str):
        return v if v.startswith(("Vector2(", "Rect2(", "ExtResource(")) else '"' + v.replace('"', '\\"') + '"'
    if isinstance(v, tuple) and len(v) == 2:
        return f"Vector2({_num(float(v[0]))}, {_num(float(v[1]))})"
    return _num(v)


class Floor:
    def __init__(self, node_name, title, hint, bounds, taunt="", is_final=False, notes=""):
        self.node_name = node_name
        self.title = title
        self.hint = hint
        self.taunt = taunt
        self.is_final = is_final
        self.bounds = bounds  # (x, y, w, h)
        self.notes = notes
        self.nodes = []  # (name, type, script, props)
        self.names = set()

    # ---------- low level ----------
    def add(self, name, typ, script, **props):
        base, i = name, 2
        while name in self.names:
            name = f"{base}{i}"
            i += 1
        self.names.add(name)
        self.nodes.append((name, typ, script, props))
        return name

    def marker(self, name, x, y):
        self.add(name, "Marker2D", None, position=(x, y))

    def rect(self, name, x0, y0, x1, y1, kind="block", **props):
        """Solid rectangle from its edges."""
        typ = {"block": "StaticBody2D", "checkpoint": "StaticBody2D", "crumble": "StaticBody2D",
               "bouncy": "StaticBody2D", "mover": "AnimatableBody2D"}[kind]
        return self.add(name, typ, kind, position=((x0 + x1) / 2, (y0 + y1) / 2), size=(x1 - x0, y1 - y0), **props)

    # ---------- surfaces ----------
    def ledge(self, name, cx, top, w=160, h=16, kind="block", **props):
        return self.rect(name, cx - w / 2, top, cx + w / 2, top + h, kind, **props)

    def checkpoint(self, name, cx, top, w=192, **props):
        return self.ledge(name, cx, top, w, 16, "checkpoint", **props)

    def crumble(self, name, cx, top, w=128, delay=0.5, regrow=2.5):
        return self.ledge(name, cx, top, w, 16, "crumble", delay=delay, regrow=regrow)

    def pad(self, name, cx, top, w=128, h=12, **props):
        return self.ledge(name, cx, top, w, h, "bouncy", **props)

    def mover(self, name, cx, top, w=128, travel=(300, 0), period=4.0, phase=0.0, wait=False):
        props = dict(travel=travel, period=period)
        if phase:
            props["phase"] = phase
        if wait:
            props["wait_for_player"] = True
        return self.ledge(name, cx, top, w, 16, "mover", **props)

    # ---------- hazards ----------
    def spikes_up(self, name, x0, surface_y, width, height=26):
        """Spikes sitting on a surface whose top is surface_y, from x0 to the right."""
        return self.add(name, "Area2D", "spikes", position=(x0, surface_y), width=float(width), height=float(height))

    def spikes_down(self, name, x0, under_y, width, height=26):
        """Spikes hanging under a surface whose bottom is under_y, from x0 to the right."""
        # Rotated 180 deg: origin is the row's bottom-left before rotation, so it becomes the right end.
        return self.add(name, "Area2D", "spikes", position=(x0 + width, under_y), rotation=math.pi,
                        width=float(width), height=float(height))

    def spikes_left(self, name, face_x, y0, length, height=26):
        """Spikes on a wall's left face (pointing left), from y0 down for `length`."""
        return self.add(name, "Area2D", "spikes", position=(face_x, y0 + length), rotation=-math.pi / 2,
                        width=float(length), height=float(height))

    def spikes_right(self, name, face_x, y0, length, height=26):
        """Spikes on a wall's right face (pointing right), from y0 down for `length`."""
        return self.add(name, "Area2D", "spikes", position=(face_x, y0), rotation=math.pi / 2,
                        width=float(length), height=float(height))

    def blocker(self, name, cx, top, w=80, h=20):
        """A small block with spikes on top: put it in the straight-up line to force an arc."""
        self.rect(name, cx - w / 2, top, cx + w / 2, top + h)
        self.spikes_up(name + "Spikes", cx - w / 2, top, w)

    def ring(self, name, x, y, amount=2, respawn=3.0, travel=None, period=3.0, phase=0.0):
        props = {}
        if amount != 2:
            props["amount"] = amount
        if respawn != 3.0:
            props["respawn_time"] = float(respawn)
        if travel:
            props["travel"] = travel
            props["period"] = period
            if phase:
                props["phase"] = phase
        return self.add(name, "Node2D", "refill", position=(x, y), **props)

    def turret(self, name, x, y, angle=0.0, interval=1.8, speed=260, burst=1, aimed=False, phase=0.0, mount=True):
        """A turret on a small mount block. angle: 0 right, pi/2 down, pi left, -pi/2 up."""
        if mount:
            back = (-math.cos(angle) * 10, -math.sin(angle) * 10)
            w, h = (24, 56) if abs(math.cos(angle)) > 0.5 else (56, 24)
            self.rect(name + "Mount", x + back[0] - w / 2, y + back[1] - h / 2, x + back[0] + w / 2, y + back[1] + h / 2)
        props = dict(interval=float(interval), bullet_speed=float(speed))
        if angle:
            props["rotation"] = angle
        if burst != 1:
            props["burst"] = burst
        if aimed:
            props["aimed"] = True
        if phase:
            props["phase"] = phase
        return self.add(name, "Node2D", "shooter", position=(x, y), **props)

    def mouth(self, name, x, y, gap=(140, 36), open_time=1.6, warn_time=0.5, shut_time=0.6, phase=0.0, rotation=0.0):
        props = dict(gap=gap, open_time=float(open_time), warn_time=float(warn_time), shut_time=float(shut_time))
        if phase:
            props["phase"] = phase
        if rotation:
            props["rotation"] = rotation
        return self.add(name, "Node2D", "mouth", position=(x, y), **props)

    def gate(self, name, y, x0, x1, holes, thick=20, names=None, **mouth_props):
        """A full-width floor from x0 to x1 (top at y) with mouths guarding holes.
        holes: list of (centre_x, width) or (centre_x, width, extra mouth props).
        names: {segment index: name} to name floor segments (0 = left of the first hole, 1 = after it, ...),
        e.g. {1: "P01_GateA"} to put a gate's top on the intended route."""
        names = names or {}
        cur = x0
        for i, h in enumerate(sorted(holes)):
            hx, hw = h[0], h[1]
            extra = dict(mouth_props)
            if len(h) > 2:
                extra.update(h[2])
            if hx - hw / 2 > cur:
                self.rect(names.get(i, f"{name}Floor{i}"), cur, y, hx - hw / 2, y + thick)
            self.mouth(f"{name}Mouth{i}", hx, y + thick / 2, gap=(hw, 36), **extra)
            cur = hx + hw / 2
        if cur < x1:
            self.rect(names.get(len(holes), f"{name}FloorEnd"), cur, y, x1, y + thick)

    def flood(self, trigger_y, speed=50.0, acceleration=2.5, start_gap=380.0, max_gap=460.0, checkpoint_gap=300.0):
        return self.add("Flood", "Node2D", "rising", trigger_y=float(trigger_y), speed=float(speed),
                        acceleration=float(acceleration), start_gap=float(start_gap), max_gap=float(max_gap),
                        checkpoint_gap=float(checkpoint_gap))

    def orb(self, name, x, y, spots):
        return self.add(name, "Node2D", "orb", position=(x, y), spots="Array[Vector2]([" + ", ".join(
            f"Vector2({_num(float(a))}, {_num(float(b))})" for a, b in spots) + "])")

    # ---------- frame: walls, slab with entry hole, ceiling with exit hole ----------
    def frame(self, entry_x=None, exit_x=None, start_x=None, ground_x=None):
        """Side walls, the bottom slab (with an entry hole unless this is floor 1) and the top ceiling
        (with an exit hole unless exit_x is None)."""
        bx, by, bw, bh = self.bounds
        x0, x1, top, bottom = bx, bx + bw, by, by + bh
        self.rect("WallLeft", x0, top, x0 + 32, bottom)
        self.rect("WallRight", x1 - 32, top, x1, bottom)
        if entry_x is not None:
            self.marker("Entry", entry_x, SLAB_TOP + SLAB_H)
            self.rect("SlabLeft", x0 + 32, SLAB_TOP, entry_x - HOLE / 2, SLAB_TOP + SLAB_H)
            self.rect("SlabRight", entry_x + HOLE / 2, SLAB_TOP, x1 - 32, SLAB_TOP + SLAB_H)
        else:
            gx0, gx1 = ground_x or (x0 + 32, x1 - 32)
            self.rect("Ground", gx0, SLAB_TOP, gx1, SLAB_TOP + SLAB_H)
        if exit_x is not None:
            self.marker("Exit", exit_x, top)
            self.rect("CeilingLeft", x0 + 32, top, exit_x - HOLE / 2, top + CEIL_H)
            self.rect("CeilingRight", exit_x + HOLE / 2, top, x1 - 32, top + CEIL_H)
        else:
            self.rect("Ceiling", x0 + 32, top, x1 - 32, top + CEIL_H)
        self.marker("Start", start_x, SLAB_TOP - 14)

    # ---------- cells: draw stone with a 32 px grid and get blocks + spikes ----------
    def cells(self, name, cells, size=32, spike_tops=None, spike_height=18):
        """cells: set of (col, row) grid cells (x = col*size, y = row*size) to fill with stone.
        Merges each row into runs, then stacks equal runs into rectangles.
        spike_tops: set of cells whose top face gets spikes (only exposed tops are used)."""
        rows = {}
        for c, r in cells:
            rows.setdefault(r, []).append(c)
        runs = []
        for r in sorted(rows):
            cs = sorted(rows[r])
            start = prev = cs[0]
            for c in cs[1:] + [None]:
                if c is not None and c == prev + 1:
                    prev = c
                    continue
                runs.append([start, prev, r, r])
                if c is not None:
                    start = prev = c
        # Stack identical column runs on consecutive rows.
        merged = []
        for run in runs:
            for m in merged:
                if m[0] == run[0] and m[1] == run[1] and m[3] == run[2] - 1:
                    m[3] = run[3]
                    break
            else:
                merged.append(list(run))
        for i, (c0, c1, r0, r1) in enumerate(merged):
            self.rect(f"{name}{i:02d}", c0 * size, r0 * size, (c1 + 1) * size, (r1 + 1) * size)
        if spike_tops:
            tops = sorted(c for c in spike_tops if c in cells and (c[0], c[1] - 1) not in cells)
            rowsk = {}
            for c, r in tops:
                rowsk.setdefault(r, []).append(c)
            k = 0
            for r in sorted(rowsk):
                cs = sorted(rowsk[r])
                start = prev = cs[0]
                for c in cs[1:] + [None]:
                    if c is not None and c == prev + 1:
                        prev = c
                        continue
                    self.spikes_up(f"{name}Spikes{k:02d}", start * size, r * size, (prev - start + 1) * size, spike_height)
                    k += 1
                    if c is not None:
                        start = prev = c

    # ---------- output ----------
    def write(self, path):
        used = {"level"} | {s for _, _, s, _ in self.nodes if s}
        out = ["[gd_scene format=3]", ""]
        for key in ["level", "block", "checkpoint", "crumble", "bouncy", "mover", "spikes", "refill",
                    "shooter", "mouth", "rising", "orb"]:
            if key in used:
                out.append(f'[ext_resource type="Script" path="{SCRIPTS[key]}" id="{key}"]')
        out.append("")
        bx, by, bw, bh = self.bounds
        out.append(f'[node name="{self.node_name}" type="Node2D"]')
        if self.notes:
            out.append("editor_description = " + _val(self.notes.strip()))
        out.append('script = ExtResource("level")')
        out.append("title = " + _val(self.title))
        out.append("hint = " + _val(self.hint))
        if self.taunt:
            out.append("taunt = " + _val(self.taunt))
        if self.is_final:
            out.append("is_final = true")
        out.append(f"bounds = Rect2({_num(float(bx))}, {_num(float(by))}, {_num(float(bw))}, {_num(float(bh))})")
        out.append("")
        for name, typ, script, props in self.nodes:
            out.append(f'[node name="{name}" type="{typ}" parent="."]')
            props = dict(props)
            for key in ("position", "rotation"):
                if key in props:
                    out.append(f"{key} = {_val(props.pop(key))}")
            if script:
                out.append(f'script = ExtResource("{script}")')
            for k, v in props.items():
                out.append(f"{k} = {_val(v)}")
            out.append("")
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(out))
        return path
