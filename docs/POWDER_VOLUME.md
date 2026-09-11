# Powder volume and local snow surface

**Current game environment:** [v15 Standard](GENERATION_V15.md) retains physical snow formations and filtered track relief. Version-specific measurements below describe their original workload.

## Responsive ski contact — 2026-09-11

Snow now follows the actual rendered ski transforms, including interpolated turns
and switch stance. Two live ribbon sections extend from the last retained tail
sample through the visible tips, with a 12 cm soft leading margin. They update
every frame instead of waiting for the next 70 cm history sample. High's two GPU
footprints use the same endpoints. This removes the history-sampling gap at the
front; it does not claim zero display, GPU or input latency.

Loaded clean carving now widens and deepens the cut even with negligible slip.
History starts at 28 cm wide, with up to 20 cm added by loaded edge work; lateral
skidding still creates the broadest swept tracks. Live ski footprints vary from
30 to 50 cm with turn work. Cuts remain bounded by loose depth and width, with
broader rounded lips and stronger snow ejection toward the front during turns.
The compute shader's lateral axis now agrees with the ribbons and world-space
snow throw, so the larger lip forms on the displaced-snow side.

The 120 Hz solver, terrain authority, penetration, friction, speed and replay
identity are unchanged. Unsupported skis, crashes and exposed rock produce no
live tracks. Landing/teleport/reset break old history. Low/Balanced also use the
two live sections; High keeps its existing 32 m patch, mesh/atlas sizes, 4096
history slots and two GPU footprints. The added CPU ribbon MultiMesh contains
only two small planes and shares the existing material. Extra longitudinal
subdivisions soften their end caps. They do not consume retained history or add
particles. Live updates write their final transforms once
per frame without an intermediate hidden transform.

Reproduce the focused validation with:

```powershell
./scripts/validate_snow_contact.ps1 -Stage checks
./scripts/validate_snow_contact.ps1 -Stage visual
./scripts/validate_snow_contact.ps1 -Stage mountain
./scripts/validate_snow_contact.ps1 -Stage timing
```

The runner waits for the shared guard and executes engine workloads serially.
Evidence is in `artifacts/snow_contact_20260911/`; its excluded `baseline/` is a
frozen snow-presentation comparison fixture, not a product fallback. Rendered
cases use the current solver with fixed glide, left/right turn and reversal
inputs. Screenshots and screenshot-free short timing windows are separate.
Full-descent performance and the user's skiing/controller acceptance remain
separate from these contact checks.

Validation: 33 response checks, 21 live-contact/pose/lifecycle checks, 32 rock
regressions and 13 native GPU checks pass. The latter include byte-exact partial
versus full uploads and the world-space side of the displaced lip. Native testing
caught the end-cap shader exceeding the varying limit; packing its two values
into one `vec2` fixed compilation, and the GPU and final rendered runs passed.
The small correctness checks and final close-up captures used the guard's
explicit concurrent mode; they are not performance measurements.

The 1920x1080 native laboratory captures cover turn onset, left/right hard turns,
reversal and chase views. One matched 130 km/h hard-turn sample at frame 60 changes
requested track width from 0.227 m to 0.440 m and depth from 0.0625 m to 0.1071 m;
the compute aspect-ratio/filter bounds still govern actual mesh displacement.
The physical positions match. Snow is visibly connected through the tips with
stronger lips and forward spray. Very close views still expose some mesh/ribbon
faceting; these frames do not establish human visual or controller acceptance.

Current-mountain integration also uses the independently completed
`snow_grounding_playtest.gd` run at 01:24 on September 11: v15 / model 28, three
current-model chase sequences, no failures, and all seven changed product files
matching this change's final hashes. Its receipt and inspected frames are copied
into `v15_integration/`. That harness's before/after labels compare physical
models; both use the current snow presentation, so it is an integration check,
not a snow-effect A/B comparison.

The separate guarded timing pair used RX 9070 / D3D12 / Godot 4.7.2,
3840x2160 output, 2880x1620 internal, Auto FSR 4.1.1, High, 120 FPS cap,
SDFGI and frame generation off. Each two-second case follows a rehearsal of
the same contact workload; captures are excluded and sources match across the
pair. Mean snow-track/powder CPU time rises from 0.071–0.077 ms to
0.102–0.113 ms. Total viewport GPU mean rises from 6.02–6.30 ms to 6.75–6.76 ms.
This is the cost of visibly stronger output, not an equivalent-output speedup.

| Current contact case | Mean rendered FPS | Frame p95 / p99 ms |
|---|---:|---:|
| Glide | 119.98 | 8.455 / 9.423 |
| Left turn | 120.01 | 8.694 / 9.989 |
| Right turn | 120.01 | 8.583 / 9.431 |
| Reversal | 119.48 | 8.941 / 10.664 |

