# How to design a floor: the thought process

This is how the existing levels were designed, written as a process you can follow. Read it before building a floor. It goes with two other files:

- [LEVEL_DESIGN.md](LEVEL_DESIGN.md): the hard numbers, every mechanic's settings, and the floor rules (exit and entry holes). **That file wins** if a number here disagrees with it.
- [STORY.md](STORY.md): what each floor is, its zone and its title.

The short version: **play every jump in your head before you place it.** Know which shot the player will use, where their cursor will be, and what happens when they miss. A level is fun when every jump is a small decision, every miss has a fair cost, and the cost grows as the floor goes on.

---

## 1. Think like the player

The player is a shotgun. They hold the mouse button to charge, release to fire, and fly **away** from the cursor. They have 2 shells and reload only by landing. That means:

- **To go up, the cursor goes below the gun.** To go up-right, the cursor goes down-left. Players aim at the opposite side of where they want to go, so every jump is a little puzzle.
- **One shot sets your velocity; it doesn't add to it.** Firing while falling cancels the fall. The second shell is a rescue as much as a boost.
- **The second shell is slow motion.** Charging it in the air slows time to 35%, so the second shot is the precise one. Design jumps where the second shot is the one that steers.
- **Landing stops sideways motion dead.** No sliding off ledges. A ledge you touch is a ledge you keep.
- **If the build has the solid barrel** (the `assets-test` branch): the gun's barrel is solid and reaches 38 px. Standing on the muzzle lifts you ~26 px, and wiggling it into a floor hops you ~113 px **without a shell**. So a ledge less than ~140 px above another can be reached for free. Keep jumps you want to *require* a shot at 150 px up or more, which the zigzag (~170) already does.

### The five questions, for every jump

Before you place a platform, answer these from the player's point of view, standing where they'll stand:

1. **Can I see it?** The target and any hazard near it must be on screen before the player commits. The camera shows about 360 px above the player and about 640 px to each side.
2. **Which move is it?** Name it from the move list in section 2: a hop, a stretch, a zigzag, a drift... If you can't name the move, the jump is probably random.
3. **Where is my cursor?** If the answer is "straight down and slightly left", good. If the jump needs a cursor position the player can't judge, like a shot almost exactly sideways from a moving platform, make the target bigger.
4. **What happens if I miss short? If I miss long?** Look at where a short shot falls and where an overshoot flies. That landing spot *is* the difficulty. See section 3.
5. **What does this jump teach or test?** Every jump should either introduce something, practise it, or test it under pressure. If it does none of those, cut it or change it.

---

## 2. The move list

These are the moves the levels are built from. Numbers use full-charge shots (580 px/s, gravity 880). A full shot straight up rises ~190 px; a tap rises ~80 px.

| Move | What the player does | Rise | Across | Shells |
|---|---|---|---|---|
| **Hop** | One shot, landing on a ledge up and to the side | up to 150 | up to 200 | 1 |
| **Stretch** | One perfect full shot almost straight up | 150 to 175 | under 100 | 1 (or 2 safely) |
| **Zigzag** | Shot 1 straight up, shot 2 sideways at the top | ~170 | ~250 to 330 | 2 |
| **Tower** | Two full shots straight up | up to 330 | small | 2 |
| **Side hop** | One 45° shot to a ledge at the same height | 0 | up to 300 (380 hard) | 1 |
| **Drift** | Two angled shots across a wide gap | up to 200 | up to 500 | 2 |
| **Catch** | Fall, then fire down to stop the fall and land | negative | small | 1 |
| **Pad stack** | Drop onto a bounce pad, ride it up, shoot at the top | pad height + 190 | varies | 1 |
| **Ring chain** | Fly through refill rings to climb with nothing to land on | ~190 per half ring, ~380 per full ring | varies | refilled |

### The standard move is the zigzag

Most jumps in the existing levels are the **zigzag: rise about 170 px, move about 300 px sideways**, alternating left and right. Ledges sit at x ≈ 470, then 805, then 505, then 850, while each one is ~170 px higher than the last.

Why it works:

- **170 px up is the decision band.** One perfect full shot can just make it (~190 px max), and two shells make it safely. The player always has a choice: risk it with one shell, or play safe with both. A gap of 120 px is a non-decision; a gap of 220 px is no choice at all.
- **300 px across can't be done with the first shot alone**, so the second shot has to steer. That's the slow-motion shot, the most satisfying moment in the game.
- **Alternating sides** makes the player rotate their aim every jump: cursor bottom-left, then bottom-right. It never becomes autopilot.

Use the zigzag as the backbone and break it up with the other moves. **Never use the same move more than 3 times in a row.**

---

## 3. Difficulty is the cost of a miss

Gap size barely changes difficulty, because the player can always use two shells. What changes difficulty is **what happens when they miss**. Decide the miss cost for every jump on purpose:

