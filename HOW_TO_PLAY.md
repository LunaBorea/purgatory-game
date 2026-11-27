# Purgatory – how to play this version

## Run it (Windows, Mac or Linux)
1. Install **Godot 4.7** (Standard): https://godotengine.org/download
2. On this page click **Code → Download ZIP** (make sure the branch is **background-testing**), then unzip it.
   With GitHub Desktop: *Fetch origin*, switch to the **background-testing** branch.
3. Open Godot → **Import** → pick `project.godot` in the folder.
4. The first time, Godot imports all pictures (about a minute).
5. Press **F5** (or ▶ top right) to play.

## Make a Windows .exe (to share with people without Godot)
Project → Export… → **Windows Desktop** (already set up: makes purgatoryGame.exe + purgatoryGame.pck, keep both files together) →
untick *Export With Debug* → **Export Project…**.
The first time Godot asks for the export templates: *Manage Export Templates → Download and Install*.

## Controls
| Action | Keys | Gamepad |
|---|---|---|
| Move | A / D or ← / → | Left stick / D-pad |
| Lane back / front | W / S or ↑ / ↓ | D-pad up / down |
| Jump | Space | A |
| Dash | Shift | B |
| Orb | R | Y |
| Use orb holder | F | X |
| Pause menu | Esc | Start |

All keys can be changed in the game: **Esc → Settings → Controls**.
The menu works with mouse, keyboard (arrows / WASD, Enter, Esc = back) and gamepad.

## Where things are
New visuals, menu and settings are in the `MyChanges` folder (see `MyChanges/README.md`).
The game starts from `MyChanges/main_with_forest.tscn`, which wraps the original level `Scenes/Levels/main.tscn`.
