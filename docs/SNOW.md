# Reactive alpine snow

The snow presentation reads the two completed ski contacts. It makes load,
carving grip, lateral displacement and loose-layer depth visible through surface
compression, edge spray and suspended powder. It does not change model v12,
race eligibility. The later [powder volume upgrade](POWDER_VOLUME.md) adds real
local geometric grooves on High and separately versions physical powder banks
and deeper loose snow as showcase v9. The original presentation-only baseline
and its measurements are retained below for comparison.

## Surface and sunlight

The existing scanned snow PBR channels retain their stochastic triangular
patch blending, macro deposits, wind relief and distance filtering. Fine clumps
now vary roughness; wind exposure reduces crystal density and slightly compacts
the roughness response. These are static material variations, not weather-driven
physical accumulation.

`assets/graphics/snow_crystals.gdshaderinc` shares the crystal treatment between
terrain and disturbed tracks. Each world-space cell has independent grain
placement and facet orientation. Glints use the real light/view half vector,
geometry shadow attenuation and the existing cloud transmission. They have no
emission term, animation clock or randomly blinking phase. The projected pixel
footprint filters and fades individual grains; ordinary dielectric specular
remains at distance. Low disables glints. The sun-below-horizon gate also disables
them under moonlight.

## Contact response

`scripts/presentation/snow_response.gd` reuses two small response objects. Inputs
are support, per-ski load in Newtons, slip and edge in radians, actual applied
grip in Newtons, speed in m/s, and loose depth / penetration in metres. The load
ratio uses half the rider's weight as one ski's reference load. It is not a force
applied back to the rider.

Lateral work saturates with lateral speed. Carve work combines edge angle,
applied grip/load and a saturating speed term. Supported load weights both.
Loose depth and condition then determine powder yield. A fast aligned ski has
only a small base cut and no mist; a deep skid can reach the bounded maximum.
The loaded ski emits more than an unweighted one. Lateral snow displacement sets
the throwing side, falling back to the engaged edge for a very clean carve.
Airborne, crashed and unsupported skis do not emit.

`snow_condition.gd` provides powder, deep powder, packed, wind-packed, ice and
groomed presentation responses. An optional `snow_condition_at(x,z)` surface
method returns a condition ID; legacy surfaces infer packed/powder/deep powder
from their existing loose depth. Archived mountains keep their original depth
fields; v9 adds deeper powder regions. The extra condition responses are extension points and test
fixtures, not newly generated ice/grooming zones or new friction laws. Adding
such physical conditions later requires explicit solver tuning and compatibility
versioning. Surface material maps for those additional conditions remain future
work.

## GPU spray

Six `GPUParticles3D` emitters share three small GPU process/draw programs, one of
each layer per ski. Their lifetimes are 0.60 s for grains, 0.95 s for powder and
1.90 s for mist. Grain gravity is 9.81 m/s². Powder settles more slowly, and mist
relaxes toward the weather's world wind more quickly. Wind changes affect already
airborne snow. Current wind input is bounded at 35 m/s for the local visual budget.

Spawn density, ejection speed and size depend on contact work. Size and intensity
are captured at birth, so a new turn cannot resize old clouds. A small birth
interval along the ski and its last GPU step limits disconnected emission at
220+ km/h. No CPU loops update individual particles. GPU simulation runs at 60 Hz
with the engine's particle interpolation; skiing stays at 120 Hz.

Powder combines overlapping irregular puffs, short-lived grains and sparse mist.
Gravity, wind drag, seed-dependent eddies, expansion and opacity decay separate
their motion. Particle depth testing and Balanced/High soft depth intersections
keep puffs integrated with terrain. Camera proximity and a restrained central
opacity fade protect the route. They do not cast expensive particle shadows or
perform particle/terrain collision. Particles passing behind terrain disappear
through ordinary depth testing.

## Local deformation and persistence

Distance-sampled per-ski ribbons consume the same contact response. Clean paths
remain narrow. Slip exposes more of the ski's length across travel, creating
wider disturbed bands, rough normals and preferentially displaced lips. Each
instance stores its footprint, terrain corner heights, compression, slip,
displacement side and crystal density.