| Cost | When you miss | Feels like | Use for |
|---|---|---|---|
| **0: free** | You land back on the same ledge or the floor | Practice | Teaching a new idea |
| **1: small** | You fall one ledge down | A slap on the wrist | Early test jumps |
| **2: medium** | You fall back to the last checkpoint | "Ugh, again" | Main test of a section |
| **3: death** | Spikes, the flood, or out of bounds | Tension | Twists and finales only |

How to set the cost:

- **Something to fall onto:** for cost 0 or 1, put the previous ledge, or the floor, right under the jump. For cost 2, leave the area under the jump open down to the last checkpoint.
- **Spikes:** for cost 3, line the floor of a pit with spikes, or put a spiked block where a short shot would fall.
- **Chain the costs:** two cost-1 jumps in a row, where the second misses onto the first, are easier than one cost-2 jump. Long sections with no ledges underneath are what make players sweat.

**Inside a section, the cost should climb: 0 → 1 → 2 → 3.** That's what makes difficulty feel like it's rising even when the jumps look the same.

---

## 4. How to shape the path with hazards

Platforms say *where* to go. Hazards say *how* to get there. In the existing levels, spikes are almost never random. They're placed in exactly three ways:

1. **The blocker: a spiked block in the straight-up line.** Put a small block (60 to 115 px wide) with spikes on top directly between two ledges. Now "fire straight up twice" hits spikes, and the player has to arc around it, which turns a tower into a zigzag. Use it to stop players from cheesing a section by going straight up.
2. **The nub: a short spike strip (20 to 40 px) on the outer edge of a ledge.** It punishes overshooting, not undershooting. The player learns to use a bit less power. Put nubs on the side the zigzag is coming from, so landing too far is the mistake.
3. **The pit: a long spike strip on the floor of a gap.** It turns a cost-1 or cost-2 jump into cost 3. Use it once the player has had a few safe tries at the same move.

Spikes that the player can't see before committing are never fair. If a spike is above the screen when they'd have to commit, move it down or add a ledge before it.

### The same idea for each mechanic

| Mechanic | Teach (cost 0-1) | Test | Twist |
|---|---|---|---|
| **Moving platform** | A slow slider near the ground (`period` 4, travel ~400 sideways) | A lift going up (`travel` 0, -260) that carries you to the next ledge | Two or three small movers out of step (`period` 2.4 to 3, `phase` 0.25 / 0.5), with spikes at the end of a path |
| **Wait-for-player lift** | Use it right after a crumble, so it feels like a rescue | A long lift (420 px) to skip a section | — |
| **Crumbling shelf** | Two crumbles in a row as stepping stones, `delay` 0.5 | A crumble you must leave in a set direction | A chain of crumbles into a lift, `delay` 0.3 |
| **Bounce pad** | A pad on the floor: drop onto it to get your height back | A pad in the air, with a spiked block next to where you bounce | An angled pad (`rotation` -0.6) that redirects you, and no reloading ledge for two moves |
| **Bounce walls** | Line both sides of a shaft so falling off the side bounces you back | — | — |
| **Turret** | Fixed, slow, at the bottom: `interval` 1.8, `bullet_speed` 220, firing across a ledge | Firing down a climbing path (`rotation` 1.57), `interval` 1.4; or a burst of 3 from the side | Aimed turrets (`aimed`, `interval` 1.6, speed 340) near spikes, so a knock *into* spikes is the danger |
| **Mouth gate** | One full-width floor with one mouth: `open_time` 1.8, `warn_time` 0.6, gap 150 | Two mouths in one floor, out of step (`phase` 0.5), `open_time` 1.3 | Two gates stacked 100 px apart (pass both in one flight), `open_time` 0.9, `warn_time` 0.35, gap 110 to 120, spikes beside the exit |
| **Refill ring** | One full ring in an open area, above the floor | A drifting ring (`travel` -250, 0) and a one-time ring (`respawn_time` 0) over spikes | A shaft with spiked walls and no ledges: half rings every ~190 px, a full one-time ring at the top |
| **Flood** | — | — | Trigger it just above the middle checkpoint (`trigger_y`), so only the last third is a chase; `speed` 45 to 55, `acceleration` 2.5 to 3 |

**Teach mechanics with spikes far away and the floor close.** The first time the player meets a new thing, failing should cost almost nothing.

**The danger of a non-lethal hazard is where it pushes you.** Turret bolts don't kill; mouths don't kill; bounce pads don't kill. Make them dangerous by putting spikes or a long fall where they send you.

---

## 5. Building a floor, step by step

### Step 1: draw the path first

Before placing any block, decide the floor's shape (LEVEL_DESIGN.md section 1 and STORY.md section 3): diagonal, zigzag switchback, corridors, shaft, or hall. Write the path as a list of sections:

