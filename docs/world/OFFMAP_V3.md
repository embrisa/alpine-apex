# Authored alpine background and distant valley fog

Presentation v3 uses one reusable background asset, `alpine_valleys_01`, shared
by every v15 mountain. Random scenery generation is an explicit authoring step;
game startup and quality switching load the baked result. Future backgrounds can
be separate named resources using the same contract. There is no new selector UI.

The user selected a natural alpine mix and background-only fog, then clarified:
use the normal mountain's visual techniques, bake once for reuse across maps,
and shorten the empty transition outside the playable boundary. The first ridge
band therefore moves from roughly 7.4 km to 6.6 km from the mountain center.
The outer 18 km horizon and 192 m protected collar remain. Following the user's
request to remove the square, featureless edges, unused rendered corners are cut
back to an irregular outline just beyond the existing 2,850 m summit-return zone.
Physical v15 generation, the 120 Hz solver and replay model are unchanged.

## Irregular perimeter

`mountain_footprint.gd` owns a fixed, gently varying outline around 3.03 km radius.
It selects 32 m blocks of the existing 4 m terrain, without changing any height,
obstacle, collision or return-zone data. The conservative minimum guard beyond the
playable zone is 83.9 m. Preview images use the same outline and transparent corners.

The terrain now submits 478 chunks, including 84 partial chunks, and 3,610,880 base
triangles instead of 576 chunks / 4,718,592 triangles. Interior LODs are unchanged;
partial edge chunks retain the authoritative 4 m triangles without coarse LODs.
The apron stitches every exposed 4 m edge vertex exactly, then follows normal-map
foothill and drainage techniques into the fixed ridges. Its collar shares the
physical terrain's contact-material texture and snow-readability uniforms and
receives the same lighting. Background shadow casting remains disabled.

Mountain scenery identity advances from 2 to 3. Physical generator 15 and replay
model 28 remain current. Scenery cache schema 2 validates the complete retained
chunk layout, unique centers and partial indices before publishing a cached result.

## Shared appearance

Snow uses the normal mountain's slope, hollow and wind-exposure calculation,
extracted without changing its arithmetic into `MountainData.snow_coverage`.
Background materials reuse the same scanned snow and mineral textures and color
grading. Texture filtering and a small snow scattering lobe retain a readable
white surface at distance. Mineral noise stays on exposed rock instead of tinting
snow gray. Elevation guides forests rather than drawing a straight snowline.

Forests occupy sheltered, gentler lower slopes, with sparse treelines, gaps and
small groves. Three existing conifer families use their normal forest LOD1 geometry
nearby, including textured bark, cutout needles and modeled snow, and their
eight-direction atlas farther away. The transition spans
480-600 m with complementary coverage dithering. Existing boulder and gneiss assets
use slope-aware snow caps. Canopy shading continues beyond the individual-tree range.
Imported materials are never modified; the background owns its own materials.

## Bake and runtime boundaries

`assets/graphics/scenery/alpine_valleys_01.res` is a compressed Godot Resource
(about 24 MB), committed through LFS. It contains three terrain/prop presets,
baked biome masks, a reference apron, triangle anchors, counts and source receipts.
No new bitmap art is required. The explicit authoring entry point is:

```powershell
./godotw --headless --script scripts/authoring/bake_wilderness.gd
```

Run it under `scripts/run_guarded.ps1` during validation. It is never invoked by
normal startup, loading, cache repair, map generation or quality switching.
`wilderness_recipe.gd`, `wilderness_mesh.gd` and `wilderness_placement.gd` live in
`scripts/authoring/`. The bake uses an isolated presentation seed and a temporary
TriangleMesh BVH over the actual apron/panorama triangles, separately for every
preset. Deterministic 32 m candidate cells produce uneven stands and small groves.

Runtime `wilderness_data.gd` reads the asset. Only the connector adapts to the
current mountain: it retains the exact 192 m collar and blends the height
difference to zero by 640 m outside the retained terrain outline. The fixed outer
background is independent of the mountain seed. All 1,024 apron/panorama joins
retain matching position, normal and mask values. The current connector supports
the standard v15 bounds; incompatible resources/bounds fail explicitly.

