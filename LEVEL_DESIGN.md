# Level design guide

This is the toolkit for building Recoil Launcher levels. It lists every mechanic, the numbers behind the movement, and the rules for keeping levels fair, fun and gradually harder. It's written so an AI (or a person) can mix and match mechanics into new levels.

**Current goal:** build the **10 floors** of the tower, each one wide, and playtest each one until the difficulty climbs smoothly. Castle art is being swapped in alongside.

> **Read this first: what we're working on right now.**
>
> - **Story:** read [STORY.md](STORY.md). The witch Morwen cursed a witch hunter, Sir Barrett, into his own shotgun. He climbs Hexmoor Castle: **Cellar (floors 1-3) -> Library (4-7) -> Tower (8-10)**.
> - **One continuous tower.** Each "level" is a **floor**: its own `.tscn` file, built separately. The game stacks the floors on top of each other, so the whole game is one unbroken climb. You leave a floor through a **hole in its ceiling** and enter the next through a **hole in its ground**. Each floor shows its own title when you enter it, so the player feels the change. **Follow the floor rules in section 2 exactly**, or the floors won't line up.
> - **Wide floors (done, use this now):** set `bounds` on the root and the camera follows on **both** axes. Paths go diagonally (up-right, up-left, switchbacks, corridors), not only straight up. See "World rules" and "Sideways reach" below, and `levels/level_01_wake_up.tscn` for a working example.
> - **One hex orb, at the top of floor 10 only.** Break it (3 blasts) and a cutscene starts: the witch talks, you shoot her once, black screen, echoed shot, the end. Floors 1-9 have no orb; they end at their exit hole.
> - **Coming (code, not level work):** stacking the floors into the tower, the floor title banner, the orb, the intro and the ending. Build floors now; they'll slot in.

---

## 1. How the player moves

The movement is final. Design around these numbers; don't change them.

| What | Value |
|---|---|
| Controls | Mouse only. Hold left click to charge, release to fire. You fly **away** from the cursor. |
| Shells | 2. Both refill the moment you land on normal ground. |
| Shot power | Tap = 380 px/s, full charge (0.4 s hold) = 580 px/s |
| A shot **sets** your velocity | It doesn't add to it. Firing while falling cancels the fall completely. |
| Gravity | 880 px/s² |
| Mid-air aim | While charging the **second** shell in the air, time slows to 35%. |
| Landing | Stops sideways motion instantly and refills both shells. |
| Player size | Circle, radius 12 px |

### Reach, the most important numbers

| Move | Rises | Sideways |
|---|---|---|
| One full shot straight up | **~190 px** | 0 |
| One tap straight up | ~80 px | 0 |
| One full shot at 45° | ~95 px | ~190 px to the top of the arc, ~380 px back at the same height |
| Two full shots, second at the top of the first | **~380 px** | up to ~500 px with angled shots |

**Rules for gaps** (measured from the top of the platform you stand on):
- **Easy single-shot hop:** up to 150 px up and 200 px across.
- **Hard single shot:** 150 to 175 px up. Above that you need both shells.
- **Two-shell jump:** up to ~330 px up. Never more than 350 px up without a mechanic (pad, refill, lift).
- Leave **at least 60 px of headroom** above any platform the player is meant to shoot up from, or they bonk into the ceiling.
- A platform the player must land on precisely should be **at least 120 px wide** early on and **at least 90 px** in hard sections.

### World rules

- Each level sets **`bounds`** (a `Rect2`) on its root: the playable area. Width 1280 up to ~3840 px. `bounds.position` is the top-left corner, so a level 1920 wide that climbs to y = -1100 is `Rect2(0, -1100, 1920, 1820)`. Keep the bottom (`bounds.end.y`) at **720**, with the ground top at y = 560.
- **Up is negative y.** The climb goes up into negative numbers.
- The camera follows the player on **x and y** with smoothing. It leads ~120 px in the direction you're flying, keeps you ~100 px below the screen centre, and stops at `bounds`. The screen shows 1280 x 720.
- Leaving the left, right or bottom of `bounds` by more than 24 px kills. Falling more than 420 px below your checkpoint also kills. You respawn at the checkpoint.
- **Line the left and right edges with stone walls** (tall blocks just inside `bounds`) so players bonk instead of dying at the edge. Put a ceiling over the top of the level.
- A level without `bounds` uses the old shaft: 1280 wide, x 0 to 1280, bottom at 720. The sandbox levels still work this way.
- In the editor, the level root draws its `bounds` as a blue rectangle.

