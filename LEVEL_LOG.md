# Level log: building the tower

Running log of the level-design work. **Read the "Where we are" section first** to pick up where the last step stopped. Every step is logged as it happens.

## Where we are

- **Current step:** all 10 floors are built and registered in `main.gd`. Checks running in the background: floor 6 (re-check after a fix), 8, 9 and 10. Each writes to `tools/verify_NN.txt`.
- **Next step:** read `tools/verify_06.txt`, `_08`, `_09` and `_10`, fix and re-check any failing floor, then run `tools/check_tower.gd` on the whole tower and log the final state.
- **Open issue sent to the Art Session:** the barrel touching a slime pad always gives only `min_speed` (see step 9). Not fixed yet; player.gd is the Art Session's file.
- **Not committed.** All work is local, in the `assets-test` checkout. Nothing is pushed.

## How the floors are made

- **Generator:** `tools/floor_kit.py` writes `.tscn` floors from short Python descriptions, and `tools/build_floors.py` holds one function per floor. Run `python tools/build_floors.py 2` to rebuild floor 2.
- **Never hand-edit a generated floor's `.tscn`.** Change its function in `build_floors.py` and rebuild. Floor 1 (`level_01_wake_up.tscn`) is the exception: it was made by hand.
- **Checking:** `python tools/floor_solver.py levels/<file>.tscn` simulates every shot from every surface and reports the route, each jump's fewest shells and how many ways it can be done:
  - 2-shell jumps: under 15 ways is precise, 15–60 fair, 60+ easy.
  - 1-shell jumps: under 6 ways is precise, 6–20 fair, 20+ easy.
  - Ring hops are 1-shell plans.
- **Intended-route names:** surfaces and rings on the intended route are named `P01_`, `P02_`... in order. The solver checks that chain jump by jump.
- **What the solver doesn't simulate:** platform movement (it tries both ends), crumble timing, turret bolts, mouth timing, the flood and the barrel wiggle.
- **Real-game replay:** `tools/replay_floor.gd` flies the solver's working shot plans in the real game, including the solid barrel, the capsule body, spikes and wisps. Steps:
  1. `python tools/floor_solver.py levels/<file>.tscn --plans=tools/plans_NN.json`
  2. Copy `tools/replay_floor.gd` to the project root as `_replay_tmp.gd` (tools/ is ignored by Godot).
  3. `Godot --headless --path . -s res://_replay_tmp.gd -- <floor index, 0-based> tools/plans_NN.json`
  4. Delete the temp copy.

  Every intended jump must have at least one plan that works.
- **Tower check:** `tools/check_tower.gd` (run the same way, no arguments) checks every floor loads, each `Entry` sits on the `Exit` below, and the player can stand at each `Start`.
- **The barrel kills on spikes:** in the real game (assets-test), the barrel touching spikes kills you, and the body is a capsule along the gun. The solver doesn't model either, which is why the replay step exists.
- **Notes in the scene:** each generated floor stores a short design note in its root node's `editor_description`, visible in the Godot inspector.

## The tower plan (10 floors)

