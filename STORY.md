# Story and world

The story behind Cursed Shotgun, and how it shapes each level. Read this with [LEVEL_DESIGN.md](LEVEL_DESIGN.md), which has the movement numbers and mechanics.

The tone is silly but straight-faced. The characters take it seriously; the player shouldn't.

---

## 1. The story

### Setup (intro card, 3 short screens)

1. **Sir Barrett** was the finest witch hunter in the kingdom. He came to Hexmoor Castle with one weapon: his trusty double-barrel shotgun.
2. The witch **Mrs. Sandwitch** caught him in the cellar. She didn't kill him. She did something worse: she turned him **into the shotgun**.
3. "A gun can't walk," she laughed, and floated up to the top of her tower. Her magic lives in the **hex orb** at the very top. Smash it and the curse breaks.

Then the game starts. No more text than that. Each line fits on one screen in Press Start 2P.

### Why the rules work the way they do

Every mechanic should have an in-world reason, so the player never asks "why?":

| Rule | Story reason |
|---|---|
| You only move by firing | You're a gun. Guns don't have legs. Recoil is all you've got. |
| 2 shells | Double barrel. Barrett always carried two. |
| Landing reloads both | Part of the curse: the castle feeds you shells every time you touch stone, so you can never run out and never stop being a gun. Mrs. Sandwitch thinks it's funny. |
| Mid-air slow-mo on the 2nd shell | Barrett's hunter instincts. Time slows when he aims. |
| Shell refill rings | **Shell wisps**: loose pieces of the curse floating around. Fly through one and it loads you. |
| Respawn at a checkpoint | Braziers. Barrett's spirit drifts back to the last fire he lit. |

### One continuous tower

The game is **one climb up one tower**. There are no level select screens and no loading between levels.

- The tower is built from **10 floors**. Each floor is its own level file, made separately, and the game stacks them on top of each other.
- You fly up through a **hole in the ceiling** of one floor and come out through a **hole in the ground** of the next. The climb never stops.
- **Every floor feels different:** new title, new zone look, new mechanic. When you enter a floor, its title appears big on screen (for example "FLOOR 4 · QUIET PLEASE") so you feel the change and the progress.
- Checkpoints (braziers) work across the whole tower. Falling sends you back to the last brazier you lit, never to the bottom.

### The hex orb (top of the tower only)

There is **one orb**, in the orb room at the top of floor 10. It takes **3 blasts** to break.

- You hit it by firing **toward** it. The blast goes where the cursor points, and you fly the other way. So every hit also knocks you away from the orb, and you have to get back for the next one.
- After each hit the orb cracks, flashes and **hops to a new spot** in the orb room. Hit 1 is easy, hit 3 asks for a real shot.
- A hit only counts within ~200 px and if the orb is inside a ~35° cone of the blast. A faint cone shows while you charge near the orb, so players learn the range.
- The orb room has a safe floor (normal ground, reloads), so a miss never kills you.

### Ending: the witch

When the orb shatters:

1. **Cutscene.** Everything stops. Mrs. Sandwitch appears in front of you. Your controls lock. She talks, one line per click, in Press Start 2P text boxes:
   - "My orb! Do you know how long that took to enchant?"
   - "Fine. FINE. You win, little boomstick."
   - "But think about it. Without me, you're just a gun on the floor. Who's going to carry you?"
   - "...You're aiming at me. Why are you aiming at me?"
2. **One click.** The cursor turns into a red crosshair locked on her. The charge bar fills on its own. A heartbeat sound. The player clicks once to fire.
3. **Black screen, instantly.** Cut to pure black on the click, no fade. The shotgun blast plays with a long **echo** that rolls away into silence.
4. **The game ends.** After the echo fades, show the title "CURSED SHOTGUN" and "Thanks for playing" in small text, then credits or back to the start. *(Optional: the time and death count from the whole run.)*

The ending is the only time in the game you shoot something without flying away. That's the point: the last shot is the only one that isn't recoil.

---

## 2. Three zones of the castle

The climb goes **cellar → library → tower**. This matches the asset shortlist, so art and story line up.

| Zone | Floors | Look (Whimsy Hallow + Dark Castle) | Music | Mrs. Sandwitch's taunt on arrival |
|---|---|---|---|---|
| **The Cellar** | 1–3 | Grey stone, wood, wine racks as ledges, potion shelves, sewer grates | Castle in Darkness | "Still kicking? Cute." |
| **The Library** | 4–7 | Stone, tall bookshelves as platforms and walls, candles, gargoyle statues | MonsterVania #2 | "Shhh. This is a library." |
| **The Tower** | 8–10 | Sandstone, arched windows, chandeliers, balconies, night sky outside | Final Castle | "You're not supposed to be up here." |