An immutable R32F height texture is uploaded once per mountain (about 0.38 MiB for
the laboratory and 9.01 MiB for a 1537² summit). Ribbon vertices sample the same
4 m triangle diagonal and barycentric interpolation as contact. There is no
terrain vertex-buffer rebuild, snow map readback or GPU-to-CPU synchronization.
Raised powder lips are geometry. The groove recess uses analytical parallax,
wall normals, roughness and occlusion on the existing surface. **The groove floor
is optical in the ribbon fallback. High now replaces the nearby surface with
geometric compression; see [powder volume](POWDER_VOLUME.md).** Extreme
grazing views and overlapping skids remain approximation limits.

Track geometry is preallocated and updated only when skis cover another 0.70 m.
Each ski has independent support history. Air gaps and teleports break ribbons;
pause freezes them; restart clears them. A CPU mirror allows quality changes to
retain the newest history without reading GPU buffers. The mirror can support
future serialized race/ghost tracks, but no saving, multiplayer accumulation or
snowfall refill is implemented. Graphics never compacts physical friction.

## Budgets

| Preset | Powder / grains / mist per ski | Active particle ceiling | Track segments | Approx. paired path retained |
|---|---:|---:|---:|---:|
| Low | 96 / 64 / 0 | 320 | 800 | 280 m |
| Balanced | 192 / 128 / 48 | 736 | 1,600 | 560 m |
| High | 384 / 256 / 128 | 1,536 | 4,096 | 1,434 m |

Low's two hidden mist emitters each retain the engine's minimum one-particle
allocation and never emit. It uses fewer ribbon subdivisions, no parallax,
no crystal glints and no soft particle intersections. Balanced and High add
mist and groove parallax; High increases density, retention and lip subdivisions.
Individual glints fade within tens of metres; track visibility fades over
220–380 m while older history remains available when revisited. Retention is a
bounded path length rather than a wall-clock expiry. Low/Balanced/High identifiers
and the recommended 4K, 75% FSR2, 120 FPS High profile remain intact.

## Validation and reproduction

Automated, rendered, performance and player skiing acceptance are separate.

Automated checks:

```powershell
./godotw.ps1 --headless --script tests/snow_response_suite.gd
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --headless --script tests/graphics_suite.gd
```

The response suite covers 0–300 km/h, clean/carve/skid separation, independent
load, depth, mirrored ejection, unsupported contacts, condition variation and
read-only sampling. The existing physics suite verifies actual snow resistance,
passivity and render-schedule independence. Graphics tests cover bounded history,
quality changes, world-space wind, restart/pause and unchanged contact heights.
Run graphics_suite with a native renderer to validate instance-corner readback;
Godot's dummy renderer cannot establish that part.

Rendered inspection and synthetic contact stress fixtures:

```powershell
./godotw.ps1 --script tests/snow_playtest.gd '--' --upscaler=native --render-scale=1.0
./godotw.ps1 --script tests/snow_lab_playtest.gd '--' --quick --upscaler=fsr2 --render-scale=0.75
./godotw.ps1 --script tests/snow_lab_playtest.gd '--' --upscaler=fsr2 --render-scale=0.75
```

The first uses actual fixed-step steering and braking. The second inspects High
at 1920×1080. The third measures all presets at verified 3840×2160 output with
150 warmup frames and 480 screenshot-free measured frames per contact case,
then captures chase, side, look-back and first-person views. Cases include 160
km/h clean glide, 130 km/h carve/skid/crosswind, and a 220 km/h extreme skid.
These synthetic contacts deliberately sustain deep powder and load; they are
visual stress tests, not proof of achievable steady skiing technique.

Full mountain performance uses the existing PC harness:

```powershell
./scripts/benchmark_pc.ps1 -Label snow_v7_high_clear -Weather clear
```

Player evaluation of repeated carving/skidding, temporal glitter comfort, plume
readability and the feel of local depth remains a separate acceptance step.

### Recorded acceptance — 2026-09-07

Automated: response **31/31**, physics **56/56**, runtime **93/93**; native
graphics **29/29**, including exact instance corners and the added wind/quality
checks. No physics or generator source changed. Tests remain unranked.

Rendered: inspected the native real-solver carving/braking sequence, close
grooves, quality variants, first person and crystal comparisons. The sunlit
test produced 503 changed sampled pixels when disabling crystals, with 99 in
the central comparison region. A real box shadow caster reduced that region
to **0** crystal pixels; the night pair also differed by **0**. The test compares
every second pixel and ignores channel differences below 0.025; these are image
comparison counts, not counts of simulated crystals.