`wilderness_instances.gd` loads authored transforms and uses their baked triangle
indices and barycentric weights to re-seat props on the adapted apron. Rocks
also follow the adjusted support normal. There is no runtime random placement,
triangle BVH, regeneration or new physical collision data. Quality switches load
the preset whose placements were baked against that exact terrain triangulation.

Cards and rocks use 1,024 m spatial MultiMeshes. Runtime preparation partitions
near conifers into 256 m batches, preserving every authored transform and custom
value. This avoids processing large hidden groves beyond the 600 m geometry range.
All bounds are conservative, including billboard orientations. Per-instance fades
cover the last 800 m of visibility.
Individual rocks fade out by 3,200 m (3,000 m on Low); rock texture breakup
continues on the terrain. Node culling adds half the batch-bound diagonal to the
instance range, matching Godot's distance measurement from the AABB center.
Bases account for the source mesh bounds; rocks are partly buried to close gaps.
All background geometry has collision, shadow casting and GI contribution off.

| Preset | Prop density | Individual-tree range | Panorama triangles |
| --- | ---: | ---: | ---: |
| Low | 0.3 | 3,000 m | 19,200 |
| Balanced | 0.6 | 4,500 m | 37,632 |
| High | 1.0 | 6,000 m | 74,240 |

High stores 177,021 tree positions, 15,142 matching near-tree instances and 16,361
rocks in 1,890 authored groups. Near-tree partitioning produces 2,592 runtime
batches, totaling 98,832,636 nominal prop triangles. Most belong to nearby tree
geometry that is culled outside 600 m. These stored counts must not be treated as visible-frame
work. The default connector changes zero authored placements; another mountain
seed re-seats only placements attached to the adapted apron.
The bake uses the same scenery seed as normal `MountainPreparation` startup.
Native comparison fixtures assert the reference height identity and zero default
anchor movement before capturing or measuring anything. Reports include both
reference/connector seeds and the actual loaded resource path and hash.

## Atmosphere and lifecycle

The shared background `FOG` output consumes the existing blended weather state.
Additional haze fades in beyond 1 km from the camera and outside the protected
collar. It concentrates in low valleys, fades out towards peaks, strengthens in
cloudy weather and follows day/dusk/night colors. Weather Off disables this
additional component. Spatial variation is static; no separate clock is added.

Godot's custom `FOG` output replaces automatic fog for that material. These
background shaders therefore compose exponential distance extinction and sun
scattering with the additional valley term. They do not sample the local
volumetric buffer. Playable terrain does not compile this custom output; the
world's Environment, nearby shadowed shafts and rider visibility are unchanged.
Inspect the join and horizon when changing these coefficients.

New ridge and prop batches build under a hidden staging owner, then replace the
active owner together. The existing data worker handles connector prop fitting;
scene submission yields through loading checkpoints. Cancellation releases the
staging owner and preserves active geometry. Newer preset requests supersede
older builds. The wilderness owns materials, meshes and its resource references;
obsolete scene batches are freed and current weather is reapplied on replacement.

Reports separate asset identity/read time, connector fitting, prop upload, nominal
prop triangles, counts/batches, seating error and physical/source identities.
Nominal triangles count every stored instance; they are not visible-frame GPU work.
Loading, memory and steady-state frame timing must be reported separately.

## Reusable validation

The original seven files under `tests/fixtures/offmap_v2/` freeze the previous presentation
for explicit comparisons on the current v15 Standard mountain. They are test-only
and are not an alternate shipping renderer. Their original hashes are retained.
A small test-only MountainData override restores the old apron-height detail.
The fixture restores the omitted square terrain chunks with their original LODs
and verifies the original 4,718,592-triangle total for the baseline. Shared physical
heights, camera and weather remain identical between both presentations.

```powershell
./scripts/check_offmap_v3.ps1 -Views -Quick
./scripts/check_offmap_v3.ps1 -Views
./scripts/check_offmap_v3.ps1 -BoundaryMotion
./scripts/check_offmap_v3.ps1 -FixedTiming
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--headless','--script','tests/performance_trace.gd','--','--version=15','--face=3','--trace-output=artifacts/offmap_v3/descent_input.json') -Label offmap_v3_trace -TimeoutSeconds 1200
./scripts/check_offmap_v3.ps1 -Descents
python scripts/report_offmap_v3.py
```

