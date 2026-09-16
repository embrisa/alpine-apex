---
id: "AA-20260912-105302-reduce-dense-scene-gpu-cost"
title: "Reduce the largest remaining dense-scene GPU passes"
status: blocked
priority: P1
depends_on: ["AA-20260912-105301-reduce-animation-cpu-cost", "AA-20260914-094136-establish-repeatable-rendering-baseline"]
created: "2026-09-12T10:53:00Z"
updated: "2026-09-14T13:37:31Z"
source_thread: "01a09527-1988-7b50-b7c9-71ff6821cb00"
---

# Reduce the largest remaining dense-scene GPU passes

## Outcome

Raise actual rendered FPS in dense terrain and forest scenes by making expensive rendering passes cheaper while preserving the current 4K presentation, lighting, foliage and snow.

## Current state and evidence

**Current direction, 2026-09-14:** the user requested large FPS gains, including
rendering fundamentals, and explicitly asked to revise/create thorough backlog
tasks. This replaces the former small-shader-pilot focus for later dispatch;
it does not resume an old Codex task now. Origin: 01a09c68-b71e-7cc1-b01a-291cd5c446e8.
Preserve the complete dated investigation history in the completion record.

Source inspected at Dev 31 / 36b25d3. The newer
[forest receipt](../../docs/COLORFUL_FOREST_RESULTS.json) reports candidate
67.06/68.24/68.61 FPS, median GPU mean 12.106 ms, p95 18.810 ms and p99 24.504 ms
at 4K High/Auto FSR 4.1.1 at 0.75 scale. Median submissions are about 1,620 draws
and 13.737 million primitives per frame. These are scene totals, not a named-pass
breakdown or proof that all geometry is rasterized. The last tree integration
was functional/rendered acceptance, not closure of the global FPS gate.

The [gravel receipt](../../docs/ROCK_GRAVEL_RESULTS.json) exposes repeatability
problems: Standard off/all/repeated-off medians 85.24/91.23/81.06 FPS; all-gravel
also had lower GPU time than both controls. This establishes no causal mountain
speedup. Its 41.67 m shelf-to-snow route is not dense forest. Local all-gravel
adds about 0.573 ms GPU near the 120 cap; removing this cosmetic component cannot
be presented as the solution to the distinct forest bottleneck.

The new [baseline prerequisite](AA-20260914-094136-establish-repeatable-rendering-baseline.md) owns renewed pass attribution,
controlled workload/camera identities and drift analysis. It consolidates the
dated observations and their limits. Its completion does not make a stale trace
or before result reusable after later changes.

Existing paths already include packed placement, terrain LOD, tree impostors,
stable shadow proxies, worker preparation and native FSR. The
[terrain/snow query task](AA-20260913-141128-reduce-terrain-and-snow-query-cost.md)
is completed: exact height-only/contact and channel-floor work improved bounded
CPU/FPS samples without changing support. Preserve it rather than re-proposing
the same cache/query changes. Accepted animation and spatial-batch work also
remain distinct results.

Older native rock attribution found roughly 1.93 ms reconstruction, 1.70 ms depth,
1.58 ms opaque and 1.43 ms motion work, with smaller shadow/post intervals. Those
model-30 values guide investigation only. The FSR2 engine marker wraps the actual
selected provider, including native FSR 4.1.1; it does not prove FSR2 was active.
Earlier local powder reconstruction was only 0.033 ms and adding timestamps
altered its submission cost. Zero-opacity/coverage and reordered-triangle probes
failed the production gate. Their exact negative results below remain binding
history; revisit only if a fresh cost premise materially changes.

Production owners include [terrain material](../../assets/graphics/alpine_surface_fragment.gdshaderinc),
[forest shading](../../assets/graphics/pc_forest_tree.gdshader),
[cards](../../assets/graphics/pc_tree_impostor.gdshader),
[world render submission](../../scripts/world/alpine_world.gd),
[terrain preparation](../../scripts/world/terrain_preparation.gd), and tracked
[custom engine patch](../../native/fidelityfx/godot-4.7.2.patch).
Do not ship edits that exist only inside ignored .tools engine sources.
Missing ignored reports require supported fresh diagnostics; no implicit map bake.

## Agreed decisions and scope

Priority remains P1. Own substantial GPU pass/material/geometry-processing work
after current named attribution. The [baseline](AA-20260914-094136-establish-repeatable-rendering-baseline.md) is the only new
measurement prerequisite. The completed animation prerequisite stays valid.
Separate task owners are [tree selection](AA-20260914-094136-select-forest-lods-before-submission.md),
[distant stand representation](AA-20260914-094136-render-distant-forest-stands.md), [occlusion](AA-20260914-094136-cull-scenery-behind-terrain.md), and
[publication/collision bursts](AA-20260913-141128-reduce-forest-publication-and-collision-bursts.md). Do not duplicate their implementations
or add a dependency solely to serialize engine workloads. Reserve literal paths,
coordinate overlaps and rebaseline after any delivered change.

