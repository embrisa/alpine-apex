# Snowy Meshy tree species experiment

Isolated art sources and a reversible in-game experiment. `.gdignore` excludes
this pack from production imports. The normal forest remains unchanged.

The user likes both seasonal directions: the existing green/gold/orange forest
and this snow-covered winter forest. Retain both. Close and middle branches in
the prototype still show angular, folded-looking surfaces; the winter atmosphere
is promising, but this is not a completed production replacement.

## Sources and cost

Meshy-7 Ultra/PBR, original generated image references, embedded 2K textures.
Each species folder retains the exact reference, prompt and generation request.
`credits.json` records 410 credits spent out of 2,250 authorized; no jobs remain
pending. Submission receipts preserve their original submission status.
`inventory.json` reads actual saved vertices/indices rather than target counts.

| Species | Selected near source | Near triangles | Local middle triangles |
| --- | --- | ---: | ---: |
| Spruce | `spruce/tree_detail.glb` | 21,407 | 5,540 |
| Fir | `fir/tree_detail.glb` | 19,320 | 5,628 |
| Stone pine | `stone_pine/tree_detail.glb` | 16,246 | 4,868 |
| Winter birch | `winter_birch_v2/tree.glb` | 8,570 | 3,244 |

Middle files are `tree_local_mid.glb`. Original lower-count generations remain
as distinct source assets. The first winter birch is nearly flat and was rejected;
v2 has a volumetric crown. Meshy task-remesh derivatives lost branches and are
retired, with task IDs/counts retained. Increasing a remesh target did not restore
missing source detail. Extracted PNG maps duplicated embedded GLB images and were
retired too. The previously user-approved September 15 spruce is separate and
untouched at `artifacts/meshy7_tree_20260915/source/tree.glb`.

Local collapse first joins coincident topology while retaining per-corner UVs,
splits edges with more than two incident faces, and then reduces triangles.
This reaches the budget but still needs silhouette/error control: it is not a
visually accepted general-purpose tree LOD solution. `local_lods.json` records
the exact counts and small height corrections. No original source is overwritten.
Local middle and finishing GLBs are ignored reproducible outputs; rebuild them
before running the experiment on another checkout.

## Close-detail follow-up

The requested 20k/40k targets used the same new 80k-target spruce generation:

| Meshy target | Actual triangles | Imported vertex records |
| --- | ---: | ---: |
| 20,000 | 17,945 | 35,275 |
| 40,000 | 38,916 | 70,116 |
| 80,000 | 72,864 | 162,507 |

Raw textured and clay views expose folded branch shapes before the game wind
shader runs. `finish_mesh.py` tests bounded snow-surface relaxation and
same-hemisphere seam-normal smoothing, preserving UVs, indices and source files.
It softens the snow shading but leaves pointed, folded foliage geometry.
Ten actual-game captures compare the original 21,407-triangle prototype,
20k/40k targets and cleaned 40k/73k versions at the same 6 m and 12 m cameras.
Only spruce LOD0 changes; the earlier middle/far prototype remains in place.
These close variants are visually rejected for production and were not timed.
Higher triangle count alone did not resolve this source's shape problem.

Keep the final winter forest predominantly white, with restrained green pockets
and snow-load variation. The separate greener spruce is only a possible accent;
it is too green to dominate. `close_review.json` retains the compact verdict.

A Meshy community balsam fir by cknight1212 has rounder snow in its web preview,
but the viewer reports 1,610,743 triangles and 1,367,583 vertices. It is listed
as Meshy 5 / CC0, not Meshy 7 or a proven game-ready tree. Its GLB download
was blocked by Chrome with ERR_BLOCKED_BY_CLIENT after successful sign-in;
manual download is pending. `community_candidate.json` retains the
source link and review limits; no community model has been downloaded or timed.

## Geometry follow-up

`geometry_review.json` retains the bounded follow-up and visual rejections.
The pre-remesh spruce source has 7,689,210 triangles and rounder snow volume.
Exact-position welding plus quadric reduction to 40k still produces pointed
sheets. Reconstructing roughly 10 cm volumes at a 12 m tree height softens those
surfaces but loses branch detail and damages the lower trunk. The 2K color bake
also smears some surfaces. Both reductions fail the close-tree visual gate.

Meshy T2 smart topology (15k target, 15 credits) produces 12,762 triangles and
17,584 vertex records. It retains folded-looking branch surfaces. The original
liked 10,617-triangle September 15 tree has similar sharp sheets in a matched
source close-up. These static source findings precede wind deformation; they do
not rule out additional animation issues. None of this follow-up was FPS timed.

Offline experiment helpers, each writing a separate output:

- `reduce_raw.py SOURCE OUTPUT --triangles 40000`: NumPy and
  fast-simplification 0.1.13; texture-free single-mesh pre-remesh input only.
- Blender 5.2 `--python volume_finish.py -- SOURCE OUTPUT`: voxel reconstruction,
  smoothing and 40k reduction; uses the 300k texture-free intermediate.
