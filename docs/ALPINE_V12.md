# Alpine terrain regions v12

These landforms remain the support surface beneath [current v13](ALPINE_V13.md).
Default and bare/random seeds select v13; explicit v12 recipes retain their own
reconstruction. The version-specific evidence below belongs to the v12 revision.

## Landforms and route choice

The asymmetric foundation supplies broad spurs and an elongated shoulder, fading
into the lower mountain before its shallow runout. The six seeded faces contain
overlapping pitched cirques, offset snow ridges,
rounded benches, terrain pockets and short tributaries. Tributaries join nearby
basins and split around shoulders. Each lasts one elevation tier, with its own
width, depth and bends. Scarps have independent elevations and local snow breaks.
There is no common cliff ring or pair of carved, cleared summit-to-base lanes.
The summit blends gradually into the larger formations so there is room to
choose an approach before committing to technical terrain.

Snow covers ordinary slopes, protected hollows and suitable rock crowns. The
exposure mask supplies the same fixed material field to shading, ski contact,
tracks and powder. Steep faces and geological shoulders retain hard stone.
Snow coverage is generated with the terrain, independent of camera or quality.

Forests follow warped stands, irregular clearings, avalanche hollows and an
elevation-dependent treeline. Smaller upper trees give way to dense lower stands,
sparse margins and glades. Boulders and erratics form debris pockets below local
scarps. Source formations generate their own fallen fragments. Existing mineral
assets, underside fitting and convex collision are retained; large formations
can make bounded foundation adjustments before final seating on the snow.

Woodland interiors are planted at a jittered 6 m candidate spacing, with a
4.2 m minimum trunk spacing. Four terrain-selected woodland bodies per face
combine overlapping lobes, short winding openings and internal meadows.
Mature cores have larger trees; irregular margins thin into open snow. There
is no low-density background sprinkle across the whole mountain. Placement
uses a separate ecology random stream, so forest changes do not move landforms.
The renderer expands shared LOD bounds to fit the taller trees. V12 trees use
48 m spatial batches, with shorter detail and shadow ranges to bound the cost
of dense stands. High currently uses 12 m near geometry, 64 m mid geometry,
32 m shadows and 5 m LOD transition bands. Low/Balanced/High remain available.

The final 4 m triangles remain the sole support surface. Wind-shaped snow rolls
and 192 seeded powder deposits are baked into it. Small local visual powder
deformation remains separate. The renderer retains the same 1537 × 1537 grid,
576 chunks and quality settings. The custom 120 Hz solver is unchanged.

## Implementation and verification

- `alpine_face_v12.gd`: finite landforms, spatially indexed tributaries and ribs,
  snow retention, forest ecology and debris pockets.
- `alpine_massif_v12.gd`: parallel immutable row passes, final snow, obstacle
  placement, exposure and fingerprints.
- `mountain_geology_v12.gd`: seeded mineral distribution and final seating.
- `mountain_cache_v12.gd`: disposable default/recent bake slots, invalidated by
  source and engine hashes. Cold generation and warm cache times are distinct.