The wrapper waits for existing validation, uses the exclusive guard and audits
engine/source identities, display settings and RAM/GPU allocations. Native runs
use seed 849205174/v15 Standard, 3840x2160 output, High, Auto FSR 75%, frame generation
off and SDFGI off. Timing uses a 120 rendered FPS cap; capture fixtures hold 30 FPS
and also incur readback/encoding overhead. Full views include six summit
bearings, lower chase/first-person and boundary views, Clear/Snowfall/dusk/night,
all presets and sampled pans. The current set contains 73 matched pairs, including
two aerial perimeter views and diagonal boundary approaches, plus 144 sampled
motion frames. A separate 48-frame eye-height boundary pass travels from 2,670 to
2,835 m radius while looking ahead, where near-tree fades and seating are visible.
Screenshot timings are not performance evidence. `offmap_prop_benchmark.gd`
isolates nearby trees, rocks and all props at the expensive face-2 lower view.

Fixed timing uses same-process ABBA blocks. Four complete ordinary-input descents
pair v2/v3 in Clear and Snowfall using the current validated v15/model-28 trace at
`artifacts/offmap_v3/descent_input.json`. Source mismatches invalidate the run.
Descents pin the current Connected camera and default foliage aid in memory;
personal preferences are never saved. The verified current trace retains the
original commands, 35,669-tick finish and exact endpoint after the camera API update.
Relative targets are <=0.5 ms added median GPU cost and <=5% p95/p99 regression;
absolute targets remain p95 <=11.1 ms and p99 <=16.7 ms. Report pre-existing baseline
failures separately from regressions.

The local comparison gallery is `artifacts/offmap_v3/index.html`, with detailed
machine-readable data in `report.json`. Automated checks, rendered inspection,
measured performance and the user's skiing acceptance are distinct.

## Validation record

The final stable validation set completed on 2026-09-11, after the shared snow
readability update (`eb8dfcc`) and near-tree culling milestone (`9e476f2`). All four
native guards exited successfully, with no concurrent heavy workload or changed
runtime sources. The gallery report marks the evidence set complete. This records
completed implementation and agent review; user/controller acceptance is pending.

The irregular-perimeter asset occupies 24,798,121 bytes; SHA-256:
`5f091db305c434fb327c1679cce2619afb0f98ad6769efabae303f0463731b85`.
Eight footprint checks pass, including 3,600 boundary bearings, exact partial
triangles and transparent preview corners. All 22 geometry checks pass, including
every exposed 4 m join vertex and a second seed using the same asset. The updated
forest/material/bounds suite passes 16 checks; atmosphere passes 10 and lifecycle
passes 5. The affected suite set totals 740 checks with no failures, including
graphics, weather, interface, mountain library, v15 contracts, cache integrity and
all six real startup cancellation stages (28-550 ms). Current source/export
receipts are refreshed. Repartitioning preserves the placement fingerprint
`240d0dd8c7bf5908ac244157c619ed8b6bfe525722819b899b933550ba2dae37`.
Physical height and obstacle checksums remain respectively
`e12569ae88d5c3c564e66ad6e3e5ed3744baa71398a914db6c954c6eba24e40e`
and `b84df994471e299e83aebbb114ad3d156f6f6a0306dbf44d8f8e08824c0d4159`.

### Rendered inspection and acceptance

The current set contains 73 matched native 4K pairs and 192 sampled motion frames:
six summit bearings, lower chase/first-person, boundary approaches, two aerial
perimeter views, all three presets, Clear/Snowfall/dusk/night, two summit pans,
camera travel and a separate eye-height boundary pass. The gallery presents eight
featured comparisons and four paired sampled clips, with the remaining stills
expandable. Original 4K files remain available; animated previews are 1280x720.

Inspected views show a continuous white snow connection, recognizable uneven
forest stands, natural boulders and clearer separation of near slopes and distant
ridges. The former square rim is absent. The normal mountain's snow sources and
coverage calculation resolve the earlier gray mineral tint on snow. Dusk and
night colors follow the existing weather state. Snowfall strongly softens distant
forest detail, and coarse panorama facets remain visible at the retained terrain
budget. Those are visual limits of this version.