The synthetic fixtures were inspected separately: two distinct clean tracks,
broader skids, larger contact-driven plumes, crosswind drift, look-back history
and unobstructed first-person terrain. The initial thin plume and sharp skid
walls were adjusted after these rendered checks. These fixtures use prescribed
contacts, and do not establish skiing feel.

Performance: Godot **4.7.2**, **D3D12 / Forward+**, **RX 9070 / Ryzen 5 5600X**,
verified **3840×2160 output**, **2880×1620 internal**, **75% FSR2**, cap **120**.
Each laboratory row has 480 measured frames after 150 warmup frames. Captures
are outside timing. All 15 preset/contact cases averaged 8.33 ms. Selected rows:

| Preset / fixture | Mean frame ms | p95 / p99 ms | Mean GPU ms | Mean render CPU ms |
|---|---:|---:|---:|---:|
| Low, 130 km/h skid | 8.333 | 8.362 / 8.398 | 4.752 | 0.582 |
| Balanced, 130 km/h skid | 8.333 | 8.371 / 8.401 | 6.779 | 0.741 |
| High, 160 km/h clean | 8.333 | 8.373 / 8.395 | 6.659 | 0.862 |
| High, 130 km/h skid | 8.333 | 8.371 / 8.397 | 6.701 | 0.859 |
| High, 220 km/h skid | 8.333 | 8.364 / 8.399 | 6.667 | 0.845 |

The laboratory peak engine video allocation was **2,306,093,056 bytes** (2.15
GiB), including terrain/textures/environment and retained resources across
quality changes. The prescribed-contact presentation update averaged 0.751 ms
in the High extreme case; it includes pose, camera, HUD and all effect updates,
and excludes the ski solver. These short capped tests establish neither an
isolated snow GPU cost nor whole-mountain performance or sustained 144 FPS.

Evidence: `artifacts/snow_upgrade/response.json`, `physics.log`, `runtime.log`,
`graphics_native.log`, `validated_playtest.log`, `playtest_legacy.json`, and
`lab/performance.json`. Baseline captures/logs are retained under `before/`;
final lab PNGs include clean, carve, skid, crosswind and extreme chase/side
views, look-back views, and first person for every preset.

### Full Technical Showcase performance

The fixed v7 / seed 849205174 western descent completed unranked without a crash
in **369.833 s**. The same PC, High, 4K output and 75% FSR2 profile recorded
**44,200 measured frames** after 120 warmup frames, with screenshots excluded.

| Scope | Average FPS | Mean ms | p95 / p99 ms | Slowest-1% mean FPS |
|---|---:|---:|---:|---:|
| Full descent | 119.52 | 8.367 | 8.821 / 9.890 | 87.06 |
| First-person forest (9,163 frames) | 118.50 | 8.438 | 9.602 / 10.581 | 83.41 |

Measured rendering averaged **6.704 ms GPU** (7.917 / 8.917 ms p95/p99) and
**0.577 ms CPU** (0.832 / 1.115 ms p95/p99). Isolated ski steps averaged
**0.347 ms**, p99 **0.490 ms**. The track ring filled to **4,096 segments**;
the immutable summit height texture used **9,449,476 bytes**.

Peak engine video allocation was **2,582,065,152 bytes** (2.40 GiB). OS sampling
recorded peak engine working set **967,368,704 bytes**, peak private allocation
**3,517,714,432 bytes**, and minimum system free RAM **3,814,404,096 bytes**.
Existing applications remained untouched; WoW was absent. Generation took
20.088 s and world construction 7.462 s, both outside steady-state measurements.
Source hashes were unchanged across the run.

This run satisfies the documented p95/p99 target for this route/profile. The
conservative pilot peaked at **74.77 km/h**. Sustained 130–220 km/h snow contact
was exercised by the separate laboratory stress fixtures; this full descent
does not establish high-speed handling, all weather combinations or 144 FPS.
User skiing acceptance remains open.

Evidence: `artifacts/pc_environment/snow_v7_high_clear/native_-1_clear.json`,
`system.json`, `stdout.log`, `stderr.log`, and the post-timing finish capture.

## References

Implementation follows Godot's [GPU particle shader contract](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/particle_shader.html),
[spatial shader lighting](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)
and [depth-texture reconstruction](https://docs.godotengine.org/en/latest/tutorials/shaders/screen-reading_shaders.html).
