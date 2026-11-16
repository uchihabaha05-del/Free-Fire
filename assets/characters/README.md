# MASS BATTLE character models

The character picker supports Godot-importable COLLADA (.dae) and GLB scenes.

## Spider-Man model supplied for this project

Place these two files together in this folder:

- `SpideyMesh.dae` — skinned Spider-Man mesh
- `Spidey512.png` — its texture

The COLLADA file references the texture by the relative path `../assets/Spidey512.png` when stored here. Alternatively, edit its image URI to `Spidey512.png` if you place the texture beside the DAE.

The game now tries `res://assets/characters/SpideyMesh.dae` for Spider-Man, then falls back to `spider_man.glb` if present.

## Other heroes

The character picker can load these GLB files when supplied:

- hulk.glb
- thor.glb
- captain_america.glb
- iron_man.glb
- thanos.glb
- doctor_strange.glb
- black_panther.glb
- deadpool.glb
- wolverine.glb

Use rigged, game-ready models. Keep each model's license and attribution file beside it. Only add models you have permission to use and redistribute in this project.

Until a matching model file is present, the game displays a clearly marked temporary placeholder. The placeholder is not an official Marvel design and is not intended to look like the original character.