These four short cases meet the frame-time target in this pair; they do not
establish sustained mountain performance or a repeatable isolated GPU delta.
The summary and source hashes are in `validation.json`. Guard receipts contain
process RAM samples; device allocation telemetry was not collected. The fixed
atlas/contact buffer and particle capacities are unchanged. A longer matched
descent should precede further GPU tuning; the CPU contact cost is small enough
that a native rewrite is not justified by these measurements.

Technical Showcase now selects **849205174 / v9**. Thirty-two wind-loaded banks
add visible accumulation to its upper chutes and lower glades. The tallest change
against v8 is 4.585 m; 8,135 physical vertices change. The banks are baked before
obstacle placement into the authoritative 4 m triangles used by skiing, survey,
crash collision and rendering. Local loose depth is 17–31 cm, so existing model
v12 penetration and passive ploughing resistance respond to the deeper powder.
No visual setting changes the physics. Both automated routes reach the base.

Versions v1–v8 remain available unchanged; bare/random seeds still use v4. V9 has
separate terrain/replay identity. Its frozen hashes are:

- Heights: `6baaeeba3608c2f47a280e5a86cb5350aed70f40c1a455cb3274e49d3904bc83`
- Obstacles: `58001d00894141a649cb33816e51fb5838c514d6417cd659330d605dd4b49232`

## Where to see it

Run `./scripts/play_powder_garden.ps1` to open an **unranked, paused, interactive**
preview directly in the upper powder section. Resume uses normal keyboard/pad
controls. Ordinary Restart returns to the showcase summit. The preview does not
write display preferences or personal bests.

In the normal game, generate **Technical Showcase** again to select v9. Previously
loaded or saved v8 mountains retain their original terrain. The upper powder
section spans approximately z=540–1290 m, with another region at z=1970–2430 m.
The mountain survey labels the Powder Garden near z=820 m.

Snow crowns on suitable rocks, softer snow shading, and High's detailed local
surface also apply to the laboratory and existing mountains. New metre-scale
physical banks belong specifically to v9.

## Static snow accumulation

Six cached snow crowns are fitted to the top envelopes of the six imported rock
meshes. Smooth polar rings and a closed, rounded lip give the deposits a visible
silhouette and thickness. The rock and crown are buried together by 0.48 times
the obstacle scale. Their union stays inside the existing radius/height impact
envelope. These are conservative obstacle envelopes, not new per-triangle rock
collision. Lower-cost index LODs and regional MultiMeshes keep crowns bounded;
visibility distances are 90 / 150 / 220 m for Low / Balanced / High.

Snow uses a brighter, less crusty scanned-material blend, fine grain, varying
roughness, and world-locked directional crystal glints. A small wrapped diffuse
term approximates light scattering in loose snow and obeys actual/cloud shadow
attenuation. It is not emissive glitter or a volumetric light-transport simulation.

## Local deformation on High

`presentation/powder_surface.gd` integrates a **32 × 32 m** patch into the existing
built-in mesh renderer. Its fixed **512 × 512** cells have 6.25 cm spacing and
263,169 vertices. The original terrain is clipped only inside the replacement
rectangle. Exact base-height sampling and matching triangle diagonals preserve
the authoritative 4 m surface underneath the small visual impressions.

A three-pass GPU compute program clears an integer atlas, rasterizes bounded
contact strokes with atomic maximum, and resolves signed height/compaction to a
filterable half-float map. Cuts take priority over displaced lips. This avoids
overlap races and unlimited accumulation. A 1024² atlas resolves 3.125 cm texels;
the current filtered 256² resolved map and integer map use 4.25 MiB together,
with a 128.1 KiB contact buffer. Centered normals and filtering over multiple
mesh vertices round deep groove edges; earlier 8 MiB measurements below predate
this change.
These buffers are allocated once and retained through quality changes.

The GPU reconstructs from the existing bounded per-ski track ring, plus two current
ski footprints. Returning to retained tracks restores their detail without texture
readback, scrolling-copy errors, or mountain-wide geometry updates. At most 128.1
KiB of contact metadata is uploaded per active frame. A five-metre edge transition
removes local relief smoothly; cheaper ribbons preserve distant history.

Untouched snow has world-fixed, rounded loose clumps up to 7.5 cm, also bounded
by local loose depth. A ski compresses those crowns and leaves an actual geometric
groove with raised lips. Rendered ski burial uses 15% of physical penetration,
bounded to 2 cm so deep snow does not hide the equipment. The binding and ankle
remain attached and render IK closes the legs.
The root, camera, 120 Hz contact solver and crash state receive no visual feedback.

This is a **visual loose layer over the authoritative support surface**, not a
new dynamic collision heightfield. Track history does not change friction or
excavate the mountain. The fixed patch limits distant geometric depth. Low and
Balanced retain the cheaper track representation; gameplay depth is identical.
Saving tracks, snowfall refill, multiplayer accumulation and physical particle
collision remain future work.

## Validation

Keep automated checks, rendered inspection, measured performance and player
skiing acceptance separate. Native GPU readbacks exist only in the inspection
harness and are excluded from all performance windows.

