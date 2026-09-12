---
id: "AA-20260912-105300-reduce-streaming-frame-spikes"
title: "Reduce collision, mineral and forest streaming frame spikes"
status: done
priority: P1
depends_on: []
created: "2026-09-12T10:53:00Z"
updated: "2026-09-12T14:35:07Z"
source_thread: "01a09527-1988-7b50-b7c9-71ff6821cb00"
---

# Reduce collision, mineral and forest streaming frame spikes

## Outcome

Make skiing through rock and forest boundaries smoother by reducing intermittent preparation and upload stalls, while keeping obstacles, forest coverage and visible detail intact.

## Current state and evidence

- The retained [v15/model-28 receipt](../../docs/V15_PERFORMANCE_BASELINE_RESULTS.json) reports medians of run scope maxima: collision preparation 25.941 ms, mineral streaming 19.238 ms and forest residency 13.762 ms. These are overlapping CPU scopes, not proven causes of particular slow frames or current model-29 measurements.
- [Main](../../scripts/main.gd) measures `crash_collision.prepare(p)` under `collision_preparation`. [CrashCollision](../../scripts/world/crash_collision.gd) builds nearby terrain/obstacle bodies for ragdolls; this is distinct from the normal skiing support solver.
- [MineralScenery](../../scripts/presentation/mineral_scenery.gd) checks macro texture residency every 0.5 seconds and changes at most two shared sources per frame. [DensityForest](../../scripts/presentation/density_forest.gd) already prepares immutable meshes/transforms before skiing and loads at most three regions per update. Count limits do not establish time bounds; do not propose these existing foundations as missing.
- Related work: [crash recovery](AA-20260911-221843-crash-location-respawn.md), [colorful forests](AA-20260912-094935-colorful-forest-variety.md) and [terrain grass](AA-20260911-193341-terrain-grass.md). Preserve their ownership and current status.

