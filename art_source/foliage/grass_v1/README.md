# Prepared grass assets

Standalone grass only: no rock, pebbles, pedestal, ground mesh or collision.
This package is **prepared, not integrated**. `.gdignore` excludes it from the
game's import scan. Terrain placement, wind, skier bending and rendering decisions
are recorded in [the terrain grass task](../../../backlog/completed/AA-20260911-193341-terrain-grass.md).

## Contents

- Six original curved-blade clumps: two short alpine tufts, two meadow clumps and
  two taller forest fans, approximately 19-49 cm high.
- Green, lightly snow-dusted and snow-covered finishes: 18 variants, each with
  LOD0/LOD1/LOD2 exports, totalling 54 self-contained GLBs in `models/`.
- `grass_library.blend`: editable baked meshes; the six green LOD0 objects are
  visible in a spaced layout. Unhide the corresponding finish/LOD to edit it.
- `recipes.json`: reproducible shape, seed and resolution controls.
- `manifest.json`: authoritative dimensions, triangle counts, file sizes/hashes,
  source identity and vertex-data contract.

The original rock-generator image was inspected as a reference. These are newly
authored meshes; no generator geometry or texture is embedded, and the original
source files remain byte-identical. Snow is additional narrow, raised geometry
following the blades, with white shading and exposed green bases. There are no
alpha cards, external textures, lights, cameras, skeletons or game scripts.

## Material, axes and future deformation

GLBs use metres, Y up, identity node transforms and a ground-level origin.
Blender source uses Z up; its specimen layout is not part of the GLBs.
Each export has one opaque, double-sided PBR material surface. `COLOR_0` contains
linear appearance RGB and opaque alpha. Keep those colors enabled in the material.
The observed Godot 4.7.2 **direct GLTFDocument** path retains `COLOR_0` but does not
enable `vertex_color_use_as_albedo`; the isolated preview explicitly enables it.
Future import/integration must verify that flag instead of treating white output
as the authored color. No production importer was changed.

Exported UV0.y is normalized root-to-tip position (0 fixed root, 1 tip); UV0.x
is across the blade. UV1 stores its ground pivot: `x=(u-.5)*1 m`,
`z=-(v-.5)*1 m`, `y=0`. Snow geometry carries the same coordinates as its blade.
This prepares deformation data only; no wind or contact animation is implemented.
Vertex alpha is opacity, not a bend weight. LODs retain the tallest blade and use
deterministic whole-blade subsets; coarse versions are intentionally sparse and
need distance/density tuning during integration.

## Rebuild and isolated review

Run from the repository root with installed Blender 5.2 and the bundled Godot:

```powershell
./scripts/prepare_foliage_assets.ps1 -Kind Grass -Mode Build
./scripts/prepare_foliage_assets.ps1 -Kind Grass -Mode Validate
./scripts/prepare_foliage_assets.ps1 -Kind Grass -Mode Preview
./scripts/prepare_foliage_assets.ps1 -Kind Grass -Mode Preview -Interactive
```

The wrapper owns the shared validation guard; do not nest it inside another guard.
Build refuses an existing package unless `-Rebuild` is supplied, and then checks
that prior generated files still match their recorded hashes before replacing
them. Preserve hand-edited Blender/GLB files separately before regenerating;
rebuilding derives meshes from recipes and does not export hand edits.

Validation independently decodes every GLB, checks package/source hashes,
grass-only hierarchy, opaque material, pivots, roots, attributes and budgets,
then reimports every export through Blender and compares bounds/counts.
Preview creates an isolated Godot project under
`artifacts/grass_asset_preparation/native_project/`, loads the real GLBs directly,
checks native meshes/materials and captures front/reverse, collection and LOD
views under `artifacts/grass_asset_preparation/native/`. No ground/support surfaces
are present. Escape closes interactive review. These checks establish isolated
asset behavior, not skiing appearance, wind behavior or mountain performance.

The matching [plant package](../plants_v1/README.md) contains leafy plants, ferns
and low shrubs with the same prepared-only boundary.
