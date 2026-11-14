"""Builds the tower's floors. Run:  python tools/build_floors.py [floor numbers...]
Then check each one:            python tools/floor_solver.py levels/level_02_chimney.tscn

Every floor is described below as a function. Coordinates: x right, y down, ground slab top
at y = 560 (see LEVEL_DESIGN.md and LEVEL_DESIGN_PROCESS.md). The design reasoning and the
solver results for each floor are logged in LEVEL_LOG.md.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from floor_kit import Floor  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def out(name):
    return os.path.join(ROOT, "levels", name)


# --------------------------------------------------------------------------------------
# Floor 2: The Chimney. New: shell wisps (refill rings). Shape: across, then a diagonal
# tunnel climbing up-left, its floor lined with spikes, rings down the middle.
# --------------------------------------------------------------------------------------
def floor_02():
    W, TOP = 2240, -1120
    f = Floor("Chimney", title="The Chimney",
              hint="Gold wisps reload your shells in midair. Fly through one, then shoot again.",
              taunt="Smoke goes up the chimney. Shotguns don't.",
              bounds=(0, TOP, W, 720 - TOP),
              notes="Floor 2. New: shell wisps. A: one wisp lifts you to a ledge you can't reach "
                    "with two shells. B: wisps carry you across a spike pit. C: the Chimney, a diagonal "
                    "tunnel going up-left with a spiked floor, wisps down the middle. See LEVEL_LOG.md.")
    f.frame(entry_x=320, exit_x=1104, start_x=128)

    # Section A (teach, cost 0): a ledge 410 px up. Two shells only reach ~380, so the wisp is needed.
    f.ring("P01_Wisp", 640, 380)
    f.ledge("P02_Ledge", cx=880, top=150, w=176)
    f.checkpoint("P03_Checkpoint", cx=1120, top=40)

    # Section B (test, cost 3): cross the spike pit on wisps.
    f.spikes_up("PitSpikes", 1280, 560, 928)
    f.ring("P04_Wisp", 1440, -10, amount=1)
    f.ring("P05_Wisp", 1720, -30, amount=1)
    f.checkpoint("P06_Checkpoint", cx=2032, top=-40, w=224)

    # Section C (twist): the Chimney. Interior band: e0 <= x - y <= e1 (a "\" diagonal going up-left).
    e0, e1 = 2080, 2336
    r_top, r_bot = -27, -5  # rows of 32 px: y from -864 to -160
    walls, spiky = set(), set()
    for r in range(r_top, r_bot + 1):
        for c in range(20, 75):
            e = 32 * (c - r)
            if e0 - 64 <= e < e0:  # floor side (below-left): spiked
                walls.add((c, r))
                spiky.add((c, r))
            elif e1 < e <= e1 + 64:  # ceiling side (above-right)
                walls.add((c, r))
    walls = {(c, r) for c, r in walls if 32 <= c * 32 < W - 32}
    f.cells("Chimney", walls, spike_tops=spiky, spike_height=16)
    mid = (e0 + e1) / 2
    # Five 1-shell wisps 140 px apart up the tunnel's middle line (solver: every hop 14+ ways).
    for i, y in enumerate((-260, -400, -540, -680, -820)):
        f.ring(f"P{7 + i:02d}_Wisp", mid + y, y, amount=1)
    f.ledge("P12_ExitLedge", cx=1104, top=-872, w=224)
    return f.write(out("level_02_chimney.tscn"))


# --------------------------------------------------------------------------------------
# Floor 3: The Chain Lift. New: moving platforms and lifts. Shape: you arrive on the far
# right and ride LEFT across a spike river, climb a lift, then ride back RIGHT on fast
# sliders under a spiked crusher. Every mover is boarded from something that holds still.
# --------------------------------------------------------------------------------------
def floor_03():
    W, TOP = 2880, -1272
    f = Floor("ChainLift", title="The Chain Lift",
              hint="Grey platforms move and still reload you. Yellow-striped lifts wait until you land.",
              taunt="Going up? Not on my lifts, you're not.",
              bounds=(0, TOP, W, 720 - TOP),
              notes="Floor 3. New: moving platforms. A: a slider over safe ground, a waiting lift. "
                    "B: sliders over a spike river going left, then a lift up. C: fast slider back right "
                    "under a spiked crusher. See LEVEL_LOG.md.")
    f.frame(entry_x=2560, exit_x=1824, start_x=2752)

    # Section A (teach, cost 0): the ground under all of it is safe.
    f.mover("P01_Slider", cx=2280, top=440, w=160, travel=(-400, 0), period=4.0)
    # P02 and the lift sit too high to reach from the ground (360+ px), so the slider is required.
    f.ledge("P02_Ledge", cx=1680, top=290, w=176)
    f.mover("P03_Lift", cx=1400, top=190, w=144, travel=(0, -200), period=4.0, wait=True)
    f.checkpoint("P04_Checkpoint", cx=1120, top=-60)

    # Section B (test, cost 3): the spike river runs under everything left of x 1344.
    f.spikes_up("River", 32, 560, 1312)
    f.mover("P05_Slider", cx=820, top=-40, w=144, travel=(-300, 0), period=3.5)
    f.mover("P06_Lift", cx=300, top=-160, w=144, travel=(0, -260), period=3.2, phase=0.5)
    f.checkpoint("P07_Checkpoint", cx=560, top=-560)

    # Section C (twist): a fast slider back to the right. Don't jump straight up at its far end:
    # the crusher's underside is spiked.
    f.mover("P08_Slider", cx=900, top=-660, w=128, travel=(360, 0), period=2.6)
    f.rect("Crusher", 1180, -900, 1340, -868)
    f.spikes_down("CrusherSpikes", 1180, -868, 160)
    f.ledge("P09_Ledge", cx=1560, top=-780, w=144)
    f.ledge("P10_ExitLedge", cx=1824, top=-1000, w=224)
    return f.write(out("level_03_chain_lift.tscn"))


# --------------------------------------------------------------------------------------
# Floor 4: Quiet Please. New: slime pads and bounce walls (never reload). Shape: across the
# hall to the right on a pinball run of pads, up a shaft with bouncy walls, back LEFT on top.
# --------------------------------------------------------------------------------------
def floor_04():
    W, TOP = 3200, -1152
    f = Floor("QuietPlease", title="Quiet Please",
              hint="Green slime bounces you back up but never reloads. Keep your shells for the top of the bounce.",
              taunt="Shhh. This is a library.",
              bounds=(0, TOP, W, 720 - TOP),
              notes="Floor 4 (first Library floor). New: slime pads and bounce walls. A: a strong pad lifts "
                    "you to a ledge two shells can't reach. B: pinball run right, pad to pad over spikes. "
                    "C: shaft with bouncy walls, then back left along the top. See LEVEL_LOG.md.")
    f.frame(entry_x=400, exit_x=1504, start_x=576)

    # Pads aren't named P##: you bounce off them mid-flight, the solver only counts landings.
    # Section A (teach, cost 0): one shot up, fall onto the strong pad, ride the bounce, shoot at the top.
    # min_speed 700: even a barrel-first touch (which only gives min_speed in the real game) throws
    # you ~280 px. Ledge P01 is 415 px up: out of reach for two shells, easy with the pad.
    f.pad("StrongPad", cx=920, top=548, w=448, strength=1.2, min_speed=700.0)
    f.ledge("P01_Ledge", cx=1290, top=145, w=192)
    f.checkpoint("P02_Checkpoint", cx=1240, top=-20)

    # Section B (test, cost 3): pinball run. Pads keep your sideways speed; the floor under them is
    # spiked, and so is the corridor's roof, so nobody walks over the top of it.
    f.rect("PinballFloor", 1440, 330, 2560, 362)
    f.spikes_up("PinballSpikes", 1440, 330, 1120)
    f.rect("PinballRoof", 1440, -330, 2560, -298)
    f.spikes_up("PinballRoofSpikes", 1440, -330, 1120)
    for i, cx in enumerate((1640, 1960, 2280)):
        f.pad(f"PinPad{i + 1}", cx=cx, top=170, w=128)
    f.checkpoint("P03_Checkpoint", cx=2660, top=60)

    # Section C (twist): a shaft with slime walls, then back left along the top.
    f.pad("ShaftWallLeft", cx=2770, top=-560, w=20, h=400)
    f.pad("ShaftWallRight", cx=3150, top=-900, w=20, h=940)
    f.ledge("P04_Ledge", cx=2890, top=-110, w=160)
    f.ledge("P05_Ledge", cx=3050, top=-330, w=144)
    f.checkpoint("P06_Checkpoint", cx=2920, top=-520, w=176)
    f.ledge("P07_Ledge", cx=2520, top=-640, w=144)
    f.blocker("BlockerTop", cx=2330, top=-860, w=96)
    f.ledge("P08_Ledge", cx=2160, top=-720, w=144)
    f.pad("TopPad", cx=1830, top=-600, w=128)
    f.ledge("P09_ExitLedge", cx=1504, top=-880, w=224)
    return f.write(out("level_04_quiet_please.tscn"))


# --------------------------------------------------------------------------------------
# Floor 5: Rotten Shelves. New: crumbling shelves. Shape: a switchback in three legs:
# LEFT over safe floor, RIGHT above a spiked divider into a waiting lift, LEFT on fast crumbles.
# --------------------------------------------------------------------------------------
def floor_05():
    W, TOP = 2560, -1452
    f = Floor("RottenShelves", title="Rotten Shelves",
              hint="Brown shelves crack and fall soon after you land. Don't stop to think on them.",
              taunt="Mind the shelves. They're older than your manners.",
              bounds=(0, TOP, W, 720 - TOP),
              notes="Floor 5. New: crumbling shelves. Switchback: leg 1 left over safe floor, leg 2 right "
                    "above a spiked divider into a waiting lift, leg 3 left on fast crumbles. See LEVEL_LOG.md.")
    f.frame(entry_x=2200, exit_x=1000, start_x=2420)

    # Leg 1 (teach, cost 0): crumbling steps going left; the slab underneath is safe.
    f.crumble("P01_Crumble", cx=1940, top=440, w=144)
    f.crumble("P02_Crumble", cx=1680, top=330, w=144)
    f.crumble("P03_Crumble", cx=1420, top=220, w=144)
    f.checkpoint("P04_Checkpoint", cx=1140, top=110)

    # The divider: a long bookshelf with a spiked top, from x 720 to the right wall.
    f.rect("Divider", 720, -140, W - 32, -108)
    f.spikes_up("DividerSpikes", 720, -140, W - 32 - 720)

    # Leg 2 (test, cost 3): up through the gap on the left, then right above the spiked divider.
    # P05 sits left of the divider's end so the hop up-left to P06 has room to clear it.
    f.crumble("P05_Crumble", cx=700, top=0, w=144)
    f.crumble("P06_Crumble", cx=430, top=-160, w=144)
    f.crumble("P07_Crumble", cx=780, top=-320, w=128)
    f.crumble("P08_Crumble", cx=1060, top=-400, w=128)
    f.crumble("P09_Crumble", cx=1340, top=-440, w=128, delay=0.4)
    f.mover("P10_Lift", cx=1640, top=-460, w=144, travel=(0, -280), period=4.0, wait=True)
    f.checkpoint("P11_Checkpoint", cx=1940, top=-780)

    # Leg 3 (twist): fast crumbles back left, a spiked blocker in the straight-up line.
    f.crumble("P12_Crumble", cx=1640, top=-920, w=128, delay=0.3)
    f.blocker("Blocker", cx=1480, top=-1150, w=96)
    f.crumble("P13_Crumble", cx=1320, top=-1050, w=128, delay=0.3)
    f.ledge("P14_ExitLedge", cx=1000, top=-1180, w=224)
    return f.write(out("level_05_rotten_shelves.tscn"))


# --------------------------------------------------------------------------------------
# Floor 6: Gargoyle Gallery. New: gargoyles (turrets). Exam floor: brings back movers, crumbles
# and spikes. Shape: a lightning bolt of three corridors: RIGHT along the bottom, LEFT through
# the middle, RIGHT across the top. Bolts don't kill; they push you into the spikes.
# --------------------------------------------------------------------------------------
def floor_06():
    W, TOP = 3840, -1012
    f = Floor("GargoyleGallery", title="Gargoyle Gallery",
              hint="Gargoyle bolts don't hurt. They shove you, and the spikes do the rest. Watch the glow before each shot.",
              taunt="My gargoyles never liked your hat either.",
              bounds=(0, TOP, W, 720 - TOP),
              notes="Floor 6 (exam). New: gargoyles. Corridor 1 right: islands over spike patches, a gargoyle "
                    "firing down the corridor. Corridor 2 left: a long slider over spikes under two gargoyles "
                    "firing down. Corridor 3 right: crumbles and an aimed gargoyle. See LEVEL_LOG.md.")
    f.frame(entry_x=400, exit_x=2240, start_x=576)

    # Corridor 1 (teach, cost 1 -> 3): islands on the slab, spike patches between, low roof.
    f.rect("Roof1", 700, 330, 2300, 362)
    f.spikes_up("Roof1Spikes", 700, 330, 1600)  # nobody walks on top of the corridor
    islands = [(820, "P01"), (1220, "P02"), (1620, "P03"), (2020, "P04")]
    for cx, tag in islands:
        f.ledge(f"{tag}_Island", cx=cx, top=536, w=176, h=24)
    for x0 in (908, 1308, 1708, 2108):
        f.spikes_up(f"Patch{x0}", x0, 560, 224)
    # The gargoyle hangs at the roof's end and fires LEFT down the corridor.
    f.turret("Gargoyle1", 2270, 420, angle=3.14159, interval=1.8, speed=220)
    f.checkpoint("P05_Checkpoint", cx=2460, top=520, w=176)

    # Climb up the right side with a crumble in the middle.
    f.ledge("P06_Ledge", cx=2800, top=380, w=160)
    f.crumble("P07_Crumble", cx=3120, top=240, w=144)
    f.ledge("P08_Ledge", cx=2880, top=90, w=176)

    # Corridor 2 (test, cost 3): a long slider LEFT over a spiked floor, two gargoyles firing down.
    f.rect("Floor2", 760, -10, 2600, 22)
    f.spikes_up("Floor2Spikes", 760, -10, 1840)
    f.rect("Roof2", 760, -330, 2600, -298)
    f.spikes_up("Roof2Spikes", 760, -330, 1840)
    f.checkpoint("P09_Checkpoint", cx=2700, top=-40, w=176)
    f.mover("P10_Slider", cx=2420, top=-130, w=144, travel=(-1400, 0), period=6.0)
    f.turret("Gargoyle2", 1900, -280, angle=1.5708, interval=1.6, speed=260, mount=False)
    f.turret("Gargoyle3", 1300, -280, angle=1.5708, interval=1.6, speed=260, phase=0.5, mount=False)
    f.checkpoint("P11_Checkpoint", cx=600, top=-60, w=192)

    # Corridor 3 (twist): up the left side, then RIGHT across the top on crumbles under an aimed gargoyle.
    f.ledge("P12_Ledge", cx=330, top=-250, w=160)
    f.ledge("P13_Ledge", cx=640, top=-420, w=160)
    f.crumble("P14_Crumble", cx=960, top=-520, w=128, delay=0.4)
    f.crumble("P15_Crumble", cx=1280, top=-600, w=128, delay=0.4)
    f.turret("Gargoyle4", 1640, -900, angle=1.5708, interval=1.6, speed=340, aimed=True)
    f.ledge("P16_Ledge", cx=1600, top=-660, w=144)
    f.blocker("Blocker", cx=1880, top=-880, w=96)
    f.ledge("P17_Ledge", cx=1960, top=-640, w=144)
    f.ledge("P18_ExitLedge", cx=2240, top=-740, w=224)
    return f.write(out("level_06_gargoyle_gallery.tscn"))


# --------------------------------------------------------------------------------------
# Floor 7: Mind the Doors. New: mimic doors (mouths). The move is the DOOR HOP: stand under a
# door, shoot straight up through it, drift sideways with the second shell, land on the gate.
# Shape: up through gates, a corridor LEFT with a door turned on its side over a spike pit,
# then two gates 100 px apart that you pass in one flight.
# --------------------------------------------------------------------------------------
def floor_07():
    W, TOP = 2560, -962
    f = Floor("MindTheDoors", title="Mind the Doors",
              hint="Mimic doors snap shut on a beat. Watch them shake, then go. If one bites you, it eats your shells.",
              taunt="My doors are hungry. You look crunchy.",
              bounds=(0, TOP, W, 720 - TOP),
              notes="Floor 7. New: mimic doors. A: one gate, one slow door. B: a gate with two doors out of step. "
                    "C: a sideways door in a corridor going left over spikes, then two gates 100 px apart. "
                    "See LEVEL_LOG.md.")
    f.frame(entry_x=1280, exit_x=760, start_x=1060)

    # Section A (teach, cost 0): one gate 160 px above the slab, one slow door. Land on its top.
    f.gate("GateA", 400, 32, W - 32, [(700, 150)], names={1: "P01_GateA"},
           open_time=1.8, warn_time=0.6, shut_time=0.6)

    # Section B (test): a gate with two doors out of step; the checkpoint sits on its top.
    f.gate("GateB", 230, 32, W - 32, [(1300, 150, {"phase": 0.5}), (2000, 150)],
           open_time=1.3, warn_time=0.45, shut_time=0.6)
    f.checkpoint("P02_Checkpoint", cx=1650, top=214, w=192)

    # Section C (twist): a corridor running LEFT, closed at its left end so the only way in is the
    # right end and the only way out is a hole in the roof at the far left. Its floor has a spike pit
    # under the sideways door, whose jaws close top and bottom. The roof is spiked on top.
    f.rect("P03_CorridorRight", 1000, 60, 1400, 92)
    f.rect("PitFloor", 800, 120, 1000, 152)
    f.spikes_up("DoorPit", 800, 120, 200)
    f.rect("P04_CorridorLeft", 432, 60, 800, 92)
    f.rect("CorridorEnd", 400, -172, 432, 92)
    f.rect("CorridorRoof", 592, -172, 1400, -140)
    f.spikes_up("CorridorRoofSpikes", 592, -172, 808)
    f.mouth("SideDoor", 900, -40, gap=(190, 36), open_time=1.4, warn_time=0.5, shut_time=0.6, rotation=1.5708)

    # Out through the roof hole (x 432-592) to a ledge on the left, then two gates 100 px apart,
    # doors offset and out of step: pass both in one flight.
    f.ledge("P05_Ledge", cx=260, top=-250, w=176)
    f.gate("GateC", -400, 32, 1100, [(330, 150)], open_time=1.2, warn_time=0.4, shut_time=0.5)
    f.gate("GateD", -500, 32, 1100, [(480, 150, {"phase": 0.3})], names={1: "P06_GateD"},
           open_time=1.2, warn_time=0.4, shut_time=0.5)
    f.ledge("P07_ExitLedge", cx=760, top=-690, w=224)
    return f.write(out("level_07_mind_the_doors.tscn"))


# --------------------------------------------------------------------------------------
# Floor 8: It's Boiling. New: the flood chases you from the first jump. Shape: a spiral:
# a leg RIGHT, a leg LEFT, a leg RIGHT, each ending at a checkpoint that pushes the flood back.
# Mixes old things: a wisp, a slider, a crumble, a slime pad. No hesitation.
# --------------------------------------------------------------------------------------
def floor_08():
    W, TOP = 2560, -1172
    f = Floor("ItsBoiling", title="It's Boiling",
              hint="The cauldron is boiling over. It rises as soon as you climb. Checkpoints push it back a little.",
              taunt="You're not supposed to be up here.",
              bounds=(0, TOP, W, 720 - TOP),
              notes="Floor 8 (first Tower floor). New: the flood chases the whole floor. Spiral: leg 1 right "
                    "(ledges, a wisp), leg 2 left (slider, crumble), leg 3 right (wisp, slime pad). "
                    "See LEVEL_LOG.md.")
    f.frame(entry_x=300, exit_x=1700, start_x=480)
    f.flood(trigger_y=500, speed=48.0, acceleration=2.5, start_gap=360.0, max_gap=440.0)

    # Leg 1, RIGHT.
    f.ledge("P01_Ledge", cx=760, top=420, w=176)
    f.ledge("P02_Ledge", cx=1060, top=290, w=160)
    f.ring("P03_Wisp", 1380, 200)
    f.ledge("P04_Ledge", cx=1720, top=150, w=160)
    f.checkpoint("P05_Checkpoint", cx=2120, top=40)

    # Spiked dividers between the legs, open at the end where the spiral turns, so you can't fly
    # straight up from one leg into the next.
    f.rect("Divider1", 32, -20, 1960, 12)
    f.spikes_up("Divider1Spikes", 32, -20, 1928)

    # Leg 2, LEFT.
    f.mover("P06_Slider", cx=1820, top=-110, w=144, travel=(-560, 0), period=3.5)
    f.ledge("P07_Ledge", cx=1000, top=-200, w=160)
    f.crumble("P08_Crumble", cx=700, top=-320, w=144, delay=0.4)
    f.checkpoint("P09_Checkpoint", cx=380, top=-440)

    f.rect("Divider2", 640, -520, W - 32, -488)
    f.spikes_up("Divider2Spikes", 640, -520, W - 32 - 640)

    # Leg 3, RIGHT.
    f.ring("P10_Wisp", 720, -560, amount=1)
    f.ledge("P11_Ledge", cx=1000, top=-600, w=192)
    # The pad is a safety net now, not a requirement (barrel touches make pads unreliable).
    f.pad("BoilPad", cx=1180, top=-470, w=176)
    f.ledge("P12_Ledge", cx=1360, top=-750, w=176)
    f.ledge("P13_ExitLedge", cx=1700, top=-900, w=224)
    return f.write(out("level_08_its_boiling.tscn"))


def tunnel_cells(e0, e1, rows, cols, up_right, W):
    """Diagonal tunnel walls on a 32 px grid. up_right: band e0 <= x + y <= e1 ("/"), floor side below-right.
    Otherwise band e0 <= x - y <= e1 ("\\"), floor side below-left. Returns (wall cells, spiked floor cells)."""
    walls, spiky = set(), set()
    for r in rows:
        for c in cols:
            e = 32 * (c + r) + 32 if up_right else 32 * (c - r)
            floor_side = e1 < e <= e1 + 64 if up_right else e0 - 64 <= e < e0
            ceil_side = e0 - 64 <= e < e0 if up_right else e1 < e <= e1 + 64
            if floor_side:
                walls.add((c, r))
                spiky.add((c, r))
            elif ceil_side:
                walls.add((c, r))
    walls = {(c, r) for c, r in walls if 32 <= c * 32 < W - 32}
    return walls, spiky & walls


# --------------------------------------------------------------------------------------
# Floor 9: Everything Hates You. Nothing new: the gauntlet. Shape: a corridor LEFT over a
# long spike pit (crumbles, slider, a gargoyle), a second diagonal tunnel going up-RIGHT with
# wisps, then a door gate, an aimed gargoyle and a wisp to the exit.
# --------------------------------------------------------------------------------------
def floor_09():
    W, TOP = 3840, -1422
    f = Floor("EverythingHatesYou", title="Everything Hates You",
              hint="Nothing new. Everything at once.",
              taunt="Everything up here hates you. I made sure of it.",
              bounds=(0, TOP, W, 720 - TOP),
              notes="Floor 9 (gauntlet). A: corridor left over a spike pit: crumbles, a slider, a gargoyle. "
                    "B: second diagonal tunnel, up-right, spiked floor, wisps. C: a door gate, an aimed gargoyle, "
                    "a wisp, the exit. See LEVEL_LOG.md.")
    f.frame(entry_x=3500, exit_x=3050, start_x=3700)

    # Section A: corridor LEFT. Spike pit on the slab from x 1408 to 3404; spiked roof at y 300.
    f.spikes_up("Pit", 1408, 560, 3404 - 1408)
    f.rect("Roof", 1408, 300, 3300, 332)
    f.spikes_up("RoofSpikes", 1408, 300, 3300 - 1408)
    f.crumble("P01_Crumble", cx=3080, top=470, w=144, delay=0.4)
    f.crumble("P02_Crumble", cx=2780, top=470, w=144, delay=0.4)
    f.mover("P03_Slider", cx=2420, top=450, w=144, travel=(-640, 0), period=3.2)
    f.turret("Gargoyle1", 1460, 400, angle=0.0, interval=1.6, speed=280)
    f.crumble("P04_Crumble", cx=1640, top=450, w=128, delay=0.4)
    f.checkpoint("P05_Checkpoint", cx=1180, top=440)

    # Section B: the second tunnel, "/" going up-right from above the checkpoint.
    e0, e1 = 1440, 1696
    walls, spiky = tunnel_cells(e0, e1, range(-13, 9), range(30, 75), True, W)
    f.cells("Tunnel", walls, spike_tops=spiky, spike_height=16)
    mid = (e0 + e1) / 2
    for i, y in enumerate((160, 20, -120, -260, -400)):
        f.ring(f"P{6 + i:02d}_Wisp", mid - y, y, amount=1)
    f.checkpoint("P11_Checkpoint", cx=2300, top=-470)

    # Section C: a door gate, an aimed gargoyle, a wisp, the exit.
    f.gate("GateE", -640, 1900, W - 32, [(2400, 150)], names={1: "P12_GateE"},
           open_time=1.0, warn_time=0.4, shut_time=0.5)
    f.turret("Gargoyle2", 3560, -1000, angle=3.14159, interval=1.6, speed=340, aimed=True)
    f.ring("P13_Wisp", 3260, -960, amount=1)
    f.ledge("P14_ExitLedge", cx=3050, top=-1150, w=224)
    return f.write(out("level_09_everything_hates_you.tscn"))


# --------------------------------------------------------------------------------------
# Floor 10: Mrs. Sandwitch. The finale: no new mechanic, every section COMBINES old ones.
# A (right): crumbles over a pit with a gargoyle firing through the gap, then a lift.
# B (left): ride a slider over a spiked shelf and hop up through a jaw door off it; a wisp and
#           a fast crumble across a spiked gate top.
# C (right): zigzag, wisp, crumble, a lift under an aimed gargoyle, a door hop into the orb room.
# No flood: a teammate removed it by hand in the editor, so the redesign leaves it out.
# --------------------------------------------------------------------------------------
def floor_10():
    W, TOP = 2560, -2060
    f = Floor("Sandwitch", title="Mrs. Sandwitch",
              hint="Nothing new. Everything you've learned, at the same time. The orb is at the top.",
              taunt="Fine. Come on up. I've got my wand ready.",
              bounds=(0, TOP, W, 720 - TOP), is_final=True,
              notes="Floor 10 (finale, combos). A: crumbles over a pit with a gargoyle shooting the gap, a lift. "
                    "B: slider over a spiked shelf, door hop off the slider, wisp and fast crumble over a spiked "
                    "gate top. C: zigzag, wisp, crumble, a lift under an aimed gargoyle, door hop into the walled "
                    "orb room. See LEVEL_LOG.md.")
    f.frame(entry_x=1280, exit_x=None, start_x=1480)

    # Section A, RIGHT: the Gargoyle Bridge. Pit from x 1680 (300 px clear of the entry hole).
    f.spikes_up("Pit", 1680, 560, W - 32 - 1680)
    f.crumble("P01_Crumble", cx=1800, top=450, w=144, delay=0.45)
    f.crumble("P02_Crumble", cx=2100, top=360, w=144, delay=0.45)
    # Fires left at y 400: the height you cross between the two crumbles. A hit shoves you into the pit.
    f.turret("Gargoyle1", 2496, 400, angle=3.14159, interval=1.6, speed=280)
    f.mover("P03_Lift", cx=2360, top=300, w=144, travel=(0, -300), period=3.6)
    f.checkpoint("P04_Checkpoint", cx=2060, top=-60)

    # Section B, LEFT: the Jaws Ferry. A spiked shelf under the slider, a full-width gate above it.
    f.rect("SpikeShelf", 1100, -20, 1800, -4)
    f.spikes_up("SpikeShelfSpikes", 1100, -20, 700)
    f.mover("P05_Slider", cx=1900, top=-120, w=144, travel=(-400, 0), period=3.4)
    # The door sits right above the slider's left end: ride over, hop straight up through the jaws.
    f.gate("GateG", -300, 32, W - 32, [(1500, 150)], names={0: "P06_GateG"},
           open_time=1.3, warn_time=0.45, shut_time=0.5)
    # The gate's top is spiked left of a safe landing strip beside the door.
    f.spikes_up("GateGSpikes", 200, -300, 950)
    f.ring("P07_Wisp", 920, -470, amount=1)
    f.crumble("P08_Crumble", cx=620, top=-560, w=144, delay=0.4)
    f.checkpoint("P09_Checkpoint", cx=260, top=-720)

    # Section C, RIGHT: the Spire.
    f.ledge("P10_Ledge", cx=600, top=-900, w=144)
    f.ring("P11_Wisp", 900, -1060, amount=1)
    f.crumble("P12_Crumble", cx=1180, top=-1150, w=128, delay=0.35)
    f.mover("P13_Lift", cx=1480, top=-1200, w=144, travel=(0, -260), period=3.0)
    # Aimed gargoyle on the right wall: hover on the lift too long and it knocks you off.
    f.turret("Gargoyle2", 2496, -1330, angle=3.14159, interval=1.7, speed=320, aimed=True)

    # The orb room: walled off on the left, entered only through the door above the lift's top.
    f.rect("OrbRoomWall", 1068, TOP + 32, 1100, -1580)
    f.rect("OrbRoomFloorL", 1100, -1600, 1405, -1580)
    f.mouth("OrbDoor", 1480, -1590, gap=(150, 36), open_time=1.2, warn_time=0.45, shut_time=0.5)
    f.checkpoint("P14_OrbRoom", cx=1795, top=-1600, w=480, is_finish=True)
    f.rect("OrbRoomFloorR", 2035, -1600, W - 32, -1580)
    f.orb("HexOrb", 1795, -1770, [(1595, -1850), (1995, -1890)])
    return f.write(out("level_10_morwen.tscn"))


FLOORS = {2: floor_02, 3: floor_03, 4: floor_04, 5: floor_05, 6: floor_06, 7: floor_07, 8: floor_08,
          9: floor_09, 10: floor_10}

if __name__ == "__main__":
    want = [int(a) for a in sys.argv[1:]] or sorted(FLOORS)
    for n in want:
        print("wrote", FLOORS[n]())
