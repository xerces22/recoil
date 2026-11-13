# Asset shortlist: castle shotgun climb

Candidates for the castle look (cellar → library → tower top). Every licence below was checked on the source page on 2026-11-13. Nothing here is imported yet. When you import something, move its row into [ASSET_CREDITS.md](ASSET_CREDITS.md) and say where it's used.

All picks are CC0 (public domain). Credit is optional, but we credit everything anyway, as the README asks.

## Main tileset (environment)

| Pick | Creator | Licence | What we use it for | Notes |
|---|---|---|---|---|
| [Whimsy Hallow Asset Pack](https://crumpaloo.itch.io/whimsy-hallow) (formerly "Hardcore Dungeon Platformer Asset Pack") | Crumpaloo | CC0 | Stone wall tiles (stone, grey stone, sandstone, wood), **wooden shelves**, arched windows, pillars, candles, candelabras, chandeliers, statues, doors, levers | Side-view, 16×16, purple castle palette. Close to the mockup. The author asks that the raw assets not be resold or redistributed; using them inside a game is fine. Has no spikes and no torches. |

Level dressing ideas from this pack:
- **Cellar:** grey stone and wood tiles, sewer grates, stone pots, potion shelves.
- **Hall / middle levels:** stone tiles, wooden shelves, candle stands, knight and gargoyle statues.
- **Tower top:** sandstone tiles, arched windows, chandeliers, balconies.

## Spikes (hazards)

| Pick | Creator | Licence | Notes |
|---|---|---|---|
| [Dark Castle 8-bit Tileset](https://quintino-pixels.itch.io/dark-castle-8-bit-tileset) | Quintino Pixels | "CC1.0" on page; "credit not necessary", free + commercial use | Side-view 16×16 with spikes, chains, an animated torch and banners. Uses a different palette, so recolour the spikes to match Whimsy Hallow. A commenter says the download is missing some tiles shown in the preview. |
| Fallback: draw our own | Team | Original | A 16×8 spike row in Whimsy Hallow colours takes about 10 minutes. Credit as original art. |

## Player: shotgun

| Pick | Creator | Licence | Notes |
|---|---|---|---|
| [Shotguns Only](https://opengameart.org/content/shotguns-only) | Leozlk | CC0 | One sheet of about 10 pixel shotguns, pump-action and double-barrel. Pick one and add a 1 px dark outline so it reads against the wall. |
| [[Pixel Art] 2D shotgun](https://opengameart.org/content/pixel-art2d-shotgun) | Phani29 | CC0 | Single western-style shotgun sprite. |
| [Tiny gun icons (16x16)](https://opengameart.org/content/tiny-gun-icons-16x16) | congusbongus | CC0 | 16×16 icons including shotguns. Good if the player should be small. |
| [2D Guns](https://opengameart.org/content/2d-guns) | Kay Lousberg | CC0 | Clean, larger shotgun plus **bullets and ammo**, which could become the shell pips. Less pixel-y; check the scale before using it. |

Shell pips under the gun: take a shell from 2D Guns, or draw two 4×7 shells (red body, brass base). Credit drawn shells as original.

## Sound effects

| Pick | Creator | Licence | Use |
|---|---|---|---|
| [Gun reload sounds](https://opengameart.org/content/gun-reload-sounds) | SpringySpringo | CC0 | `shotguncock_0.wav` as the reload sound on landing. |
| [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library) | Ben Jaszczak et al. | CC0 | Shotgun blast. The download is a **194 MB .7z**, so grab only the shotgun files. |
| [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 | Landing thud, spike hit. Already on our sheet. |
| [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 | Menu clicks. Already on our sheet. |

## Music (CC0 chiptune, castle mood)

| Pick | Creator | Licence | Mood |
|---|---|---|---|
| [8-bit MonsterVania #2](https://opengameart.org/content/8-bit-monstervania-2-0) | HydroGene | CC0 | Action, castle-climb energy. A good main track. |
| [Castle In Darkness (Chiptune) 2](https://opengameart.org/content/castle-in-darkness-chiptune-2) | Pro Sensory (Alex McCulloch) | CC0 | Darker. Fits the cellar. The author asks for a credit by name. |
| [Final Castle](https://opengameart.org/content/final-castle) | Sudocolon | CC0 | Dramatic. Fits the tower top or the final level. |
| [Sinister Abode](https://opengameart.org/content/sinister-abode) | Zane Little Music | CC0 | Evil castle theme. |
| [Kenney Music Jingles](https://kenney.nl/assets/music-jingles) | Kenney | CC0 | Level-clear and death stings. Already on our sheet. |

## Font

| Pick | Creator | Licence |
|---|---|---|
| [Press Start 2P](https://fonts.google.com/specimen/Press+Start+2P) | CodeMan38 | OFL |

## Downloaded (2026-11-13)

Raw downloads live **outside** the Godot project, in `E:\Projects\GameJam\Recoil\downloads\`. Copy only the pieces you use into the project, then log each one in `ASSET_CREDITS.md`.

| Folder | What's there |
|---|---|
| `whimsy-hallow/extracted/` | One 2680×2896 atlas PNG (`Whimsy_Hallow_Dungeon_Asset_Pack_V1.62.png`) containing stone/wood tiles, wooden platforms and stairs, **banners**, stained-glass windows, pillars, candles, chandeliers, **fire braziers** (checkpoint candidate), statues, doors and characters. There is no licence file in the zip; the licence (CC0) is from the itch.io page. |
| `dark-castle/dark_castle_tileset.png` | A small 16×16 sheet with walls, a window, a banner, a chain, a torch and **spikes**. The palette is dark purple. |
| `shotguns-only/shotguns_2.png` | A sheet of about 10 pixel shotguns. **This is the player sprite source.** |
| `2d-guns/extracted/PNG/` | Vector-style guns and bullets. These don't match the pixel look, so use them for reference only. |
| `gun-reload-sounds/shotguncock_0.wav` | The reload sound. |
| `firearm-sound-library/shotguns/` | Mossberg (`N_26P`, `N_30P`) and Winchester Model 12 (`K_17P`, `K_22P`) blasts. These are long files and need trimming. The full `.7z` is also kept there. |
| `kenney-impact-sounds/extracted/` | 133 files, including `License.txt` (CC0). |
| `kenney-music-jingles/extracted/` | 89 files, including `License.txt` (CC0). |
| `music/` | `monstervania_2.mp3`, `castle_in_the_darkness_2.wav`, `final_castle.mp3`. |
| `font-press-start-2p/` | `PressStart2P-Regular.ttf` and `OFL.txt`. |

## Still open

- Spikes: recolour Quintino's spikes, or draw our own.
- Pick one shotgun from the sheets and outline it.
- Checkpoint object: use a Whimsy Hallow candle stand that lights up. The pack has no torches; Quintino has an animated torch if we want one.
