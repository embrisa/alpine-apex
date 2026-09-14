---
id: "AA-20260914-094136-establish-repeatable-rendering-baseline"
title: "Establish repeatable current rendering costs and comparison controls"
status: ready
priority: P1
depends_on: []
created: "2026-09-14T09:41:36Z"
updated: "2026-09-14T09:41:36Z"
source_thread: "01a09c68-b71e-7cc1-b01a-291cd5c446e8"
---

# Establish repeatable current rendering costs and comparison controls

## Outcome

Give the next FPS experiments a repeatable current workload and a ranked cost
breakdown, so large architectural changes are selected by removable frame cost.
Resolve or quantify the repeated baseline drift before treating another isolated
good run as a gain. This is a bounded investigation/tooling task; it does not
claim a runtime optimization or require reaching the whole-game FPS target.

## Current state and evidence

The user requested substantially larger FPS gains, including changes to rendering
fundamentals, and then explicitly requested thorough backlog authoring. This
record is ready for later dispatch; authoring does not run the investigation.
Source was inspected at Dev 31 / 36b25d3 on 2026-09-14. Retained measurements
below identify leads; they are not a fresh Dev 31 baseline.

| Retained workload | Result | Interpretation |
|---|---|---|
| Scenery-facing dense Standard, colorful forest candidate | 67.06 / 68.24 / 68.61 FPS; median GPU mean 12.106 ms, frame p95 18.810 ms, p99 24.504 ms | GPU alone exceeds the 8.333 ms budget for 120 rendered FPS |
| Same candidate, median run statistics | 1,619.6 draw calls and 13.737 million submitted primitives/frame; forest residency mean 25.077 microseconds | Submitted primitives are not visible triangles or per-pass vertex counts; tiny average residency does not exclude hitches |
| Frozen gravel Standard off / all / repeated off | Median 85.24 / 91.23 / 81.06 FPS; GPU 9.234 / 8.638 / 9.714 ms | Adding gravel appeared faster than both controls; no causal speedup or reliable isolated mountain gravel cost established |
| Local gravel off / all, near 120 cap | Median GPU 5.319 / 5.892 ms | About 0.573 ms local component cost; this cannot explain or close the separate dense-forest gate |

Authoritative receipts: [colorful forest](../../docs/COLORFUL_FOREST_RESULTS.json),
[gravel](../../docs/ROCK_GRAVEL_RESULTS.json), and
[grass](../../docs/TERRAIN_GRASS_PERFORMANCE_RESULTS.json). Grass comparisons
used an older snow-facing camera. Local vegetation/gravel, the shelf-to-snow
Standard route, dense ordinary forest and 170 km/h stress are distinct workloads.
Never pool or compare their absolute FPS as if only code changed. The gravel
route travels 41.67 m, peaks near 49 km/h and slows substantially after the rock;
it is not sustained dense forest or sustained gravel coverage.

Raw forest candidate evidence is under
artifacts/colorful_forest_variety/frozen_v1/candidate/artifacts/pc_environment/colorful_frozen_warm_candidate/.
The frozen gravel v3 project and its 27 trials are retained under
artifacts/rock_gravel/frozen_v3/. Earlier gravel v1/v2 project copies were cleaned;
their receipts and raw artifacts remain, but those projects are not runnable.
Read per-frame samples, streaming_events and system.json at matching route
intervals. Missing ignored artifacts require fresh supported producers, not
invented results or an implicit mountain bake.

Older [GPU work](AA-20260912-105302-reduce-dense-scene-gpu-cost.md) already added native pass queries and rejected
small powder/zero-coverage shader pilots. The engine marker named FSR2 wraps the
actual selected provider; the older rock pass capture reported FSR 4.1.1.
Its roughly 1.93 ms reconstruction, 1.70 depth, 1.58 opaque and 1.43 motion
intervals are dated model-30 attribution, not the current forest breakdown.

## Agreed decisions and scope

