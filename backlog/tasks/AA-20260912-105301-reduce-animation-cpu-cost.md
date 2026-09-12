---
id: "AA-20260912-105301-reduce-animation-cpu-cost"
title: "Reduce animation and final-pose CPU cost without changing motion"
status: ready
priority: P1
depends_on: ["AA-20260912-105300-reduce-streaming-frame-spikes"]
created: "2026-09-12T10:53:00Z"
updated: "2026-09-12T10:53:00Z"
source_thread: "01a09527-1988-7b50-b7c9-71ff6821cb00"
---

# Reduce animation and final-pose CPU cost without changing motion

## Outcome

Increase rendered FPS by reducing repeated animation and final-pose computation, preserving the skier's current whole-body motion, connected equipment and recording behavior.

## Current state and evidence

- The retained [v15/model-28 receipt](../../docs/V15_PERFORMANCE_BASELINE_RESULTS.json) records mean `animation_tick` 1.027 ms per fixed tick and `pose` 1.539 ms per rendered update. These have different cadences and overlapping scope boundaries; do not sum them into a claimed frame saving.
- [Main](../../scripts/main.gd) separates fixed animation updates, visible pose updates and completed-pose ghost capture. The current ghost path can evaluate a completed pose before restoring normal interpolation; verify its actual cost on the implemented build.
- [Animation](../../docs/ANIMATION.md#production-pipeline) identifies [SkierAnimation](../../scripts/presentation/skier_animation.gd), [SkierFullMotion](../../scripts/presentation/skier_full_motion.gd), [SkierVisual](../../scripts/presentation/skier_visual.gd) and the single final skeleton writer. Full motion samples retargeted clips and applies posture/anatomy/fitting; F8 procedural comparison remains live.
- Related work: [pole pushing](AA-20260911-183812-slope-limited-pole-pushing.md) and [animated ghosts](AA-20260911-220556-animated-ghost-snow-tracks.md). Inspect their completed sources before fixing a baseline. This task does not author different motions or reopen the abandoned animator editor.

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

Own clip sampling, immutable lookup/index preparation, temporary-data allocation and repeated transform/fitting evaluation. Preserve 120 Hz physical state, source timing, action clocks, render interpolation, final anatomy, rigid boots/skis, fixed grips and the single skeleton writer. Keep ghost capture cadence and exact boundaries; never skip visible or recorded poses simply to reduce work.

Preserve the Node-independent 120 Hz solver, 4 m support, ordinary inputs,
race/replay authority, current visual quality and personal settings/records.
Follow [engine strategy](../../docs/ARCHITECTURE.md#engine-strategy).
Coordinate with active owners before editing overlapping files; freeze source
and settings for each comparison. Unrelated feature completion is not silently
claimed or added as a prerequisite. Rebaseline after completed changes.

## Implementation approach

1. Follow the [animation skill](../../.agents/skills/alpine-animation/SKILL.md); freeze matched source, requested and final-pose baselines before editing.
2. Profile source sampling, blends, hierarchy transforms, anatomy limits, pelvis/limb fitting, writer submission and ghost-related repeat evaluations separately. Determine which results actually repeat with identical inputs.
3. Prefer packed reusable scratch storage, precomputed immutable indices and removing redundant calculations. Any cache must include all state/interpolation/settings dependencies and have bounded lifetime and explicit invalidation.
4. Reuse a result only when visible and recording evaluations request the same state and interpolation. Test discontinuities, F8 blending, mirror state, equipment changes and multiple render cadences.
5. Consider a substantial native kernel only if the measured remaining work justifies conversion, copy, synchronization and packaging costs. Retain only changes with whole-game benefit, not merely faster isolated functions.

## Acceptance and verification

- [ ] Three-run matched production comparisons show lower animation/pose CPU cost and a repeatable rendered-FPS or frame-tail improvement beyond observed noise, without a reproducible regression in control sections.
- [ ] Paired ordinary-input runs preserve completed physical states and recorded pose boundaries. Frozen source/requested/final transforms are equal within declared existing numerical tolerances; any new tolerance requires a justified numerical bound and rendered evidence, not a relaxed test to hide drift.
- [ ] Inspect whole-body entry/hold/release chronology for glide, tuck, left/right carving and reversal, pole pushing, takeoff/landing, grabs, crash/recovery and F8 transitions. Include chase and relevant first-person equipment views; no new clipping, grip drift or delayed motion.
- [ ] Run animation/motion/steep-motion checks, focused cache/invalidation checks if added, and physics/runtime after dispatch/session changes. Include current ghost/pole suites when touching their evaluation interfaces.
- [ ] Report allocations, memory, fixed-tick and render-update costs separately; preserve existing unresolved animation findings rather than claiming they are fixed by optimization.
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
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','reduce-animation-cpu-cost-before','-Version','15','-InputTrace',$fpsTracePath,'-TrialStartSeconds','0','-TrialSeconds','15','-Upscaler','auto','-RenderScale','0.75','-TerrainGI','off','-FrameGeneration','off','-FrameCap','0','-Repetitions','3','-ProfileFrameCosts') -Label reduce-animation-cpu-cost-before -TimeoutSeconds 2400 -CollectGpuMemory
./scripts/test_pc_environment.ps1 -Suites skier_animation_suite,skier_motion_suite,steep_motion_suite,physics_suite,runtime_suite
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
