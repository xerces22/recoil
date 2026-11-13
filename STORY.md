# Story and world

The story behind Recoil Launcher, and how it shapes each level. Read this with [LEVEL_DESIGN.md](LEVEL_DESIGN.md), which has the movement numbers and mechanics.

The tone is silly but straight-faced. The characters take it seriously; the player shouldn't.

---

## 1. The story

### Setup (intro card, 3 short screens)

1. **Sir Barrett** was the finest witch hunter in the kingdom. He came to Hexmoor Castle with one weapon: his trusty double-barrel shotgun.
2. The witch **Morwen the Unloaded** caught him in the cellar. She didn't kill him. She did something worse: she turned him **into the shotgun**.
3. "A gun can't walk," she laughed, and floated up to her tower. Her magic lives in **hex orbs** hidden through the castle. Smash them all and the curse breaks.

Then the game starts. No more text than that. Each line fits on one screen in Press Start 2P.

### Why the rules work the way they do

Every mechanic should have an in-world reason, so the player never asks "why?":

| Rule | Story reason |
|---|---|
| You only move by firing | You're a gun. Guns don't have legs. Recoil is all you've got. |
| 2 shells | Double barrel. Barrett always carried two. |
| Landing reloads both | Part of the curse: the castle feeds you shells every time you touch stone, so you can never run out and never stop being a gun. Morwen thinks it's funny. |
| Mid-air slow-mo on the 2nd shell | Barrett's hunter instincts. Time slows when he aims. |
| Shell refill rings | **Shell wisps**: loose pieces of the curse floating around. Fly through one and it loads you. |
| Respawn at a checkpoint | Braziers. Barrett's spirit drifts back to the last fire he lit. |

### The hex orb (end of every level)

Each level ends at a **hex orb** instead of a plain finish platform. It takes **3 blasts** to break.

- You hit it by firing **toward** it. The blast goes where the cursor points, and you fly the other way. So every hit also knocks you away from the orb, and you have to climb back for the next one. That's the fun part.
- After each hit the orb cracks, flashes and **hops to a new spot** in the orb room (3 spots per room, set by the level designer). Hit 1 is easy, hit 3 asks for a real shot.
- On the third hit it shatters, a jingle plays, and the next level loads.
- A hit only counts within ~200 px and if the orb is inside a ~35° cone of the blast. Show the cone faintly while charging near an orb so players learn the range.

Each level's orb room has a safe floor (normal ground, reloads) so a miss never kills you. Orb rooms are the reward, not a skill wall.

### Ending (after level 10)

The last orb is Morwen's **heart orb**, held in her hands at the tower top. Three hits, and she moves between hits like the others, but she also throws one bolt between hits (reuse the turret bolt: shoves, doesn't kill).

On the third hit the curse breaks... and bounces. Barrett turns back into a man. **Morwen turns into a broom.** Barrett picks her up and sweeps the floor. Roll credits.

Optional end-card line: *"He never fired a shotgun again. He just sort of hopped everywhere."*

---

## 2. Three zones of the castle

The climb goes **cellar → library → tower**. This matches the asset shortlist, so art and story line up.

| Zone | Levels | Look (Whimsy Hallow + Dark Castle) | Music | Morwen's taunt on arrival |
|---|---|---|---|---|
| **The Cellar** | 1–3 | Grey stone, wood, wine racks as ledges, potion shelves, sewer grates | Castle in Darkness | "Still kicking? Cute." |
| **The Library** | 4–7 | Stone, tall bookshelves as platforms and walls, candles, gargoyle statues | MonsterVania #2 | "Shhh. This is a library." |
| **The Tower** | 8–10 | Sandstone, arched windows, chandeliers, balconies, night sky outside | Final Castle | "You're not supposed to be up here." |

The taunt is the level's `title` card subtitle on the first level of each zone. Everywhere else, `hint` stays a one-sentence mechanic tip.

