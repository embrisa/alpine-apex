# Authored alpine background and distant valley fog

Presentation v3 uses one reusable background asset, `alpine_valleys_01`, shared
by every v15 mountain. Random scenery generation is an explicit authoring step;
game startup and quality switching load the baked result. Future backgrounds can
be separate named resources using the same contract. There is no new selector UI.

The user selected a natural alpine mix and background-only fog, then clarified:
use the normal mountain's visual techniques, bake once for reuse across maps,
and shorten the empty transition outside the playable boundary. The first ridge
band therefore moves from roughly 7.4 km to 6.6 km from the mountain center.
The outer 18 km horizon, 192 m protected collar and terrain triangle budgets remain.
Physical v15 generation, the 120 Hz solver and replay identity are unchanged.

## Shared appearance

Snow uses the normal mountain's slope, hollow and wind-exposure calculation,
extracted without changing its arithmetic into `MountainData.snow_coverage`.
Background materials reuse the same scanned snow and mineral textures and color
grading. Texture filtering and a small snow scattering lobe retain a readable
white surface at distance. Mineral noise stays on exposed rock instead of tinting
snow gray. Elevation guides forests rather than drawing a straight snowline.

Forests occupy sheltered, gentler lower slopes, with sparse treelines, gaps and
small groves. Three existing conifer families use simplified shadow geometry
nearby and their eight-direction atlas farther away. The transition spans
480-600 m with complementary coverage dithering. Three existing rock assets use
slope-aware snow caps. Canopy shading continues beyond the individual-tree range.
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
difference to zero by 640 m outside the physical rectangle. The fixed outer
background is independent of the mountain seed. All 1,024 apron/panorama joins
retain matching position, normal and mask values. The current connector supports
the standard v15 bounds; incompatible resources/bounds fail explicitly.

`wilderness_instances.gd` loads authored transforms and uses their baked triangle
indices and barycentric weights to re-seat props on the adapted apron. Rocks
also follow the adjusted support normal. There is no runtime random placement,
triangle BVH, regeneration or new physical collision data. Quality switches load
the preset whose placements were baked against that exact terrain triangulation.

Props use 1,024 m spatial MultiMeshes with conservative bounds, including all
billboard orientations. Per-instance fades cover the last 800 m of visibility.
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

The shared asset occupies 24,347,984 bytes. High stores 167,352 tree positions,
19,645 matching near-tree instances and 16,369 rocks in 1,781 spatial batches.
Its nominal prop triangle count is 30,451,916, mostly near-tree geometry that is
culled outside 600 m. These stored counts must not be treated as visible-frame
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

The seven files under `tests/fixtures/offmap_v2/` freeze the previous presentation
for explicit comparisons on the current v15 Standard mountain. They are test-only
and are not an alternate shipping renderer. Their original hashes are retained.

```powershell
./scripts/check_offmap_v3.ps1 -Views -Quick
./scripts/check_offmap_v3.ps1 -Views
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
all presets and sampled pans. Screenshot timings are not performance evidence.

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

The authored asset and runtime integration are undergoing validation. Final
measurements and inspection findings will be recorded here after the stable runs.

Initial implementation milestone (`4c2dccf`): 458 automated assertions passed
across wilderness, atmosphere, lifecycle, v15 fingerprints/mesh joins, graphics,
weather submission and staged scenery suites. All six real startup cancellation
stages passed (28-485 ms). The tighter culling subsequently passed all 14 wilderness
checks. The corrected production-reference asset hash is
`973b2412a47e618b5b7787a1bb1cb9bf4a472768596e3784da58094d163ac5e2`.
Its 41 wilderness, geometry, physical-fingerprint and lifecycle checks passed
again. Real staged startup also passed the reference-identity assertion with
zero adjusted anchors.

The first full rendered set contains 67 matched 4K pairs and 144 sampled motion
frames. Inspected summit, lower, boundary, weather and preset views show cleaner
snow and recognizable closer forests. Simplified nearby trees/rocks remain
apparent at the boundary, and Snowfall substantially softens distant detail.
Sampled frames did not show obvious floating or open joins; they do not establish
absence of shimmer during continuous skiing. Current-camera/current-culling
captures and final timing runs supersede this first set below. User/controller
acceptance remains pending.