| Floor | Zone | Title | New mechanic | Shape / side movement | Status |
|---|---|---|---|---|---|
| 1 | Cellar | Wake Up, You're a Gun | Charge, two shells, spikes | Diagonal up-right, a pillar ditch run sideways | **Done** (made earlier, solver passes) |
| 2 | Cellar | The Chimney | Shell wisps (refill rings) | Across a spike pit on wisps, then a **diagonal tunnel** up-left (the user's drawing idea) | **Done** (solver + real-game replay pass) |
| 3 | Cellar | The Chain Lift | Moving platforms, lifts | Arrive far right, ride LEFT over a spike river, lift up, fast slider back RIGHT under a spiked crusher | **Done** (solver + replay pass) |
| 4 | Library | Quiet Please | Slime pads and bounce walls | Across right on a pinball run of pads, up a shaft with slime walls, back LEFT on top | **Done** (solver + replay pass) |
| 5 | Library | Rotten Shelves | Crumbling shelves | Switchback: LEFT over safe floor, RIGHT above a spiked divider into a lift, LEFT on fast crumbles | **Done** (solver + replay pass) |
| 6 | Library | Gargoyle Gallery | Turrets | Lightning bolt of 3 corridors: RIGHT, LEFT on a long slider, RIGHT across the top (exam floor) | Built, re-check running |
| 7 | Library | Mind the Doors | Mimic doors (mouths) | Door hops up through gates, a corridor LEFT with a sideways door, a double gate | **Done** (solver + replay pass) |
| 8 | Tower | It's Boiling | Flood, whole floor | Spiral: RIGHT, LEFT, RIGHT with a wisp, slider, crumble and pad | Built, check running |
| 9 | Tower | Everything Hates You | Nothing new: gauntlet | Corridor LEFT over a pit, a second diagonal tunnel going up-RIGHT, gate and aimed gargoyle | Built, check running |
| 10 | Tower | Morwen | Orb room | Gargoyle and lift, a two-door gate, then the flood up to the orb room | Built, check running |

Order change from STORY.md: wisps moved to floor 2 (the tunnel needs them) and movers to floor 3. Update STORY.md and LEVEL_DESIGN.md's tables when the floors are done.

## Step log

### 1. Picked up the work (done)
- Found floor 1 already redesigned by hand with `P01`–`P12` names, plus `tools/floor_solver.py`. No log existed.
- Solver on floor 1: **passes**. A route exists, no dead ends, and every intended jump is possible (the hardest is P10 to P11 at 40 ways with 2 shells).
- No floor 2 to 10 existed yet.

### 2. Built the generator (done)
- `tools/floor_kit.py`: ledges by top edge, checkpoints, wisps, spikes on any face, spiked blockers, movers, crumbles, pads, turrets on mounts, mouth gates, flood and orb.
- `frame()` builds the walls, the bottom slab with the 192 px entry hole (`Entry` marker at y 592) and the ceiling with the 192 px exit hole (`Exit` marker).
- `cells()` turns 32 px grid cells into stone blocks and adds spikes on exposed tops. This is how the diagonal tunnel is drawn: the solver can't simulate rotated blocks, so the tunnel is a staircase of stone.

### 3. Floor 2, The Chimney: first build (done)
- **Layout:** 2240 wide, climbs from the slab at 560 to the ceiling at -1120. Entry hole at x 320, exit hole at x 1104.
  - **A (teach, miss cost 0):** wisp P01 at (640, 380) under a ledge 410 px up, more than two shells can reach, so the wisp is needed. Then a zigzag to checkpoint P03.
  - **B (test, cost 3):** a spike pit from x 1280 to 2208. Wisps P04 and P05 (1 shell each) carry you 700 px sideways to checkpoint P06.
  - **C (twist): the Chimney.** A diagonal tunnel going up-left from above P06 (x 1920–2176 at y -160) to the top (x 1200–1456 at y -864), 181 px wide across. Its floor side is spiked, its ceiling side is plain stone, and wisps P07–P10 run down the middle. It opens onto the exit ledge P11 under the exit hole.
- **Solver, first pass:** beatable, no dead ends. Every intended jump is possible.
  - Tunnel wisp hops: P07 to P08 at 9 ways, **P08 to P09 at only 2 ways (too precise for floor 2)**, P09 to P10 at 5, P10 to the exit ledge at 20.
  - Shortcut found: from P02 you can reach wisp P04 directly, skipping checkpoint P03. That's harmless.

### 4. Floor 2: tuned the tunnel (done)
- Compared four wisp layouts in the tunnel with the solver:

  | Layout | Hardest tunnel hop |
  |---|---|
  | 4 wisps 170 apart | 2 ways |
  | 4 wisps with the 2nd a full refill | 2 ways (1 shell) |
  | 5 wisps 150 apart | 4 ways |
  | **5 wisps 140 apart, y -260 to -820** | **14 ways** |

- Applied the last layout. Wisps are now P07–P11 and the exit ledge is P12.
- **Solver, final:** beatable, no dead ends. Tunnel hops are 32, 14, 44, 58 and 46 ways; entering the tunnel from P06 is 372 ways with 2 shells; the exit is 192 ways.
- **Floor 2 status: built and solver-checked.** Not yet loaded in Godot (next step).

### 5. Floor 2 registered and loaded in Godot (done)
- Added `res://levels/level_02_chimney.tscn` to `FLOORS` in `main.gd`, after floor 1.
- `tools/check_tower.gd`: **all pass**. Both floors load, floor 2's entry sits exactly on floor 1's exit, and the player stands safely at both starts.

### 6. Real-game replay tools (done)
- Found that in the real game the barrel touching spikes kills, and the body is a capsule along the gun. The solver models neither.
- Added `--plans=FILE` to `tools/floor_solver.py`: it saves up to 24 working shot plans per intended jump.
- Added `tools/replay_floor.gd`: flies those plans in the real game and counts how many reach the target.
- **Floor 2 replay: all 13 hops work in the real game.** Plans that worked per hop:

  | Hop | Worked |
  |---|---|
  | slab to P01 | 5/16 |
  | P01 to P02 | 16/16 |
  | P02 to P03 | 15/24 |
  | P03 to P04 | 8/24 |
  | P04 to P05 | 8/8 |
  | P05 to P06 | 8/8 |
  | P06 into the tunnel (P07) | 12/24 |
  | tunnel hops P07–P11 | 8/8, 8/8, 6/8, 8/8 |
  | P11 to P12 | 7/8 |
  | exit | 16/16 |

- **Floor 2 is DONE.**

### 7. One-command check, and movers in the replay (done)
- `tools/verify_floor.py N`: builds floor N, runs the solver (saving plans), and replays the plans in the real game. The floor must be registered in `FLOORS` first.
- The solver now records which end of a moving platform each plan uses (`src`/`dst`, e.g. `P05_Slider@end`). The replay freezes each mover at that end, which matches a player waiting for the platform to arrive.
- **Design rule this depends on:** every mover is boarded from something that holds still (ground, a ledge, a checkpoint or a waiting lift), so waiting is always possible.

### 8. Floor 3, The Chain Lift (done)
- **Layout:** 2880 wide, slab at 560 to ceiling top at -1272. Entry hole at x 2560 (far right), exit at x 1824.
  - **A (teach, cost 0):** safe slab underneath. Slider P01 (travel -400, period 4) carries you left to ledge P02, then waiting lift P03 (travel -200) to checkpoint P04.
  - **B (test, cost 3):** spike river on the slab from x 32 to 1344. Slider P05 goes left (travel -300, period 3.5), lift P06 goes up (travel -260, period 3.2, half a cycle out of step), then checkpoint P07.
  - **C (twist):** fast slider P08 goes right (travel 360, period 2.6) under the **Crusher**, a block with spikes underneath at x 1180–1340, y -868. Jumping straight up at the slider's far end hits it. Then ledge P09, then the exit ledge P10.
- **First solver pass:** found a skip from the slab straight to the lift P03, missing the teaching slider. Fixed by raising P02 to top 290 and the lift P03 to top 190 (travel -200). Now every route rides P01.
- **Solver, final:** beatable, no dead ends. Hardest intended jumps are P01 to P02 (2-shell 435 ways) and P08 to P09 (447).
- **Real-game replay: all 11 hops work.** The weakest is P08 to P09 at 9/24 plans.
- **Floor 3 is DONE** and registered in `main.gd` after floor 2.

### 9. Floor 4, Quiet Please (done)
- **Layout:** 3200 wide, slab at 560 to ceiling top at -1152. Entry hole at x 400, exit at x 1504. Morwen's taunt: "Shhh. This is a library."
  - **A (teach, cost 0):** a wide strong pad, StrongPad (x 696–1144, strength 1.2, **min_speed 700**). Ledge P01 is 415 px up: two shells can't reach it, but pad plus one shell easily can. Then checkpoint P02.
  - **B (test, cost 3):** the pinball run. Three pads (PinPad1–3) at x 1640, 1960 and 2280 carry your sideways speed. The floor under them is spiked (y 330), and so is the corridor's roof (y -330). Ends at checkpoint P03.
  - **C (twist):** a shaft with slime walls (ShaftWallLeft, ShaftWallRight). Zigzag ledges P04 and P05 go up to checkpoint P06, then back LEFT along the top: P07, past a spiked blocker, P08, an optional TopPad, then exit ledge P09.
- **Problems found and fixed:**
  1. The solver can't use pads as route points (it only counts landings), so pads are no longer named `P##`.
  2. **Shortcut:** you could land on top of the pinball corridor's roof and skip sections B and C. Fixed by spiking the roof.
  3. The start was on the wrong side of the entry hole from the pad. Moved the start to x 576.
  4. Getting into the shaft was precise (6 ways). The left slime wall is now shorter (y -560 to -160) and P04 is lower; now 281 ways.
  5. **Real-game finding:** the teaching pad jump worked for only 1 of 8 plans in the replay. Tracing it showed two causes:
     - **Barrel pokes:** when the barrel touches a pad first, `player.gd` `_brace()` launches you at only the pad's `min_speed` (a ~100 px hop), whatever your fall speed. Players aiming down to shoot up hit this every time.
     - **Pad edges:** landing near the edge of a narrow pad bounced the player sideways into the entry hole.

     **Fix in the level:** the teaching pad is now 448 wide, away from the hole, with `min_speed` 700, so even a barrel touch launches ~280 px. Real game: 4/15 plans now work. **Fix in player.gd: suggested to the Art Session** (reflect the fall speed on barrel touches too).
- **Solver, final:** beatable, no dead ends. Intended jumps:

  | Hop | 2-shell ways |
  |---|---|
  | slab to P01 (via the pad) | 12 |
  | P01 to P02 | 185 |
  | P02 to P03 (pinball) | 66 |
  | P03 to P04 | 281 |
  | P04 to P05 | 253 |
  | P05 to P06 | 206 |
  | P06 to P07 | 264 |
  | P07 to P08 | 604 |
  | P08 to P09 | 86 |
  | exit | 137 |

- **Real-game replay: all 10 hops work.** Weakest: the pad jump at 4/15, P08 to P09 at 7/24, pinball at 9–11/24.
- **Floor 4 is DONE** and registered in `main.gd`.

### 10. Floor 5, Rotten Shelves: first build (in progress)
- **Layout:** 2560 wide, slab at 560 to ceiling top at -1452. Entry hole at x 2200, exit at x 1000. A switchback in three legs:
  - **Leg 1 (teach, cost 0):** crumbles P01–P03 step LEFT over the safe slab to checkpoint P04.
  - **Divider:** a bookshelf with a spiked top from x 720 to the right wall at y -140. Leg 2 runs above it.
  - **Leg 2 (test, cost 3):** crumbles P05 and P06 go up through the gap on the left, then P07–P09 go RIGHT above the divider (P09 `delay` 0.4) into waiting lift P10, then checkpoint P11.
  - **Leg 3 (twist):** fast crumbles P12 and P13 (`delay` 0.3) go back LEFT, with a spiked blocker in the straight-up line, to exit ledge P14.
- Registered in `main.gd` after floor 4.
- **First check:** solver and replay both pass. All 15 hops work in the real game (5 to 23 of 24 plans each).
  - Weak spot: **P05 to P06** (2-shell 11 ways, real 5/22), the hop up-left around the divider's left end from a crumble. It's precise and rushed at once.
  - A skip from the slab straight to P03 exists (2 ways). That's harmless.
- **Fix:** moved P05 to cx 700, top 0 (left of the divider's end) and P06 to cx 430. Re-check running (`tools/verify_05.txt`).

### 11. Floor 6, Gargoyle Gallery: first build (check running)
- **Layout:** 3840 wide (the widest floor), slab at 560 to ceiling top at -1012. Entry hole at x 400, exit at x 2240. A lightning bolt of three corridors:
  - **Corridor 1 (RIGHT, teach):** islands P01–P04 on the slab, spike patches between them, a spiked roof at y 330. Gargoyle1 at x 2600 fires LEFT down the corridor (interval 1.8, speed 220). Ends at checkpoint P05.
  - **Climb:** P06, crumble P07, P08 up the right side.
  - **Corridor 2 (LEFT, test):** checkpoint P09, then slider P10 (travel -1400, period 6) over a spiked floor at y -10, under a spiked roof at y -330. Gargoyle2 and Gargoyle3 fire DOWN from the roof, half a cycle apart. Ends at checkpoint P11 on the left.
  - **Corridor 3 (RIGHT, twist):** up the left side (P12, P13), crumbles P14 and P15, aimed Gargoyle4 (speed 340) above, ledge P16, a spiked blocker, P17, exit ledge P18.
- **Note:** the solver ignores gargoyle bolts. The real-game replay includes them, so bolts can make some replay plans fail.
- Registered in `main.gd` after floor 5.

### 12. Floor 7, Mind the Doors: first build (check running)
- **Layout:** 2560 wide, slab at 560 to ceiling top at -1032. Entry hole at x 1280, exit at x 600.
  - **A (teach, cost 0):** GateA, a full-width floor at y 380 with one slow door at x 1600 (open 1.8 s). Checkpoint P01 above it on the right.
  - **B (test):** GateB at y 40 with two doors at x 900 and 1700, half a cycle apart (open 1.3 s). Ledge P02 above.
  - **C (twist):**
    - A corridor runs LEFT from checkpoint P03 (x 1260) to ledge P04 (x 540). Its floor is at y -220 with a spike pit under the door, and its roof (y -452) is spiked on top.
    - **SideDoor**: a mouth turned 90° at x 900, so its jaws close top and bottom across the corridor. You time a side hop through it.
    - Then GateC (y -560, door at x 320) and GateD (y -660, door at x 470) sit 100 px apart and out of step: pass both in one flight to exit ledge P05.
- **Note:** gate floors aren't named `P##`. The solver treats doors as open holes, so it checks the geometry. The replay runs real doors, so timing can make some plans fail.
- Registered in `main.gd` after floor 6.

### 13. Replay fix for floods (done)
- `tools/replay_floor.gd` now resets every flood before each try. The flood follows the player, and teleporting between tries would otherwise put the water above them.
- **Re-check after the fix:** passes. P05 to P06 went from 11 ways to **335** (real game 8/24). All 15 hops work in the real game. **Floor 5 is DONE.**

### 14. Floor 6 first check, and a fix (re-check running)
- **First check:** solver and replay pass; all 19 hops work in the real game.
- **Weak spot:** checkpoint P05 to P06 (2-shell 17 ways, **real 2/16**). P05 sat under the end of the corridor roof, so you had to slide out sideways before climbing.
- **Not a real skip:** the solver's "slab to P06" route uses standing spots on the slab's far right, which you can only reach by crossing the corridor anyway.
- **Fix:** the corridor roof now ends at x 2300 (was 2640). Gargoyle1 hangs at the roof's end (x 2270, y 420, still firing LEFT). P05 moved to cx 2460 and P06 to cx 2800. Re-check: `tools/verify_06.txt`.

### 15. Floor 7 rebuilt around the door hop (done)
- **First check FAILED:** the route stops sat away from the gate floors, but you really land on each gate's top between doors. That made my named jumps impossible, and the solver's real route was a different chain.
- **Rebuilt** around the **door hop**: stand under a door, shoot straight up through it, drift sideways with the second shell and land on the gate's top. `floor_kit.gate()` gained `names={segment: name}` so a gate's top segment can be a route stop (e.g. `P01_GateA`).
- **Shortcut found:** from GateB's left side you could fly into the corridor's open left end and skip the sideways door. Fixed: the corridor is closed at its left end (CorridorEnd), and you leave it through a **hole in its roof** (x 432–592).
- **Unreachable:** corridor floor to P05 was 390 px. Lowered P05 to top -250; the double gate moved to y -400 and -500, the exit ledge to -690, and the ceiling top to -962.
- **Final layout:**
  1. GateA (y 400, slow door at x 700); its top right of the door is P01.
  2. GateB (y 230, doors at x 1300 and 2000, out of step) with checkpoint P02 on top.
  3. Corridor LEFT: P03 (right floor) over the door pit to P04 (left floor), with the sideways door at x 900.
  4. Out through the roof hole to P05.
  5. Double gate C/D (doors at x 330 and 480, 100 px apart). D's top is P06.
  6. Exit ledge P07.
- **Solver:** beatable, no dead ends. Hardest: P04 to P05 at 8 ways and the double gate at 18 ways (2-shell).
- **Real-game replay with the doors snapping: all 8 hops work.** The double gate is the hardest at 2/15; that's the twist. The first door hop is 4/24.
- **Floor 7 is DONE.**

### 16. Floors 8, 9 and 10 built (checks running)
- **Floor 8, It's Boiling** (2560 wide, top -1172, entry x 300, exit x 1950). Taunt: "You're not supposed to be up here."
  - The flood starts at the first jump (`trigger_y` 500, speed 48, acceleration 2.5).
  - Leg 1 RIGHT: P01, P02, full wisp P03, P04, checkpoint P05.
  - Leg 2 LEFT: slider P06 (travel -560), P07, crumble P08, checkpoint P09.
  - Leg 3 RIGHT: wisp P10, P11, BoilPad, P12, exit ledge P13.
- **Floor 9, Everything Hates You** (3840 wide, top -1422, entry x 3500 far right, exit x 3050).
  - A: corridor LEFT over a spike pit (x 1408–3404) under a spiked roof. Crumbles P01 and P02, slider P03 (travel -640), Gargoyle1 firing RIGHT, crumble P04, checkpoint P05.
  - B: the **second diagonal tunnel**, going up-RIGHT ("/") from above P05, its floor side spiked, wisps P06–P10 up the middle, then checkpoint P11.
  - C: GateE (y -640, door at x 2700), P12, aimed Gargoyle2, wisp P13, exit ledge P14.
  - New helper: `tunnel_cells()` builds either tunnel direction.
- **Floor 10, Morwen** (2560 wide, top -1900, entry x 1280, no exit hole, `is_final`).
  - A: P01, Gargoyle1, crumble P02, lift P03, checkpoint P04.
  - B: GateF (y -300, two doors out of step), P05, full wisp P06, checkpoint P07.
  - C: the flood from just above P07 (`trigger_y` -730, speed 55, acceleration 3). P08, BoilPad, wisp P09, P10, crumble P11, P12.
  - **Orb room:** P13_OrbRoom, a 480-wide finish platform at top -1520. The HexOrb sits above it with hop spots. The orb isn't wired into main.gd yet, so the finish platform ends the run for now.
- All three are registered in `main.gd`. The FLOORS list now has all 10.
