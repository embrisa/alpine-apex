# Performance handoff - 16 September 2026

Snapshot for Fable's next experiments. Current contracts and commands remain in
[Rendering](RENDERING.md), [Development](DEVELOPMENT.md#native-skier-math) and
[Validation](VALIDATION.md#reusable-baselines-and-experiment-budget).

## Enabled in this milestone

- Native physical hip fitting, presentation pelvis fitting and joint limits;
  immutable anatomy data cached. Physical fitting saved **0.185 ms/tick** in the
  isolated paired test, with 1,800 full simulation states matching.
- Cached branch contact geometry, exact resting-spring skips and a uniform
  contact shortcut; defer invisible-tree tint work until coverage is positive.
- Bounded cosmetic snow queries, narrower collision candidate lookup with the
  same creation/retirement distances, and a 1 ms soft follow-on forest upload budget.
- Correct crown-based distance bounds read the actual packed production buffer.
  LOD0/1 render groups split once into 16 m cells; 32 m residency/shadow ownership
  and all individual tree distances, transforms and populations remain intact.
- LOD1 mesh-normal material removes normal-map sampling and tangent-frame wind
  work. Small shading changes passed matched in-game inspection at 7/12/17/32/
  59/64/69 m. It does **not** reduce the authored alpha footprint.
- Exact terrain queries now share results within one solver tick; the unused
  curvature look-ahead is removed. Production-adapter paired timing saved
  **0.190 ms/tick (17.2%)**, with 1,800 route states and two 720-tick jump/landing
  cases matching. This GDScript improvement is portable; Mac timing is untested.
- Windows skeletal tracking now batches quaternion integration, joint limits and
  grip reconstruction in the existing native module. On the matched route its
  scope fell **250.55 to 34.13 us/tick**; total animation fell **813.45 to
  584.77 us/tick**. These overlapping savings must not be added. All 19,800
  paired tracker updates and 3,787 final pose/equipment comparisons matched.
- Tree materials now draw in near/mid/far priority order before default terrain.
  No geometry, alpha footprint, placement or LOD change; scene depth prepass
  fell **3.480 to 3.203 ms (-8.0%)** in separate native profiling.
- Recommended High now makes SSAO and SSIL optional; both default on at presets
  8-10. This small shading tradeoff removes their normal/roughness depth-prepass
  prerequisite in the measured configuration. All other quality budgets stay.

## Windows measurements to reuse

### Canopy contact CPU, 16 September (current source)

Nearby-tree motion rejects disjoint swept canopy bounds and publishes only
changed contact arrays. The 120 Hz spring response is retained. With four nearby
trees and five shader receivers, paired native CPU measured **214.77 -> 148.45 us**
outside canopies (-30.9%) and **222.46 -> 183.78 us** during brushing/recovery
(-17.4%), 1,200 measured updates per arm after warmup. All 9,000 authored-family
spring comparisons and 40,320 motion/uniform comparisons matched; 221 regressions
passed. Matched instanced-tree rest/contact/recovery stills were inspected.

One clean warmed timed route measured **107.01 FPS / 9.345 ms**, GPU **7.616 ms**,
p95 **13.247 ms**, p99 **15.820 ms**, at the same 4K High/Auto75%/FG-off settings.
This is inside the Dev63 reference's 101.34-109.22 FPS range: retain the verified
CPU saving, with no meaningful route-FPS gain established and no extra control
run. Physical cache hit; scenery rebuilt before warmup, so no startup comparison.
Latest compatible trace: `artifacts/canopy_idle_20260916/forest.json` (same 1,800
inputs/camera, all 15 checkpoints matched). The first stale-trace attempt stopped
before loading. Evidence: `artifacts/canopy_idle_20260916/summary.json`, paired
source/review files, and `artifacts/pc_environment/canopy-idle-current-20260916/`.
[Rendering](RENDERING.md) owns the canopy bounds/publication contract.

### Reuse displayed ghost rigs, 16 September (Dev63 timed reference)

Routine 20 Hz ghost records now reuse a recent displayed local rig at the current
recorded root. The live rider stays unchanged; ghost limbs may lag by up to 25 ms.
Stale/invalid poses, support/facing changes and explicit race boundaries get fresh
solves. Boots/grips remained connected in seven-action rendered checks; fast pole
motion showed the largest phase difference. The user accepted coarser ghost motion.
2,158 review checks and 722 regressions passed. Human continuous motion review
remains separate. [Animation](ANIMATION.md#recorded-ghost-presentation) owns the contract.

Separate route profiling reduced ghost-capture mean **1.077 -> 0.452 ms/sample**
(-58.0%, 300 samples); pose-hierarchy calls fell from one per frame plus captures
to one per frame plus the initial pose. The implied saving is about 12.5 ms CPU
per second at 20 Hz, not per rendered frame. The first clean candidate was only
**101.34 FPS / 9.867 ms** versus the saved 109.81 average. One same-process check
therefore forced fresh poses for the control: **107.42 -> 109.22 FPS (+1.7%)**,
**9.309 -> 9.156 ms**, GPU **7.599 -> 7.536 ms**; p95 **12.908 -> 12.509 ms**,
p99 **15.190 -> 15.356 ms**. Both used the same 4K High/Auto75%/FG-off scene,
ordinary input, focus and 20 Hz recording. Cache invalidation adds one trivial
assignment per physics tick to the control. No further timing matrix was run.

Keep this verified CPU saving under the user's small-gain policy; the pair does
not establish a sustained FPS gain or improved p99. Preserve both valid clean
candidate samples (101.34 and 109.22 FPS), not only the faster one. The provisional
current-source reference and its wide range are in
`artifacts/ghost_pose_reuse_20260916/reusable_timed_baseline.json`; small deltas
inside that range are inconclusive. The Dev61 mean below is historical now.
Trace regeneration after Fable's body-cache merge matched 1,800 paired simulation
states and all 15 prior checkpoints, with unchanged inputs/camera. New compatible
trace: `artifacts/ghost_pose_reuse_20260916/forest.json`. Compact review/receipts:
`artifacts/ghost_pose_reuse_20260916/` and the `ghost-pose-reuse-{current,pair}`
folders under `artifacts/pc_environment/`. The initial stale-trace attempt stopped
before loading; its timings are not acceptance evidence.

### Ghost recording cadence, 16 September (Dev61 historical reference)

Routine completed-pose recording now runs at 20 Hz; 120 Hz inputs, the live rider,
exact race clock and explicit finish/crash/recovery boundaries retain their owners.
The user accepted coarser ghost motion. Seven compact action reviews passed with
connected boots/grips; fast pole tips differed most (up to 33 cm between samples).
676 timeline/codec/comparison checks and 535 physics/runtime/archive/retry/clock/
crash checks passed. This is author visual review, not human motion acceptance.

The initial clean candidate measured **109.03 FPS / 9.171 ms**, but the older
92.64 FPS average overstated the attributable gain. One same-process frozen
30 Hz control and 20 Hz confirmation measured **104.24 -> 110.60 FPS (+6.1%)**,
**9.594 -> 9.041 ms**, GPU **7.752 -> 7.480 ms**, p95 **13.985 -> 12.295 ms**,
p99 **16.399 -> 14.406 ms**. Both reproduced the route with zero unfocused frames;
4K High, Auto 75% FSR 4.1.1, FG off, density, camera and physics stayed matched.
Recording fell from 451 to 301 stored poses including the initial endpoint.
Separate profiling counted 300 routine captures at 1.077 ms each: removing ten
per second avoids about 10.8 ms CPU work per second at that measured call cost.
That scope estimate is not a 10.8 ms saving per rendered frame.

Reuse the two clean candidate samples: **109.81 FPS / 9.106 ms**, GPU 7.561 ms,
median-of-run p95 12.594 / p99 14.941 ms; individual FPS 109.03-110.60.
`artifacts/ghost_cadence_20260916/reusable_timed_baseline.json` supersedes the
Dev56 timed reference for subsequent matching candidates. Raw receipts are
`artifacts/pc_environment/ghost-cadence-{timed,pair}-20260916/`.
The p95 target and sustained full-route 90-120 FPS remain unproven.

### Forest batch settings, 16 September

Batch setup now publishes final culling/shadow values once. In the paired native
324-tree / 27-region fixture, configuration/publication CPU fell **404.92 to
356.81 us per region (-11.9%)**; complete region-loading updates totalled
**44.50 to 42.13 ms (-5.3%)** across 27 regions, not per frame. Four alternating
warmed samples per arm; one initial pair excluded. This retains a small CPU
saving without a new mountain FPS claim or baseline run. MultiMesh allocation
remains the largest measured construction section, about 14 us per batch.
Paired final properties/uniforms matched; 3,845 native lifecycle checks and
639 headless LOD/spatial/graphics/runtime checks passed. Matched mixed-map stills
at two camera positions showed no added culling gaps. Evidence and frozen
original: `artifacts/forest_nodes_20260916/`. Mac timing and human motion review
remain untested; the broader streaming-burst task remains open.

### Equipment audio pair cache, 16 September

Audio-only ski/pole contact detection caches cross-owner pair indices between
validated resets and tests live swept bounds before reading pair dictionaries.
In regular/carve/grab production-pose sequences, paired observer CPU averaged
**124.91 -> 108.07 us/update (-13.5%, 16.84 us saved)**. Individual means were
102.16 -> 84.73, 167.96 -> 152.53 and 104.61 -> 86.95 us; 294 measured samples
per arm/case, alternating order. This excludes pose construction and snapshots.
All 1,500 event/state comparisons match the frozen original, including 10 actual
contact events and ownership/rearm/lifecycle cases. Equipment audio, SFX and
runtime suites passed 44 + 39 + 192 checks. No visuals, audio synthesis, physical
collision, replay or settings changed; human listening was not repeated.

No new mountain FPS claim or baseline: the saving is below the existing route's
variation and is retained under the user's policy to keep verified small gains.
Evidence: `artifacts/equipment_pairs_20260916/oracle.json` and `regression/`.
The initial diagnostic in `artifacts/effects_cost_20260916/probe.json` guided
selection; its compact-plane response costs do not attribute the full mountain's
entire effects scope. Initial oracle attempt emitted no sounds because its
synthetic surface changed each frame; that test stimulus was corrected before
acceptance, with production code unchanged.

### Grass worker packing, 16 September

Grass workers now prepare the shared instance buffer and both LOD bounds.
The main thread still owns render resources/publication. Population, placement,
materials, 18-26 m blend, draw distances and three-cell budget are unchanged.
On 36 forest-habitat cells (2,187 tufts), 360 alternating native publications per
arm measured **376.31 -> 77.85 us/cell (-79.3%)** on the main thread. Packing
alone averaged 244.39 us/cell off-thread; this is a scope transfer, not a 79%
reduction in total CPU work or frame time.

One warmed, capture/profile-free timed route measured **93.13 FPS / 10.738 ms**,
GPU **8.483 ms**, p95 **14.430 ms**, p99 **16.658 ms**. The saved Dev56 average
is 92.64 FPS / 10.798 ms, GPU 8.485 ms, p95 14.539 / p99 17.264 ms;
its individual FPS range is 90.99-94.29. No meaningful FPS/tail gain is established.
The physical cache hit; scenery rebuilt during startup before warmup. This is
a comparison limitation, not a matching cached-startup measurement. No repeat
control or cache-only confirmation was run: retain the verified publication
saving, and do not replace the reusable timed reference with this observation.

A separate third traversal measured `stream_grass` mean **50.33 us**, p99
**1,488 us**, max **2,869 us**. The older `recording-direct-fields-20260916`
diagnostic was 84.44 / 2,405 / 3,639 us, but intervening rendering changes and
different frame counts preclude treating that as an isolated paired saving.
Worker preparation now includes packing and must not be compared as though its
scope were unchanged. Clean route: zero unfocused frames, exact 1,800 ticks /
451 poses, identical recording channels, settings/camera and 8,778 -> 8,081
ground tufts plus 496 mineral tufts. No screenshot/profiling overhead in row 2.

Evidence: `artifacts/grass_pack_20260916/` (paired CPU, visual sheet, regressions)
and `artifacts/pc_environment/grass-pack-timed-20260916/` (row 1 warmup,
row 2 clean, row 3 CPU diagnostic). Native grass suite: 89 checks; headless
grass and runtime suites: 86 and 192 checks. Matched mixed-map close, 18/22/26 m
and cell-boundary stills inspected; full descent/human acceptance remains open.
The broader gravel/texture-streaming task remains partly unimplemented.

### Earlier successive samples

RX 9070, Godot 4.7.2 custom ed1daf0bf, D3D12, 3840x2160 output, 2880x1620 internal,
High, Auto FSR 4.1.1, frame generation/GI off, clear/day, same 1,800-input dense
forest route. One warmup followed by one capture-free 15-second measured sample
per candidate; zero unfocused frames and exact trace completion.

| Successive free-ski samples | Average FPS | Frame ms | Viewport GPU ms | Frame p99 ms |
| --- | ---: | ---: | ---: | ---: |
| Corrected bounds, 32 m detail groups | 78.23 | 12.783 | 11.216 | 18.171 |
| Static 16 m detail groups | 79.26 | 12.617 | 11.050 | 17.207 |
| Plus LOD1 mesh normals | 84.07 | 11.895 | 10.280 | 17.585 |
| Plus exact tick query reuse | 87.67 | 11.407 | 10.171 | 15.133 |
| Plus native skeletal tracking | 88.29 | 11.326 | 10.246 | 15.894 |
| Plus forest material ordering | 91.06 | 10.982 | 9.943 | 15.128 |
| Plus smaller powder mesh (two-run reference) | 92.28 | 10.837 | 9.588 | 16.192 |
| Plus High screen-space lighting tradeoff | **113.94** | **8.776** | **7.500** | **14.294** |

The LOD1 material change gained 4.81 FPS (6.1%) and saved 0.722 ms/frame / 0.770 ms GPU
in these samples. The p99 increased 0.378 ms. These are short samples, not a
repeatability study, full-descent acceptance or a 90-120 FPS result. Viewport
timings do not isolate tree depth draws. Never add CPU microbenchmark savings
to these frame savings as though they were independently measured gains.

Tick query reuse then reached **87.67 FPS / 11.407 ms** against 84.07 FPS /
11.895 ms: +3.60 FPS (4.3%), -0.489 ms/frame. p95 was 14.091 ms and p99
15.133 ms. Both physical and scenery caches hit; exact 1,800 ticks, zero
unfocused frames, no captures or profiling, same effective settings/camera.
An initial 88.50 FPS candidate rebuilt scenery during startup; it remains a
secondary observation, not the new matching reference. One candidate-only
confirmation resolved that cache difference. The original was not rerun.

Native tracking then measured **88.29 FPS / 11.326 ms**, +0.62 FPS (0.7%) and
-0.081 ms/frame. p95 was 13.786 ms and p99 15.894 ms (+0.761 ms). This single
sample does not prove an FPS gain or improved tails. It is retained for the
**0.216 ms/tick** CPU saving under the small-gain policy. Both caches hit, settings
and camera matched, 1,800 ticks matched and no frames lost focus. A separate
third traversal measured CPU scopes; it is not pooled with the clean FPS sample.
The earlier scope diagnostic is `remaining-cpu-20260916`, row 2, and the candidate
is `native-tracking-20260916`, row 3, under `artifacts/pc_environment/`.

Material ordering then reached **91.06 FPS / 10.982 ms**, +2.77 FPS (3.14%) and
-0.344 ms/frame, using the saved 88.29 FPS control. p95 improved to 13.395 ms
and p99 to 15.128 ms. Settings, camera, caches and exact trace matched. Seven
matched 7/12/17/32/59/64/69 m mountain views passed inspection, as did 361 render
efficiency checks. Separate native profiles show depth **3.480 -> 3.203 ms**,
opaque **2.129 -> 2.132 ms**. These are whole-scene intervals, not isolated LOD1
or fragment-count attribution. The short-route average crosses 90 FPS, but
p95 remains above 11.1 ms: sustained 90-120 FPS is still unproven.

Per-route actual normal evaluations fell 38,874 to 14,899 and snow-depth
evaluations 25,366 to 12,622. Only raw terrain queries are cached; dynamic crush
and contact state remain live. See [the ownership contract](PHYSICS.md#ownership-and-tuning).

Local detailed receipts (ignored, not transferred by Git) are under
`artifacts/pc_environment/{retained-cpu-correct-bounds,static-detail-batches,lod1-mesh-normals}-20260916/production.json`, row 2.
The first row is warmup. The replay is
`artifacts/retained_cpu_correct_bounds_20260916/forest.json`.
The exact-query receipt is
`artifacts/pc_environment/solver-query-confirm-20260916/production.json`, row 2;
its regenerated, unchanged input route is
`artifacts/solver_queries_20260916/forest.json`.
The native-tracking clean receipt is
`artifacts/pc_environment/native-tracking-20260916/production.json`, row 2.
The pre-powder clean reference is `artifacts/pc_environment/forest-order-20260916/production.json`,
row 2, using that same trace. Native profile summaries are under
`artifacts/pc_environment/{current-gpu,forest-order-gpu}-20260916/summary.json`.
Compact evidence is `artifacts/native_tracking_20260916/` and
`artifacts/forest_draw_order_20260916/`.

**Baseline correction:** earlier 81.99-89.18 FPS candidates used faulty distance
bounds: production groups had empty `transforms`, while poses were in
`prepared.buffer`. Those results do not establish preserved-quality performance.
The historical 71.94 FPS reference is an older engine/import context and remains
historical context, not an exact attribution baseline for this milestone.

## Powder mesh refinement and pre-lighting reference

The local 32 m snow mesh now uses 256 subdivisions: **524,288 -> 131,072
triangles (-75%)**. Texture resolutions, visible relief shader, shadows, track
budgets, recenter mapping and simulation are unchanged. Production rough-snow
captures passed for chase, low-angle, first-person and adjacent recenter frames;
269 support/response/runtime/native-upload checks passed.

Saved-reference comparisons gave 92.38 and 91.31 FPS versus 91.06, with
GPU savings of 0.397 and 0.353 ms, but worse p99. One same-process old/new
mesh comparison specifically checked that regression: **90.74 -> 93.26 FPS**,
**11.021 -> 10.723 ms**, GPU **9.931 -> 9.585 ms**. P95 improved 13.398 -> 13.147;
p99 was nearly equal, 15.025 -> 15.078 ms. Maximum frame time still grew
18.439 -> 23.316 ms. Keep the consistent GPU saving; do not claim improved
hitches or sustained 90-120 FPS. No isolated powder/depth-pass attribution.

The saved average of the two cache-hit clean candidates is **92.28 FPS /
10.837 ms**, GPU **9.588 ms**. Median run p95/p99: **13.375/16.192 ms**.
This combines `powder-mesh-confirm-20260916` row 2 and
`powder-mesh-tail-pair-20260916` row 3 under `artifacts/pc_environment/`;
row 1 is warmup, and row 2 of the pair is the old mesh. The initial
`powder-mesh-20260916` row 2 rebuilt scenery during startup and is supplemental.
All samples match effective settings/camera and 1,800 final-state ticks,
with zero unfocused frames.
Both reference candidates hit physical/scenery caches. Detailed compact evidence
and the aggregation definition: `artifacts/powder_mesh_20260916/`.
Earlier 91.06 FPS and timed 82.72 FPS receipts describe the previous 512 mesh.
The timed sample below includes 256; Mac and human review remain open.

## Screen-space lighting and current references

SSAO/SSIL already used half-size medium-quality buffers. Their larger hidden
cost was Godot's shared normal/roughness depth prepass. With both off, the
same-process native scene interval fell **3.098 -> 1.739 ms (-43.9%)**; opaque
fell **2.149 -> 2.055 ms**. SSAO/SSIL themselves accounted for **0.496 ms**.
These are whole-scene pass timings, not isolated LOD1 or fragment counts.
Other normal-reading features can also require this prepass.

One capture-free warmed free-ski candidate measured **113.94 FPS / 8.776 ms**,
GPU **7.500 ms**, versus the saved 92.28 / 10.837 / 9.588 reference: **+23.5%
FPS, -2.061 ms/frame**. P95/p99: **11.652/14.294 ms**. Both caches hit;
resolution, camera, forest population and exact 1,800-tick route matched.
Only the two lighting flags changed. Keep this as the new free-ski reference,
`artifacts/pc_environment/depth-lighting-20260916/production.json` row 2.
Native profile summary: `depth-lighting-gpu-20260916/summary.json` in the same
parent; its diagnostic FPS is excluded from clean measurements.

The delivered defaults also measured **96.68 FPS / 10.344 ms** with timed-race
recording active, versus saved **82.72 / 12.089**; GPU **9.939 -> 8.164 ms**,
p95 **15.634 -> 14.212**, p99 **18.520 -> 16.284 ms**. This comparison includes
both powder 512->256 and the lighting tradeoff. All recorded channels matched:
1,800 ticks and 451 poses, with zero unfocused frames. Startup rebuilt scenery
before the warmup; the measured row has the same forest counters and no pending
regions. Reuse `depth-lighting-timed-20260916/production.json` row 2 as the new
timed reference, and keep it separate from free skiing.

Matched mountain views at 7/32/64 m and compact mixed clear/cloudy/rock views
passed agent inspection: slightly less contact darkening/indirect fill, with
direct shadows, snow relief and layered forest retained. An invalid weather
identifier and an occluded initial rock view were excluded and replaced with
valid targeted views. The change defaults both effects off at presets 1-7 and
on at 8-10; explicit saved overrides still win. **842 automated checks passed**,
including live setting consumers. A stale graphics assertion was corrected to
count current catalog families instead of legacy obstacle names.

Compact evidence: `artifacts/depth_lighting_20260916/`. Neither sample meets
the p95 target of 11.1 ms. Sustained 90-120 FPS, full descent, human/controller
review and Mac performance remain unproven. The timed/free-ski gap is still a
useful lead for CPU/session work; it is not isolated recording-cost attribution.

## Earlier timed recording investigation

The historical 91.06 FPS reference is free skiing with the 512 powder mesh.
A timed-recording diagnostic on the same route produced **82.65 FPS / 12.099 ms**.
Timed HUD/session/audio paths also differ, so this is not an isolated capture-toggle FPS attribution.
`ghost_capture` costs **1.208 ms per 30 Hz sample**, including another completed
pose solve; the regular rendered pose is about **0.846 ms per solve**.

Direct typed access to the three recorded pole fields removes repeated property
introspection. Replay-recording CPU fell **54.35 -> 48.35 us per 120 Hz tick**;
paired isolated snapshot construction fell **31.19 -> 24.45 us**. Timed FPS was
**82.65 -> 82.72**, effectively unchanged; frame p95/p99 were 15.634/18.520 ms.
Retained for the small verified CPU saving. Do not attribute GPU/tail variation
to this two-line change. Broader buffer rewrites were rejected: small snapshot
savings and slower pose serialization did not justify their complexity.

All three paired 1,800-tick recordings match exactly, including all 451 pose
samples, physical samples, inputs and timestamps. A compact five-action oracle
also passed 2,260 byte-equivalence checks. The pre-powder/lighting timed reference is
`artifacts/pc_environment/recording-direct-fields-20260916/production.json` row 2;
row 1 is warmup and row 3 is CPU attribution, not clean FPS. Control is
`recording-control-20260916` in the same parent directory. Keep this workload
separate from free skiing. Compact findings: `artifacts/recording_capture_20260916/`.
The larger open target is the extra completed pose solve, with the recorded
sample timestamps and final contact footprint retained.
Physics, runtime, race, archive, retry-cache, exact-clock, crash-replay and input-
recording suites passed (598 checks). `competitive_suite` has two failures in
both the original and candidate: resume clock alignment and the new-PB message.
Those existing lifecycle findings remain unresolved; that suite is not green.

## Native final knee search: CPU saving, no measured FPS gain

The existing native skier module now executes the final ten-iteration knee
search for each leg. Limits, numerical search order, equipment attachment,
120 Hz simulation and 30 Hz recording are unchanged. This serves visible and
recorded poses; it does not reuse a pose from a different timestamp.

An alternating-order isolated comparison over five production action states
and 6,000 solves per implementation measured complete pose **725.24 -> 615.36
us (-15.2%)**, including leg fitting **153.04 -> 44.13 us**. Do not add these
overlapping savings. Four thousand native/reference knee cases and 3,787 final
pose/equipment snapshots matched exactly. Matched action stills were inspected.

The first clean timed route regressed against the saved 96.68 FPS reference:
**90.99 FPS / 10.990 ms**, GPU 8.631 ms. One same-process old/new pair checked
that finding: **94.23 -> 94.29 FPS**, **10.612 -> 10.606 ms**, GPU **8.370 ->
8.339 ms**. This is **no meaningful FPS gain**. P95 worsened **14.255 -> 14.434**,
p99 **16.743 -> 17.091 ms**. The large first-sample regression did not repeat;
its cause is unresolved. Retain the verified CPU saving under the small-gain
policy, without claiming improved frame rate or tails.

All physical/input/pose/time channels of the three clean recordings match the
retained Dev54 recording exactly (1,800 ticks, 451 poses). Both new processes
hit both caches; camera, quality, resolution, population and focus matched.
The pair disables profiling on every trial. Windows only; portable reference
remains active on Mac. Anatomy, attachment, poles, physics and runtime checks
cover the rebuilt shared library; older unrelated procedural-suite failures
listed below remain unresolved.

For subsequent timed candidates, reuse the two native candidate samples rather
than repeating the control: **92.64 FPS / 10.798 ms**, GPU **8.485 ms**; median
run p95/p99 **14.539/17.264 ms**. This includes both 90.99 and 94.29 FPS samples,
not just the faster one, and supersedes the single Dev54 timed reference above.
The 113.94 FPS free-ski reference predates this CPU change; free skiing was not
remeasured. Sources: `artifacts/pc_environment/render-knee-timed-20260916/production.json`
row 2 and `render-knee-pair-20260916/production.json` row 3. Pair row 2 is the
script control; row 1 is warmup. Compact receipts and aggregation:
`artifacts/render_knee_20260916/`. Sustained target and human/Mac acceptance remain open.

## Mac baseline (Fable, 16 September 2026)

Apple M4 MacBook, stock Godot 4.7.2 Metal, fullscreen 3600x2260 backing pixels,
standard mountain, fixed full-tuck input from the summit, 240 warm-up frames then
25 measured seconds per configuration. Full rows, scopes and limitations are in
[MAC_PERFORMANCE_BASELINE.json](MAC_PERFORMANCE_BASELINE.json).

| Configuration (High unless noted) | Frame ms mean | p95 | p99 | FPS |
| --- | ---: | ---: | ---: | ---: |
| Auto = FSR 2, 0.75 internal | 40.0 | 42.7 | 45.5 | 25.0 |
| Bilinear, 0.75 internal | 24.7 | 26.5 | 27.7 | 40.5 |
| Bilinear, 0.50 internal | 18.6 | 20.5 | 20.9 | 53.7 |
| Native 1.0 (no upscale pass) | 35.9 | 39.1 | 41.6 | 27.9 |
| Low preset, FSR 2, 0.75 | 28.9 | 31.3 | 32.1 | 34.7 |
| Branch Auto on Metal: bilinear 0.75 + MSAA 2x (production path) | 27.6 | 30.2 | 30.8 | 36.3 |
| Branch explicit FSR 2, 0.75 (same code) | 39.1 | 42.0 | 45.4 | 25.6 |

These single-run comparisons identify reconstruction as a large Mac cost:
the same-code Auto/bilinear + MSAA 2x configuration saves 11.5 ms against explicit
FSR 2 (39.1 to 27.6 ms, 25.6 to 36.3 FPS). This trades temporal reconstruction
for spatial scaling; it is not an isolated GPU pass measurement. Scripted CPU is
5.5-6 ms per frame at 25 FPS (simulation about 2.5, animation tick 1.4, pose 0.5)
and render CPU p95 1.2 ms, suggesting substantial GPU or presentation cost remains.
Single feature toggles from the
38.5 ms FSR 2 reference: sun shafts -2.0 ms, glow -2.5, local powder patch -3.0,
shadows 60 m/filter 0 -0.8, minimum tree distances 0.0 (fewer draws, no time
change); everything minimised plus weather 0 gives -7.5 ms. Metal exposes no
viewport GPU timer, so these are configuration deltas. `ViewportTexture.get_size()`
on the root reports the window size times the canvas stretch ratio; forcing the
content scale size to the window size did not change frame time, so the 6480x4067
figure is not real 3D pixels. Branch `fable/mac-spatial-upscaler` makes Auto
resolve to bilinear on Metal and lowers the internal resolution floor to 50
percent; Windows Auto behaviour is unchanged.

Main integration adds a frame-generation compatibility fix: bilinear stays
spatial when generation was requested, retaining that preference for compatible
modes. The Windows custom DX12 engine passed 389 focused regression checks and
22 native settings assertions, including Auto FSR 4.1.1, bilinear/MSAA and the
generation conflict. The matched 1280x720 mixed-map stills show the expected
softer, more jagged spatial result without a composition change. They are
functional Windows evidence, not Mac image-quality or FPS acceptance; the Mac
performance figures above are Fable's measurements. Mac motion/human review and
sustained target performance remain open. Compact integration evidence:
`artifacts/mac_merge_20260916/`. Benchmark wrappers now accept `bilinear`.

## Mac and next experiments

Grass worker crash investigation (Fable, 2026-09-16): one macOS probe launch out
of about fifty crashed right after the scene became ready, printing the
`propagate_notification()` thread guard error for `/root` with a GDScript
backtrace inside a grass `CellWork.run` (`stand_density`), then signal 11 with
a deeply recursive `propagate_notification` stack. No project code calls
node methods, signals or tree propagators from workers (`grass_placement.gd`,
`alpine_massif_v15.gd`, `alpine_face_v15.gd`, `mineral_collision.gd` are pure
reads; the MCP Logger only touches a mutex-guarded buffer). `tests/grass_worker_stress.gd`
(156,000 cells, 400 s, blocking waits, concurrent main-thread queries) and eight
targeted relaunches did not reproduce it. Godot 4.7.x has upstream reports of the
same guard error and crash from non-main threads (godot#123152 on Wayland, a
4.7.1 import-worker crash), so this is treated as an engine-side race. If it
recurs, retain the log and the exact launch conditions; a project-side
mitigation would be to defer grass and gravel worker streaming until display
setup has settled after startup.

Fable's Apple Silicon branch is now integrated: macOS arm64 loads the packaged
native hip/pelvis/knee/tracking kernels. Windows keeps its existing DLL; Intel
Macs and other platforms retain the script reference. Immutable body names,
offsets and limb lengths are cached on both paths. No solver cadence/model change.

Mac frame-floor attribution (Fable, `tests/mac_frame_probe.gd` via
`scripts/mac_frame_probe.sh`, Auto = bilinear 0.75 + MSAA 2x, 20 s runs, noise
about +/-1.5 ms): reference 26.3-27.5 ms. The local powder patch is the only
robust single-feature cost: deformation off -4.0 ms twice, patch draw hidden
-5.0 ms; its atlas compute costs nothing, trimming 17 percent of its triangles
or its shadow pass nothing, 128 subdivisions -1.6 ms and 64 -2.5 ms, so the
tile-based GPU pays for micro-triangles and the rest is fill. Glow and shafts
read -2 ms alone but 0 together; MSAA, cloud shadows, weather, snow detail,
normals, shadows and the backdrop are inside noise. Delivered on branch
`fable/mac-metal-frame-floor`: Metal uses 128 powder subdivisions, the powder
mesh omits quads outside the handover disc (exact), and fully faded ski-track
fragments discard early. Rows: [MAC_PERFORMANCE_BASELINE.json](MAC_PERFORMANCE_BASELINE.json)
`frame_floor_matrix_20260916`. One probe run crashed in the new grass worker
path (`stand_density` reached from `terrain_grass.gd` `run` with a
`propagate_notification` cross-thread error, then signal 11); log retained
locally under `artifacts/mac_floor_20260916/`.

HUD frame cost (Fable, task `084504`, delivered on `main` 2026-09-16): the
`hud` scope on the M4 MacBook fell from 147 us mean / 212 us p95
riding and 146 us in the pause menu to 44 / 69 us riding
and 36 us in the menu (`scripts/mac_frame_probe.sh`, 20 s runs, new
`--probe-menu` option). Gains come from skipping formatting behind menus,
change-gated readouts and theme overrides, a retained widget layout, cached
menu-background state, once-per-frame footer/mode text, memoised prompts, a
sleeping menu-navigation scope scan and an exact travel bound for flavor
discovery. Windows numbers were not re-measured; the same GDScript work is
removed there. The Windows-only `interface_performance_suite` still owns the
`ui_settings_*` rows and should be rerun when a Windows host is available.

Presentation terrain probing (Fable, task `084508`, delivered on `main`
2026-09-16): height-only presentation reads (camera boom/clearance/slope,
spray tails, track stamps, animation clearance joints, weather drifts, voice
survey) now call the exact allocation-free `sample_height` when the surface
offers it, spray uniforms and the equipment mode string are change-gated,
track stamps and GPU stroke buffers stop allocating, and `WeatherState.blend`
uses typed assignments. Mac scope means (us): `camera` 73 -> 68, `effects` 276 -> 254, `snow_tracks_powder` 171 -> 148, `weather_world` 180 -> 165, `audio_observers` 23 -> 22. New sub-scopes
`powder_surface` (inside `snow_tracks_powder`) and `sfx_advance` (inside
`effects`) attribute the remaining cost; equipment contacts are about 12 us
per frame and the powder patch about 88 us, which belongs to task `084507`.
The `dt > .10` equipment reset was kept because `equipment_audio_suite`
asserts long frame gaps re-prime without false hits.

Fable reported 3,000 exact random physical hip fits; extreme presentation pelvis
poses differed by at most 1.04 mm, knee by 2.4e-7 m and tracking quaternion distance
by 9.7e-7. Its 6,000-tick minimum-pass solver observations were 333-346 us/tick
for the hoisted reference and about 302 us/tick with native fitting. Only the
sampled position/velocity/heading/support channels were compared over that route;
this is not an all-state equivalence proof. The claimed 2-4% hoist saving is near
the laptop's noise floor. Separate Mac profiling showed tracking 74 -> 24 us/tick,
animation 315 -> 246 us/tick and render pose 430 -> 361 us/frame; these scopes
overlap. That profile remained GPU-bound near 25 FPS under its older FSR 2 setup,
so it does not establish an FPS gain or replace the spatial-upscaler baseline.

Windows integration passed 2,160 paired tick comparisons of physical snapshots
and every body script property across regular/carve/jump-grab cases, with no
crashes. The compact paired solver averaged **414.65 -> 396.46 us/tick (-4.4%)**,
1,800 timed ticks per arm after warmup, alternating execution order. This retains
about 18.2 us/tick of CPU work; no new mountain FPS claim. Required physics/runtime
and platform/native fitting/tracking/knee checks passed (530,189 assertions).
The merge retains both Metal-upscaler and native-library startup checks. Evidence:
`artifacts/fable_native_20260916/`; Fable's Mac evidence remains in its committed
note `changes/ee06e19415194b008906239c53dcfa41.json`.
StringName capability literals, cached adapter capability flags and a byte-table
rock lookup were rejected by Fable as noise-floor results; do not repeat unchanged.

Keep the native port's CPU savings while investigating remaining Metal intervals.
User motion review, packaged exports and sustained target performance remain open.
Use one focused candidate and a short warmed run; reuse matching baselines and
skip manual hash audits and large capture archives.

Do not repeat unchanged rejected approaches: broad UV packing, per-frame CPU
tree compaction, LOD1 alpha trapezoid trimming, small-angle wind polynomial, or
blindly replacing trees based on source triangle count. Terrain occlusion's
roughly 5% figure was fewer draws, not a measured FPS gain; it remains disabled.
Static 8 m forest groups also failed: 88.29 -> 87.00 FPS, despite 3.45% fewer
submitted primitives. Render CPU grew 0.171 ms while GPU saved only 0.096 ms;
16 m groups were restored. Compact evidence: `artifacts/tighter_forest_batches_20260916/`.

Precomputed per-instance crown centre/radius also failed: **91.06 -> 89.40 FPS**
(frame 10.982 -> 11.186 ms), with only 0.020 ms less GPU time and 10.47 MiB
more prepared data. Seven matched near/mid/far views passed, but the clean route
showed no useful gain; all four runtime changes were restored. No additional
GPU-pass run was warranted. Keep the existing matrix-based crown calculation.
The preparation regression now compares actual placements across subdivided
detail and regional shadow batches instead of assuming three nodes per region.
Compact evidence: `artifacts/prepared_crowns_20260916/`.

Earlier terrain LOD selection (`lod_bias=0.25`, existing indices) also failed
the dense route: **91.06 -> 90.68 FPS**, GPU 9.943 -> 9.923 ms, with 1.74%
fewer primitives. World source restored. Open-snow stills and native wireframe
were reviewed; two foliage-obscured views were inadequate for ridge acceptance.
Open-route timing remains untested. Evidence: `artifacts/terrain_lod_20260916/`.

Tracker equality, matched rendered poses, anatomy/attachment/pole checks and
physics/runtime checks passed on Windows. Four older procedural assertions
(one in `skier_motion_suite`, three in `skier_animation_suite`) failed identically
with original and native tracking, including identical animation metrics. Those
remain unresolved existing findings; those two suites are not claimed as passing.
The Mac integration evidence is recorded above; packaged export and
human/controller feel remain unverified.

## Fable task overlap review

Reviewed remote commit `a75212c`. Its title says five tasks, but it adds only
four task files. The linked `AA-20260916-084514-reduce-vertex-shader-transcendentals`
file is absent from that commit and its tree.

| Task suffix | What has already been tried | Remaining investigation |
| --- | --- | --- |
| `084500-reduce-solver-terrain-query-redundancy` | Native hip fitting, allocation-free heights, exact tick-local query reuse and removal of unread curvature probes are enabled. The bounded snow shortcut remains cosmetic only. | Capability checks, material-map storage and other proposed allocations/sweeps remain untested. This task is only partly implemented. |
| `084501-index-skier-pose-by-bone` | Rest geometry caching, native pelvis fitting and limits are enabled. Native tracking now caches immutable bone offsets/ancestry and batches the costly tick loop. | Broad pose-container conversion, mirror indices, reusable sampling buffers and fewer skeleton writes remain untested. Current writer cost is only 42 us/frame; pose is about 0.86 ms/frame. |
| `084502-reduce-recording-tick-cost` | Direct typed snapshot field access saves about 6 us/tick; all recorded channels remain exact. Broad buffer rewrites were rejected. | Routine capture now runs at 20 Hz, saving one third of completed-pose evaluations with accepted coarser ghost motion; see the current timed reference above. Further per-capture work remains open. |
| `084503-publish-shared-shader-uniforms-globally` | Cloud parameter/direction/height change gates and wind direction/strength gates already exist. Tree contact shader work now skips exact rest. | Global publication and remaining write reduction are untested. Preserve separate world/preview state and pause behavior; receiver count estimates are not measured savings. |
| `084504-reduce-hud-frame-cost` | Delivered on `main` 2026-09-16: hidden-instrument early return, retained widget layout, change-gated readouts/theme override/crash card, cached menu-background state, once-per-frame footer/mode text, memoised prompts, sleeping navigation scope scan, exact flavor discovery bound. Mac `hud` scope about 147 -> 44 us riding and 146 -> 36 us in menus. | Windows `interface_performance_suite` rerun; `node_added` popup tracking kept deliberately. |
| `084508-reduce-presentation-terrain-probing` | Delivered on `main` 2026-09-16: exact `sample_height` for height-only presentation reads, change-gated spray uniforms and equipment mode string, allocation-free track stamps/stroke buffers, typed weather blend. Mac `camera` 73 -> 68, `effects` 276 -> 254, `snow_tracks_powder` 171 -> 148, `weather_world` 180 -> 165, `audio_observers` 23 -> 22. | Windows scope re-measure; `dt > .10` equipment reset kept (suite contract); powder patch cost belongs to `084507`. |
| `084512-bound-physics-catch-up-steps` | Measured 2026-09-16 with injected 100 ms stalls (`mac_frame_probe --probe-stall`): caps of 8 and 6 spread the same recovery over two frames, raise p99 33 -> 46 ms and drop 4-6 ticks of clock per stall; 24 kept. | None; closed. |
| `084511-reduce-finish-crash-restart-hitches` | Measured 2026-09-16 (`tests/session_stall_probe.gd`, 150 s run): finish save 17 ms (SHA-256 dominated), crash placement 0.3-3.7 ms, retry roster 20 -> 9 ms cached and 1384 -> 1028 ms cold after parallel payload verification in `Records.selected`. | Finish save stays synchronous (contract); cold decode is GDScript-bound and belongs to the cold archive task. |
| `084514-reduce-menu-and-loading-interface-hitches` | Delivered on `main` 2026-09-16: button pulse on a modulated overlay with cached badge styles and a focus-stable reserve, debounced slider preference writes (volume step 150 -> 5 us headless), single-assignment panel text, 10 Hz loading snapshots, change-gated navigation overlay redraws; `tests/interface_cost_probe.gd` measures the menu paths. | Windows interface_performance_suite rerun; HUD editor freeze image left at full resolution. |

All four were written against Dev 43 and older scope measurements. Use the
enabled implementation and current matching reference, not their old 72 FPS
number as an exact control. Their strict pixel/physics acceptance language must
also be read alongside the user's newer permission to accept small changes
for worthwhile gains. The later `62e615d` batch supplies eleven additional tasks,
including the
vertex-transcendental, terrain LOD and powder-render proposals. Terrain LOD and
powder subdivision have now been tested. The shader proposals still need
comparison with the rejected wind polynomial and retained contact/tint work.
Solver-query reuse and native tracking address parts of the earlier tasks;
their other proposals remain investigations.
