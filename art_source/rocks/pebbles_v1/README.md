# Cosmetic rock pebbles

Prepared assets for surface detail on exposed rock terrain. Nine standalone
shapes: three gravel stones, three rounded pebbles and three flat shale chips.
The manifest owns exact dimensions, geometry budgets and hashes. This source
pack is excluded from production import by `.gdignore`; the integration task
selects and converts its meshes into a separate runtime catalog.

## Rebuild and review

From the repository root, with the installed Blender 5.2 and repository Godot:

```powershell
./scripts/prepare_rock_pebbles.ps1 -Mode Build
./scripts/prepare_rock_pebbles.ps1 -Mode Validate
./scripts/prepare_rock_pebbles.ps1 -Mode Preview
```

Build uses `scripts/art/build_rock_pebbles.py` and `recipes.json`. Existing packs
require `-Rebuild`; any export changed since its receipt is protected from
overwrite. Preserve manual edits separately before an intentional rebuild.
The wrapper owns the engine guard; do not wrap it in another guard. Validation
is a stdlib GLB inspection; Preview loads every GLB directly into an isolated
Godot project and writes three captures plus a native validation receipt under
`artifacts/rock_pebbles_20260914/`. It never loads a game scene or user state.

The source is the unchanged supplied `art_source/blender/rock_generator.blend`.
Its `Set Position.006` Geometry Nodes branch makes the stones used by the
`Stone Density` scatter. This builder extracts that branch before scattering,
changes noise sampling by deterministic seed, fits metre dimensions and reduces
detail. It does not extract the large rock, display pedestal or grass.
`pebble_library.blend` contains the 27 editable baked mesh objects in a grid.
The supplied generator and Python/JSON recipe retain procedural provenance.

## Integration contract

- Each GLB contains one opaque, backface-culled mesh and one texture-free PBR
  material, with `COLOR_0`, normals and identity transforms. Metres, Godot Y-up,
  base at Y=0, centered in XZ. Widths are 5-28 cm. Each shape has 80/40/16 triangles.
- All assets are cosmetic. No physics bodies, collision shapes, collision
  proxies, obstacle records, vegetation, snow geometry or terrain chunks are
  included. Runtime integration must keep collision and solver inputs unchanged.
- Preserve source files and create runtime derivatives with source hashes.
  When extracting meshes, honor `COLOR_0`; the current editor's direct
  `GLTFDocument` review needs `vertex_color_use_as_albedo = true` explicitly.
- Place using authoritative exposed-rock surface information. Seat and orient
  each stone on the shared terrain; avoid visible floating bases, snow-covered
  areas, grass terrain and steep faces where loose pebbles would look implausible.
  Snow/burial treatment belongs to the production presentation layer.
- Use spatial batches and bounded local residency, with measured density,
  shadows, culling, LOD/fade distances and streaming work. Do not instantiate
  a scene or material per stone. The three LOD meshes offer options; they do
  not prescribe distances or prove a performance improvement.

Before accepting integration, inspect production rock and snow/rock boundaries
at skiing height and speed, including LOD transitions. Compare matched short
on/off runs with identical physics/input and 4K High visual settings, recording
frame averages/tails, CPU/GPU cost and residency. Start with the targeted rocks
map; report whole-mountain coverage separately. The review-plane scatter is an
asset arrangement only, not a terrain placement test or FPS measurement.