The taunt shows under the floor title on the first floor of each zone (set `taunt` on that floor). Everywhere else, `hint` stays a one-sentence mechanic tip.

### Mechanics as Mrs. Sandwitch's stuff

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
| Finish | Hex orb | Glowing purple orb, 3 hits. Top of floor 10 only. |

---

## 3. Wide floors: climb diagonally, not just up

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

Every floor starts at its **entry hole** (bottom) and ends at its **exit hole** (top). The shape is the path between them.

- **Diagonal (↗):** enter bottom-left, exit top-right. The simplest.
- **Lightning bolt (↗ ← ↗):** up-right, a corridor back left, up-right again.
- **Tower spiral (↗ ↖ ↗ ↖):** switchbacks the whole way. Good for the Tower zone.
- **Wide room (→ ↑ ←):** cross the room on the floor, climb the far wall, come back across the top to the exit.

---

## 4. The 10 floors

Same mechanic order as LEVEL_DESIGN.md. Each floor is a separate file; the game stacks them into one tower.

| Floor | Zone | Title | New idea | Shape | Size (w × climb) |
|---|---|---|---|---|---|
| 1 | Cellar | Wake Up, You're a Gun | Charge, two shells, spikes | Diagonal ↗, a pillar ditch run sideways | 1920 × 1680 |
| 2 | Cellar | The Chimney | Shell wisps (refills) | Across a spike pit on wisps, then a diagonal tunnel ↖ with a spiked floor | 2240 × 1840 |
| 3 | Cellar | The Chain Lift | Movers and lifts | Ride ← over a spike river, lift ↑, fast slider → under a spiked crusher | 2880 × 1992 |
| 4 | Library | Quiet Please | Slime pads and bounce walls | Pinball run → over spikes, slime-walled shaft ↑, back ← on top | 3200 × 1872 |
| 5 | Library | Rotten Shelves | Crumbling shelves | Switchback ← → ← over a spiked divider, crumbles into a lift | 2560 × 2172 |
| 6 | Library | Gargoyle Gallery | Gargoyles (turrets) | Three corridors → ← → under gargoyle fire, long slider | 3840 × 1732 |
| 7 | Library | Mind the Doors | Mimic doors (mouths) | Door hops ↑ through gates, a sideways door in a corridor ←, a double gate | 2560 × 1682 |
| 8 | Tower | It's Boiling | The flood, whole floor | Spiral → ← → between spiked dividers | 2560 × 1892 |
| 9 | Tower | Everything Hates You | Nothing new: gauntlet | Corridor ← over a pit, second diagonal tunnel ↗, gate and aimed gargoyle | 3840 × 2142 |
| 10 | Tower | Mrs. Sandwitch | Finale: the orb room | Gargoyle, lift, two-door gate, then the flood up to the orb room | 2560 × 2620 |

Keep the "teach → test → twist" structure from LEVEL_DESIGN.md: three sections with a brazier between each, then the exit hole. Floor 10 ends in the orb room instead.

---

## 5. What has to change in code

**Done:**

1. `level.gd` has `bounds` (Rect2). Levels without it act like the old 1280 px shaft.
2. The camera follows x and y with smoothing and look-ahead, and stops at `bounds`.
3. Leaving the sides or bottom of `bounds` by more than 24 px kills.
4. The flood spans the level's `bounds` width and works on any floor of the tower.
5. LEVEL_DESIGN.md describes wide floors and the floor-stacking rules.
6. **Tower stacking.** `main.gd` loads every floor in `FLOORS` and shifts each one so its `Entry` sits on the `Exit` of the floor below. The camera's sides follow the floor you're in; checkpoints, timer and deaths run for the whole tower. A flood stops once you leave its floor.
7. **Floor title banner.** Rising into a new floor shows "FLOOR N", its title and Mrs. Sandwitch's taunt (if set). Music follows the floor.
8. **Single-floor testing.** Number keys load one floor; flying up through its `Exit` clears it. T loads the whole tower.

**Next (code, not level work):**

9. **Hex orb** (`hazards/orb.gd`, written, not wired in): 3 hits, hops between `spots`. On the third hit, start the ending.
10. **Intro cards** (`story_cards.gd`, written, not wired in): the 3 setup screens before floor 1.
11. **Ending:** Mrs. Sandwitch's lines, the locked crosshair, one click, an instant black screen, an echoed blast, then "Thanks for playing".