### Mechanics as Morwen's stuff

Rename the mechanics in-world so they belong to the castle. Code names stay the same.

| Mechanic (code) | In-world name | Look |
|---|---|---|
| Block | Shelves, stone ledges | Wine racks / bookshelves / planks by zone |
| Spikes | Iron spikes | Dark Castle spikes, recoloured |
| Checkpoint | Brazier | Whimsy Hallow fire brazier, lights up when reached |
| Bouncy | Slime jelly | Green wobbly blob (her failed potions) |
| Mover | Chain lift / floating book | Chain-hung platform in cellar/tower; flying book in the library |
| Crumble | Rotten shelf | Cracked wood that sags, then drops |
| Turret | Gargoyle | Stone gargoyle that spits hex bolts |
| Mouth | Mimic door | A wooden trapdoor with teeth |
| Flood | Overflowing cauldron | Rising hex brew (purple-green instead of red) |
| Refill | Shell wisp | Gold ring with shell icons |
| Finish | Hex orb | Glowing purple orb, 3 hits |

---

## 3. Wider levels: climb diagonally, not just up

### The change

Right now levels are a 1280 px wide vertical shaft and the camera only follows height. New rule:

- **Each level sets its own bounds.** Width can be 1280 up to about **3840 px** (3 screens). Height is whatever the climb needs.
- **The camera follows you on both axes**, smoothly, and stops at the level's edges so you never see past the walls.
- The overall direction is still **up**: every level ends higher than it starts. But the path goes up-right, up-left, and sometimes sideways for a stretch.

### Camera rules

- Follow the player on x and y with smoothing (Godot `Camera2D` position smoothing, speed ~6).
- **Look ahead** a little in the direction you're flying (about 120 px at full speed), so you see where you're going.
- Keep the player slightly **below centre** vertically (~60 px), because the goal is usually above.
- Clamp to the level bounds with `limit_left/right/top/bottom`.
- During the mid-air slow-mo, don't move the look-ahead. A swinging camera while aiming feels awful.

### Spacing rules for sideways travel

From the reach numbers in LEVEL_DESIGN.md:

| Move | Across | Up |
|---|---|---|
| One full shot at 45°, land at the same height | ~380 px | 0 |
| One full shot at 45°, land at the top of the arc | ~190 px | ~95 px |
| Flat-ish shot (≈20° above horizontal), same height | ~400 px | 0 |
| Two shots, both angled | up to ~500 px | up to ~200 px |

- **Easy sideways hop:** up to 300 px across at the same height.
- **Hard sideways hop:** 300 to 380 px.
- **Over 380 px across** needs both shells, a refill, a slime pad or a mover.
- The screen shows 1280 px across, so with the camera centred you see ~640 px to each side. The next platform must be **visible before the jump**: never more than ~550 px away sideways.
- Long sideways stretches need a **ceiling** sometimes, or the player will just shoot up over everything. Low ceilings make horizontal sections feel different from climbing.

### Layout shapes

Mix these inside a level. Each one is a section between checkpoints.

**1. Staircase.** A diagonal line of ledges going up-right (or up-left). The bread and butter. Each step ~200 px across, ~120 px up.

```
                         [==]
                 [==]
         [==]
[==]
```

**2. Switchback.** Climb up-right, then a wall forces you up-left, then up-right again. Like a zig-zag ramp. Good for pacing: each leg is a mini-section.

```
[====]  ←←←←←←←←←  [  ]
                    |  |
[  ]  →→→→→→→→→  [====]
```

**3. Corridor.** A flat run with a low ceiling (~140 px headroom). You can't go up, so you have to do shallow shots across. Great for turrets (gargoyles firing along it), crumbles and mouth doors set in the floor.

**4. Shaft.** The old straight-up climb, kept narrow (≤ 480 px wide). Use it as a short contrast between wide sections, not the whole level.

