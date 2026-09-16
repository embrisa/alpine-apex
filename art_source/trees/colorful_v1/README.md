# Prepared colorful trees

This authoring asset pack stays excluded from Godot's production import scan by
`.gdignore`. The user resumed integration on 2026-09-14: production uses separate
packed derivatives, leaving these source assets and their hashes unchanged. See
[`AA-20260912-094935-colorful-forest-variety`](../../../backlog/completed/AA-20260912-094935-colorful-forest-variety.md).
`./scripts/art/integrate_colorful_trees.ps1` rebuilds all runtime derivatives;
`-Asset forest_golden_01` selects one. The owning [Assets guide](../../../docs/ASSETS.md#trees)
describes production material conversion and detail levels. Original preparation
evidence below remains isolated asset evidence; it is not mountain acceptance.

## Contents and ownership

- `manifest.json` owns the actual catalog, source preset/seed, generator and
  authoring hashes, dimensions, triangle counts, leaf counts and file hashes.
- `blends/` contains editable baked tree derivatives and leaf samples. The
  purchased TreeDesigner generator is never packaged here.
- `models/` contains portable GLBs: LOD0 near, LOD1 reduced, LOD2 coarse geometry,
  plus a unit-scale leaf sample for each variant. The three golden birches have
  rounded leaves; three autumn maples have lobed leaves and orange/red palettes.
- `impostors/`, when baked, contains eight-direction unlit RGBA atlas images and
  their view/scale manifest. These are preparation assets, not a registered
  runtime directional-impostor shader or a verified forest LOD transition.
- `textures/` retains the generated leaf artwork, exact prompt/provenance, and
  compact 1024x512 albedo, tangent normal and roughness atlases. Left/right tiles
  have distinct pinnate birch and palmate maple venation. Fine cellular grain,
  mottling and veins remain visible in the native leaf close-ups. Normal relief
  and roughness are approximate data maps derived from artwork, not scanned PBR.
  Build rebakes them deterministically; `bake.json` pins their hashes. No Meshy
  credits were consumed. The original imagegen output is preserved unchanged.

GLBs use metres and Y-up; Blender sources use metres and Z-up. Materials are
three explicit opaque PBR surfaces: `PreparedTree_Wood`, `PreparedTree_Leaves`
and `PreparedTree_Snow`. Colors are authored in linear vertex RGB; vertex alpha
is opaque, not a production material-selection mask. UV0 is texture/leaf UV;
UV1 is the existing twelve-sector branch-pivot encoding. Portable materials
show the intended palette without depending on Alpine Apex's current shaders.
The leaf samples use the same mesh construction as the trees.
Leaf materials multiply the texture with warm vertex colors and use subtle
normal relief plus varying roughness. The maps are embedded in the GLBs/blends;
there are no external texture dependencies. Future production materials must
retain this surface detail rather than reverting to flat vertex color.
The existing low-tier bark albedo is embedded for portability; its hash is
included in the authoring receipt to avoid duplicating the large high-tier map.

## Rebuild and review

From the repository root, with the owned local TreeDesigner library and Blender
5.2 installed:

```powershell
./scripts/prepare_colorful_trees.ps1 -Mode Build
./scripts/prepare_colorful_trees.ps1 -Mode Build -Asset autumn_maple_02
./scripts/prepare_colorful_trees.ps1 -Mode Bake
./scripts/prepare_colorful_trees.ps1 -Mode Preview -Interactive
```

The wrapper owns the shared workload guard; do not wrap it in another guard.
Build writes only this package. Bake/Preview generate an isolated Godot project
under `artifacts/colorful_tree_preparation/native_project/`, load GLBs directly,
and write captures plus `native_validation.json` under the task's artifacts.
The isolated project has no game scene, autoloads, player profile or race state.
Escape closes interactive review. Native preview uses portable PBR materials;
production wind, visibility assistance, lighting and batching use the separate
runtime conversion described in [Assets](../../../docs/ASSETS.md#trees).

The isolated preview uses stock Godot Forward+ and explicitly applies GLB vertex
colors to its portable materials. An initial custom-runtime Compatibility-mode
startup crash occurred before asset loading; its logs are retained in
`artifacts/colorful_tree_preparation/startup_crash/`. This pack does not change
the game's selected renderer. Reduced geometry retains the near woody skeleton:
aggressive trunk simplification was rejected after native review showed breaks.
Production far rendering uses the directional atlases; do not use the coarse
inspection mesh as evidence of an optimized forest. Re-bake after rebuilding a
tree; atlas receipts pin their source GLB hashes and the verifier rejects stale
atlases.

Independent Blender reimport verification:

```powershell
./scripts/run_guarded.ps1 -FilePath 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -Arguments @('--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python','scripts/art/validate_prepared_trees.py') -Label colorful-tree-roundtrip -TimeoutSeconds 300
```

That checks all GLB dimensions, triangle counts, textured leaf materials, vertex colors and
branch UV metadata against the manifest. Validation logs and review images are
evidence, not dependencies. Completion evidence is recorded in the backlog item.

## Production integration

The user resumed integration on 2026-09-14. The converter at the top of this
document produces separate runtime derivatives while preserving this source pack.
[Assets](../../../docs/ASSETS.md#trees) owns its conversion and material contract;
[Validation](../../../docs/VALIDATION.md#colorful-tree-checks) owns the current
mountain review and matched performance commands.
Neither isolated asset checks nor the preview establish player acceptance.