### Sideways reach (wide levels)

| Move | Across | Up |
|---|---|---|
| One full shot at 45 deg, land at the same height | ~380 px | 0 |
| One full shot at 45 deg, land at the top of the arc | ~190 px | ~95 px |
| Two angled shots | up to ~500 px | up to ~200 px |

- **Easy sideways hop:** up to 300 px across at the same height. **Hard:** 300 to 380 px. Wider gaps need both shells, a refill, a pad or a mover.
- The next platform must be on screen before the jump: never more than ~550 px away sideways.
- Long sideways stretches need a ceiling now and then (~140 px headroom), or players just shoot up over everything.
- Every level still ends **higher** than it starts. Sideways is for variety, not instead of climbing.

### Section shapes

Mix these. Each one is a section between checkpoints. STORY.md section 3 has sketches.

- **Staircase:** diagonal line of ledges, each step ~200 px across and ~120 px up.
- **Switchback:** up-right, a wall turns you up-left, then up-right again.
- **Corridor:** flat run with a low ceiling. Good for turrets, crumbles and mouths in the floor.
- **Shaft:** short straight climb, 480 px wide or less. A contrast between wide sections.
- **Hall:** a wide room with a safe slow route and a fast risky one.

---

## 2. Level files (floors)

Each floor is one scene in `levels/`, e.g. `levels/level_08_name.tscn`.

### Floor rules: how floors connect into one tower

The game stacks floor N+1 on top of floor N. It shifts floor N+1 sideways and up so its `Entry` marker sits exactly on floor N's `Exit` marker. Floors can be different widths; only the holes have to line up, and the game does that for you.

