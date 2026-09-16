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

## Windows measurements to reuse

RX 9070, Godot 4.7.2 custom ed1daf0bf, D3D12, 3840x2160 output, 2880x1620 internal,
High, Auto FSR 4.1.1, frame generation/GI off, clear/day, same 1,800-input dense
forest route. One warmup followed by one capture-free 15-second measured sample
per candidate; zero unfocused frames and exact trace completion.

| Current matching samples | Average FPS | Frame ms | Viewport GPU ms | Frame p99 ms |
| --- | ---: | ---: | ---: | ---: |
| Corrected bounds, 32 m detail groups | 78.23 | 12.783 | 11.216 | 18.171 |
| Static 16 m detail groups | 79.26 | 12.617 | 11.050 | 17.207 |
| Plus LOD1 mesh normals | 84.07 | 11.895 | 10.280 | 17.585 |
| Plus exact tick query reuse | 87.67 | 11.407 | 10.171 | 15.133 |
| Plus native skeletal tracking | 88.29 | 11.326 | 10.246 | 15.894 |
| Plus forest material ordering | 91.06 | 10.982 | 9.943 | 15.128 |
| Plus smaller powder mesh (two-run reference) | **92.28** | **10.837** | **9.588** | **16.192** |

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

## Powder mesh refinement and current free-ski reference

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

Reuse the average of the two cache-hit clean candidates: **92.28 FPS /
10.837 ms**, GPU **9.588 ms**. Median run p95/p99: **13.375/16.192 ms**.
This combines `powder-mesh-confirm-20260916` row 2 and
`powder-mesh-tail-pair-20260916` row 3 under `artifacts/pc_environment/`;
row 1 is warmup, and row 2 of the pair is the old mesh. The initial
`powder-mesh-20260916` row 2 rebuilt scenery during startup and is supplemental.
All samples match effective settings/camera and 1,800 final-state ticks,
with zero unfocused frames.
Both reference candidates hit physical/scenery caches. Detailed compact evidence
and the aggregation definition: `artifacts/powder_mesh_20260916/`.
Earlier 91.06 FPS and timed 82.72 FPS receipts describe the previous 512 mesh;
timed recording and Mac have not been measured with 256. Human review remains open.

## Timed recording reference

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
also passed 2,260 byte-equivalence checks. Use the candidate timed reference
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

## Mac and next experiments

The shipped native skier library is Windows x64 only. Mac uses the existing
GDScript implementation; it does not receive the native CPU savings yet. A Mac
port needs a native build and paired numerical/gameplay checks. Record one Mac
baseline for that device, renderer and settings; Windows numbers are not its
control. Keep the portable shader/batching changes enabled while investigating.

Promising next questions: which remaining renderer intervals dominate on Mac,
and whether native skier math is worth porting there. Keep 120 Hz simulation;
small visual/physics differences may be accepted for measured gains. Use one
focused candidate and a short warmed run; reuse matching baselines. Skip manual
hash audits and large capture archives. Prefer real improvements over reporting.

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
Mac execution, packaged export and human/controller feel are unverified.

## Fable task overlap review

Reviewed remote commit `a75212c`. Its title says five tasks, but it adds only
four task files. The linked `AA-20260916-084514-reduce-vertex-shader-transcendentals`
file is absent from that commit and its tree.

| Task suffix | What has already been tried | Remaining investigation |
| --- | --- | --- |
| `084500-reduce-solver-terrain-query-redundancy` | Native hip fitting, allocation-free heights, exact tick-local query reuse and removal of unread curvature probes are enabled. The bounded snow shortcut remains cosmetic only. | Capability checks, material-map storage and other proposed allocations/sweeps remain untested. This task is only partly implemented. |
| `084501-index-skier-pose-by-bone` | Rest geometry caching, native pelvis fitting and limits are enabled. Native tracking now caches immutable bone offsets/ancestry and batches the costly tick loop. | Broad pose-container conversion, mirror indices, reusable sampling buffers and fewer skeleton writes remain untested. Current writer cost is only 42 us/frame; pose is about 0.86 ms/frame. |
| `084502-reduce-recording-tick-cost` | Direct typed snapshot field access saves about 6 us/tick; all recorded channels remain exact. Broad buffer rewrites were rejected. | Timed control now exists; extra completed-pose capture costs about 1.2 ms at 30 Hz. Eliminating repeated solve work remains open. |
| `084503-publish-shared-shader-uniforms-globally` | Cloud parameter/direction/height change gates and wind direction/strength gates already exist. Tree contact shader work now skips exact rest. | Global publication and remaining write reduction are untested. Preserve separate world/preview state and pause behavior; receiver count estimates are not measured savings. |

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
