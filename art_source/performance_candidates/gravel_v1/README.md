# Cosmetic gravel cell-cluster source candidates

This is an isolated source comparison for a later **8 m cell grouping** experiment. It does not replace `rock_gravel.gd`, `gravel_placement.gd`, `mineral_scenery.gd`, their shaders or assets. The [scenery cost inventory](../../../artifacts/scenery_cost_inventory_20260914/REPORT.md) measured a local `off` → `all` gravel envelope of +0.521 ms GPU mean, but did not isolate the saving from grouping. These source candidates carry **no timing or FPS claim**.

[`gravel_cell_candidates.blend`](gravel_cell_candidates.blend) contains exactly two cosmetic payloads: a dense irregular mixed-size bed and a sparse rock-to-snow transition. Each is represented by one near mesh and one far mesh at the same stone roots. The four mesh objects share **one opaque PBR material** and the existing source stone albedo, normal and metallic/roughness maps. There are no per-stone objects, collision bodies, terrain chunks, grass, or terrain write-back. `.gdignore` keeps the pack outside production imports.

## Geometry inventory

Counts are for each authored **8 × 8 m cell template**. `LOD0` copies the existing 80-triangle stone source; `LOD2` copies its corresponding 16-triangle source. Counts include the full prepared mesh, not the number visible at a particular camera distance. Coordinates are Blender X/Y horizontal, Z up, in metres. The full 8 m horizontal cell plus future terrain-displacement margin, rather than only the occupied stone bounds below, must determine a runtime cluster's culling envelope.

| Payload | Stones | LOD | Vertices | Triangles | Material slots | Occupied bounds min → max (m) |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| Dense bed | 3,300 | LOD0 near | 792,000 | 264,000 | 1 | (2.38810, 2.55133, -0.006) → (4.75388, 4.88500, 0.010) |
| Dense bed | 3,300 | LOD2 far | 158,400 | 52,800 | 1 | (2.38882, 2.55170, -0.006) → (4.75337, 4.88486, 0.010) |
| Sparse transition | 440 | LOD0 near | 105,600 | 35,200 | 1 | (0.17361, 0.14181, -0.006) → (5.37871, 7.84466, 0.010) |
| Sparse transition | 440 | LOD2 far | 21,120 | 7,040 | 1 | (0.17399, 0.14266, -0.006) → (5.38035, 7.84361, 0.010) |

The dense mix has 2,766 grit, 504 gravel, 27 pebbles and 3 shallow shale chips; the sparse mix has 82 grit, 263 gravel, 74 pebbles and 21 chips. Source dimensions remain 1–10 cm wide, mostly 1–3 cm. The static template buries at least 30% of every stone and leaves **at most 1 cm exposed height** on its level authoring plane. The later runtime work must still apply the existing per-stone support sampling and crease clamp before it can be accepted on terrain. The static template alone is not a terrain-fit test. The dense bed has a jagged, roughly 2.4 m occupied width; the sparse stones thin toward the illustrative snow line and never enter the snow side of the preview. Actual rock, snow, mineral and grass exclusions stay owned by the existing placement path.

## Shared data and later-use contract

The `.blend` material packs the existing `art_source/rocks/pebbles_v1/textures/stone_albedo.png`, `stone_normal.png` and `stone_metallic_roughness.png` for portable **source preview**. Both payloads use these same three maps, one material slot, per-corner `StoneUV` and `Color` tint, and per-corner `StoneRoot` UV2 coordinates. The exact source input hashes, output bounds and counts are in [`manifest.json`](manifest.json). No texture was changed or copied into a runtime asset. There is no separate material or texture per stone.

For a later runtime experiment, group surviving source stones **after** the current 8 m cell's placement masks and mineral/grass exclusions. Retain the same roots and use `StoneRoot` for the existing support-height seating logic; do not transform this flat static preview mesh into a terrain surface. Keep dense/sparse mode selection, 0.4 s cell birth fade, the complementary 3.5–5.5 m near/far dither, and fade over the final 28% of the existing 8/12/16 m quality ranges. A grouped derivative needs its own full-cell culling bounds and must preserve existing collision-free, no-shadow, no-GI behavior. The fixed templates document a grouping shape and geometry budget; they do not themselves solve variable cell masks or prove a better residency/submission path.

**Recommended first experiment: dense bed.** The measured `all` arm contained far more dense than sparse stones (100,925 versus 7,386 at its start), and dense cells carry the main geometry volume. Grouping a masked dense cell is the stronger test of the publication/submission hypothesis. Compare it against current `off`/`all`, then dense/sparse/all, rock/snow boundary images and a mixed-scenery return control under the maintained gravel validation protocol. The dense candidate's 264,000 near triangles also make a possible upload or culling regression explicit; its presence here is not an endorsement of that cost.

## Static review and rebuild

The labelled stills are [dense cell](previews/dense_8m_cell.png), [dense detail](previews/dense_detail.png), [sparse cell](previews/sparse_8m_cell.png), and [sparse detail](previews/sparse_detail.png). The flat two-colour plane is temporary **preview context**, not source geometry. These Blender renders show arrangement, scale mix and the rock/snow edge only. They do not show production terrain seating, motion fade, in-game lighting, GPU timing, or frame rate.

From the repository root, after the shared validation lock admits the work:

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
./scripts/run_guarded.ps1 -FilePath $blender -Arguments @('--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python','art_source/performance_candidates/gravel_v1/build.py') -Label gravel-source-v1 -WorkloadMode Shared -ResourceKeys @('gravel-source-v1') -TimeoutSeconds 1200
```

`build.py` deterministically reads the 12 retained pebble families at LOD0/LOD2, saves the editable `.blend`, renders four stills and refreshes the manifest. The guarded Blender admission was `Exclusive` as classified by the repository guard. Its receipts and logs are task-owned under `artifacts/guarded/gravel-source-v1/`. No Godot import, benchmark or GPU profiler was run.
