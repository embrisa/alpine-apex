# Meshy 7 skier

The active character is `assets/graphics/models/skier_v7.glb`, generated from
`art_source/meshy/skier_v7/reference.png` using explicit `meshy-7`, Ultra geometry,
4K albedo and PBR maps. The previous `skier.glb` and original Blender sources remain
available. `art_source/blender/skier_v7.blend` contains the assembled, editable model
with packed textures. The separate boot GLBs are also self-contained.

## Runtime preparation

The generated mesh had 61,260 triangles. The prepared body has 35,900 triangles,
and both boots together have 5,171. With the existing skis, bindings and poles,
the complete rider is **42,063 triangles**, versus 43,113 before the grip/material pass. These are
base mesh counts; Godot also generates automatic LODs. The larger albedo has a memory cost. See the measured model-v5 result in [rider physics validation](SKIER_PHYSICS.md#validation).

The preparation script preserves the 24-bone skin, restores source PBR maps,
removes the rig viewer's emissive albedo, smooths normals and reduces geometry.
It separates the boots at the trouser cuffs and fades the lower trouser weights
into the foot bones, preventing the hem from pulling away under knee flexion.
Boots follow the skis; matching ankle targets include the original foot height
and the ski's roll. Clothing, helmet, curved lens, skin and authored gloves use separate material surfaces; boots retain their own atlas material. Visual Settings exposes independent tint, roughness and metallic reflection for clothing, helmet and lens.

Every exported GLB is independently reimported to check triangle counts, object
types, skinning, bones, UVs and retained albedo/normal maps and semantic PBR material properties. Blender's generated bone-display
custom shapes are excluded from those counts and never exported.

Rebuild locally, without spending credits:

```sh
blender --background --python scripts/art/prepare_skier_v7.py
./godotw --headless --editor --import
```

## Posture and arm movement

The Node-independent 120 Hz simulation now computes all joints, hand springs,
centre of mass, body inertia and pressure-limited balance. The renderer only
interpolates those states. Each boot/ankle follows its own simulated ski; two-bone
IK preserves segment lengths and a shared pelvis prevents detached hip targets.
Full tuck retains approximately 30 degrees of torso pitch relative to the stance
and about 8 degrees between pelvis and torso. Crouching comes from hips and knees.

`scripts/art/skier_details.py` replaces the generated open hands with closed
insulated gloves: four curved fingers, a crossing thumb and wrist cuffs. Each
handle lies on a fixed grip axis through the fingers; wrist orientation follows
the shaft. Fingers are fixed grip geometry, not independently animated digits.

Crashes transfer the solved pose and momentum to a fifteen-body Jolt skeleton
with knee/elbow hinges and bounded torso, neck, shoulder, hip and ankle joints.
Boots/skis remain attached and skis have collision shapes. Poles remain held;
there is no equipment-release/binding model yet. See [rider physics](SKIER_PHYSICS.md)
for crash lifecycle, validation and explicit approximations.

## Validation and comparison

```sh
./godotw --headless --script tests/skier_motion_suite.gd
./godotw --script tests/graphics_suite.gd
./godotw --script tests/skier_asset_playtest.gd -- --skier-label=final --skier-motion
```

The current articulation/material suite passes 19 checks; the native graphics
suite passes 25. See [rider physics validation](SKIER_PHYSICS.md#validation) for
physics, runtime, competition and crash checks and the measured Low result.

The original advanced-rider inspection is in `artifacts/advanced_rider/visual/`, including
real simulated turns, tuck and hop, a close grip view, material controls and a
150 km/h terrain crash. The earlier `artifacts/skier_v7/` captures and motion clip
remain historical asset comparisons. The current solver uses physics model v7 and
replay format v2; test/lab runs remain unranked and the scenery is still bounded.

## Generation record

The built-in image generation tool produced the reference. Its exact prompt is
`art_source/meshy/skier_v7/reference_prompt.txt`. Meshy image-to-3D task
`01a073b6-b9b8-76f2-ac92-96e2960859cb` cost 35 credits; rigging task
`01a073ba-ad56-70e1-9e35-1fa17fe1b2f2` cost 5. Total spending was **40 of the
authorized 1,000 credits**. Balance changed from 4,005 to 3,965. The ledger and
round-trip results are saved alongside the raw source under `art_source/meshy/skier_v7/`.

The turning-anatomy correction and close rear-view inspection are documented in
[the model-v6 notes](SKIER_PHYSICS.md#turning-anatomy--model-v6), with evidence in
`artifacts/turn_anatomy/`.
