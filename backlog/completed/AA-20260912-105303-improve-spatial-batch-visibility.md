---
id: "AA-20260912-105303-improve-spatial-batch-visibility"
title: "Improve spatial batch visibility and render submission efficiency"
status: done
priority: P1
depends_on: ["AA-20260912-105302-reduce-dense-scene-gpu-cost"]
created: "2026-09-12T10:53:00Z"
updated: "2026-09-12T22:11:07Z"
source_thread: "01a09527-1988-7b50-b7c9-71ff6821cb00"
---

# Improve spatial batch visibility and render submission efficiency

## Outcome

Increase rendered FPS in dense scenes by submitting fewer unnecessary instances and reducing submission overhead, while keeping the same visible forest, rocks, shadows and detail ranges.

## Current state and evidence

- The retained [v15/model-28 receipt](../../docs/V15_PERFORMANCE_BASELINE_RESULTS.json) reports average draw calls 1080.996 and p99 1884. These are profiling leads, not evidence that reducing draw calls alone improves FPS.
- [DensityForest](../../scripts/presentation/density_forest.gd) partitions detail into 32 m regions and distant groups into 192 m cells, with 128 m loading and 192 m retention radii. Near/mid/shadow geometry shares prepared placement data. Reverify these values at implementation.
- [MineralScenery](../../scripts/presentation/mineral_scenery.gd) uploads prepared MultiMesh buffers with explicit bounds. [World](../../docs/WORLD.md) owns physical placement; presentation batching must preserve that identity.
- Godot MultiMesh frustum visibility applies to the whole batch, not individual instances. Smaller spatial groups can reject more off-screen work but create more draw calls; the optimum must be measured. [Official reference](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html).
- Related work: [colorful forests](AA-20260912-094935-colorful-forest-variety.md) and [terrain grass](AA-20260911-193341-terrain-grass.md). Optimize installed assets; do not absorb their art/placement work.