**5. Hall.** A big open room, 2 screens wide, with several routes up: a safe slow one and a fast risky one (refills over spikes). Good for orb rooms.

### Overall level shapes

Draw each level as a rough path before placing blocks. A few patterns:

- **Diagonal (↗):** start bottom-left, orb top-right. The simplest.
- **Lightning bolt (↗ ← ↗):** up-right, a corridor back left, up-right again.
- **Tower spiral (↗ ↖ ↗ ↖):** switchbacks the whole way. Good for the Tower zone.
- **Wide room (→ ↑ ←):** cross the room on the floor, climb the far wall, come back across the top to the orb.

---

## 4. The 10 levels

Same mechanic order as LEVEL_DESIGN.md, now with zone, shape and orb room.

| # | Zone | Title | New idea | Shape | Size (w × climb) | Orb room |
|---|---|---|---|---|---|---|
| 1 | Cellar | Wake Up, You're a Gun | Charge, two shells, spikes | Diagonal ↗ | 1920 × 1200 | Wide wine-cellar floor, orb hops between barrels |
| 2 | Cellar | The Chain Lift | Movers and lifts | Lightning bolt | 2560 × 1400 | Orb sits on a moving chain platform |
| 3 | Cellar | Loose Shells | Refills (shell wisps) | Diagonal ↗ with a wisp-only gap over a spike pit | 2560 × 1600 | Orb floats over a pit; wisps let you hover near it |
| 4 | Library | Quiet Please | Slime jelly pads | Wide room → ↑ ← | 3200 × 1400 | Slime floor; you bounce while aiming |
| 5 | Library | Rotten Shelves | Crumbling shelves | Switchback | 2560 × 1800 | Floor is crumble, walls are safe |
| 6 | Library | Gargoyle Gallery | Gargoyles (turrets) | Corridor-heavy lightning bolt | 3840 × 1400 | Gargoyles on both sides between hits |
| 7 | Library | Mind the Doors | Mimic doors (mouths) | Shaft + halls, gates as floors | 1920 × 2200 | Orb behind one mimic door |
| 8 | Tower | It's Boiling | Cauldron flood (chase) | Tower spiral | 2560 × 2400 | Flood stops when you reach the orb room |
| 9 | Tower | Everything Hates You | Mixed gauntlet | Lightning bolt, long | 3840 × 2400 | Mix of all |
| 10 | Tower | Morwen | Finale + heart orb | Spiral, flood over last third | 2560 × 3000 | Morwen herself, throws bolts between hits |

Keep the "teach → test → twist" structure from LEVEL_DESIGN.md: three sections, a brazier between each, then the orb room.

---

## 5. What has to change in code

Items 1, 2, 3 and 5 are **done** (wide levels work now; see `levels/level_01_wake_up.tscn`). The rest is in progress.

1. **Done. `level.gd`:** add `@export var bounds: Rect2` (the level's playable area). Default to the old 1280-wide shaft so existing levels still load.
2. **Done. `main.gd` / camera:** follow x as well as y, use smoothing and look-ahead, set the camera `limit_*` from `level.bounds`.
3. **Done. Out-of-bounds death:** replace the fixed `x < -24 / x > 1304` and `y > 740` checks with "outside `bounds` by more than 24 px", plus the existing 420 px below-checkpoint rule.
4. **New `hazards/orb.gd`:** an `Area2D` with `hits_left = 3` and `spots: Array[Vector2]`. Listen to the player's `shot_fired`; if the orb is within range and inside the blast cone, crack it and move to the next spot. On 0, call the level-finish code that `is_finish` uses now.
5. **Done. Flood:** it already spans the whole width; make it use `bounds` width instead of 1280.
6. **Intro and ending cards:** three text screens before level 1, one after level 10. A `Label` on a black `ColorRect`, click to advance.
7. **Done. LEVEL_DESIGN.md:** "World rules" now describes wide levels.
