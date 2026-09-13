---
id: "AA-20260913-141128-reduce-forest-publication-and-collision-bursts"
title: "Reduce forest publication and remaining collision frame bursts"
status: blocked
priority: P1
depends_on: []
created: "2026-09-13T14:11:28Z"
updated: "2026-09-13T19:44:34Z"
source_thread: "01a09aec-9f0a-71a3-b543-b8b9765e660d"
---

# Reduce forest publication and remaining collision frame bursts

## Outcome

Make fast skiing into and through forest boundaries smoother by reducing the
remaining scene publication and collision-refresh bursts. Diagnose event causes
and implement smaller or cheaper work units while preserving visible forest
coverage, detail and immediate required crash collision.

## Current state and evidence

- The 2026-09-13 [FPS report](../../artifacts/fps_next/REPORT.md) records the
  `d768808` packed-position improvement: forest obstacle refresh fell from
  8.477 to 6.234 ms per event; median per-run maximum remained 9.294 ms. Whole
  forest p95/p99 remained 20.072/28.786 ms. These separate metrics do not prove
  each slow frame was caused by that event; correlate current chronology.
- [DensityForest.update_residency](../../scripts/presentation/density_forest.gd)
  rebuilds its pending region list after sufficient camera movement and creates
  up to three regions per update, including asset/LOD batches. It then configures
  new batches and publishes a residency texture. A region count is not a bounded
  amount of upload/scene work. Existing subscopes distinguish scan/evict, region
  construction and publication.
- [ForestPlacement](../../scripts/presentation/forest_placement.gd) already
  prepares immutable placement data. The completed
  [spatial-batch task](../archive/AA-20260912-105303-improve-spatial-batch-visibility.md)
  retained small near/mid groups and improved distant grouping/removal; preserve
  those gains and their visibility ranges.
