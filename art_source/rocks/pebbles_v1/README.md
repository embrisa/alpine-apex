# Cosmetic rock pebbles

Prepared assets for surface detail on exposed rock terrain. Nine standalone
shapes plus three fine grit variants: 12 shapes spanning 1.5-28 cm. Each uses
the supplied generator's rock albedo, normal and roughness textures. Dense gravel
beds are the main field target, with small grit filling gaps around larger accents.
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
Godot project and writes four captures plus a native validation receipt under
`artifacts/rock_pebble_textures_20260914/`. It never loads a game scene or user state.

The source is the unchanged supplied `art_source/blender/rock_generator.blend`.
Its `Set Position.006` Geometry Nodes branch makes the stones used by the
`Stone Density` scatter. This builder extracts that branch before scattering,
changes noise sampling by deterministic seed, fits metre dimensions and reduces
detail. It does not extract the large rock, display pedestal or grass.
`pebble_library.blend` contains the 36 editable baked mesh objects in a grid and
packed source-derived texture images. The shared 1024-pixel PBR maps are extracted
from the original packed `ROCK_Base Color.jpeg`, `ROCK_Normal.jpeg` and
`ROCK_Roughness.jpeg`; normal/roughness channels use non-color interpretation.
The supplied generator and Python/JSON recipe retain procedural provenance.

## Integration contract

- Each GLB contains one opaque, backface-culled mesh with UVs, tangents, normals,
  subtle `COLOR_0` tint and identity transforms. Three shared image files supply
  albedo, tangent normals and metallic/roughness (metallic B=0, roughness G).
  The GLBs embed geometry and reference `../textures/`; copy the pack with its
  models/textures directory relationship intact. Runtime conversion should load
  one shared material/map set across all variants, avoiding per-GLB texture copies.
  Metres, Godot Y-up, base at Y=0, centered in XZ. Widths are 1.5-28 cm and each
  shape has 80/40/16 triangles. UV orientation is stable across geometry levels.
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

`field_presets.json` describes dense `gravel_bed` and `sparse_rock_accents`
authoring recipes. A gravel bed is primarily 1.5-3 cm grit mixed with 5-8 cm
stones and occasional larger pebbles. Use coherent fields with irregular edges,
local density variation and smaller stones filling gaps. Do not render a uniform
distribution of large pebbles as the gravel-field result. Suggested patch widths,
falloff and populations are appearance starting points; production measurements
must determine batching, residency and representation. The preview includes a
bounded irregular gravel arrangement to show the intended size mix and packing.

Before accepting integration, inspect production rock and snow/rock boundaries
at skiing height and speed, including LOD transitions. Compare matched short
on/off runs with identical physics/input and 4K High visual settings, recording
frame averages/tails, CPU/GPU cost and residency. Start with the targeted rocks
map; measure dense gravel fields and sparse accents separately and report
whole-mountain coverage separately. The review-plane scatter is an
asset arrangement only, not a terrain placement test or FPS measurement.