The user authorizes aggressive technical changes when evidence supports them:
pass specialization, substantial material algorithms, render-only terrain LOD
or derived material data, native kernels and narrow custom-Godot patches are
within scope. Godot, the Node-independent 120 Hz solver and shared 4 m terrain
authority remain fixed. No blanket C++ rewrite, engine switch or schema layer is
required. Source/asset/import/UID preservation, LFS budget and reproducible build
contracts continue to apply.

Maintain 4K High output, actual 0.75 internal pixels/provider, scene density and
perceptible detail reach, shadows, wind/contact, weather, snow relief and tracks.
Algorithms or intermediate representations may change with visually equivalent
or better results. Reduced effects/frequency, resolution/density or generated
frames do not count as gains. A representation change must not be disguised as
an unreviewed quality reduction. No physical map regeneration or deferred tree
thinning. Preserve ordinary input, collision, race/replay and personal records.

The bounded matrix is the baseline task's dense ordinary forest, affected open/
mineral controls and separately labelled immortal 170 km/h full-tuck/no-brake
stress. Stress regulates speed and prevents fatal stops only in the diagnostic
driver; it is not handling/crash acceptance. Use separate native still/motion
review and a normal 120-cap check. Human acceptance remains a follow-up.

## Implementation approach

1. Consume the baseline task's current cost ranking, then capture a fresh before
   result for this exact source/runtime. Identify whether the dominant interval
   is vertex/geometry work, cutout overdraw, fragment sampling, bandwidth,
   synchronization/copies or reconstruction. Define a credible removable-cost
   upper bound and choose one mechanism; percentages from unrelated scenes do
   not justify an intervention. Instrumentation overhead stays separate.
2. If depth/opaque/motion geometry dominates, inspect actual render lists and
   material variants. Test equivalent depth/velocity specialization, elimination
   of truly redundant submissions, or shared deformation/results across passes.
   Never assume all three passes duplicate the same objects: the pinned renderer
   splits static/dynamic work. Preserve alpha coverage, displacement, normals,
   light/shadow dependencies and current/previous transforms. Evaluate extra
   buffers and barriers together with saved geometry/vertex work.
3. If terrain fragment work dominates, inspect the active material's projected
   detail and repeated noise/triplanar sampling. Evaluate a substantial derived
   material field or distance-specialized path only where it replaces measured
   work and preserves snow/rock transitions, slope detail and weather. The older
   tiny powder reconstruction cache is not this candidate. Include cache build,
   invalidation, upload/bandwidth and memory cost; avoid screen-visible seams.
4. If terrain geometry cost is substantial, evaluate more efficient render-only
   chunk/LOD or clipmap representation from the same exact 4 m support. Near ski
   contact, powder replacement, terrain seams and skyline error must remain
   correct. Current CrashCollision creates trimeshes from render chunks: first
   separate its exact triangle source if render topology changes, so simplifying
   graphics cannot silently simplify ragdoll collision. The physical generator
   and solver stay unchanged. Coordinate this boundary with the burst task.
5. If reconstruction/post work dominates, inspect the native FidelityFX path's
   copies, transitions, reactive/history inputs and queue synchronization. A
   narrow patch may remove redundant transfers or equivalent work; disabling
   the provider/effects or worsening reconstruction is not acceptance. Preserve
   resize, minimize/resume, device/context reset, UI exclusion and motion history.
   Track source, build/runtime selection and package integration in the repo.
6. Evaluate one substantial candidate against the unchanged before source. A
   second prototype needs a new measured premise, not another zero-work branch
   search. Include CPU/render-thread regressions and effects on open/rock/forest
   controls. Retain all first repetitions and return controls. If named GPU cost
   falls without net rendered-FPS or frame-tail gain, investigate the new limit
   before retaining the change; do not declare success from a microbenchmark.
7. Verify affected quality tiers, clear/cloud/snowfall/night and relevant effect
   toggles after High passes. Keep low-impact task scope; do not implement new
   scenery, map ecology, mountain-shadow features or unrelated animation work.

## Acceptance and verification

- [ ] The baseline prerequisite is complete and a fresh current comparison
  attributes the chosen substantial mechanism. Report a removable-cost estimate,
  actual pass/object coverage and any moved cost; do not sum overlapping passes
  or inherit an older camera/source result as the before measurement.
- [ ] Native renderer changes are reproducible from tracked source/patches and
  packaged engine identity. Exercise affected FidelityFX resize/reset, fallback,
  FG-off/on lifecycle and current/previous motion history through the maintained
  native validation route; SDK/present counters are not latency acceptance.
- [ ] Render-topology changes retain exact independent 4 m crash triangles and
  solver support. Run affected terrain/grounding and collision checks, plus
  physics_suite/runtime_suite for physical/input/session changes. Material-only
  changes require affected graphics/snow/forest/weather suites and rendered review.

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

**Manual investigation, 2026-09-14: blocked; candidate rejected.** The user's
current request authorized this bounded implementation attempt. The broader
rendering-baseline prerequisite remains blocked; this narrow fresh A/B/A does
not close it. No production optimization is retained.