```powershell
./godotw.ps1 --headless --script tests/powder_volume_suite.gd
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --script tests/graphics_suite.gd
./godotw.ps1 --headless --script tests/mountain_library_suite.gd
./godotw.ps1 --headless --script tests/competitive_suite.gd
./godotw.ps1 --headless --script tests/snow_response_suite.gd
./godotw.ps1 --script tests/powder_volume_playtest.gd '--' --version=9 --views --graphics-quality=high --benchmark-label=powder_v9_views --benchmark-resolution=3840x2160
./godotw.ps1 --script tests/powder_stress_playtest.gd '--' --measure-only --render-scale=0.75 --upscaler=fsr2 --fps-limit=120
./scripts/benchmark_pc.ps1 -Label powder_v9_final_high_clear -Version 9
```

Physical results: `artifacts/powder_volume/physical_results.json`. Both pilot
routes finish without a crash: west 394.42 s / 70.87 km/h peak, east 366.94 s /
107.78 km/h peak. These conservative pilot routes are not extreme-speed handling
acceptance. The separate prescribed-contact stress matrix exercises clean
160 km/h, carve/skid/wind 130 km/h, and extreme skids at 220 km/h.

Rendered views include untouched banks, plain geometry, buried outcrops, consecutive
moving frames and nearby tracks. Native atlas inspection found approximately
10.1 cm recesses and 9.8 cm raised lips, verified restoration of the base on Low,
history retention through quality changes, and unchanged physical height bytes.
The final 4K views and native atlas checks are in
`artifacts/pc_environment/powder_v9_final/`. Human skiing/art-direction
acceptance remains open.

### Prescribed-contact performance

The 15-case Low/Balanced/High matrix runs at 3840 × 2160 output, 2880 × 1620
internal, 75% FSR2, 120 FPS cap and SDFGI off on RX 9070 / D3D12 / Godot 4.7.2.
Each case excludes 150 warmup frames and measures 480 frames without captures.
All cases average approximately 8.333 ms, holding the cap. High results:

| Contact case | Frame p95 / p99 ms | GPU mean ms | Render CPU mean ms |
|---|---:|---:|---:|
| Clean, 160 km/h | 8.386 / 8.527 | 6.674 | 1.204 |
| Carve, 130 km/h | 8.381 / 8.555 | 6.695 | 1.144 |
| Skid, 130 km/h | 8.377 / 8.476 | 6.940 | 1.118 |
| Wind and skid, 130 km/h | 8.424 / 8.863 | 6.959 | 1.227 |
| Extreme skid, 220 km/h | 8.386 / 8.600 | 6.703 | 1.158 |

Peak engine video allocation is 2.176 GiB. These are short, synthetic-contact
laboratory samples, not a complete descent or proof of 144 FPS. They include
the final 512-cell local surface, but precede the last cap-envelope correction
(which retains the same geometry budget). See
`artifacts/powder_volume/stress/performance.json` for the complete matrix.

### Final full descent

`artifacts/pc_environment/powder_v9_final_high_clear/` records the completed,
unranked western route on Ryzen 5 5600X / RX 9070 / 16 GB with the same 4K output,
75% FSR2, High, 120 FPS cap, Clear/Day and SDFGI-off configuration. All final snow
code and resources, including the corrected closed caps, remained unchanged.
The screenshot-free window excludes 120 warmup frames and contains 46,436 frames.

| Scope | Mean FPS | Frame p95 / p99 ms | Slowest 1% mean FPS |
|---|---:|---:|---:|
| Full descent | 117.74 | 9.579 / 11.541 | 62.83 |
| First-person forest | 114.38 | 10.373 / 13.638 | 55.97 |

Both scopes meet the documented p95 ≤ 11.1 ms / p99 ≤ 16.7 ms policy for this
run. Occasional forest stalls remain; this does **not** establish a guaranteed
60 FPS minimum or 144 FPS support. The conservative pilot peaks at 70.87 km/h,
finishes in 394.42 simulation seconds and does not crash.

GPU rendering averages 7.117 ms (8.767 / 9.784 ms p95 / p99); render CPU averages
0.901 ms (1.554 / 2.252 ms). Isolated solver calls average 425.9 µs, p99 797 µs.
Engine video allocation peaks at 2.445 GiB. Sampled process working set peaks at
0.945 GiB and private bytes at 3.383 GiB; available system RAM falls to 1.628 GiB.
Generation takes 27.90 s and world construction 10.35 s, outside timing. The
retained ring reaches all 4,096 strokes and the local GPU atlas remains bounded.

Existing applications were left untouched. No WoW process was sampled. Concurrent
mineral-library work changed four unused art/gallery source files during the run,
as recorded in `system.json`; no snow/runtime source changed. This is a measured
desktop workload, not an isolated attribution of GPU cost or a fully frozen
project snapshot. Earlier interrupted `powder_v9_high_clear` output is not
used for performance acceptance.