Inspected during backlog authoring on 2026-09-12. The retained full-descent
baseline is 92.568 average rendered FPS, frame p95/p99 16.311/23.198 ms, at
3840x2160 / 2880x1620 internal, High, Auto FSR 4.1.1, FG/SDFGI off.
It predates the current model-29 feature integration and is not a new-build
measurement. No implementation, engine benchmark or rendered acceptance was
performed during authoring. Read [the baseline limits](../../docs/VALIDATION.md#performance-evidence).

## Agreed decisions and scope

The user selected all four FPS areas for separate backlog implementation.
Priority is P1. Order: [streaming](AA-20260912-105300-reduce-streaming-frame-spikes.md),
[animation CPU](AA-20260912-105301-reduce-animation-cpu-cost.md), [dense-scene GPU](../blocked/AA-20260912-105302-reduce-dense-scene-gpu-cost.md),
then [batch visibility](AA-20260912-105303-improve-spatial-batch-visibility.md). Dependencies serialize shared edits and
performance attribution; they do not authorize this authoring task to dispatch.

Own spatial partition size, conservative batch bounds, material/mesh grouping, visibility decisions and supported render-buffer submission. Build on the completed streaming changes instead of replacing their scheduling. The GPU task owns shader/pass algorithms; this task may adjust batch-facing instance data only when necessary. No population reduction, shortened view distances, whole-forest scans per frame or camera-dependent physical collisions.

Preserve the Node-independent 120 Hz solver, 4 m support, ordinary inputs,
race/replay authority, current visual quality and personal settings/records.
Follow [engine strategy](../../docs/ARCHITECTURE.md#engine-strategy).
Coordinate with active owners before editing overlapping files; freeze source
and settings for each comparison. Unrelated feature completion is not silently
claimed or added as a prerequisite. Rebaseline after completed changes.

## Implementation approach

1. Instrument visible/submitted batches and instances, draw calls, bounds, render-thread CPU/GPU cost and residency. Distinguish stored instances, resident regions, submitted geometry and pixels actually visible.
2. Compare a small bounded set of partition/grouping candidates at matched camera paths and asset identities. Include forest interiors, forest edges, open/mineral terrain, camera turns and shadow-casting objects outside the camera frustum.
3. Retain conservative bounds for animated crowns, wind, snow-covered geometry, impostor orientation and shadow passes. Validate against final mesh bounds, not just trunk positions.
4. Use immutable packed grouping and bulk upload where beneficial; retain stable instance identities and material variation. Evaluate CPU culling cost against saved GPU work instead of assuming smaller or larger batches are universally faster.
5. Cover streaming re-entry, restarts, quality changes and current authored asset variants; bound buffers and bookkeeping and preserve the earlier streaming task's gains.

## Acceptance and verification

- [x] At least one measured partition/submission change produces repeatable rendered-FPS or frame-tail improvement beyond run noise. Report render CPU/GPU cost and submitted geometry alongside draw calls; fewer calls alone do not pass.
- [x] Native moving-camera comparisons show no premature disappearance, missing shadows, gaps, doubled geometry, altered density or earlier LOD transition. Include fast turns, region edges, wind extrema and low-sun off-camera casters.
- [x] Physical terrain/placement identities, obstacle queries and record eligibility remain unchanged. Run forest preparation, relevant mineral and graphics checks; add conservative-bounds/partition coverage tests.
- [x] Compare memory, startup and repeated streaming entry against the completed streaming task baseline. Do not regain a draw-call benefit by introducing its removed stalls or unbounded residency.
- [x] Exercise affected High and lower/higher graphics consumers, visibility aid and installed tree variants without relying on an unfinished art task for completion.
- [x] First collect a valid current baseline; never reuse the dated receipt as
  the before measurement. Use the current documented 170 km/h stress sections covering the
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
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','improve-spatial-batch-visibility-before','-Version','15','-InputTrace',$fpsTracePath,'-TrialStartSeconds','0','-TrialSeconds','15','-Upscaler','auto','-RenderScale','0.75','-TerrainGI','off','-FrameGeneration','off','-FrameCap','0','-Repetitions','3','-ProfileFrameCosts') -Label improve-spatial-batch-visibility-before -TimeoutSeconds 2400 -CollectGpuMemory
./scripts/test_pc_environment.ps1 -Suites forest_preparation_suite,mineral_detail_suite,pc_graphics_suite
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

Completed manually on 2026-09-13 (local date), following the user's direct request
after the GPU trials. No scheduled claim or downstream dispatch was taken.
The GPU task remains a separate, unaccepted optimization investigation.
Implementation/tests/guides were committed and pushed to `origin/main` as
**d4c073ea8d746fe171444a27ebed2c2a758b145a**.

**Retained production changes:** distant two-triangle forest cards use 384 m
cells, with one shared constant for prepared and direct construction. Near/mid
and shadow geometry keep 32 m regions and the existing 128 m load / 192 m retain
window. `AlpineScenery.remove_batch()` maintains an unordered slot-indexed array
by swapping its last member into the removed slot, eliminating repeated scans
of roughly 8,000 distant batches during detail retirement. Upload scheduling,
physical poses/IDs, materials, per-tree LOD distances, wind bounds, residency
fallback and shadows are unchanged. No shader, solver, input or session behavior
was edited. Minerals retain their existing partition.

**Current matched evidence:** base checkout `ed21419`, generator 15 / **model 30**,
Standard seed 849205174; 3840x2160 output / 2880x1620 internal, High preset 7,
Auto FSR 4.1.1, FG/GI off, clear/day, current camera and saved weather-quality
2 override. Fresh traces were regenerated from current sources at the saved
forest/rock starts and the summit. Per current Validation direction, these are
explicit immortal 170 km/h performance scenarios, not ordinary handling tests.
Every case used three independently warmed (240 frames), capture-free 15-second
repetitions with exact endpoints, full focus, fixed sources/settings and no
competing engine during measurement. Travel remained about 708 m per run.

| Case | Median rendered FPS before -> after | Frame p95 ms | Frame p99 ms | Render CPU mean ms | GPU mean ms |
|---|---:|---:|---:|---:|---:|
| Dense forest | 66.54 -> 74.37 | 22.880 -> 20.087 | 35.412 -> 28.751 | 2.467 -> 1.982 | 10.705 -> 10.225 |
| Rock field | 75.60 -> 77.04 | 18.620 -> 17.735 | 27.790 -> 27.431 | 2.213 -> 1.922 | 9.714 -> 9.502 |
| Open slope | 85.77 -> 94.48 | 16.454 -> 15.471 | 18.839 -> 17.230 | 2.016 -> 1.779 | 9.073 -> 8.317 |

Forest draw calls fell 1480 -> 1209 while submitted primitives rose slightly
7.578 -> 7.622 million: the gain is fewer submissions, not reduced density or
pixel quality. End-state forest batches fell 8629 -> 4015 with identical 59
resident regions and 9.6 MB prepared detail buffers. Median maximum scan/eviction
cost fell 9.015 -> .308 ms. Scoped CPU timers are not summed with frame/GPU cost.

A return-to-old-code confirmation produced **65.29 / 66.86 / 66.97 FPS**, below
all three new-code runs (**70.98 / 74.37 / 75.32**). This confirms the forest FPS
gain after an isolated Battle.net Agent burst in the first baseline. Its p99
median was 30.696 ms, showing that tail-improvement magnitude is noisier than
FPS. ChatGPT/Discord/background observations are retained; no user apps were
closed. The small rock FPS difference remains within run spread, with no
reproducible control regression.

Process private-byte peaks stayed 5.48-5.61 GiB across the matrix/confirmation;
engine static peaks fell about 55-62 MiB and engine video allocation stayed about
3579 MiB. Warm rock/open startup changed 55.52/57.70 -> 46.95/49.01 seconds.
New-source scenery invalidation incurred a one-time rebuild; separate scenery-cache-miss
observations were 74.37 s old / 65.19 s new. These are individual startup
observations, not three cold-start repetitions or physical VRAM measurements.

**Verification:** 3,533 native forest checks passed, including all 24 variants,
bounds, native bulk uploads, signed cell edges, quality consumers, slot ownership,
restart and repeated eviction/re-entry. Mineral detail passed all 120 assets; PC graphics 14, graphics 28, tree collection 565 and scenery integrity 8 checks passed (4,148 counted checks overall plus the mineral asset audit).
The mineral/tree report-folder assumptions were fixed. The two failed
report-writing attempts remain as diagnostic history. No mineral or tree asset was changed.

63 paired native 1280x720 frames were **byte-identical**, covering presets 1/7/10,
fast turns, region crossings, maximum wind, 50/100% visibility aid and low-sun
shadows. Eight chronological 4K production snapshots were separately reviewed
through the forest approach/interior. The readback/BVH diagnostic distinguishes
stored trees, resident batches and pre-shader candidate instances; it is excluded
from timing. Two scalar submission counters add about .09 microseconds over
array appends in a separate native API microcheck, not a gameplay benchmark.

The 120-cap configuration passed trajectory/focus checks at 71.10 FPS
(p95/p99 21.525/35.836 ms). The dense/rock cases still miss 90-120 rendered FPS;
all primary cases still miss p95 <=11.1 ms / p99 <=16.7 ms. This is a verified
local gain, not complete-descent, controller comfort or user visual acceptance.
16 saved preference files and eight sampled current race/record files retained
their hashes; only expected generation-time calibration changed during cache
rebuilds. Every stress run remained unranked.

**Rejected/limited candidates:** 16 m detail splitting submitted fewer vertices
but increased submission/retirement work; its exploratory script changed during
the pilot, so it is diagnostic-only and no code was retained. A 768 m far-cell
pilot did not establish additional gain beyond the 384 m run spread. Constant-time
retirement alone removed the CPU spike but did not independently establish a
whole-run FPS gain; delivery is the measured combined change.

**Owners and reproduction:** [Rendering](../../docs/RENDERING.md#terrain-forests-and-lighting)
owns partition/retirement contracts; [Validation](../../docs/VALIDATION.md#forest-batch-submission)
owns native checks, paired visuals and submission-counter limits. Detailed
individual repetitions, hashes, timing/memory, source snapshots, commands and
background observations are in
[the task receipt](../../artifacts/spatial_batch_visibility/REPORT.md) and
`artifacts/spatial_batch_visibility/acceptance.json`; benchmark labels are
`batch-accept-{before,after}-{forest,rocks,open}`, `batch-confirm-before-forest`,
`batch-final-forest-cap120` and `batch-final-forest-visual` under
`artifacts/pc_environment/`. Primary visual/performance evidence remains for
review. Cleanup of nine unused task scratch files was deferred after automatic
approval review rejected deletion with the reason 'blocked by policy'; all files
were preserved. No separate next-step proposal was authored. Human skiing/controller acceptance remains pending.