[Investigation and next gate](../../docs/DENSE_GPU_ENCODING.md) and
[individual trials/native intervals](../../docs/DENSE_GPU_ENCODING_RESULTS.json)
record Dev 34 source `4163162`, the unchanged model-35 ordinary forest trace,
4K High/0.75/FSR 4.1.1, three warmed 15-second before/candidate/return repetitions,
six local vegetation timings and two separate native GPU profiles.

Full vertex compression failed normal/tangent preservation and was stopped.
The UV-only refinement passed 355,860 focused checks and reduced ten render
meshes' vertex/attribute streams by 20%, while retaining original resources.
It added approximately 244 ms of one-time production setup. Dense median FPS
was 69.33 before, 70.19 candidate and 69.56 after restoration; candidate GPU mean
was only 0.42% lower than the return, with worse p95/p99 and first-repetition
spikes of 96.388 ms (ordinary) and 88.222 ms (profiled). Local median FPS fell
1.05%. Shared depth/opaque intervals fell about 0.117 ms in separate profiles;
this does not establish a reliable net benefit or per-object bandwidth cause.

Original runtime bytes were restored and temporary runtime scripts/includes
removed. Original source assets/imports/UIDs, 120 Hz solver, shared 4 m support,
collision, replay and records remain unchanged. Native local detail/overview/
riding stills showed no gross discrepancy, but full motion/weather/quality and
open/mineral/stress/capped-production acceptance was stopped after the failed
primary performance gate. Human/controller acceptance is untested. The restored
sample remains 69.56 FPS, p95 17.943 ms and p99 22.840 ms against the task targets.

Next gate: measured pass/object coverage and a new substantial removable-cost
premise, plus the unresolved baseline and remaining candidate acceptance matrix.
Do not repeat this storage mechanism from byte-count savings alone. Detailed
negative evidence and exact candidate sources remain under
`artifacts/dense_gpu_20260914/` and `artifacts/pc_environment/dgp-forest-*`.
Delivery identity and final verification are recorded in
[the development note](../../changes/a04955ba95af4528bb9f5dae1e39f228.json);
find its containing commit through `scripts/versioning.py history`. All earlier dated history below is preserved.

### Prior investigation history (retained)

**Ready for renewed backlog work, 2026-09-13:** the user's new request authorizes
the focused investigation above for later dispatch and supersedes the historical
pause below for backlog eligibility only. No worker is claimed or launched and
the former Codex task is not resumed. Preserve the following dated history;
completion remains pending until an equivalent-quality production gain passes
the acceptance gates. Record the new baseline, ranked pass evidence, successful
and rejected candidates, actual tests, rendered comparisons, individual timing
runs, remaining target gap, human acceptance and commit/push references.

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

**170 km/h workload milestone, 2026-09-12:** the user committed the explicit
immortal stress driver, its checks and the saved Dense forest fixture in
`0c59e6b`. After the requested raid pause, surveyed 750 rock-rich starts and
resimulated eight separated candidates. Excluded routes that stalled despite
the speed override. Saved the rendered Rock field case at X/Z `-736,288`:
48-196 nearby non-glacier rock bounds per second, 398 distinct rocks, 707.66 m
travel in 15 seconds, 39 nonblocking contacts and 35 prevented fatal rock
impacts. Native 4K selection passed all trajectory/speed/focus checks; eight
selection stills are separate from timing. A subsequent native pass-profile
run also passed, with zero source drift. Locations, fixture links and stale-
trace regeneration rules are maintained in Validation. Forest and rock cases
are workload coverage; no new production GPU optimization is claimed.

Receipts: `artifacts/high_speed_stress/rock_candidates.json`,
`artifacts/pc_environment/high-speed-rock-visual/` and
`artifacts/pc_environment/high-speed-rock-passes/`. The earlier forest visual
capture had 27 unfocused frames and is visual-only evidence; its separate
three capture-free timing repetitions passed. Evidence is retained while GPU
optimization and visual review remain active.

**Paused by the user on 2026-09-13:** this investigation did not deliver an
accepted production GPU optimization and is paused for now. Status is `blocked`
pending an explicit user decision to resume; do not automatically retry it or
treat it as an active implementation. This supersedes the reopening instruction
above. Preserve the profiler, workload fixtures, rejected-candidate findings and
unresolved acceptance evidence. The user reports gains from the other three FPS
areas (streaming, animation CPU and spatial batch visibility); their completed
results remain separate and are not attributed to this investigation. Independent
eligible backlog work can proceed when the normal activity/ownership checks pass.

**Narrow ALU result, 2026-09-16 (Fable, task `AA-20260916-084513`, macOS):**
the forest tree shaders now evaluate wind sines/cosines once per vertex
(exact); an exact zero-angle early-out cost 0.6 ms on Metal and was rejected;
cloud-noise texture baking cannot reproduce the aperiodic pattern and stays
open. Whole-frame Mac means moved 24.8 -> 24.7 ms, inside noise. This task
remains `blocked` as before; no production GPU optimization is claimed here.