- [Earlier streaming work](../archive/AA-20260912-105300-reduce-streaming-frame-spikes.md)
  already warms mineral convex pieces. [CrashCollision](../../scripts/world/crash_collision.gd)
  now avoids full obstacle records for resident distance checks. Required bodies
  still publish synchronously. [World](../../docs/WORLD.md#geology-and-collision)
  and [Rendering](../../docs/RENDERING.md#terrain-forests-and-lighting) own coverage,
  lifetime and rendering contracts.
- Rebaseline current source after `d768808`; its generator-15/model-35 receipts
  are dated leads with drift, not a reusable before result. Local ignored
  artifacts can be regenerated from the current producers if unavailable.

## Agreed decisions and scope

The user requested this next investigation and fix as P1. Own measured forest
scan, eviction, batch/upload/publication work and remaining tree/collision
refresh cost in the owners above, with narrow main/diagnostic integration as
needed. GPU shader/pass cost belongs to the existing
[GPU item](AA-20260912-105302-reduce-dense-scene-gpu-cost.md); terrain/snow queries
and pelvis fitting have separate tasks. Repartition visibility only if current
evidence specifically justifies revisiting the completed spatial change.

Keep near/mid/far/shadow distances, density, transforms, masks, alpha transitions,
materials, original required coverage and physical identities. No lower 4K High
quality, reduced FSR internal scale, missing trees or delayed crash collision.
The Node-independent 120 Hz skiing solver and 4 m terrain remain authoritative.
No unbounded preload or retained history; disclose startup/memory tradeoffs.
Preserve unrelated feature work, settings and personal records.

Comparative work is FPS-sensitive: reserve actual read/write paths and use
FpsCritical under the existing guard. Ordinary isolated correctness checks may
use Shared; import/cache mutation uses Exclusive. Wait for conflicts, never nest
guards. No new task depends on this one merely to serialize timing.

## Implementation approach

1. Correlate per-frame/event timestamps for scan, eviction, allocation, buffer
   upload, batch configuration, residency texture update and collision attachment
   with slow frames. Separate cold first encounter, warmed re-entry and reversal;
   distinguish resident scans from new-body publication and native cook costs.
2. Test smaller bounded preparation/publication units, reduced redundant work,
   resource reuse and immutable off-thread preparation where supported. Engine
   scene mutation/uploads stay on supported threads. Account for the largest
   non-preemptible operation rather than claiming an absolute time guarantee.
3. Stage region work so the mask reports ready only when required batches are
   usable. Prefetch must finish before the original visible boundary; retain a
   correctness path for discontinuous travel. Cancel obsolete work without
   starvation, duplicate batches, gaps or unbounded queues.
4. Preserve immediate physical coverage at required distances and on crash,
   teleport/recovery and reverse entry. Budget optional preparation only; do not
   leave required collision pending to improve a frame-time graph. Recheck
   reload, quality changes, teardown and interrupted generation.

## Acceptance and verification

- [ ] Current chronology identifies the retained cause and shows repeatably fewer
  or shorter correlated slow frames, with improved p95/p99 beyond run variation
  and no reproducible mean-FPS/control regression. Report per-event units and
  counts separately from per-frame scopes; never add overlapping timers.
- [ ] Follow the [performance method](../../docs/VALIDATION.md#performance-method)
  using fresh labels and three independently warmed, capture-free 15-30 second
  before/after repetitions. Match current seed/model/trace/runtime, actual 4K
  High/Auto 75%, current camera and saved effects/overrides. Include affected
  forest/rock boundaries, ordinary input and an open control. Label immortal
  170 km/h stress separately. Resolve drift with return-to-original or
  counterbalanced trials; reject unfocused/source-drifting/incomplete evidence.
- [ ] Test publication, cancellation, re-entry, repeated traversal, reverse/fast
  travel, crash/recovery and teardown. Run streaming_collision_suite,
  geology_collision_suite, physics_suite and runtime_suite through the guarded
  batch. Run forest_preparation_suite with its required native renderer and add
  affected density_lod_suite/density_spatial_suite and focused lifecycle coverage
  under the [validation skill](../../.agents/skills/alpine-validation/SKILL.md).
- [ ] Separate native stills/motion and visibility/coverage comparisons establish
  no new gaps, doubled instances, late mask/detail transitions, pop-in or missing
  collision at original boundaries. Equal final resident counts alone are not
  proof of coverage because refresh cadence differs between frame rates.
- [ ] Report individual FPS/p95/p99 runs, CPU/GPU costs, draw/geometry submission,
  queue peaks, largest publication unit, startup cost and memory across repeated
  entry. Queues drain/cancel correctly and resources do not grow per traversal.
  Perform a separate normal 120-cap check and report the remaining global target
  gap; short scenarios are not full-route acceptance.
- [ ] Keep only demonstrated production gains. If no candidate qualifies, revert
  owned experiments and record blocked findings and unfinished work. Update
  owning guides and affected skills, commit/push validated owned work, preserve
  useful evidence and perform safe task-only artifact cleanup.

Human acceptance: continuous smoothness, visual comfort and controller/crash
feel remain separate follow-ups, not worker-completion gates.

## Open questions

None

## Completion record

Investigated manually on 2026-09-13 from Dev 16 (`3a2d2dd2fc6a801fb331a40957f36a2e3e056411`). **Blocked: no production candidate met the required frame-time and control acceptance.** All experimental production, test and guide edits were restored to their exact original bytes; no runtime fix is retained. The [measurement report](../../artifacts/forest_bursts/REPORT.md) retains individual runs, source/runtime audits, event chronology, submission/memory/startup costs and rejected variants.

Tested hidden per-batch forest staging, conservative immediate-detail coverage,
cheaper packed tree queries/direct cylinder attachment, and optional terrain
collision lookahead. Also isolated the tree change with original forest and
terrain paths. Tree refresh CPU cost fell from roughly 6.1 to 3.2 ms per event;
the 16-position diagnostic retained 1,895 attachments while reducing refresh
work from about 87 to 47 ms. Those CPU results are promising attribution, not
sufficient production FPS acceptance.

The combined forest comparison appeared to improve median FPS/p95/p99 from
80.709 / 17.421 / 24.839 to 83.382 / 16.504 / 21.589. Its rock control did not
hold: 89.061 original FPS versus 87.261 candidate and 85.367 on confirmation.
Final original-code controls exposed session drift (forest 76.327 FPS; rocks
86.108 FPS), so these differences do not establish a code-caused regression or
an accepted gain. Against that closing control, the tree-only candidate had
77.434 FPS with worse forest p99 (25.734 versus 24.984 ms), and 81.226 rock FPS.
No candidate established the required repeatable p95/p99 gain and stable controls.

Chronology separates the costs: required forest collision frames above 25 ms
fell from 8/6/7 to 2/1/2, but terrain lookahead added 5/1/2 separate slow frames.
A single cold terrain cook still reached 12.067 ms in forest and 14.473 ms in
rock confirmation. Smaller forest batches reduced the publication unit but
increased total publication overhead and added about 2.1 seconds to cold forest
submission. A 750 microsecond optional scheduler cannot bound a native cook.

The rejected combined candidate passed 694 headless checks across streaming
collision (42), geology collision (16), physics (56), runtime (192), density LOD
(348), and density spatial (40), plus 3,495 native forest preparation checks.
Lifecycle fixtures covered required collision, cancellation, re-entry, reverse
and discontinuous travel, quality changes and teardown. Separate 4K stills and
sampled forward/reverse views showed no added gaps; both 256-step scripted
sequences recorded zero missing required-detail observations. These checks do
not certify continuous motion, full-route performance or controller/crash feel.

The separate normal 120-cap forest check measured 76.086 FPS, p95 17.307 ms and
p99 25.781 ms; the global target remains unmet. Resume with a stable,
counterbalanced timing environment and a smaller or cheaper largest native
cook/upload operation. Preserve cold versus warmed re-entry distinctions and
rerun the full affected matrix; do not ship the microbenchmark or the best
isolated forest run as proof. Human/controller acceptance remains separate.

No replacement domain contract or skill change is retained because the
implementation was rejected. [Development note](../../changes/7516e9a7be084cc5bc81ca3fef168186.json)
records the validated investigation milestone; its containing commit identifies
delivery. Raw evidence, candidate patches and lifecycle fixtures remain under
`artifacts/forest_bursts/` and `artifacts/pc_environment/forest-bursts-*` for the
unresolved finding. Remove only unneeded task helpers after push, following the
artifact lifecycle; preserve those evidence directories.
