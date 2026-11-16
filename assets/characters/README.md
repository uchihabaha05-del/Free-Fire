# MASS BATTLE character models

The character picker supports Godot-importable COLLADA (.dae) and GLB scenes.

## Spider-Man model

The source archive is stored at `assets/assets/SpideyMesh.zip`. The Android GitHub Actions workflow extracts its contents into this folder before Godot imports the project:

- `SpideyMesh.dae` — skinned Spider-Man mesh
- `Spidey512.png` — referenced texture

Both files are placed together so the COLLADA texture reference resolves correctly.

The game loads `res://assets/characters/SpideyMesh.dae` for Spider-Man and falls back to `spider_man.glb` if the DAE scene cannot be loaded.

## Hulk model

The supplied Hulk model is a rigged GLB with 27 joints, one animation and embedded PBR textures (base color, normal, and metallic/roughness). The game is configured to load it from:

- `hulk.glb`

Place the uploaded GLB at `assets/characters/hulk.glb`. No separate PNG texture files are required because the GLB already embeds its material textures. The game now attempts to play the first imported AnimationPlayer clip for loaded character models.

## Other heroes

The character picker can load these GLB files when supplied:

- thor.glb
- captain_america.glb
- iron_man.glb
- thanos.glb
- doctor_strange.glb
- black_panther.glb
- deadpool.glb
- wolverine.glb

Use rigged, game-ready models. Keep each model's license and attribution file beside the model. Only add models you have permission to use and redistribute in this project.

Until a matching model file is present, the game displays a clearly marked temporary placeholder. The placeholder is not an official Marvel design and is not intended to look like the original character.
