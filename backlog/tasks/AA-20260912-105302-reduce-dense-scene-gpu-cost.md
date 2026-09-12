---
id: "AA-20260912-105302-reduce-dense-scene-gpu-cost"
title: "Reduce dense-scene GPU cost while preserving visual quality"
status: ready
priority: P1
depends_on: ["AA-20260912-105301-reduce-animation-cpu-cost"]
created: "2026-09-12T10:53:00Z"
updated: "2026-09-12T10:53:00Z"
source_thread: "01a09527-1988-7b50-b7c9-71ff6821cb00"
---

# Reduce dense-scene GPU cost while preserving visual quality

## Outcome

Raise actual rendered FPS in dense terrain and forest scenes by making expensive rendering passes cheaper while preserving the current 4K presentation, lighting, foliage and snow.

## Current state and evidence

- The retained [v15/model-28 receipt](../../docs/V15_PERFORMANCE_BASELINE_RESULTS.json) reports GPU mean 8.607 ms and p95 11.827 ms; sustained 120 FPS has an 8.333 ms total frame budget. GPU and CPU work overlap, and these measurements do not identify the dominant GPU pass.
- [Rendering](../../docs/RENDERING.md) owns the current terrain/forest, snow, weather and native FidelityFX contracts. Candidate owners include [terrain surface shading](../../assets/graphics/alpine_surface_fragment.gdshaderinc), [forest geometry](../../assets/graphics/pc_forest_tree.gdshader), [forest impostors](../../assets/graphics/pc_tree_impostor.gdshader), and [powder](../../scripts/presentation/powder_surface.gd).
- Existing features already include instancing, LOD, prepared data and native FSR. Inspect actual active passes rather than proposing their addition.
- Related work: [snow boundary](AA-20260912-005323-subtle-local-snow-boundary.md), [forest transparency](AA-20260912-004316-forest-transparency-strength.md), [scenery snow](AA-20260911-230603-scenery-snow-material.md), [scenery shadows](AA-20260911-230604-scenery-mountain-shadows.md), [motion blur](AA-20260912-004402-scene-motion-blur.md) and [colorful forests](AA-20260912-094935-colorful-forest-variety.md). Do not implement those feature tasks here.

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

Own demonstrated GPU shader/pass bottlenecks in shadows, foliage, terrain/snow, weather or distant scenery. The fourth task owns spatial batch partitioning/culling. Preserve output/internal resolution, reconstruction provider, density, detail distances, shadow quality, enabled effects and physical identities. Temporary diagnostic feature toggles are allowed only for attribution; restored production visuals are required for accepted results.

Preserve the Node-independent 120 Hz solver, 4 m support, ordinary inputs,
race/replay authority, current visual quality and personal settings/records.
Follow [engine strategy](../../docs/ARCHITECTURE.md#engine-strategy).
Coordinate with active owners before editing overlapping files; freeze source
and settings for each comparison. Unrelated feature completion is not silently
claimed or added as a prerequisite. Rebaseline after completed changes.

## Implementation approach

1. Capture pass-level GPU timings on the current custom DX12 runtime, using supported engine timings and PIX/Radeon tooling if needed. Separate shadows, opaque/cutout geometry, snow/terrain shading, weather, post-processing and upscaling; account for synchronization/copies.
2. Compare open snow, a dense forest and a mineral-rich section. Use isolated diagnostic toggles or reduced resolution only to identify sensitivity; never count their quality changes as a delivered gain.
3. Optimize the highest demonstrated cost: remove duplicate sampling/calculation, avoid unused shader work, share equivalent material inputs or eliminate redundant passes/copies without changing their visible result. Preserve history, barriers and pipeline-state contracts if touching native renderer integration.
4. Establish correctness on High first, then exercise affected Low/Balanced/Ultra consumers and effect toggles. Keep terrain relief, track continuity, readable weather and shadows intact during motion.

## Acceptance and verification

- [ ] Attribute the changed GPU cost to named passes and retain actual native GPU timing evidence. Three matched before/after production repetitions show lower GPU cost and rendered-FPS or frame-tail improvement beyond observed noise.
- [ ] Native matched stills and chronological motion retain terrain texture, compact snow facets/sheen, track deformation, foliage silhouettes/transparency, shadow reach and weather readability. Inspect forest/open-snow/mineral views and affected daylight/weather cases.
- [ ] Shader compilation and relevant existing graphics, forest, snow and weather suites pass. Run required physics/runtime if shared dispatch/session code changes. Native integration edits additionally require the documented FidelityFX lifecycle checks.
- [ ] No accepted gain comes from lower quality, resolution, effect frequency, scene density or generated-frame counts. Report control-scenario regressions, per-pass costs, bandwidth/allocation evidence when available and new memory resources.
- [ ] Recheck the 120-rendered-cap configuration after uncapped attribution, without claiming monitor delivery or latency from SDK/present counters.
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
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','reduce-dense-scene-gpu-cost-before','-Version','15','-InputTrace',$fpsTracePath,'-TrialStartSeconds','0','-TrialSeconds','15','-Upscaler','auto','-RenderScale','0.75','-TerrainGI','off','-FrameGeneration','off','-FrameCap','0','-Repetitions','3','-ProfileFrameCosts') -Label reduce-dense-scene-gpu-cost-before -TimeoutSeconds 2400 -CollectGpuMemory
./scripts/test_pc_environment.ps1 -Suites pc_graphics_suite,forest_preparation_suite,weather_suite
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
