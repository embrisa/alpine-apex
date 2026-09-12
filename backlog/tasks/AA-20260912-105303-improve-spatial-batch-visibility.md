---
id: "AA-20260912-105303-improve-spatial-batch-visibility"
title: "Improve spatial batch visibility and render submission efficiency"
status: ready
priority: P1
depends_on: ["AA-20260912-105302-reduce-dense-scene-gpu-cost"]
created: "2026-09-12T10:53:00Z"
updated: "2026-09-12T10:53:00Z"
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
[animation CPU](AA-20260912-105301-reduce-animation-cpu-cost.md), [dense-scene GPU](AA-20260912-105302-reduce-dense-scene-gpu-cost.md),
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

- [ ] At least one measured partition/submission change produces repeatable rendered-FPS or frame-tail improvement beyond run noise. Report render CPU/GPU cost and submitted geometry alongside draw calls; fewer calls alone do not pass.
- [ ] Native moving-camera comparisons show no premature disappearance, missing shadows, gaps, doubled geometry, altered density or earlier LOD transition. Include fast turns, region edges, wind extrema and low-sun off-camera casters.
- [ ] Physical terrain/placement identities, obstacle queries and record eligibility remain unchanged. Run forest preparation, relevant mineral and graphics checks; add conservative-bounds/partition coverage tests.
- [ ] Compare memory, startup and repeated streaming entry against the completed streaming task baseline. Do not regain a draw-call benefit by introducing its removed stalls or unbounded residency.
- [ ] Exercise affected High and lower/higher graphics consumers, visibility aid and installed tree variants without relying on an unfinished art task for completion.
- [ ] First collect a valid current baseline; never reuse the dated receipt as
  the before measurement. Use ordinary-input 15-30 second sections covering the
  targeted event plus a control section. Name the question, warmup, duration and
  clean stop before launch. Match seed/model, camera, current source/engine
  identity and actual output/internal pixels.
- [ ] Follow [performance method](../../docs/VALIDATION.md#performance-method)
  and [bounded descents](../../docs/VALIDATION.md#bounded-test-descents).
  Compare three independently warmed, capture-free repetitions before/after.
  Report individual runs and medians of run statistics, rendered FPS, frame
  p95/p99, CPU/GPU timing, memory and observed background contention. Scope
  maxima and overlapping CPU timers must not be summed into frame cost.
- [ ] Use the existing serial validation guard and wait for occupied workloads;
  no nested guards or terminating another task's job. Preserve test/lab isolation.
  Keep profiling/readback captures separate from acceptance timing and assess
  instrumentation overhead. Reject unfocused, source-drifting or stale-trace runs.
- [ ] Retain only demonstrated gains without reproducible performance or visual
  regressions in control sections. If no beneficial candidate is demonstrated,
  revert owned experiments and record a blocker/findings; an isolated microbench
  improvement or completed investigation does not mark this optimization done.
  Report remaining distance from 90-120 rendered FPS, p95 <=11.1 ms and
  p99 <=16.7 ms. Meeting the global target on every route is not a prerequisite
  for a useful verified local gain; bounded cases establish only their scenarios.
- [ ] Update the affected authoritative domain guide with durable ownership and
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

Pending implementation. Record actual changed owners, baseline/after source and
engine identities, accepted and rejected candidates, executed checks, rendered
review, scenario performance, remaining acceptance, guide updates and commit/push
references. If blocked, record the concrete cause and remaining work. Link
separate next-step proposals in backlog/ideas/ or state that none were proposed;
they require user selection before task authoring.