```
Section A (teach):  bottom-left, zigzags up-right, ground underneath.   ~500 px climb
  checkpoint
Section B (test):   corridor to the right over a spike pit.            ~400 px across, ~300 px climb
  checkpoint
Section C (twist):  switchback up-left, two-shell jumps, flood chase.  ~600 px climb
  ledge under the exit hole -> exit
```

Each floor has **3 sections and 2 to 3 checkpoints**, ending at the exit hole (or the orb room on floor 10).

### Step 2: place the ledges, one jump at a time

For each jump:

1. **Pick the move** (section 2), based on what this part of the section is for.
2. **Compute the target** from the ledge the player stands on. Measure from the *top* of the ledge. A zigzag from a ledge whose top is y = 405, x = 785 puts the next ledge's top near y = 235, centre x ≈ 480 to 500.
3. **Set the width** by difficulty: 160 to 210 px for teaching, 150 to 170 for testing, 120 to 140 for twists, and never under 90 px. Checkpoints are 160 to 200 px (floor 1 uses up to 384 for the last one). Mechanics' gates and corridors can be much wider.
4. **Check the headroom:** at least 60 px of open space above a ledge the player shoots up from.
5. **Answer the five questions** (section 1). Fix anything that fails.
6. **Set the miss cost** (section 3): what's under this jump?

Keep everything on the 16 px grid where you can. Ledges are 16 px thick; spike-block bases are 20 px; walls and the ground slab are 32 px.

### Step 3: shape it with hazards

Now add blockers, nubs and pits (section 4) to:

- stop the obvious shortcut (usually "go straight up twice"),
- raise the miss cost along the section, 0 → 1 → 2 → 3,
- make the floor's new mechanic matter.

### Step 4: pace it

- **One hard jump, then a breather:** after the hardest jump of a section, give a wide, safe ledge or a checkpoint.
- **Checkpoints every ~500 to 700 px of climbing** (or ~1200 px of sideways travel). Wide (160+), safe, and right after a hard part, never right before it.
- **The last section is the hardest.** If there's a flood, trigger it just above the second checkpoint so only the final stretch is chased.
- **End calm.** The ledge under the exit hole is wide and safe, no more than 240 px below the ceiling.

### Step 5: the hint and the title

- The `hint` is one sentence that teaches the new mechanic, in plain words, e.g. "Gold rings reload your shells in midair. Chain them to climb where there's nothing to land on."
- The `title` comes from STORY.md. The first floor of each zone also gets Mrs. Sandwitch's `taunt`.

---

## 6. Using the width of a floor

Floors are up to 3 screens wide. Width is a tool, not just more space:

- **Diagonal climbs** feel like progress because the scenery slides sideways *and* down.
- **Two routes:** in a wide hall, offer a slow safe route (more ledges, ground underneath) and a fast risky one (a refill ring over spikes). Players pick their own difficulty. Put the risky one where they can see it from the safe one.
- **Corridors** (a ceiling ~140 px above the floor) stop players from shooting up over everything. Use them for side hops, turrets firing along the corridor, and mouths in the floor.
- **Sideways jumps over 380 px need help:** two shells, a ring, a pad or a mover.
- **The next target is never more than ~550 px away sideways**, or the player can't see it before jumping.
- **Line the edges with walls** so the sides of the floor are bonk-safe, not deadly.

---

## 7. Difficulty across the 10 floors

Each floor adds **one** new mechanic and brings back older ones. The new one is taught in section A. The old ones appear in sections B and C, and more of them appear as the tower goes up. Floors 3, 6 and 9 are **checkpoints of difficulty**: they combine everything so far and test it properly.

| Floor | New mechanic (section A) | Comes back (B and C) | Ledge width | Usual move | Highest miss cost | Flood |
|---|---|---|---|---|---|---|
| 1 | Charge, two shells, spikes | — | 160 to 190 | hop, stretch, zigzag | 2 (spike pit once, at the end) | No |
| 2 | Moving platforms, lifts | spikes (blockers, nubs) | 150 to 180 | zigzag, ride and jump off | 3 | No |
| **3** | Refill rings | movers, spikes | 150 to 170 | zigzag, ring chain | 3 | No |
| 4 | Bounce pads and walls | rings, spikes | 140 to 170 | pad stack, drift | 3 | No |
| 5 | Crumbling shelves | lifts, pads | 130 to 160 | zigzag on crumbles, into a lift | 3 | No |
| **6** | Turrets | movers, crumbles, spikes | 130 to 160 | side hops in corridors | 3 | Short chase, last section |
| 7 | Mouth gates | turrets (light), rings | 120 to 150 | timed towers through gates | 3 | No |
| 8 | The flood (whole-floor chase) | rings, pads, movers | 120 to 150 | fast zigzags, no hesitation | 3 | Whole floor |
| **9** | Nothing new: the gauntlet | everything except the flood | 100 to 140 | everything | 3 | No |
| 10 | The orb room and the witch | everything | 100 to 140, wide orb room | everything | 3 until the orb room, then 0 | Last third, stops at the orb room |

