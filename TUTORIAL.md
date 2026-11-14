# Tutorial: the cellar floor

Mrs. Sandwitch throws Mr. Guy into her cellar at the end of the opening cutscene. That fall is the tutorial. Before the climb starts, the player gets a short room of safe jumps that teaches the controls one at a time and then asks for all of them at once.

The room plays once, after New Game. It isn't one of the tower's ten floors, so it doesn't change floor numbers, saves or Continue.

## Principles

- **One idea per jump.** Each jump teaches one control. The last jump combines them.
- **Safe floor under everything.** A miss drops you onto the cellar floor, never onto spikes. You try again, and nothing is lost.
- **Read, then jump.** Every sign stands where you take off, so you finish reading before you commit.
- **Show, don't lecture.** Each sign is one short line. The jump itself does the teaching.

## The beats

| Beat | What the player does | Why it works | Sign |
|---|---|---|---|
| **Recoil** | Aim below the gun and fire to reach a low ledge. | Pointing away from where you want to go is the game's main surprise. A low ledge makes the first success easy. | "Aim down. Shoot yourself up." |
| **Charge** | Cross a gap that a quick tap falls short of. | A short click drops you in the gap; holding gets you across. The difference is felt, not explained. | "Hold to charge. Release to fire." |
| **Slow-motion aim** | Shoot up past a wall, then steer sideways onto a ledge behind it. | The wall makes a straight shot impossible. The second shot, aimed in slow motion, is the only way over. | "One shell left? Hold it in midair to slow time and line up your shot." |
| **Midair reload** | Fly through a wisp on the way to a high ledge. | The ledge is too high and too far for two shells. The wisp sits on the natural arc, so the player sees their shells refill as they pass through. | "Fly through a glowing wisp to reload in midair." |
| **Put it together** | Charge off a ledge, use the wisp, aim the last shot in slow motion, and land on the brazier. | Every control in one flight. A safety ledge below catches a miss. | "Light the brazier to save your progress." |

## The brazier and the aim guide

Lighting the brazier saves your progress and ends the tutorial. It also asks one question:

> **Keep the aim guide?** The arrow beside the gun shows which way your next shot will send you.
> [Keep Aim Guide] [Hide Aim Guide]
> You can change this any time in Settings.

New players keep the help; players who know the game can turn it off straight away.

## Signs on every floor

Each floor that introduces a mechanic has the same wooden sign next to where you arrive. It holds one plain sentence about what's new, so the hint is where the player is, not hidden in the pause menu.

| Floor | New mechanic | Sign |
|---|---|---|
| 2 | Wisps | "Gold wisps reload your shells in midair. Chain them where there's nothing to land on." |
| 3 | Moving platforms | "Platforms move. Wait for one to come to you, ride it, and jump with its speed." |
| 4 | Slime | "Slime bounces you back up but never reloads. Ride the bounce, then shoot from the top." |
| 5 | Crumbling shelves | "Rotten shelves give way a moment after you land. Keep moving." |
| 6 | Gargoyles | "Gargoyles spit bolts. They don't hurt, but they knock you into things that do." |
| 7 | Mimic doors | "Doors snap shut on a beat. Wait for them to open. Get caught and they eat your shells." |
| 8 | The flood | "The cauldron is boiling over and rising. Don't stop. Checkpoints push it back." |
| 9 | Nothing new | "Nothing new up here. Everything at once." |
| 10 | The finale | "The orb is at the top. Everything you've learned, at the same time." |

## Readable signs

- **One sign asset everywhere:** a small wooden signpost drawn in the castle palette.
- **Text appears on screen, not on the sign.** Walk up to a sign and its line fades in as a panel at the bottom of the screen: light text on a dark panel, in the game's pixel font at full size. It stays sharp at any render quality, because it isn't drawn into the scaled game world.
- **Signs never cover the path.** They stand at the edge of a ledge or beside the arrival hole.
