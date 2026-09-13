---
id: "AA-20260912-105301-reduce-animation-cpu-cost"
title: "Reduce animation and final-pose CPU cost without changing motion"
status: done
priority: P1
depends_on: ["AA-20260912-105300-reduce-streaming-frame-spikes"]
created: "2026-09-12T10:53:00Z"
updated: "2026-09-13T14:15:08Z"
source_thread: "01a09527-1988-7b50-b7c9-71ff6821cb00"
---

# Reduce animation and final-pose CPU cost without changing motion

## Outcome

Increase rendered FPS by reducing repeated animation and final-pose computation, preserving the skier's current whole-body motion, connected equipment and recording behavior.

## Current state and evidence

- The retained [v15/model-28 receipt](../../docs/V15_PERFORMANCE_BASELINE_RESULTS.json) records mean `animation_tick` 1.027 ms per fixed tick and `pose` 1.539 ms per rendered update. These have different cadences and overlapping scope boundaries; do not sum them into a claimed frame saving.
- [Main](../../scripts/main.gd) separates fixed animation updates, visible pose updates and completed-pose ghost capture. The current ghost path can evaluate a completed pose before restoring normal interpolation; verify its actual cost on the implemented build.
- [Animation](../../docs/ANIMATION.md#production-pipeline) identifies [SkierAnimation](../../scripts/presentation/skier_animation.gd), [SkierFullMotion](../../scripts/presentation/skier_full_motion.gd), [SkierVisual](../../scripts/presentation/skier_visual.gd) and the single final skeleton writer. Full motion samples retargeted clips and applies posture/anatomy/fitting; F8 procedural comparison remains live.
- Related work: [pole pushing](../tasks/AA-20260911-183812-slope-limited-pole-pushing.md) and [animated ghosts](../tasks/AA-20260911-220556-animated-ghost-snow-tracks.md). Inspect their completed sources before fixing a baseline. This task does not author different motions or reopen the abandoned animator editor.

Inspected during backlog authoring on 2026-09-12. The retained full-descent
baseline is 92.568 average rendered FPS, frame p95/p99 16.311/23.198 ms, at
3840x2160 / 2880x1620 internal, High, Auto FSR 4.1.1, FG/SDFGI off.
It predates the current model-29 feature integration and is not a new-build
measurement. No implementation, engine benchmark or rendered acceptance was
performed during authoring. Read [the baseline limits](../../docs/VALIDATION.md#performance-evidence).

## Agreed decisions and scope

The user selected all four FPS areas for separate backlog implementation.
Priority is P1. Order: [streaming](AA-20260912-105300-reduce-streaming-frame-spikes.md),
[animation CPU](AA-20260912-105301-reduce-animation-cpu-cost.md), [dense-scene GPU](../tasks/AA-20260912-105302-reduce-dense-scene-gpu-cost.md),
then [batch visibility](AA-20260912-105303-improve-spatial-batch-visibility.md). Dependencies serialize shared edits and
performance attribution; they do not authorize this authoring task to dispatch.

Own clip sampling, immutable lookup/index preparation, temporary-data allocation and repeated transform/fitting evaluation. Preserve 120 Hz physical state, source timing, action clocks, render interpolation, final anatomy, rigid boots/skis, fixed grips and the single skeleton writer. Keep ghost capture cadence and exact boundaries; never skip visible or recorded poses simply to reduce work.

During manual implementation on 2026-09-12 the user explicitly expanded the
visual scope: cheaper poses and new transition animations are permitted when
visually close or better. Exact pose preservation is a comparison tool rather
than an acceptance requirement. This supersedes the exact-transform requirement
below; physics, recording boundaries, connected equipment and rendered quality
remain required. Blender Animation MCP is available if source authoring is useful.

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

- [x] Three-run matched production comparisons show lower animation/pose CPU cost and a repeatable rendered-FPS or frame-tail improvement beyond observed noise, without a reproducible regression in control sections.
- [x] Paired ordinary-input runs preserve completed physical states and recorded pose boundaries. Frozen source/requested/final transforms are equal within declared existing numerical tolerances; any new tolerance requires a justified numerical bound and rendered evidence, not a relaxed test to hide drift.
- [x] Inspect whole-body entry/hold/release chronology for glide, tuck, left/right carving and reversal, pole pushing, takeoff/landing, grabs, crash/recovery and F8 transitions. Include chase and relevant first-person equipment views; no new clipping, grip drift or delayed motion.
- [x] Run animation/motion/steep-motion checks, focused cache/invalidation checks if added, and physics/runtime after dispatch/session changes. Include current ghost/pole suites when touching their evaluation interfaces.
- [x] Report allocations, memory, fixed-tick and render-update costs separately; preserve existing unresolved animation findings rather than claiming they are fixed by optimization.
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

Completed manually on 2026-09-12; no scheduled claim or downstream dispatch.
Implementation, focused test and animation guide committed/pushed to `main` as
**50a5c83**. The expanded visual authority above is recorded, but new clips were
unnecessary for the retained gain.

**Retained change:** `skier_full_motion.gd` prepares normalized clip samples once
per immutable script/resource lifetime, evaluates only the needed arm ancestors,
hoists pose-wide values and removes eagerly evaluated dictionary copies.
`skier_visual.gd` omits procedural limb frames only at exactly full source weight;
F8 and partial clearance blends retain both inputs. `action_posture.gd` rebuilds
the requested ancestor chain each call because parents advance within the tick.
No dynamic pose cache, pose-rate reduction, new native kernel, solver/session
change or asset modification. Ghost recording still evaluates completed poses
at its existing boundaries and restores visible interpolation.

**Matched production evidence:** fresh baseline `9614435` plus identical opt-in
profiling scopes; after is `50a5c83`. Current validated
`artifacts/streaming_spikes/scenario.json`, scenario replay, v15/model29,
seed849205174, High plus saved weather_quality 2 override, current saved camera,
3840x2160 output / 2880x1620 internal, Auto FSR4.1.1, FG/GI off. Each repetition
warms 240 frames independently, measures 15 seconds, then stops. All paired
endpoints match exactly, with no measured source drift or other engine job.

| Measurement | Before runs | After runs | Median before → after |
|---|---|---|---|
| Unprofiled opening 0–15 s FPS | 98.506,104.804,105.986 | 110.247,111.891,113.555 | 104.804 → 111.891 (+6.76%) |
| Unprofiled opening p95 ms | 14.415,13.613,13.674 | 12.618,12.401,12.280 | 13.674 → 12.401 |
| Unprofiled opening p99 ms | 17.893,15.088,15.379 | 14.644,14.351,13.929 | 15.379 → 14.351 |
| Profiled opening FPS | 93.536,95.437,97.161 | 99.304,104.683,105.461 | 95.437 → 104.683 |
| Profiled moving 15–30 s FPS | 71.721,76.437,76.238 | 75.766,76.348,71.271 | 76.238 → 75.766 |

Moving FPS varies by -0.62%, within the roughly 7% observed run spread; no
moving-FPS improvement is claimed. Its p95/p99 improve 17.583/24.199 →
17.359/22.079 ms. Profiled animation fixed-tick means fall 968.102 → 849.268 us
opening and 1424.233 → 1201.358 us moving (12.28–15.65%). Complete render-pose
means fall 1520.096 → 1420.461 us and 1649.299 → 1554.131 us (5.77–6.55%).
Different cadences/overlapping scopes must not be summed into frame savings.
Render CPU/GPU medians: opening 1.733/8.126 → 1.620/7.508 ms; moving 1.785/9.492
→ 2.005/9.946 ms. Unprofiled opening confirms the gain without active subscopes.

Separate unprofiled moving cap 120: 82.503/87.062/88.093 FPS, median p95/p99
15.682/17.731 ms. The global 90–120 FPS target remains open in moving sections;
opening p95 remains 1.301 ms above 11.1 ms. These bounded samples establish neither
full-route performance nor player acceptance.

**Resources:** preparation holds 3,985 frames / 95,640 joint samples and costs
about 2.37 MB extra engine allocation, 1.97 MB serialized, 83–86 ms once before
riding. Each sampled pose is independent. Process private peaks remain
5.52–5.58 GiB; engine static medians about 1.075 → 1.077 GiB; video allocation
3.495 GiB opening / 3.452 GiB moving. Cached setup 55–59 s, with no startup gain
claim. Isolated profiler begin/end costs .557 us disabled / 1.425 us enabled;
that diagnostic does not establish whole-game overhead.

**Mechanical verification:** the new raw-asset oracle passes 72 checks across 726
samples, including seams, endpoints, mirroring, rider isolation and ancestry.
The 17-case frozen comparison covers 22,020 rows at interpolation 0/.5/1:
physical state, source rotations, requested transforms and skis remain exact.
Final bone/pole components differ by at most 7.868e-6/7.838e-6 after removing a
redundant quaternion round trip. This uses the user's expanded visual authority;
no existing tolerance was weakened. The earlier strictly identical candidate
was superseded by this cheaper full-weight composition.

Passing checks: anatomy/steep 84, compact 36, ski attachment 20, landing 155,
airborne 10, pole push 108, ghost archive 119, crash replay 36, physics 56,
runtime 192, and native crash/recovery 105. Nine animation/motion/pole assertions
still fail with exactly the same labels on the frozen baseline. Native ghost
recording/equipment comparisons pass; its two failing 4K Records-menu input
checks also reproduce identically before/after in an isolated selector rerun.
These failures are preserved, not hidden by relaxed tests or reported as fixed.

**Rendered review:** native cached-v15 chase/front/side chronology covers
glide/tuck/release, both carve reversals, hop, landing, safety/mute grabs and
F8. Reviewed 12 phase samples per case/view from 30 Hz captures. A 15-second flat
pole-push capture includes entry/cycle/release at 60 Hz; inspected cycle/release
samples. Native ghost playback and all 26 crash/recovery phase thumbnails,
plus selected original frames, cover recorded motion and first-person/chase
reset. No new offset or snap was identified in those sampled phases; this is
not an every-frame visual or human/controller acceptance claim. Snow sometimes
occludes skis; ten overlapping ghosts expose interior faces in first-person.
Selected first-person recovery views have limited equipment visibility.
An obsolete-v13 setup attempt was stopped before riding and replaced with a
cached-v15 fixture; it supplies no performance or acceptance evidence.

**User's excessive-carve finding:** a focused 12-case diagnostic reproduces a
26.56-degree body lean and 0.400 m sideways pelvis at only 0.188 m/s² lateral
acceleration after reversal, with action weight 0.009 but deeply edged physical
skis. The existing rigid-cuff/leg fit forces this residual body inclination.
A transition clip can smooth entry but cannot resolve that sustained constraint.
No physical retune or claim that this visual defect is fixed is included; the
existing [Carving finding](../../docs/ANIMATION.md#carving) remains authoritative.
Human/controller preference and listening remain pending. No separate next-step
proposals or executable tasks were added.

**Reproduction and retention:** [Animation](../../docs/ANIMATION.md#runtime-preparation-and-cost)
owns preparation lifetime, evaluation boundaries and profiler scope contracts.
Detailed individual distributions, source/settings hashes, commands, resources,
failure comparisons and reviewed views are in `artifacts/animation_cpu/REVIEW.md`,
`comparison.json`, `resources.json`, `existing_failures.json`,
`selector-comparison.json`, paired captures and native folders; benchmark
receipts are in `artifacts/pc_environment/animation-cpu-*`. Recovery output is
`artifacts/orchestration_20260912/crash/lifecycle-native-5396-2063250/`.
Engine worker SHA256:
`a18ddc9f3ee8fa1915a47d54c3e0d05ec4b10f8ee9deb15d7206b4e23d29bcc9`;
launcher `0c4e9e4d32c3e550189f463efbf16bd7325cd26eae69b6718a40dc4088ef0b0b`.
Useful evidence is retained for unresolved findings and review. After push,
only the superseded candidate1 raw dump was removed under the validation lock;
its comparison/source and the final paired captures remain. Other tasks' outputs
and initial unrelated untracked files were preserved.

**Archived on 2026-09-13:** completed implementation and acceptance history remain
`done`; the broader optimization path is not declared exhausted. Remaining work
is scoped in the [new focused task](../tasks/AA-20260913-141128-reduce-pelvis-fitting-cpu-cost.md).
This archival does not reopen implementation or invalidate completed dependencies.
