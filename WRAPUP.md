# Wrap-up checklist: Cursed Shotgun (submit by 18:00)

The game is called **Cursed Shotgun**. Use that name everywhere: title screen, window title, exports, jam page, logo, credits.

Started 14:00, Nov 14. Hard submit: **18:00**. Jam closes 23:59.

---

## 0. Get the repo in one place (first 15 min)

- [x] Commit the uncommitted work on `playtest1` (floors 8–10, main.gd, tools, docs)
- [x] New working branch **`planned_release`** (from `playtest1`) + merged `origin/main` (level design doc)
- [x] Merged friend's `level-redesign` (title screen, settings, SubViewport world, audio buses, stetson, 3 extra floors as sandboxes, WIP level editor not wired in)
- [x] Skipped `tower-draft`: an older parallel 10-floor tower with its own hazards; ours replaces it
- [ ] Push `planned_release`, friend switches to it
- [ ] Decide: use friend's Counterweight / Switchyard / Shellworks floors in the tower, or leave them as sandboxes

## 1. Intro logo

- [ ] `intro.tscn`: black screen, logo fades in, holds ~1.5 s, fades out
- [ ] Click / any key skips
- [ ] Set as the project's main scene, goes to the main menu when done

## 2. Main menu + settings (friend's branch)

- [ ] Hooked up after the intro
- [ ] Play, Settings, Quit
- [ ] Settings at minimum: music volume, SFX volume, fullscreen
- [ ] Check it works in the exported build, not just the editor

## 3. Play → New Game / Continue

- [ ] Pressing Play shows two buttons: **New Game** and **Continue**
- [ ] Save on every brazier lit: floor number + checkpoint id to `user://save.cfg`
- [ ] Continue is greyed out when there is no save
- [ ] Continue loads the tower and spawns at the saved brazier
- [ ] New Game wipes the save

## 4. Story scene (New Game only)

- [ ] Story cards from STORY.md section 1 (Barrett → turned into a shotgun → Mrs. Sandwitch and the orb at the top). `story_cards.gd` already exists, reuse it
- [ ] Click to advance, skippable
- [ ] Ends by loading floor 1

## 5. The tower (floors 1 → 10 stacked)

- [ ] Floors 1–10 load stacked in one run, no gaps between ceiling hole and floor hole
- [ ] Floor title shows on entering each floor
- [ ] Braziers save progress across the whole tower
- [ ] One full playthrough top to bottom with no softlocks
- [ ] Remove or hide the old `level_1_basics … level_7_refills` scenes from the build if unused

## 6. Boss fight: the witch (top of floor 10)

This replaces the old "3-blast orb room + one-click ending" in STORY.md.

**Phase 1: shoot the orb**
- [ ] Entering the boss room locks the gun to the **middle of the screen** (no recoil movement)
- [ ] Gun rotates to follow the aim; the witch flies around holding/near the orb
- [ ] Each hit cracks the orb one stage (crack sprites or shader, screen shake, sound)
- [ ] Decide hit count (suggest 4–5)

**Cutscene: the save**
- [ ] On the second-to-last hit, the witch swoops in and grabs the orb
- [ ] Taunt text box, one line per click ("Did you think this would be a walk in the park?")

**Phase 2: shoot the orb in her hand**
- [ ] Prompt on screen: "SHOOT THE ORB"
- [ ] Hitting it breaks the orb, the curse flies back into the witch
- [ ] She turns into a shotgun and recoils off screen
- [ ] End card / credits → back to main menu, clear save

## 7. Ship (start by 17:15 at the latest)

- [ ] Export (web build if the jam page plays in browser, plus Windows zip)
- [ ] Test the exported build from a clean folder / clean browser
- [ ] Credits screen or credits on the page from `ASSET_CREDITS.md`
- [ ] Jam page: title, short description, 3–4 screenshots, controls
- [ ] **Submit before 18:00**

---

## Suggested timeline

| Time | What |
|---|---|
| 14:00–14:15 | Section 0: commit, merge, get friend's branch in |
| 14:15–14:45 | Intro logo + hook up menu (1, 2) |
| 14:45–15:15 | New Game / Continue + save (3) |
| 15:15–15:30 | Story scene (4) |
| 15:30–17:00 | Boss fight (6) + tower full playthrough in parallel (5) |
| 17:00–17:15 | Bug fixing buffer |
| 17:15–18:00 | Export, test, submit (7) |

## If time runs out, cut in this order

1. Continue button (New Game only is fine)
2. Phase 1 orb crack stages (just count hits, flash on hit)
3. Witch-turns-into-shotgun animation (a flash + "the curse rebounds!" text + end card)
4. Settings beyond volume

Never cut: the export test and the submit.