Run engine workloads sequentially through `scripts/run_guarded.ps1`, as described
in [the geology runbook](GEOLOGY_V11.md#reproduction). Existing applications remain
open. The main fixtures are:

```powershell
./godotw.ps1 --headless --script tests/alpine_v12_suite.gd '--' --repeat
./godotw.ps1 --headless --script tests/alpine_v12_descent_suite.gd '--' --all-faces
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --script tests/alpine_v12_playtest.gd '--' --views --ui-staged-loading --version=12 --benchmark-resolution=3840x2160 --benchmark-label=alpine_v12_views --graphics-quality=high --upscaler=fsr2 --render-scale=0.75 --fps-limit=30 --terrain-gi=off
./scripts/benchmark_pc.ps1 -Version 12 -Label alpine_v12_high_clear -Face 0
```

The generation suite measures actual snow/hard area, slope variety, tree and
mineral budgets, seating, neighbour continuity and deterministic cache identity.
A separate test-only downhill graph samples final support, material and obstacle
clearance, including traverses across neighbouring face boundaries. It permits
short technical stone crossings and rejects sustained hard-terrain routes.
It checks distributed reachable snow and branching connections; the
generator never reads that graph. Its polylines supply ordinary steering and
braking to the skiing fixtures, without changing terrain or applying a movement
force. A sampled graph is not proof of every opening or of human skiing feel.

Results live under `artifacts/alpine_v12` and native captures/benchmarks under
`artifacts/pc_environment`. Automated checks, rendered views, measured performance
and user skiing acceptance are reported separately in the validation record.

## Validation — 2026-09-08

### Automated generation and simulation

The revised default has **27,832 collidable trees**, concentrated in woodland
bodies. Its strongest sampled cores contain **144–220 actual trunks within
60 m**; every face has a second core with at least 139. The default and seed 0
each pass **49/49 generation checks**, including actual forest-core counts,
mineral seating, shared surface continuity, warm-cache reconstruction and two
sampled downhill alternatives on every face. The existing physics and runtime
suites passed **56/56** and **126/126** checks. No solver changes were made here.

The same 37,564 sample positions cover radii 360–2,650 m at 24 m spacing.
Snow means rock fraction below 0.42; hard means at least 0.50; the remainder is
transitional. These are horizontal sampled areas, not completed skiing lines.

| Current woodland revision | Snow | Hard | Trees | Minerals |
| --- | ---: | ---: | ---: | ---: |
| 849205174 (default) | 73.7% | 22.5% | 27,832 | 1,322 |
| 0 | 76.1% | 20.9% | 28,907 | 1,541 |

The comparable v11 default had 55.0% snow and 41.7% hard terrain. V12 keeps
technical faces while opening more of the mountain to snow. The route survey
checks branching and rejoining connections, local constrictions and at least
500 m separation between its two endpoints. It permits descending lateral
traverses and up to 30 m of continuous stone crossing. A sampled graph does not
certify every line or prove that a skier can negotiate it dynamically.

Seeds 42 and 2147483647 passed the earlier 43-check terrain suite. Their current
woodland checks remain incomplete after memory interruptions; the earlier
results must not be represented as final forest acceptance. A completed fresh
independent rebake and full-descent pilot acceptance also remain outstanding.

Current default height fingerprint:
`78ceec0c8a9aa27ac7542eac6ae9c0f6648c94faddd6ea4c87538fa27bcd4ae7`.
Current default obstacle fingerprint:
`c687a43d8038140249c8c226fab88c462dc0896f33b2cca7a285a29274b4e097`.

### Rendered woodland inspection

The initial sparse forest placement was rejected. The denser placement was
captured at skiing height and from above in
`artifacts/pc_environment/alpine_v12_woodlands`; inspected faces 0 and 1 show
overlapping canopies, substantial stands and snow openings. Those captures use
the original longer LOD ranges and demonstrate placement, not final rendering
cost. The all-face woodland captures in `alpine_v12_woodland_final` use a shorter
40 m mid-geometry range. Inspection found conspicuous flat tree impostors near
the glades, so that range was increased to 64 m in the current High settings.

The current 12/64/32 m detail/shadow configuration has **not completed native
verification**. Earlier incomplete attempts are not evidence for the current
configuration. The temporary local fixture was removed.

### Measured performance and remaining acceptance

The first dense-forest benchmark with the original renderer settings averaged
only **40.5–59.8 FPS** in forest samples. Smaller 48 m batches and shorter detail
and shadow ranges substantially reduced that cost without removing any trees.

The last **completed** 12-section benchmark is
`artifacts/pc_environment/alpine_v12_woodland_lod/terrain_timing.json`.
It uses the current woodland positions, but an intermediate High configuration
of **16/48/42 m** near/mid/shadow ranges and 10 m transitions. On RX 9070 at actual
**3840 × 2160**, High, 75% FSR2 (**2880 × 1620** internal), 120 cap and SDFGI off,
its six forest samples average **89.6–115.3 FPS**. Across all twelve samples,
frame p95 is **8.51–14.31 ms**, p99 **8.73–17.23 ms**, render CPU p95
**1.21–2.50 ms**, GPU p95 **6.07–12.20 ms**, and simulation plus animation step
p95 **655–855 µs**. All twelve four-second samples completed without a crash.
Screenshots were excluded from measurement.

That process peaked at **6.16 GiB private RAM**. Godot reported **4.68 GiB** video
memory; the system-wide GPU counter peaked at **11.17 GiB**, including other
processes. World construction from a warm cache took **53.43 s**. Source hashes
and physical fingerprints are embedded in the report. These measurements miss
the frame-time target in dense sections and do **not** validate the current
64 m mid-geometry range or a full-descent 90 FPS minimum.

The earlier `alpine_v12_final` benchmark used the rejected sparse placement;
its 105.7–120 FPS averages are historical, not current forest performance.
Final LOD appearance, all-seed woodland checks, full-descent performance,
temporal stability and human skiing/route-choice acceptance remain open.

Generation reports are `artifacts/alpine_v12/survey_<seed>.json`.
