---
id: "AA-20260912-105302-reduce-dense-scene-gpu-cost"
title: "Reduce dense-scene GPU cost while preserving visual quality"
status: in_progress
priority: P1
depends_on: ["AA-20260912-105301-reduce-animation-cpu-cost"]
created: "2026-09-12T10:53:00Z"
updated: "2026-09-12T17:18:41Z"
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

Preserve the production Node-independent 120 Hz solver, 4 m support, ordinary inputs,
race/replay authority, current visual quality and personal settings/records.
Follow [engine strategy](../../docs/ARCHITECTURE.md#engine-strategy).
Coordinate with active owners before editing overlapping files; freeze source
and settings for each comparison. Unrelated feature completion is not silently
claimed or added as a prerequisite. Rebaseline after completed changes.

**User test direction, 2026-09-12:** use immortal **170 km/h** stress trials
as the primary high-speed rendering workload. Full tuck, no braking, continued
travel through fatal/obstacle events, and actual speed/distance receipts are
required. The explicit benchmark-only driver and fixture identity are owned by
[Validation](../../docs/VALIDATION.md#immortal-high-speed-stress-trials).
Rebaseline open/mineral/dense-forest sections at this speed. Earlier slow/stalled
ordinary replays remain diagnostic history, not the primary acceptance workload.
Production physics, input/replay behavior and personal settings remain unchanged.

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
  the before measurement. Use the agreed 170 km/h stress sections covering the
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
high-speed stress preparation. `fpsTracePath` below denotes that real file; do not create
a placeholder trace or bypass its identity checks. Choose the section start to
include the observed event, not automatically the historical 90-second window.
The example uses a 15-second section from its start:

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','reduce-dense-scene-gpu-cost-before','-Version','15','-InputTrace',$fpsTracePath,'-ScenarioReplay','-StressSpeedKmh','170','-TrialStartSeconds','0','-TrialSeconds','15','-Upscaler','auto','-RenderScale','0.75','-TerrainGI','off','-FrameGeneration','off','-FrameCap','0','-Repetitions','3','-ProfileFrameCosts') -Label reduce-dense-scene-gpu-cost-before -TimeoutSeconds 2400 -CollectGpuMemory
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

Initial investigation on 2026-09-12; reopened for continued manual implementation. **No production optimization
was accepted or retained.** The tested GPU savings did not establish a rendered
FPS or frame-tail gain beyond observed variation. No scheduled claim, downstream
dispatch or separate next-step proposal was made.

**Fresh baseline:** `95ef3a3`, default seed 849205174, generator 15/model 29,
3840x2160 output / 2880x1620 internal, High/Auto FSR 4.1.1, clear/day, FG/GI off,
uncapped, current camera and saved `weather_quality: 2` override. Each window
used three independently warmed (240 frames), capture-free 15-second ordinary
input repetitions; every endpoint matched, all frames stayed focused, source
hashes stayed fixed and no competing engine was observed.

| Window | Median rendered FPS | Frame p95 / p99 ms | GPU mean ms | Render CPU mean ms |
|---|---:|---:|---:|---:|
| Open snow, 0-15 s | 104.74 | 13.987 / 16.686 | 7.116 | 1.627 |
| Minerals, 15-30 s | 77.57 | 17.625 / 20.213 | 8.267 | 1.838 |
| Woodland edge, 165-180 s | 70.95 | 20.606 / 25.256 | 8.640 | 2.069 |

Private-byte peaks were 5.51-5.58 GiB. Background ChatGPT and PowerShell activity
was recorded and preserved. Windows allocation counters are not physical VRAM
occupancy. The dense/mineral samples still miss the 90-120 rendered FPS,
p95 <=11.1 ms and p99 <=16.7 ms targets.

**Native attribution:** a separately resimulated 240-second offline control
prefix supplied a 225-240 s diagnostic with 163-286 trees within 175 m; this
was not a rendered full descent. Its one profiled trial reached 68.71 FPS.
GPU means: depth prepass 1.504 ms, moving geometry 1.531, opaque geometry 1.002,
shadows .380, transparent geometry .493, SSIL .475, SSAO .200, fog .085 plus
filter/integration, glow .557, tonemap .331, and the native FSR interval 1.844.
The engine calls that last marker `FSR2`, but the active provider was 4.1.1.
These diagnostic pass intervals are not acceptance repetitions or isolated
shader-instruction costs. The separately instrumented powder reconstruction
cost .033 ms in the opening; its extra query boundaries altered submission.

**Rejected experiments:** exact-zero crystal coverage, invisible local-patch
shading, zero-opacity particle fragments, and zero-visibility lighting branches
produced negligible changes. Disabling powder entirely saved about 1 ms but
changes quality and was diagnostic only. Removing its cloud light saved only
about .04 ms. A shared-tile reconstruction filter passed 25 byte-exact native
comparisons plus the existing 13 upload/lip checks; its .033 ms baseline cost
was too small to justify advancing it as the main bottleneck. All experiments
remain isolated in task artifacts; runtime shaders and geometry are unchanged.

Tiled powder triangle ordering reduced the named moving-geometry interval by
about .076 ms in its pilot. A subsequent capture-free, interleaved A/B/B/A/A/B
comparison rejected delivery: medians were **108.35 -> 107.57 FPS**, GPU
**7.100 -> 6.953 ms**, p95 **13.501 -> 13.562 ms**, p99 **16.407 -> 16.299 ms**.
All six endpoints/focus checks passed. That small tail difference is within the
run spread; an isolated GPU reduction is insufficient under this task's gate.

**Retained tooling and remaining work:** `benchmark_pc.ps1 -ProfileGpuPasses`
now exposes the validated named-pass collector through the existing isolated
benchmark. [Validation](../../docs/VALIDATION.md#native-gpu-pass-attribution)
owns reproduction, delayed-frame interpretation, bounds and instrumentation
limits. Further work needs a materially larger shader/pass candidate, with
finer vertex/pixel or native renderer attribution if necessary, followed by
three matched production repetitions, controls, rendered still/motion review,
relevant suites and the 120-cap check. Those optimization acceptance gates
remain open; no visual or human/controller acceptance is claimed.

**Receipts:** detailed runs, settings/identities, rejected candidates, native
query records and exact commands are retained in `artifacts/dense_scene_gpu/`
(`comparison.json`, `index_pairs.json`, `compute_oracle.json`, `REVIEW.md`) and
`artifacts/pc_environment/dense-gpu-*`. Worker SHA256:
`a18ddc9f3ee8fa1915a47d54c3e0d05ec4b10f8ee9deb15d7206b4e23d29bcc9`;
launcher `0c4e9e4d32c3e550189f463efbf16bd7325cd26eae69b6718a40dc4088ef0b0b`.
Evidence is retained for this unresolved investigation; cleanup is deferred.

**Tooling validation:** the delivered profiler passed a native 3-second replay:
301 named-pass frames, zero dropped records, ordered GPU IDs/timestamps, exact
endpoint, no focus loss or source drift. Headless mode rejected with expected
exit 2. Backlog validation and CRLF-aware diff checks passed. Personal settings
and race records were unchanged; only generation-duration telemetry changed.
The retained change is test tooling/documentation, so no runtime physics or
visual acceptance is inferred. Delivery hashes are retained in
`artifacts/dense_scene_gpu/delivery.json`.

**Delivery:** profiler and authoritative validation guide committed and pushed
to `origin/main` as `2a1c989987f40dc506d721b99ce47b471ded09fb`. This task record
preserves the unresolved optimization and rejected-candidate evidence.

**Reopened by the user on 2026-09-12:** there is no external blocker. Rejected
candidates remain evidence, not a reason to stop investigation. Status is
`in_progress` for this manual task; no scheduled claim is taken. Continue
measuring the largest native passes and testing larger equivalent-work
reductions against the existing quality and repeated-performance gates.