- Own workload identity, comparison ordering, repeatability analysis and the
  smallest missing attribution instrumentation in the existing benchmark tools.
  Reuse the [performance method](../../docs/VALIDATION.md#performance-method)
  and [performance skill](../../.agents/skills/alpine-performance/SKILL.md).
  Do not build a replacement benchmark framework or dispatch other tasks.
- Preserve Standard's physical population, map, assets/imports, selected effects,
  4K High, actual Auto FSR provider and 0.75 internal scale; FG/GI stay off in
  matched acceptance. Use uncapped attribution plus a separate normal 120-cap
  confirmation. Diagnostic feature-off/resolution probes are attribution only.
- The 120 Hz solver, 4 m support, collision, response and personal data remain
  unchanged. [Map regeneration](AA-20260913-232221-natural-forest-generation.md)
  is separate and is not a dependency or a way to pass these FPS checks.
- Routine technical choices are settled by the implementer from evidence. An
  unmeasured hypothesis is not an unresolved product question. No gain percentage
  is promised: 68.24 to 100/120 FPS requires about 31.8/43.1 percent less total
  frame time, not that much improvement in every individual subsystem.


### Work routing and order

| Order | Task | Distinct responsibility |
|---|---|---|
| 1 / P1 | This baseline task | Repeatability, current pass attribution and candidate ranking |
| Recommended first optimization / P1 | [Tree selection](AA-20260914-094136-select-forest-lods-before-submission.md) | Remove unneeded individual LOD/instance submission before vertex processing |
| P1, independent after baseline | [GPU passes](AA-20260912-105302-reduce-dense-scene-gpu-cost.md) | Substantial equivalent pass/material/terrain-render algorithms or narrow engine changes |
| P1, independent after baseline | [Publication and collision](AA-20260913-141128-reduce-forest-publication-and-collision-bursts.md) | Avoid/reuse or shrink the largest native upload/cook operation; reduce frame tails |
| P2 after cost justification | [Distant stands](AA-20260914-094136-render-distant-forest-stands.md) | Replace individual distant trees with coherent stand representations |
| P2 after hidden-work attribution | [Occlusion](AA-20260914-094136-cull-scenery-behind-terrain.md) | Reject fully hidden scenery conservatively behind opaque ridges/rocks |

All five implementation items depend on this evidence task. Their file scopes and
the workload guard serialize overlaps; there is no artificial chain requiring
one optimization to succeed before another hypothesis can be evaluated. After
any delivered change, refresh affected baselines. Preserve the completed
[terrain/snow query optimization](AA-20260913-141128-reduce-terrain-and-snow-query-cost.md)
and animation/spatial gains. Physical regeneration remains separate.

## Implementation approach

1. Audit retained off/all/off and forest runs first. Compare identical tick
   intervals, resident/visible coverage, pass/CPU timing, first repetition and
   later re-entry, source/runtime/cache/focus receipts and background samples.
   Do not infer thermal throttling, driver compilation, VRAM pressure or an OS
   scheduling cause without telemetry supporting it. Allocation telemetry is
   not physical VRAM occupancy. CPU scopes overlap and have different cadences.
2. Freeze the actual current code and hydrated assets, engine executable and
   launcher hashes, seed/generator/model/tuning, trace and camera. Verify the
   custom engine selected by scripts/resolve_godot_engine.ps1; explicitly pin
   GODOT_BIN when measuring frozen projects. Prepare each arm's scenery cache
   immediately before it runs: there is one shared source-specific scenery slot.
   Require an existing compatible physical archive; stop a cache miss and use
   explicit preparation. Do not bypass trace identity or regenerate the map.
3. Qualify scenery-facing routes using tests/scenery_camera.gd and
   tests/scenery_trace.gd. Separately inspect native frames showing near trees,
   canopy gaps, minerals and horizon, with sufficient camera-ground clearance.
   Retain a riding-camera visual control; no preference writes. Capture no
   screenshots or video during timed windows.
4. Use a bounded matrix: dense ordinary forest, open ordinary control, a mineral
   section, and the affected 170 km/h stress route. Keep the complete speed,
   distance, contacts and prevented-fatal-event receipts for stress; it is not
   skiing/crash acceptance. Local perf-vegetation/perf-rocks/perf-slopes/perf-mixed
   diagnose components only. Survey an alternate seed only if visibility or
   population assumptions need testing; it is not a compulsory timing sweep.
5. For repeatability, begin with unchanged-source A/A return controls.
   Feature-off arms may diagnose cost but cannot deliver an optimization.
   Run three independently warmed 15-second repetitions per comparison arm with
   240 warmup frames per production repetition. Counterbalance fresh processes
   and include a return-to-original control, preserving all first repetitions.
   First encounter versus warmed re-entry must be recorded. Use existing switches
   such as ColdCollision only with their documented trace/cache semantics.
   Set the matrix and a finite follow-up budget before launch: at most one
   additional return-control sequence for an unexplained drift result. If still
   unstable, report an uncertainty range and exact missing evidence, not an
   unlimited benchmark loop or an accepted speedup.
6. Collect separate native pass profiles on representative 15-second sections.
   Correlate GPU and render-thread cost with submissions by object family and
   LOD; add bounded counters only where existing data cannot isolate the cause.
   Count submitted instances, zero-coverage instances, vertices and cutout/opaque
   passes separately. If needed, use a small native renderer/PIX/Radeon capture
   to distinguish vertex cost, overdraw, bandwidth, dispatch/copies and waits.
   Follow delayed GPU-frame rules; never align the requesting tick as exact.
7. Produce a compact ranking with measured cost, evidence confidence, defensible
   removable upper bound, likely CPU/upload overhead, visual risks and next
   experiment. Route tree selection, stand HLOD, occlusion, pass work and native
   publication to the linked tasks; do not silently implement all of them here.

Maintained command entry points (choose fresh output labels and current traces):

~~~powershell
./scripts/benchmark_targeted.ps1 -Map vegetation -Seconds 6 -Repetitions 3 -FrameCap 0 -Camera scenery -PlanOnly
./scripts/benchmark_targeted.ps1 -Map vegetation -Seconds 6 -Repetitions 3 -FrameCap 0 -Camera scenery -Output artifacts/fps-baseline-local-UNIQUE
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','fps-baseline-UNIQUE','-InputTrace',$fpsTracePath,'-ScenarioReplay','-TrialStartSeconds','0','-TrialSeconds','15','-Repetitions','3','-FrameCap','0','-Upscaler','auto','-RenderScale','0.75','-TerrainGI','off','-FrameGeneration','off','-ProfileFrameCosts') -Label fps-baseline-UNIQUE -WorkloadMode FpsCritical -TimeoutSeconds 900 -CollectGpuMemory -FullMountain -FullMountainReason 'Matched identified forest workload and open/mineral controls for rendering attribution'
~~~

Set fpsTracePath to a freshly verified ordinary trace. For native pass attribution
use one repetition and add ProfileGpuPasses; for stress use a separately qualified
stress trace and StressSpeedKmh 170. See
[trace producers](../../docs/VALIDATION.md#immortal-high-speed-stress-trials) and
[GPU queries](../../docs/VALIDATION.md#native-gpu-pass-attribution).
The targeted and forest/gravel comparison wrappers own their guards; never nest
them. Imports/preparation/builds use Exclusive, timings FpsCritical, ordinary
isolated checks Shared. Every full-mountain guard needs the explicit reason.

## Acceptance and verification

- [ ] Retained variation is analyzed and a fresh identity-matched baseline has
  complete ordinary/stress coverage, effective pixel/provider settings, warmup,
  cache, focus, source and endpoint validity. Reject and retain invalid attempts.
- [ ] A machine-readable run table and concise report contain all individual
  trials, medians of run statistics, frame p95/p99/max, rendered FPS, GPU and
  render CPU timing, cadence-labelled CPU scopes, submissions, memory and
  startup/re-entry observations. Percentiles are not pooled; generated frames
  and local-component results are not whole-mountain acceptance.
- [ ] Counterbalanced or return-control evidence either establishes usable
  repeatability or quantifies the unresolved drift. If no trustworthy comparison
  is possible within the bound, record blocked with the exact external evidence
  needed; do not mark optimization prerequisites done from unstable timing.
- [ ] The ranked report names a concrete first experiment and its kill criterion.
  Tree selection is the leading hypothesis, not a mandatory conclusion. Preserve
  earlier accepted CPU/query work and rejected GPU/publication evidence.
- [ ] Any tooling change receives focused schema/identity/failure checks and a
  bounded native smoke check; shader/camera changes receive separate rendered
  inspection. Physics/input/session changes require physics_suite and
  runtime_suite under the guard. Update Validation and affected skills only if
  the maintained commands/evidence contract changes.
- [ ] Commit/push owned tooling/docs with a captured development note and scoped
  versioning checks. Link retained raw evidence and clean only disposable owned
  artifacts after push. No runtime speedup is claimed for this baseline milestone.

Human acceptance: continuous smoothness, viewing comfort and controller feel are
separate follow-ups, not completion gates for this measurement task.

## Open questions

None

## Completion record

Pending investigation. Record actual commands, runtime/source identities,
measurements, remaining uncertainty, report path, Dev ID and commit/push. No
checks or FPS gains were performed or established during backlog authoring.
This dependency supplies a methodology and dated baseline; downstream tasks must
refresh their own before measurements after source changes.
