# Prepared leafy plants, ferns and low shrubs

Six original plant forms, each in green, lightly dusted and snow-covered finishes,
with three geometry levels: **18 variants and 54 GLBs**. These are generic artistic
growth forms, not scanned or botanically certified species. No wildflowers were
requested for this package.

All assets are standalone vegetation: leaves, stems, shrub twigs and attached
snow only. No rocks, pebbles, soil chunks, pedestals or collision are included.
`.gdignore` excludes the package from production imports. Placement, material
registration, wind/skier interaction and gameplay integration are not implemented
or authorized by this asset-preparation delivery.

`manifest.json` owns the catalog, dimensions, triangle counts, hashes and vertex
contract. `recipes.json` owns deterministic shapes and seeds. `plant_library.blend`
contains editable derived meshes arranged for inspection, with the green LOD0
forms initially visible; other finishes and LODs can be unhidden. `models/`
contains self-contained GLBs, with one opaque, double-sided PBR surface each.
No vendor model, external texture, game script, light or camera is embedded.

GLBs use metres, Y up and identity node transforms at ground level. Blender is
Z up. Vertex RGB is linear appearance color and alpha stays opaque. Keep vertex
colors enabled: the observed Godot 4.7.2 direct GLTFDocument loader needs an
explicit `vertex_color_use_as_albedo=true`, which the isolated preview applies.
UV0.y is clamped local plant height divided by the recipe's height, suitable as
a future bend weight; UV1 encodes a shared origin pivot at (.5,.5). This differs
from the grass package's individual blade pivots. No deformation is running yet.

Run these commands from the repository root:

```powershell
./scripts/prepare_foliage_assets.ps1 -Kind Plants -Mode Build
./scripts/prepare_foliage_assets.ps1 -Kind Plants -Mode Validate
./scripts/prepare_foliage_assets.ps1 -Kind Plants -Mode Preview
./scripts/prepare_foliage_assets.ps1 -Kind Plants -Mode Preview -Interactive
```

The wrapper owns the guard. Existing packages require `-Rebuild`; modified source
or export hashes cause a refusal, so preserve hand edits before regenerating.
Rebuild generates from recipes; it does not export hand-edited source objects.
The builder reuses only mesh/PBR helpers from `prepare_grass_assets.py`; its hash
is recorded as an authoring dependency, not an exported asset dependency.

Validation checks raw GLB structure/attributes and independently reimports every
model in Blender. The isolated native preview verifies Godot meshes/materials,
captures the complete collection, leafy/fern/shrub snow treatment and LODs, and
leaves evidence under `artifacts/plant_asset_preparation/`. It has no support
surfaces, game autoloads, terrain, player profile or race state. Escape exits.
Actual terrain fit, motion, dense-population performance and user visual
acceptance remain future integration work. The related
[grass assets](../grass_v1/README.md) use the same preparation boundary.
