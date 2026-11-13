# Recoil Launcher

Mouse-only recoil climber made for 17 GameJam. Hold left-click to charge and release to launch away from the cursor. Each shot sets your velocity from your aim and charge. Charging the second shot in midair slows your movement so you can aim. Land to refill both shots.

## Play on Windows

[Download the latest playtest build](https://github.com/xerces22/recoil/releases/latest/download/RecoilLauncher-Windows.zip). Extract it and open `RecoilLauncher.exe`. Keep the EXE and PCK together.

## Work on the game

Open `project.godot` in Godot 4.7.2 and press F5. Push changes to `main` to publish a new Windows playtest build.

To build levels, read [LEVEL_DESIGN.md](LEVEL_DESIGN.md). It lists every mechanic, the reach numbers and the difficulty rules. Keys 1 to 9 and 0 switch levels while testing.

Godot editor runs show live recoil stats and recent events. Each run writes a timestamped log in `playtest_logs/` in the project folder. If the project folder is read-only, the log goes to Godot's user data folder. Release builds hide the overlay and skip logging.

## Final draft

- Start first-time players with a short tutorial that shows the recoil arrow and teaches both shots. At the end, let them choose whether to keep or hide the arrow. Save the choice and let them change it later in settings.

## Assets

Keep the mechanics prototype bare-bones. Basic shapes, simple generated visuals, and temporary sounds are fine for testing. Record any generated placeholders so they can be replaced before submission.

Use free online asset packs for final graphics, sound effects, and music. When importing an asset, add its creator, pack link, license, and where it's used to [ASSET_CREDITS.md](ASSET_CREDITS.md). Include the linked credits in the itch.io description, even when the pack makes attribution optional.
