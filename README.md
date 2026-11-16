# MASS BATTLE

A free, original Godot 4 prototype for large automatic army battles.

## Run locally
1. Install Godot 4.x: https://godotengine.org/download/
2. Clone or download this repository.
3. Open `project.godot` in Godot.
4. Press F6/F5 or the Play button.
5. Set the blue and red army sizes (1–10,000), choose battle speed, and press **START BATTLE**.

## Prototype features
- 3D arena with two opposing armies.
- Up to 10,000 visible instances per side using Godot `MultiMeshInstance3D`.
- Automatic group-based battle simulation.
- Pause/resume, speed control, survivor count and winner display.
- No paid assets, plugins, accounts, or network services.

## Current limitations
This is an early technical prototype, not a finished mobile game. Combat is currently abstracted as group damage: soldiers are rendered as simple capsules and do not yet individually animate, pathfind, or fight with detailed physics. The 10,000-per-team setting is a development target, not a verified performance claim on phones.

## Roadmap
1. Add original low-poly character models and basic animations.
2. Add formations, movement, melee/ranged unit types and better combat logic.
3. Add camera controls, replays, maps and mobile-friendly UI.
4. Profile 1k/5k/10k per team on real Android and iPhone devices.
5. Configure and test Android/iOS exports.

## Technology
- Godot Engine 4
- GDScript
- MultiMesh instancing
