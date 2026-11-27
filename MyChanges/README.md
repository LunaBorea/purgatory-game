# MyChanges

Everything I added lives in this folder. The only original file touched is
`project.godot` (one line: `run/main_scene` points to `main_with_forest.tscn`).
**To undo everything:** set Main Scene back to `Scenes/Levels/main.tscn`
(Project Settings → Application → Run), then delete this folder.

## How to play with it
Just press **F5** – the project now starts with `MyChanges/main_with_forest.tscn`.
It loads the normal level (`Scenes/Levels/main.tscn`) and adds my stuff on top.

## What's inside
| File | What it does |
|---|---|
| `main_with_forest.tscn` | The level + forest background + deep floor + water together |
| `Background/forest_background.tscn` | 5 parallax layers (sky, far trees, mid trees, near trees, ground) plus 2 firefly swarms. They repeat forever, so the background never ends |
| `Background/firefly_swarm.gd` | Fireflies that glide slowly on their own random paths and glow in and out |
| `Background/Images/` | The background pictures, full resolution (7680x1080) so they stay sharp |
| `Background/crisp_edges.gdshader` | Tightens the soft painted tree edges so they look sharp on screen |
| `Water/water.gd` + `Water/Frames/` | Animated water in the pit (replaces the old teal blocks), 10 looping frames, fading to black in the deep |
| `Water/water_reflection.gdshader` | Rippling reflection of the forest on the water |
| `Effects/glow_and_shadows.gd` | Glow around the character and the orb, soft shadows under the character, orb and hunters |
| `Floor/deep_floor.gd` | Dark floor colours, deep earth under the floor, endless floor with real collision, grass edge, a different tone per lane and a moonlit edge on the lane you stand on, hides the placeholder sky and white boxes |

## Tweaking
Click the `DeepFloor` node in `main_with_forest.tscn`: all colours, depth, grass
and on/off switches are in the Inspector.
Layer speeds are each layer's `Scroll Scale` (x) in `forest_background.tscn`.