- **Exit hole (every floor except 10):** the top of the floor is a stone ceiling, 32 px thick, along the top edge of `bounds`, with **one gap exactly 192 px wide**. Add a `Marker2D` named exactly **`Exit`** at the centre of the gap, at the **top** of the ceiling (that's `bounds.position.y`).
- **Entry hole (every floor except 1):** the ground at the bottom of the floor is a stone slab, 32 px thick, with its top at y = 560 (so it runs y 560 to 592). It has **one gap exactly 192 px wide**. Add a `Marker2D` named exactly **`Entry`** at the centre of the gap, at the **bottom** of the slab (y = 592). Floor 1 has no entry hole; its ground is solid.
- **`Start`** sits on the ground slab **beside** the entry hole (not over it), 14 px above the slab top (y = 546). It's where the player spawns when the floor is loaded on its own, and the first respawn point on that floor.
- **Make the exit reachable:** put a wide, safe ledge (ideally a checkpoint) under the exit hole, no more than **330 px** below the bottom of the ceiling, so two straight-up shots carry the player through.
- **Arrival is safe:** the player comes up through the entry hole with little speed left. Put the ground slab or a wide platform right beside the hole, and **no hazards within ~250 px** of it.
- **Below the entry hole there is nothing** when the floor is played on its own: falling back down it is a death. In the tower it drops you into the floor below, which is fine.
- **Until the tower code lands:** put an `is_finish` checkpoint on the ledge under the exit hole, so a floor can be cleared when tested on its own (keys 1-0). It gets removed later.
- **Floor 10** has no exit hole. It ends in the orb room (see 3.11).

```
   floor N+1   |========== ground slab ==========|  ____  |=====|
                                                  Entry (gap 192)
   floor N     |======= ceiling ======|  ____  |=================|
                                        Exit (gap 192)
                                     [ ledge under the exit ]
```

- **Root node:** `Node2D` with the script `res://hazards/level.gd`. Set `title` (shown top-left) and `hint` (one sentence teaching the level's new idea).
- **Wide floors:** set `bounds` on the root (see World rules). The `title` is shown big when the player enters the floor. Optional: `taunt` (Morwen's line, first floor of each zone) and `is_final` (floor 10 only). These two do nothing yet.
- **`Start`:** a `Marker2D` child named exactly `Start`, where the player spawns. Put it 14 px above the ground top, e.g. `(640, 546)`.
- **Register it:** add the path to `LEVELS` in `main.gd`. Keys 1 to 9 load levels 1 to 9 and key 0 loads level 10.
- All mechanics are direct children of the root. Positions of rectangles are their **centre**.
- **Keep sizes and positions on a 16 px grid** where you can. The art tiles are 16×16, so this makes the art swap painless.

Minimal level (text `.tscn`, which you can write by hand):

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://hazards/level.gd" id="level"]
[ext_resource type="Script" path="res://hazards/block.gd" id="block"]
[ext_resource type="Script" path="res://hazards/checkpoint.gd" id="checkpoint"]

[node name="MyLevel" type="Node2D"]
script = ExtResource("level")
title = "My Level"
hint = "One sentence that teaches the new idea."
bounds = Rect2(0, -800, 1920, 1520)

[node name="Start" type="Marker2D" parent="."]
position = Vector2(640, 546)

[node name="Ground" type="StaticBody2D" parent="."]
position = Vector2(640, 569)
script = ExtResource("block")
size = Vector2(1020, 18)

[node name="Ledge1" type="StaticBody2D" parent="."]
position = Vector2(800, 400)
script = ExtResource("block")
size = Vector2(160, 16)

[node name="Finish" type="StaticBody2D" parent="."]
position = Vector2(560, 230)
script = ExtResource("checkpoint")
size = Vector2(160, 16)
is_finish = true
```

Look at `levels/level_01_wake_up.tscn` for a wide level, and `levels/level_1_basics.tscn` through `level_7_refills.tscn` for working examples of every mechanic.

### Testing keys (editor runs only)

| Key | Does |
|---|---|
| 1 to 9, 0 | Load level 1 to 10 |
| R | Die and restart from the last checkpoint |
| N | Jump to the next checkpoint (test a later section quickly) |
| F7 | Debug flight: the player follows the mouse, ignoring physics |

The bottom-right shows time, deaths and checkpoints. Every run writes a log to `playtest_logs/` with every shot, landing, bounce, bite and death. Use it to find where players die most.

---

## 3. Mechanics

Each entry gives its node type and script, what it does, how to use it, and which settings make it easier or harder.

### 3.1 Block (normal ground)
`StaticBody2D` + `res://hazards/block.gd`. Black.

- Solid, and landing reloads both shells. This is the basic step of every level.
- **Settings:** `size` (Vector2).
- Tall thin blocks make walls; wide thin ones make ledges and ceilings.

### 3.2 Spikes
`Area2D` + `res://hazards/spikes.gd`. Black triangles. **Kills on touch.**

- The origin is the **bottom-left** of the row. Teeth point **up** and the row runs to the right.
- **Settings:** `width`, `height` (default 26). Rotate the node to point them elsewhere: `rotation = 1.5708` (90°) points them right with the row running down; `-1.5708` points them left with the row running up; `3.1416` points them down.
- **Uses:**
  - Spiked edges on a ledge punish overshooting.
  - A spiked block (a block with spikes along its top) is a hazard to arc around.
  - Spiked walls along a shaft force precise straight shots.
- **Difficulty:** more coverage and narrower safe landings. Never put spikes where the player can't see them before committing to a shot.

### 3.3 Checkpoint and Finish
`StaticBody2D` + `res://hazards/checkpoint.gd`. Black, turns green when reached.

- A normal platform that saves your respawn point when you land on it. Tick `is_finish` for the level goal.
- Checkpoints only save upward, so landing on a lower one does nothing.
- **Rules:**
  - Put one at the end of every section, about every 500 to 700 px of climbing.
  - Make them wide (160 px or more) and safe. A checkpoint is a breather.
  - A level needs **at least 1 checkpoint plus 1 finish**.

### 3.4 Bouncy surface
`StaticBody2D` + `res://hazards/bouncy.gd`. Blue.

- Reflects the player and **never reloads shells**. Every bounce leaves at least `min_speed`, so you can't rest on it.
- Floor pads return you to roughly the height you fell from. That's "free height" you can stack a shot on top of.
- **Settings:** `size`, `strength` (1.0 keeps speed, 1.2 adds speed), `min_speed` (420 is about a 100 px hop). Rotate for angled bumpers.
- **Uses:**
  - Trampoline floors.
  - Side walls that bounce you back instead of letting you fall.
  - Angled bumpers that redirect a shot.
  - "Pad ladders": several pads in a row with no reload spots between them.
- **Difficulty:** more pads in a row without a black landing spot, smaller pads, spikes beside pads.
- **Watch out:** a pad directly below with nothing else nearby can trap a player with 0 shells bouncing forever. Make sure there's always a way off (an angle, or a nearby ledge). R is the escape key during testing.

### 3.5 Moving platform
`AnimatableBody2D` + `res://hazards/mover.gd`. Grey, with its path drawn as a dashed line.

- Eases back and forth between where it's placed and `position + travel`. It carries the player, and landing reloads. Jumping off adds the platform's speed to your shot.
- **Settings:**
  - `size`
  - `travel` (Vector2 offset to the far end)
  - `period` (seconds for a full round trip)
  - `phase` (0 to 1, where in the cycle it starts; use it to offset neighbours)
  - `wait_for_player`: when on, it waits until you land, makes one round trip, then waits again. It shows a yellow stripe while waiting and green while moving.
- **Uses:**
  - Horizontal sliders across gaps.
  - Lifts.
  - Lifts that wait for you (safe teaching).
  - Several platforms moving out of step.
- **Difficulty:**
  - Shorter `period` (4 s is gentle, 2.4 s is hard).
  - Smaller platforms.
  - Out-of-step neighbours.
  - Spikes near the ends of the path.

### 3.6 Crumbling platform
`StaticBody2D` + `res://hazards/crumble.gd`. Brown with cracks.

- Reloads like normal ground, then shakes and disappears `delay` seconds after you land. It comes back after `regrow` seconds.
- **Settings:** `size`, `delay` (0.5), `regrow` (2.5).
- **Uses:** forces the player to keep moving, and works well as stepping stones into a lift.
- **Difficulty:** a shorter `delay` (0.3 is hard), or chains of crumbling platforms.

### 3.7 Turret
`Node2D` + `res://hazards/shooter.gd`. Dark red box with a barrel; aimed turrets have a yellow eye.

- Fires bolts along its rotation (0 = right, 1.5708 = down, 3.1416 = left, -1.5708 = up). The barrel glows red 0.35 s before each shot.
- A bolt **doesn't kill**. It shoves you (`knockback`) and keeps your shells. The danger is being pushed into spikes or off a ledge. Bolts vanish when they hit anything solid.
- **Settings:**
  - `interval` (seconds between volleys)
  - `phase`
  - `bullet_speed`
  - `burst` (bolts per volley) and `burst_gap`
  - `knockback` (420)
  - `aimed`: tracks the player, and only while they're within `reach` (650 px)
- Mount it on a block. The bolt spawns 22 px out from the centre, so keep that point clear of walls.
- **Uses:**
  - Fixed lanes the player must time a crossing through.
  - Columns firing down a climbing path.
  - Aimed turrets that punish hovering.
- **Difficulty:**

  | | Easy | Hard |
  |---|---|---|
  | `interval` | 1.8 s | 1.2 s |
  | `bullet_speed` | 220 | 360 |
  | `burst` | 1 | 3 |
  | `aimed` | false | true |

### 3.8 Mouth
`Node2D` + `res://hazards/mouth.gd`. Purple jaws with teeth.

- Two jaws snap shut across a gap on a fixed beat: open → shake warning (teeth turn red) → snap → shut → open.
- If it catches you, it **eats all your shells** until you land and spits you back the way you came.
- By default the jaws close left-right and you fly up or down through it. Rotate it for sideways passages.
- **Settings:**
  - `gap` (x = opening width, y = bite depth)
  - `open_time`, `warn_time`, `shut_time`
  - `phase`
  - `spit_speed`
- **Best use:** "gates", which are full-width floors (x 0 to 1280) with one or two holes, each guarded by a mouth. The top of a gate floor is normal ground, so it reloads. See `level_5_mouths.tscn`.
- **Difficulty:**
  - Shorter `open_time` (1.8 s is easy, 0.9 s is hard) and `warn_time` (0.6 s, down to 0.35 s).
  - Narrower holes.
  - Two mouths stacked close together that you must pass in one flight, set out of step with `phase`.

### 3.9 Flood (rising hazard)
`Node2D` + `res://hazards/rising.gd`. Red water across the whole width. **Kills on touch.** Keep this node at position (0, 0).

- Starts once the player climbs above `trigger_y`. It appears `start_gap` below them, rises at `speed`, and speeds up by `acceleration` every second.
- It never falls more than `max_gap` behind, so fast players still feel it.
- Reaching a checkpoint pushes it back to at least `checkpoint_gap` below. Dying resets it, and it stops when you finish.
- **Settings:** `trigger_y`, `start_gap` (380), `speed` (50), `acceleration` (2), `max_gap` (460), `checkpoint_gap` (300).
- **Uses:**
  - A **chase finale**: set `trigger_y` just above the last checkpoint so only the final section is chased.
  - A **full-level chase**: set `trigger_y` below the start.
- **Difficulty:** `speed` 40 → 60, `acceleration` 2 → 4, smaller `max_gap`.

### 3.10 Shell refill (new)
`Node2D` + `res://hazards/refill.gd`. Gold ring with shell icons inside.

- Flying through it **reloads shells mid-air**, without landing. It's only used up if you were missing a shell.
- After use it shows as a faint ring with a timer, then comes back after `respawn_time`. With `respawn_time = 0` it only comes back when you die (one use per attempt).
- **Settings:**
  - `amount`: 1 = half refill, 2 = full
  - `respawn_time`: 3 s, or 0 for once per life
  - `travel`, `period`, `phase`: makes it drift like a moving platform
- **Uses:**
  - **Climb where there's nothing to land on**: chain refills up a shaft. Each full refill is worth about 380 px of height.
  - Cross wide gaps over spikes.
  - Place a refill as a "reward" for a risky line.
- **Difficulty:**
  - `amount` 1 instead of 2.
  - `respawn_time` 0 (one chance).
  - Drifting refills.
  - Refills placed just off the natural arc, so the player has to aim for them.
  - Spikes lining a refill shaft.
- **Watch out:** air-slow only happens while charging the second shell. After a full refill your next shot is a "first" shot, so it isn't slowed. Space refill chains about 190 px apart for `amount = 1` and about 380 px for `amount = 2`.

### 3.11 Hex orb (coming, floor 10 only)
`Node2D` + `res://hazards/orb.gd`. Not in the build yet.

- **There is only one orb, at the top of floor 10.** It's the end of the game. Floors 1-9 never have one.
- Blast it **3 times**: point the cursor at it and fire while it's within ~200 px and inside a ~35 deg cone. Walls block the blast. You fly away from it on every hit, so you get back for the next one.
- After each hit it hops to the next entry in `spots`. The third hit shatters it and starts the ending cutscene (see STORY.md).
- **Settings:** `hits` (3), `spots` (positions for hits 2 and 3).
- **Build the orb room now (floor 10):** a wide, safe floor (normal ground) at the top, with open space ~150 to 350 px above it, and a ceiling. For now put the `is_finish` checkpoint there. Spot 1 easy from the floor, spot 2 needs a hop, spot 3 a real mid-air shot.

---

## 4. Making levels fun and gradually harder

### Inside one level: teach → test → twist → chase

Every level has **3 sections** with a checkpoint between each:

1. **Teach:** introduce the one new idea somewhere safe, where failing costs little (falling back to the ground or the last ledge). Explain it in the `hint`.
2. **Test:** use it for real, with spikes or a longer fall as the cost.
3. **Twist:** a variant (faster, out of step, combined with one earlier mechanic), or fewer reload spots.
4. **Optional chase:** a Flood that starts after the last checkpoint, for a pressured finish.

### Across the game: one new thing at a time

- **Never introduce two new mechanics in the same level.** A level may *combine* mechanics the player already knows.
- Each new level should be **a little** harder than the last. Aim for the playtest targets below, not a spike.
- Give the player a breather after a hard level: introduce the next mechanic gently.

### Suggested 10-level order

The current `level_1` to `level_7` files are **sandboxes** for testing each mechanic, not final levels. A suggested final order:

| Floor | Zone | Title | New idea | Combines with | Shape | Size (w x climb) |
|---|---|---|---|---|---|---|
| 1 | Cellar | Wake Up, You're a Gun | Basics: charge, two shells, spikes | - | Diagonal up-right | 1920 x 1600 |
| 2 | Cellar | The Chain Lift | Moving platforms and lifts | spikes | Lightning bolt (up-right, left, up-right) | 2560 x 1400 |
| 3 | Cellar | Loose Shells | Shell refills | moving platforms | Diagonal with a refill-only gap | 2560 x 1600 |
| 4 | Library | Quiet Please | Bouncy pads and walls | refills | Wide room (across, up, back) | 3200 x 1400 |
| 5 | Library | Rotten Shelves | Crumbling platforms | lifts, bounce | Switchback | 2560 x 1800 |
| 6 | Library | Gargoyle Gallery | Turrets | moving platforms | Corridors | 3840 x 1400 |
| 7 | Library | Mind the Doors | Mouth gates | turrets (light) | Shaft + halls | 1920 x 2200 |
| 8 | Tower | It's Boiling | Flood (full-level chase) | refills, bounce | Spiral (up-right, up-left) | 2560 x 2400 |
| 9 | Tower | Everything Hates You | Mixed gauntlet | everything except flood | Long lightning bolt | 3840 x 2400 |
| 10 | Tower | Morwen | Finale: orb room, then the witch | everything, flood over the last third | Spiral | 2560 x 3000 |

Floor 1 exists as a first draft (`level_01_wake_up.tscn`), including its exit hole and `Exit` marker. Floor 2 needs an `Entry` hole; the game lines it up with floor 1's exit. In-world names for each mechanic (gargoyles, mimic doors, slime, cauldron) are in STORY.md.

### Playtest targets

Measured by a player who has beaten the previous level (time and deaths are on screen):

| Levels | Time | Deaths |
|---|---|---|
| 1–3 | 30–90 s | 0–5 |
| 4–7 | 1–2 min | 3–10 |
| 8–10 | 2–3 min | 8–20 |

If one section causes more than half of a level's deaths, it's too hard for its spot. Ease it or move it later.

### Fairness checklist (every level)

- [ ] Every required jump is possible with full-charge shots within the reach numbers above. Fly it with F7 to check spacing, then play it for real.
- [ ] Every hazard is visible before the player has to commit to a shot.
- [ ] Every timed hazard (turret, mouth, mover) gives a warning or a readable rhythm.
- [ ] No softlocks: there's always a way to continue, or a quick death that respawns.
- [ ] Checkpoints are wide, safe, and no more than ~700 px of climbing (or ~1200 px of sideways travel) apart.
- [ ] `bounds` is set, the side edges have walls, and the top has a ceiling.
- [ ] Exit hole (192 px gap, `Exit` marker on top of the ceiling) unless it's floor 10. Entry hole (192 px gap, `Entry` marker under the ground slab) unless it's floor 1.
- [ ] A safe ledge under the exit (no more than 330 px below it) and a safe landing beside the entry, with no hazards within ~250 px.
- [ ] The `hint` explains the new idea in one sentence.
- [ ] Sizes and positions are on the 16 px grid where possible.

---

## 5. Later: swapping in art

All mechanics draw themselves with plain shapes for now. When the levels are locked, replace each script's `_draw()` with sprites from `assets/sprites/`. Keep sizes and collisions the same:

| Mechanic | Art |
|---|---|
| Blocks | Shelves, planks, and the stone tilesets |
| Checkpoints | Bonfire and lanterns |
| Spikes | `spikes_up` / `spikes_down` |
| Moving platforms | Chain-hung platforms |
| Turrets | Gargoyles |
| Background | Banners, windows and statues |

Credits are tracked in `ASSET_CREDITS.md`.