Inspected during backlog authoring on 2026-09-12. The retained full-descent
baseline is 92.568 average rendered FPS, frame p95/p99 16.311/23.198 ms, at
3840x2160 / 2880x1620 internal, High, Auto FSR 4.1.1, FG/SDFGI off.
It predates the current model-29 feature integration and is not a new-build
measurement. No implementation, engine benchmark or rendered acceptance was
performed during authoring. Read [the baseline limits](../../docs/VALIDATION.md#performance-evidence).

## Agreed decisions and scope

The user selected all four FPS areas for separate backlog implementation.
Priority is P1. Order: [streaming](AA-20260912-105300-reduce-streaming-frame-spikes.md),
[animation CPU](AA-20260912-105301-reduce-animation-cpu-cost.md), [dense-scene GPU](AA-20260912-105302-reduce-dense-scene-gpu-cost.md),
then [batch visibility](../archive/AA-20260912-105303-improve-spatial-batch-visibility.md). Dependencies serialize shared edits and
performance attribution; they do not authorize this authoring task to dispatch.

Own runtime preparation scheduling, allocation/resource reuse, preload decisions and publication boundaries in the three measured systems. The later batch task owns spatial batch partitioning; the GPU task owns shader/pass cost. Keep existing visible ranges and collision coverage; moving work earlier must not replace a skiing hitch with unbounded startup or memory cost. Never delay required physical support or leave a crash without its collision neighborhood.

Preserve the Node-independent 120 Hz solver, 4 m support, ordinary inputs,
race/replay authority, current visual quality and personal settings/records.
Follow [engine strategy](../../docs/ARCHITECTURE.md#engine-strategy).
Coordinate with active owners before editing overlapping files; freeze source
and settings for each comparison. Unrelated feature completion is not silently
claimed or added as a prerequisite. Rebaseline after completed changes.

## Implementation approach

1. Add or refine low-overhead subscopes and event/frame identifiers for shape creation, scene mutation, resource loading, texture/buffer upload, eviction and residency publication. Correlate spikes with actual slow-frame chronology.
2. Reproduce one rock-boundary and one forest-boundary case with ordinary input. Measure cold first encounter separately from repeated entry and reversal.
3. Optimize the demonstrated cause: split large work units, prepare immutable arrays off-thread when safe, publish on supported engine paths, reuse bounded resources, and prefetch before the rider can reach the relevant boundary. Choose time/work budgets from measurements; preserve a correctness path for discontinuities.
4. Cover fast travel, reverse travel, camera changes, restart, crash/recovery, quality switches and cancellation. Ensure pending queues cannot starve, duplicate instances or grow without bound. Only mark a forest region ready after its required batches are usable.

## Acceptance and verification

- [x] Slow-frame/event correlation identifies the changed cause; before/after records show reduced hitch frequency or frame p95/p99 beyond observed run noise in the targeted sections, without a reproducible mean-FPS regression.
- [x] Collision checks verify exact authoritative terrain/obstacle coverage on both sides of preparation boundaries and immediate crash/recovery availability. Run `geology_collision_suite`, `forest_preparation_suite`, and required physics/runtime suites; add focused queue/publication lifecycle checks where needed.
- [x] Native chronology shows unchanged forest/mineral detail, no missing or doubled batches, no delayed texture transition or new pop-in at the original visible ranges.
- [x] Report startup, per-event preparation/upload cost, queue peaks and memory after repeated re-entry; savings must not rely on accumulating all visited resources forever.
- [x] First collect a valid current baseline; never reuse the dated receipt as
  the before measurement. Use ordinary-input 15-30 second sections covering the
  targeted event plus a control section. Name the question, warmup, duration and
  clean stop before launch. Match seed/model, camera, current source/engine
  identity and actual output/internal pixels.
- [x] Follow [performance method](../../docs/VALIDATION.md#performance-method)
  and [bounded descents](../../docs/VALIDATION.md#bounded-test-descents).
  Compare three independently warmed, capture-free repetitions before/after.
  Report individual runs and medians of run statistics, rendered FPS, frame
  p95/p99, CPU/GPU timing, memory and observed background contention. Scope
  maxima and overlapping CPU timers must not be summed into frame cost.
- [x] Use the existing serial validation guard and wait for occupied workloads;
  no nested guards or terminating another task's job. Preserve test/lab isolation.
  Keep profiling/readback captures separate from acceptance timing and assess
  instrumentation overhead. Reject unfocused, source-drifting or stale-trace runs.
- [x] Retain only demonstrated gains without reproducible performance or visual
  regressions in control sections. If no beneficial candidate is demonstrated,
  revert owned experiments and record a blocker/findings; an isolated microbench
  improvement or completed investigation does not mark this optimization done.
  Report remaining distance from 90-120 rendered FPS, p95 <=11.1 ms and
  p99 <=16.7 ms. Meeting the global target on every route is not a prerequisite
  for a useful verified local gain; bounded cases establish only their scenarios.
- [x] Update the affected authoritative domain guide with durable ownership and
  reproduction details. Put detailed receipts/comparisons in a task-owned
  artifacts directory; commit/push only related validated work and perform
  task-owned artifact cleanup under Development safeguards.

Use the existing benchmark with a current validated input file selected during
baseline preparation. `fpsTracePath` below denotes that real file; do not create
a placeholder trace or bypass its identity checks. Choose the section start to
include the observed event, not automatically the historical 90-second window.
The example uses a 15-second section from its start:

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','reduce-streaming-frame-spikes-before','-Version','15','-InputTrace',$fpsTracePath,'-TrialStartSeconds','0','-TrialSeconds','15','-Upscaler','auto','-RenderScale','0.75','-TerrainGI','off','-FrameGeneration','off','-FrameCap','0','-Repetitions','3','-ProfileFrameCosts') -Label reduce-streaming-frame-spikes-before -TimeoutSeconds 2400 -CollectGpuMemory
./scripts/test_pc_environment.ps1 -Suites geology_collision_suite,forest_preparation_suite,physics_suite,runtime_suite
```

Use fresh labels for after/control runs and record final commands. The benchmark
also exposes `-ScenarioReplay` for a supported bounded recorded scenario; validate
that mode and its endpoint rather than demanding a new full descent solely to
obtain short diagnostic data. Preserve full gameplay observers/HUD/effects.
The example uses the documented standard High configuration; explicitly enabled
saved visual overrides must be matched, never silently disabled. Run a separate
120-cap check after uncapped attribution. Physics/input/session changes require
`./godotw --headless --script tests/physics_suite.gd` and
`./godotw --headless --script tests/runtime_suite.gd` through the guard or the
existing guarded suite runner. Inspect current suite names before execution.

Human acceptance: skiing smoothness, controller comfort and subjective visual
preference remain separate pending follow-up, not a worker-completion gate.
Required worker-rendered, automated and measured performance evidence above
must be completed; do not claim user acceptance.

## Open questions

None

## Completion record

Completed manually on 2026-09-12; no scheduled claim or downstream dispatch.
Implementation and guides committed/pushed to `main` as **25aa523**.

**Retained change:** `CrashCollision` warms shared mineral convex pieces through
one non-colliding reusable body, nearest-first within 300 m. Each frame processes
at most eight pieces and stops subsequent work at 750 microseconds. Required
bodies still publish every authoritative piece immediately at the original
preparation boundary; discontinuities have the synchronous correctness path.
The solver, terrain triangles, obstacle coverage, visible ranges, geometry,
texture choices and forest publication logic are unchanged. The two presentation
owners gained diagnostic subscopes, not speculative streaming rewrites.

**Demonstrated cause and gain:** formation 24003 (`mineral_large_outcrop_03`) has
124 convex pieces. Native first attachment cooked them together, taking
11.4–13.2 ms in three fresh-collision-owner trials. With bounded warming, mineral
publication took 0.40–0.45 ms and warmup slices peaked at 1.051 ms (one native cook
is not preemptible). The corresponding frame intervals near ticks 3347–3349 were
26.478/25.930/28.069 ms before and 15.921/16.495/18.052 ms after. Collision events
above 5 ms fell from one per trial to zero. Setting the final transform before
attachment was tested and rejected: it did not remove the cook stall.

**Matched scenario measurements:** default seed 849205174, generator 15/model 29,
3840×2160 output / 2880×1620 internal, High, Auto FSR 4.1.1, clear/day, FG/GI off,
current saved camera, 240 warmup frames, three focused capture-free repetitions.
All endpoints reproduced exactly; no measured source drift or other engine jobs.
An offline 180-second ordinary-control prefix was freshly simulated on model 29
to reach the first forest boundary; measured windows were only 15 seconds.
The historical recording supplied control values, never a relabeled trajectory.

| Window | Median rendered FPS before → after | Frame p95 ms | Frame p99 ms |
|---|---:|---:|---:|
| Rock 15–30 s, fresh collision owner each trial | 72.11 → 80.56 | 19.870 → 16.389 | 23.723 → 18.892 |
| First forest residency 165–180 s | 77.84 → 75.36 | 17.580 → 18.753 | 25.338 → 24.254 |
| Opening control 0–15 s | 101.65 → 104.97 | 14.157 → 13.777 | 15.855 → 15.689 |

Accept the repeatable collision-event gain, not a general FPS uplift. Forest mean
was about 3% lower, within the observed run spread; its p99 improved. Background
application/telemetry activity and whole-section variation remain recorded.
The initial `streaming-before-forest` attempt is diagnostic only: repetitions
2/3 lost focus and were rejected. The benchmark now reacquires focus before each
warmup and fails unfocused trials. A separate unprofiled 120-cap check reproduced
all three endpoints at 72.67/76.48/75.63 FPS. The global 90–120 FPS / 11.1 ms p95 /
16.7 ms p99 target is still unmet in the rock and forest samples.

**Resource/startup evidence:** rock cache counts stayed at 13 records / 205 pieces
and forest at 25 records / 411 pieces across re-entry, with empty final queues.
Queue peaks were 4/14 records; shape point payloads were 104,508/235,260 bytes,
excluding native Jolt allocations. Process private-byte peaks stayed around
5.9 GB across variants; no monotonic re-entry accumulation appeared. Matched
cached scene setup was 55–61 seconds; no startup gain is claimed. The catalog
cache is world-owned and bounded by shared records, not visited placements.
Enabled event timing added about 0.75 microseconds per begin/end call in the
isolated diagnostic; this is not an FPS measurement. Both A/B arms used it.

**Verification:** geology collision 16, streaming collision lifecycle 22,
physics 56, runtime 192, trace contracts 13, native forest preparation 2,111,
and native residency lifecycle 38 checks passed. The latter exercised far/near
camera moves, all three authored texture channels, Low/High changes, queue drain
and three re-entries without duplicate batches. Backlog tests: 23 passed.
The forest suite requires native GPU readback, so it ran separately from the
headless batch rather than using the task's headless example for that suite.

**Rendered review:** inspected 15 native frames through the 165–180 s section
and a close macro-rock view. Rock detail, forest coverage and publication were
continuous in the sampled views; timing runs contained no capture readback.
The capture also shows intermittent ski/snow occlusion outside the changed
owners; it is retained as an unresolved visual finding, not claimed fixed here.
Human smoothness/controller acceptance and dense/full-route coverage remain
separate. Personal preferences and records were unchanged; the normal generation
timing cache updated during loading. No separate next-step proposals were made.

**Reproduction/provenance:** [World](../../docs/WORLD.md#geology-and-collision)
owns the warmup contract; [Validation](../../docs/VALIDATION.md#player-recordings-and-short-scenarios)
documents event chronology and `-ColdCollision`. Detailed individual runs,
CPU/GPU statistics, source/settings hashes, memory/background telemetry, snapshots
and commands are retained in `artifacts/streaming_spikes/comparison.json`,
`matrix.ps1`, `final_native.ps1`, `regression/`, `residency_lifecycle.json`,
`chronology.jpg` and `artifacts/pc_environment/streaming-*`. Baseline runtime is
259b50b plus the shared diagnostic harness; exact per-file identities are in the
comparison. Engine worker SHA-256:
`a18ddc9f3ee8fa1915a47d54c3e0d05ec4b10f8ee9deb15d7206b4e23d29bcc9`;
launcher `0c4e9e4d32c3e550189f463efbf16bd7325cd26eae69b6718a40dc4088ef0b0b`.
Evidence is retained for review and the unresolved visual finding. Only a
redundant task-owned prototype is removed after push; other task outputs remain.