- Blender 5.2 `--python bake_volume.py -- TEXTURED_SOURCE NEW_GEOMETRY OUTPUT`:
  aligned diffuse-color transfer into an embedded 2K texture.

Run these under Exclusive admission. Rejected derivatives remain local;
these helpers are an art investigation, not an accepted production LOD recipe.

## Actual game comparison

`library.gd` replaces 22 living-tree catalogue slots in memory only, using four
species with the original instance transforms. Golden/maple slots use winter
birch; dead/broken trees and the mountain's distant scenery stay original.
Near/middle trees use opaque textured geometry, the existing LOD/wind/contact
vertex path and original branch metadata; far trees use matching eight-view,
two-triangle cards. Branch tagging and animation fidelity need further review.
Original collision, density, LOD distances, terrain, shadow meshes and gameplay
remain unchanged. The library detaches visible MultiMeshes that share a bare-tree
shadow resource, and restores original assets before quitting.

Thirty matched 4K game captures cover the forest overview, spruce at 6/12/32/64/85 m
from the production crown sphere, and fir/pine/birch near/middle/far views.
These are static visual checks, not a moving-transition or controller verdict.
Close/middle faceting was reported before timing; the user then explicitly asked
for FPS despite the visual concern and subsequently liked both seasonal looks.

### Capture-free 15-second dense-route diagnostic

| Measurement | Original | Winter candidate |
| --- | ---: | ---: |
| Average rendered FPS | 87.18 | 86.86 |
| Mean frame time | 11.470 ms | 11.513 ms |
| Mean GPU time | 7.457 ms | 7.002 ms |
| Frame p95 | 15.926 ms | 15.550 ms |
| Frame p99 | 21.335 ms | 20.971 ms |

No meaningful whole-frame FPS difference in this sample. GPU time fell 0.455 ms
(6.10%); this does not establish an equivalent whole-frame saving. One excluded
warm traversal, one original measurement and one candidate measurement; this is
not a repeated confidence study. All three reproduced the ordinary-input route
exactly, with zero unfocused frames and no scoped input changes. No capture ran
during measurement. LOD1 depth work was not separately measured.

Current Standard generator 18/model 35, RX 9070/DX12, 4K High, 2880x1620 internal,
Auto FSR 4.1.1, no frame generation or cap, clear/day, terrain GI off.
The older retained route is generator 17; current generation required refreshed
ordinary inputs, so one current control was necessary. Do not compare these values
directly with the older 72 or 109 FPS references or with a small targeted map.

Compact results: `experiment.json`. Full receipts and images:
`artifacts/meshy_snow_20260918/game_review/`, `timing_{before,after,stability}.json`,
and `artifacts/pc_environment/meshy-snow-v18/`.

## Reproduce

Use `scripts/run_guarded.ps1`; never nest guards. Blender/local LOD preparation,
native source preparation and texture compression use `Exclusive`.

1. Blender 5.2: `--background --python art_source/trees/meshy_snow_v1/simplify.py`.
2. Native game engine: `--script art_source/trees/meshy_snow_v1/prepare.gd -- --candidate --smooth --bake`.
3. Official Godot 4.7.2 **editor executable**, headless:
   `--script art_source/trees/meshy_snow_v1/compress.gd`.
   The custom game executable cannot perform offline BC7 compression.
4. Native game engine: `--script art_source/trees/meshy_snow_v1/game_review.gd`
   with High, Auto, scale 0.75, 30 FPS, GI/FG off and staged loading.
   Requires the current warm Standard cache and retained placement fixture
   `artifacts/far_stand_mesh_20260917/stand.bin`. Full-mountain admission and a
   recorded visual-review reason are required. It writes matched original/winter
   images and restores the original tree library before quitting.
5. Only when timing is authorized, run `cost.gd` with the same display settings,
   cap 0, `--scenario-replay --trial-seconds=15 --repetitions=3`, a fresh
   `--benchmark-label`, and the retained current trace
   `--input-trace=res://artifacts/meshy_snow_20260918/trace/lower.json`.
   Use `FpsCritical`, explicit full-mountain reason and scoped before/after metadata
   including this pack and generated prepared resources. Rows 2/3 are the matched
   control/candidate; row 1 is excluded. Do not time concurrently with gaming.

For the close-detail follow-up, run `finish_mesh.py SOURCE.glb OUTPUT.glb` with
Python, NumPy and Pillow for `tree_close_40k.glb` and `tree_close_80k.glb`, writing
`tree_finish_40k.glb` and `tree_finish_80k.glb` beside them. `--relax 0.0125` is
the default displacement bound as a fraction of tree height. `quality_review.gd`
accepts repeated `--model=res://...glb` and `--review-output=res://artifacts/...`.
`near_compare.gd` uses the existing prepared library and game-review cameras;
run it with the same capped visual settings and full-mountain admission as step 4.
Results are under `artifacts/meshy_snow_20260918/near_compare/`.

Prepared resources are reproducible outputs under `artifacts/`, not production
dependencies. Source/receipt preservation does not integrate this forest into
normal play, change personal preferences or imply human acceptance of movement.
