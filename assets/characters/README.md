# MASS BATTLE character models

Only the two models supplied for this project are selectable.

## Spider-Man

- Source archive: `assets/assets/SpideyMesh.zip`
- Imported by the Android workflow into `res://assets/characters/SpideyMesh.dae`
- Texture: `Spidey512.png`
- The COLLADA model contains a rig; the game applies runtime skeleton poses for locomotion and attacks.

## Hulk

- Source model: `assets/characters/b337594dc560b6dd1d13c8c4d744eef9.glb`
- Rigged GLB with 27 joints and embedded PBR textures.
- The game applies runtime skeleton poses and a model-specific facing correction.

No placeholder soldiers or unprovided heroes are added to the character picker. If either supplied model fails to load, that spawn is skipped and an error is logged instead of substituting a different character.