Sampled pans and the boundary pass show no obvious open joins, floating props or
large abrupt changes in the inspected frames. This is sampled rendered evidence,
not proof of shimmer-free continuous motion. Complete descents below verify the
ordinary-input route and performance without screenshots; they do not establish
controller feel. Agent visual review accepts this as an improvement in background
readability and perimeter continuity. The user's skiing/appearance acceptance is
still open.

### Measured performance

The guarded comparison ran on the Ryzen 5 5600X / RX 9070 at 3840x2160 output,
2880x1620 internal rendering, High, Auto FSR 4.1.1 at 75%, a 120 rendered FPS cap,
frame generation off and SDFGI off. No screenshots or encoding occur inside the
measurement windows. The fixed views pool 4,320 frames per version across six
same-process ABBA views. Four full descents pair v3/v2 for Clear and Snowfall.

| Workload | Version | Median GPU ms | Frame p95 ms | Frame p99 ms |
| --- | --- | ---: | ---: | ---: |
| Fixed views | v2 | 9.194 | 11.877 | 12.136 |
| Fixed views | v3 | 9.616 | 11.820 | 12.016 |
| Clear descent | v2 | 7.807 | 20.217 | 27.728 |
| Clear descent | v3 | 7.742 | 18.119 | 24.192 |
| Snowfall descent | v2 | 8.087 | 19.511 | 31.239 |
| Snowfall descent | v3 | 7.885 | 18.232 | 24.194 |

All three workloads pass the relative budget. Fixed-view median GPU cost adds
0.422 ms; p95/p99 change by -0.48%/-0.99%. Clear descent median GPU changes by
-0.065 ms with p95/p99 -10.38%/-12.75%; Snowfall changes by -0.202 ms with
p95/p99 -6.56%/-22.55%. These descents are one observed pair per weather, not a
multi-session estimate of a speedup. The report computes descent GPU medians from
the retained raw frame samples and records their hashes; native summaries are
left intact.

The absolute p95 <=11.1 ms / p99 <=16.7 ms targets remain unmet. Both fixed-view
versions exceed the p95 target; both descent versions exceed both tail targets.
Average rendered descent rates are 77.50/77.19 FPS for v3 Clear/Snowfall versus
75.86/75.00 FPS for v2, below the desired 90-120 FPS. This milestone meets the
scenery regression budget, not overall rendered gameplay performance acceptance.

All four descents finish the same 35,669-tick ordinary-input trace exactly, with
no crash or source mismatch and no generated frames. Physical generator 15 and
model 28 remain unchanged. The trace SHA-256 is
`5fc463142e545fb9238ba637622d8e10cbea81e69bab7e6e853715ed1642ff2c`.

### Loading and memory

These are cached starts, not cold physical generation. Descent startup measured
2.368 s physical-cache reading and 5.173 s scenery-preparation-cache reading.
The authored background read took 124.9 ms; prop preparation took 222.3 ms;
prop submission took 3.769 s and apron construction 3.944 s. The fixed-view
startup measured 127.6 ms / 256.0 ms / 7.453 s for asset read, preparation and
prop submission. Submission/construction are elapsed times including loading
checkpoints and frame pacing, not pure CPU work or steady-state GPU cost.

Peak process private memory / GPU allocation were 5.75 / 4.06 GiB for fixed views
and 5.69 / 4.10 GiB for descents. Both v2 and v3 fixtures are resident in these
comparison processes; these figures do not measure incremental v3 RAM or VRAM.
The report retains stage timing, engine allocation counters, full process/GPU
samples and asset/source identities separately from frame timing. Reducing scene
submission time and measuring standalone production allocations remain useful
follow-up opportunities.

### Retained diagnostic iteration

The first perimeter timing run (`fixed_before_prop_culling.json`) missed the added
median GPU target: +0.790 ms, with p95/p99 ratios 1.0016/0.9977. Component isolation
at the expensive lower view attributed about 1.5 ms to near conifers. Partitioning
those batches at 256 m reduced their measured contribution to about 0.2 ms while
preserving the authored asset, placement fingerprint, geometry and fade ranges.
Preparation was 220 ms in the headless check. These component runs diagnose the
change; the final stable full comparison above determines acceptance. Older
67-pair captures and pre-perimeter assets are historical iteration evidence and
are superseded by the current gallery and source audit.
