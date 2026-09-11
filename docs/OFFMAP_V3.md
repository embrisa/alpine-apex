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
Bases account for the source mesh bounds; rocks are partly buried to close gaps.
All background geometry has collision, shadow casting and GI contribution off.

| Preset | Prop density | Individual-tree range | Panorama triangles |
| --- | ---: | ---: | ---: |
| Low | 0.3 | 3,000 m | 19,200 |
| Balanced | 0.6 | 4,500 m | 37,632 |
| High | 1.0 | 6,000 m | 74,240 |

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
./scripts/check_offmap_v3.ps1 -Descents
python scripts/report_offmap_v3.py
```

The wrapper waits for existing validation, uses the exclusive guard and audits
engine/source identities, display settings and RAM/GPU allocations. Native runs
use seed 849205174/v15 Standard, 3840x2160 output, High, Auto FSR 75%, a 120 rendered
FPS cap, frame generation off and SDFGI off. Full views include six summit
bearings, lower chase/first-person and boundary views, Clear/Snowfall/dusk/night,
all presets and sampled pans. Screenshot timings are not performance evidence.

Fixed timing uses same-process ABBA blocks. Four complete ordinary-input descents
pair v2/v3 in Clear and Snowfall using the current validated v15/model-28 trace at
`artifacts/foliage_v3/descent_input.json`. Source mismatches invalidate the run.
Relative targets are <=0.5 ms added median GPU cost and <=5% p95/p99 regression;
absolute targets remain p95 <=11.1 ms and p99 <=16.7 ms. Report pre-existing baseline
failures separately from regressions.

The local comparison gallery is `artifacts/offmap_v3/index.html`, with detailed
machine-readable data in `report.json`. Automated checks, rendered inspection,
measured performance and the user's skiing acceptance are distinct.

## Validation record

The authored asset and runtime integration are undergoing validation. Final
measurements and inspection findings will be recorded here after the stable runs.

Initial implementation milestone: 458 automated assertions passed across wilderness, atmosphere, lifecycle, v15 fingerprints/mesh joins, graphics, weather submission and staged scenery suites. All six real startup cancellation stages passed (28-485 ms). Native clear-day summit and first-person captures have been inspected; the full matrix and final timing runs are still pending.