Rules behind the table:

- **Never two new mechanics in one floor.** Combining old ones is fine.
- **Each floor is a little harder than the last, never a jump.** Most of the increase comes from miss cost, ledge width and hazard timing (`period`, `interval`, `open_time`), not from bigger gaps.
- **Turn one knob at a time.** If a floor's mouths are faster, don't also shrink its ledges.
- **After a hard floor, teach the next mechanic gently.** Floor 4's section A should feel easier than floor 3's section C.
- **Settings tighten across the game the same way they tighten inside a floor:** a mover with `period` 4 on floor 2 can be `period` 2.4 by floor 9; a turret's `interval` goes from 1.8 down to 1.2.

### Playtest targets

| Floors | Time | Deaths |
|---|---|---|
| 1 to 3 | 30 to 90 s | 0 to 5 |
| 4 to 7 | 1 to 2 min | 3 to 10 |
| 8 to 10 | 2 to 3 min | 8 to 20 |

If one section causes more than half of a floor's deaths, it's too hard for where it is. Lower its miss cost first, before changing the gaps.

---

## 8. Worked example: floor 1, "Wake Up, You're a Gun"

This is the thinking behind `levels/level_01_wake_up.tscn`, jump by jump. Ground top is y = 560; up is negative. Ledge tops are 8 px above their centre.

**The plan:** a diagonal up-right, then a switchback up-left to the exit. 1920 px wide, three sections. The only hazard is spikes, and they only matter in the second half.

**Section A, teach (cost 0):** the player has never fired a shot.

- Start at x = 160 on solid ground that runs to x = 896. Everything in section A falls back onto this ground, so missing costs nothing.
- Step 1 at (480, 440), 160 wide: top 432, so 128 px up and ~320 across. An easy hop, or a tower and a nudge. It teaches "aim down-left to go up-right".
- Step 2 at (736, 336), 160 wide: 104 up, 256 across. Same move again, so it sinks in.
- Checkpoint 1 at (1008, 224), 192 wide. Its left edge (912) hangs over the **spike pit** that starts at x = 896. The player sees the spikes below for the first time from a safe spot.

**Section B, test (cost 3, but forgiving):** the same hops, now over spikes.

- Step 3 at (1296, 120), 128 wide (narrower), and step 4 at (1520, 8), 128 wide: about 105 to 110 up and ~225 to 290 across each. Same move as section A, but now a miss lands in the pit. The player already knows the move; now it matters.
- Checkpoint 2 at (1760, -104), 192 wide, near the right wall: the breather.

**Section C, twist (cost 2):** the direction flips and the jumps need both shells.

- Step 5 at (1504, -296), 128 wide: **192 up**, just above one full shot. The player has to use both shells for the first time, and turn around to go up-left.
- Step 6 at (1200, -400), 128 wide: 104 up, ~300 across, back to a familiar hop.
- The top floor, 136 px up from step 6: a wide stone floor at (888, -528) and, joined to its left, the finish ledge at (512, -536), 384 wide. Together they make one long safe landing. A side hop left gets you under the exit. It's wide because it's the end of the floor.
- The ceiling at y = -816 to -784 has the **exit hole** at x 416 to 608, directly above the finish ledge. The ledge top (-544) is 240 px below the ceiling, so two straight-up shots go through the hole with room to land on the next floor.
- The twist is "new move", not "new danger": a short miss in section C usually drops onto a lower ledge or checkpoint 2. Only a bad miss reaches the old spike pit. One new thing at a time, even inside a floor.

---

## 9. Check your floor before you call it done

1. **Do the reach math for every jump.** Measure top to top. Compare with the move list. Nothing over 330 px up without a pad, ring or lift.
2. **Fly it with F7** (debug flight) to see spacing and what's on screen from each ledge.
3. **Play it for real** with full-charge shots only, then again trying to cheese it by going straight up. If straight up works where it shouldn't, add a blocker.
4. **Read the playtest log** in `playtest_logs/`: where did you die most?
5. **Run the checklist** at the end of LEVEL_DESIGN.md: visibility, rhythm warnings, no softlocks, checkpoints, bounds, walls, ceiling, exit and entry holes.

### Smell tests

- **Three identical jumps in a row:** change one.
- **A jump with no answer to "what if I miss?":** you haven't decided its cost yet.
- **A hazard that doesn't change how the player moves:** it's decoration. Move it into the path or remove it.
- **A section where the hardest jump comes first:** reorder it.
- **The player can't see the next ledge from where they stand:** move it closer or lower.
