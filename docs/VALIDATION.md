# Validation and acceptance

## Execution

Use [current source identities](ARCHITECTURE.md#current-identity), not the version
embedded in an old filename. Run engine workloads serially through
`scripts/run_guarded.ps1` or an owning wrapper; do not nest guards. Occupied
`artifacts/validation.lock` means wait. The guard waits automatically (up to
`-WaitTimeoutSeconds 3600` by default), reports the owner when available, and
records queue time separately from `-TimeoutSeconds` for the workload. A wait
timeout writes a separate request receipt without replacing the active owner's
logs. The guard owns only its launched process tree and records timeout/engine/
driver failures. Existing user apps are preserved.
Explicitly authorized concurrent functional checks cannot establish performance.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/physics_suite.gd') -Label physics
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/runtime_suite.gd') -Label runtime
```

For a PowerShell target with named parameters, invoke native `pwsh` with
`@('-NoProfile','-File',SCRIPT,...)`; string-array splatting directly into a .ps1
can bind named-looking strings positionally. Use repository-relative trace
output paths; an inline `res://` argument can split at its colon in PowerShell.
Inspect actual engine errors as well as exit codes/JSON presence.

The guard streams stage/progress/error lines and a ten-second running notice.
Full stdout/stderr remain in `artifacts/guarded/LABEL/`; `-OutputMode all` also
streams individual passing assertions and complete long lines. `quiet` suppresses
child output, not lifecycle notices. Engine/parse errors fail immediately;
assertion failures also fail the final receipt even if the child exits zero.

`scripts/test_pc_environment.ps1` owns one guard when invoked directly and reuses
an inherited guard when wrapped. It runs the entire batch serially, stops after
the first failing suite, and records subsequent suites as `not_run` in `run.json`.
`-ContinueOnFailure` requests the rest of the assertion-failure inventory; engine
errors/timeouts still stop the guard. `results.json` contains completed suites,
check counts, wall times and any emitted stage timings. Neither old logs nor
unrun suites establish a pass. The whole suite list is checked before launch.

```powershell
./scripts/test_pc_environment.ps1 -Profile input -PlanOnly
./scripts/test_pc_environment.ps1 -Suites controller_input_suite,haptics_suite
./scripts/test_pc_environment.ps1 -Profile core
```

| Profile | Serial headless selection |
|---|---|
| `core` (default) | Physics, runtime |
| `input` | Controller input, haptics, then physics/runtime |
| `graphics` | Graphics settings, PC graphics settings |
| `generation` | Current v15 estimates, archive/recipe contracts, scenery integrity |

These are focused selections, not universal acceptance gates. Explicit `-Suites`
accepts a PowerShell array or comma-separated names, including with `pwsh -File`.
Historical generation suites are available only by explicit selection. Run the
affected small checks while iterating, then the required complete checks after
the change stabilizes. Repeat successful checks only for new changes or unresolved
concerns. Documentation-only edits do not require the engine batch.

Physics/runtime emit `TEST_STAGE_START` and `TEST_STAGE` with wall milliseconds;
standalone timing JSON is in `artifacts/validation_timings/`, or the batch output
directory. These timings expose fixture/setup/simulation costs; they are not
rendered FPS or user acceptance.

2026-09-11 single before/after headless pair: the physics suite fell from
57.72 to 47.58 seconds after collecting the ten-second speed and speed-band
measurements during the existing full laboratory descent. All 56 assertions and
all non-timing result values matched; that stage fell from 20.07 to 9.50 seconds.
Runtime retained its real scene construction/reload and passed 192 checks.
Evidence: `artifacts/validation_turnaround/comparison.json`, `baseline/` and
`optimized/`. This is one diagnostic pair, not a guaranteed latency bound.

Warm v15 contracts, scenery-integrity checks, trace generation and production
descent playback use `tests/validation_mountain.gd`. It reuses the production
source/engine key, archive checksums and structural restore validation, and fails
on a missing/incompatible Standard fixture without starting a cold bake. Prepare
the current Standard mountain explicitly through normal generation or
`tests/generation_v15_baseline.gd` under the guard before rerunning. Cold generation,
cancellation, determinism, capacity and export checks remain separately selected;
the warm profile does not replace them or skip source/engine validation.

## Bounded test descents

Agents default to short, timed descents for diagnostic data and iteration. A
complete mountain run is not required to inspect handling, animation, camera,
effects, audio or local frame cost.

- Before launching, name the question, relevant terrain/event, measured duration
  and stop condition. Default to **15–30 seconds of riding**; use less when one
  event answers the question. Separate loading and warm-up from the sample.
- Set a duration/tick limit in the harness, or save a bounded input clip and
  replay to its captured final tick. End cleanly and flush evidence at the limit
  or after the target event and its recovery. A guard wall timeout is a failure
  backstop, not a successful sample boundary; budget setup separately.
- Start near the relevant feature using a supported test launch/fixture, or reuse
  a matching short recording. During measurement, use ordinary inputs and the
  unchanged solver. Do not teleport through a route to claim descent performance.
- One sample is enough for an initial diagnostic. For a performance comparison,
  use three independently warmed repetitions of the same bounded scenario before
  and after, with matched identities/settings and the performance method below.
  Repeat only for changed code, failures, noise or an unresolved question.
- Going beyond **60 seconds of measured riding per sample**, or choosing a full
  descent, requires a recorded coverage reason before launch. Valid reasons
  include finish/record/replay completion, an issue that appears only after
  prolonged riding, whole-route coverage or an explicitly requested full-run
  baseline. Agents may select these when the task needs them without asking for
  routine permission. Extend only enough to cover that requirement.
- Record actual riding seconds/ticks, setup/warm-up time, launch/route/event,
  source/seed/settings, stop reason and collected metrics. Label bounded results
  as scenario evidence; they establish only the sampled conditions. Keep visual,
  performance and human/controller/listening acceptance separate.

Use [player recordings and short scenarios](#player-recordings-and-short-scenarios)
for existing early-save and exact-stop replay support. The interactive recorder
does not currently expose a duration option: save at the planned boundary, then
close it to release the guard. An unattended harness must provide its own clean
timed stop; do not assume the wrapper timeout saves a clip. Existing complete-trace
benchmark requirements remain intact, and mandatory physics/runtime suites still
run in full when required by the agent contract.

## Check selection

Paths in this table are under `tests/` unless noted.

| Change | Relevant checks |
|---|---|
| Physics/input/session | Required physics/runtime; focused contact, carving, jump, flight, impact, race/replay tests |
| Controller/haptics | `controller_input_suite.gd`, `haptics_suite.gd`, native `controller_input_playtest.gd`; actual hardware acceptance separate |
| Snow contact | `scripts/validate_snow_contact.ps1 -Stage checks`, then visual/mountain/timing for changed presentation |
| Animation/fitting | Animation skill's Regression stages; anatomy, attachment, motion, relevant flight/landing and full clothing audit; chronological rendered review |
| Pose-review tools | `pose_review_tools_test.py`, affected real-capture commands, `pose_review_state.test.cjs` for feedback state; native smoke if rendering changes |
| Generation/cache | Existing v15 generation/cache/recipe/cancellation/export suites; cold/worker determinism and actual requested/achieved populations |
| Default-v15 routes | `alpine_v15_route_audit.gd`, then `python tests/report_v15_route_audit.py`; six surveys and one bounded ordinary-input pilot per face; human/multiple-seed acceptance separate |
| Geology/assets | `geology_asset_suite.gd`, collision/seating/proxy checks as affected; source hashes plus native gallery/gameplay |
| Trees | `density_lod_suite.gd`, `foliage_playtest.gd`, actual near/mid/far transition and dense-route cost |
| Camera/UI | Camera/profile/menu-camera, interface/settings/retained-screen/HUD suites; native multi-size/controller/popup/display matrix |
| Graphics/native | Graphics/PC settings, FidelityFX settings plus actual DX12 provider/resize/fullscreen/HUD/history/shutdown tests |
| Audio | Wind/SFX offline/native/lifecycle, equipment observer and voice fixtures; actual listening separate |
| Packaging | `playtest_bake_suite.gd`, `scripts/test_windows_playtest.ps1` on the actual packaged executable/PCK with isolated APPDATA |
| Backlog/skills/docs | `python tests/test_backlog.py`, `./scripts/backlog.ps1 validate`, skill-creator `quick_validate.py`, local links/anchors and source-path checks |
| Validation tooling | `python tests/test_validation_runner.py` (disposable Windows process/lock/pipe fixtures), physics/runtime timings, `validation_mountain_suite.gd`, `performance_trace_contract_suite.gd` |

Fixtures stay unranked and use disposable preferences/records. Generated evidence
belongs in ignored `artifacts/`, not personal bests. Source snapshots, actual
commands, hashes, coverage and missing evidence accompany new claims. Historical
missing output must be regenerated from a known baseline; a path is not a receipt.

## Performance method

Apply [the rendering target](RENDERING.md#performance-policy). Finish source edits,
resolve/hash the exact runtime and record driver/OS, recipe/seed/model, camera,
physical/scenery cache status, actual pixels and effective settings. Warm up the
workload; exclude screenshot/readback/video encoding and GPU validation layers
from timing. Capture visuals separately.

For a full-descent baseline justified under the bounded descent policy, generate
ordinary-input traces with `tests/performance_trace.gd` under the guard.
Only complete uncrashed descents become valid traces; the pilot supplies inputs,
not position/solver changes. Validate trace/core/generator/tuning/terrain identity
before playback. A failed pilot is a workload blocker, not license to substitute
a scripted teleport descent. Check the test's selected version against the current
baseline before producing or accepting a trace.

Playback rejects stale source/model/generator identity and unsuccessful traces
before mountain/scene setup, then still verifies terrain identity and exact
replay completion. Use `-Repetitions 3` in one invocation to reuse the loaded
scene across the existing independently warmed trials. This does not replace
cold-start measurements or permit reusing old FPS results.
`scripts/benchmark_pc.ps1` relays the engine's loading, trace and per-run progress
while preserving full logs; the outer guard no longer hides this second layer.

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','current-v15','-Version','15','-InputTrace','artifacts/current/input.json','-Upscaler','auto','-TerrainGI','off','-FrameGeneration','off','-FrameCap','0','-Repetitions','3','-ProfileFrameCosts') -Label current-v15 -TimeoutSeconds 2400 -CollectGpuMemory
```

The example requires a separately prepared matching complete trace. Follow with
the 120 FPS capped configuration and independently selected FG if assessing it.
Report individual runs and medians of run statistics; do not pool percentiles.
`production.json` contains route/section frame distributions, CPU scopes in μs,
GPU/render-thread ms, draw calls and engine memory; `system.json` records source
stability, engine hash and process/system/GPU allocation telemetry. Windows
allocation and engine memory are not precise physical VRAM occupancy. Radial
route sections are labels for that trace, not universal terrain classifications.
Keep the game window focused during the measured descents. The current baseline
receipt producer rejects any unfocused measured frames, source drift, incomplete
replays or changed personal settings/records; preserve rejected attempts as
diagnostic evidence and use a fresh label for replacements.

### Player recordings and short scenarios

Use `./scripts/record_run.ps1` when a player can demonstrate a faster route or a
specific event. The guarded launch opens current default v15 Standard with normal
riding input, High/Auto .75/120 FPS/FG off/GI off and read-only saved camera settings.
At the summit, choose a face and drop in to start recording. **Triangle / R**
restarts with a fresh input stream; **D-pad Right / F8** or **Save clip** ends early.
Base arrival and crashes also save automatically. Each saved attempt has its own
file under the printed `artifacts/player_recordings/<label>/` directory. Restart
discards the unsaved attempt and preserves saved clips. Close the game when done.
The recording window owns the engine guard while open.

These are diagnostic input recordings, separate from personal-best snapshot ghosts
and video. They retain all nine resolved riding fields at 120 Hz (including jump
hold and air tilt), initial launch, one-second position/velocity/heading checkpoints,
final outcome, sampled camera look/view, source/terrain/runtime identities and
starting presentation settings. They never change the solver or write personal
records/preferences. Inputs and launch heading use packed 64-bit values inside JSON
to avoid decimal-parser drift; the remaining metadata uses full precision. Replay compares
Vector3 state exactly and allows only 1e-12 radians of JSON heading roundoff.
Camera look samples are applied through the production following camera; rendering
still depends on frame cadence. Menu interaction, settings changes, post-crash
ragdoll sequences and video/audio are not captured as an interaction recording.
Save before pausing, or restart after resuming/changing settings.

Replay a short or crashed scenario once with:

```powershell
./scripts/record_run.ps1 -Replay artifacts/player_recordings/<label>/attempt_001.json -Label scenario-check
```

The same normal physics/render loop checks the original trajectory and stops at
the captured tick. Partial/crashed clips require explicit scenario mode and produce
`scope: recorded_scenario`; they cannot count as full-descent evidence. Only a
complete uncrashed player recording may replace the pilot trace in
`scripts/benchmark_pc.ps1 -InputTrace ... -Repetitions 3`. Old eight-field benchmark
traces must be regenerated; personal replay format 5 is unchanged. The recorder
and replay helpers live entirely under `tests/`; the production scene is inherited.
Use `performance_recording_suite.gd`, `performance_trace_contract_suite.gd` and
`record_run.ps1 -SmokeTest -Label <fresh-label>` to verify this tooling.

2026-09-12 verification: 12 recorder and 13 trace-contract checks passed. The
native manual-input smoke saved two independent early clips and verified restart,
preservation and isolation; a native 3840×2160 replay reproduced the 240-tick clip
and checkpoints. Four controller-prompt UI/test files were finalized during that
playback; its functional result stands, but its timings are not baseline evidence.
The recorded physics/input identities remained unchanged. Shared physics/runtime checks passed
56/192 in the controller-prompts milestone `3a554cb`; all 32 checked preference/
record files stayed unchanged. Detailed receipts are in
`artifacts/player_recording_validation/summary.json`. This validates the recorder,
not a full-descent FPS baseline or physical-controller comfort.

`tests/interface_performance_suite.gd` is the bounded native UI/graphics protocol.
It uses actual v15 Standard main-scene handoff and validated caches; physical
cache misses invalidate comparisons. Run via the resolved DX12 engine with
`--ui-staged-loading --benchmark-no-captures --graphics-quality=high
--upscaler=auto --render-scale=0.75 --fps-limit=120 --frame-generation=off
--terrain-gi=off --interface-performance-output=artifacts/new-ui-performance`.
Optional `--interface-display-checks` runs recovery/FG transitions;
`--interface-matched-ui` requires the baseline HUD from commit `6830997` at
`artifacts/interface_overhaul/baseline/hud.gd`.

`--interface-phase=fixed|moving|ui|powder|timeline|display|matched` runs only that
phase (default all); `--interface-no-captures` omits visual evidence. Paired
layout runs keep both HUDs resident/updated while toggling visibility, so they
isolate layout cost, not the whole historical engine. Ordinary production moving
routes are measured separately. Never imply omitted phases passed.

## Input and controller evidence

2026-09-11 model-28 input audit: 388 automated checks and eight native laboratory
captures were inspected. Haptic threshold retune later passed 284 checks and a
native 1920×1080 fixture with hardware vibration disabled. These are input/event
and rendered results, not controller comfort. Producers: controller input,
haptics, physics/runtime suites; output `artifacts/controller_input_v1/`.

Remaining device review: small/hard landings, bumps/rock taps, intensity zero,
reconnect/focus loss, neutral-gated flips, tuck/turn/jump transitions, menu focus
and HUD editing. Preserve the posture observation linked from the existing
[tuck consistency idea](../backlog/ideas/archive/IDEA-20260911-185650-tuck-presentation-consistency.md).

## Mountain evidence

2026-09-10 v15 matched Standard work established deterministic outputs across
worker counts, source/engine-validated caches and faster generation/loading.
Initial means: cold generation 422.634 s v14 →135.579 s v15, physical-cache
loading 10.349→5.402 s, cached rendered readiness 144.683→64.324 s. A later
dependency-hash optimization brought v15 cold mean to 130.843 s. These retain
their original workloads; readiness includes scene submission and is not FPS.
Producers/receipts are the v15 generation suites and `artifacts/generation_v15/`.

Current default-v15 route coverage, per-face pilot outcomes, methodology and
reproduction commands are in [World's route audit](WORLD.md#default-v15-route-audit)
and its [source-hashed receipt](V15_ROUTE_AUDIT_RESULTS.json). This replaces the
historical v13 pilot result (face index 3 completed; others crashed/stalled) as
the current route acceptance evidence. Natural population saturation and
synthetic million-tree capacity remain separate results; user skiing and other
seeds remain open.

## Performance evidence

### Current v15 player-descent baseline

2026-09-12: three capture-free replays of the user's **attempt 8**, a complete
122.025-second descent, reproduced all 14,643 solver ticks and 122 checkpoints.
All three stayed focused; 1,008 source hashes and 32 personal settings/record
files stayed unchanged. The [structured receipt](V15_PERFORMANCE_BASELINE_RESULTS.json)
retains each run, medians of run statistics, full identities and raw-evidence
hashes. This completes the [baseline audit](../backlog/archive/AA-20260911-153903-current-4k-performance-baseline.md).

Workload: default Standard seed 849205174, generator 15/model 28, launch face
index 0, recorded chase-camera profile/look, clear/day, full production scenery
and animation. Actual output was 3840×2160, internal scale 2880×1620, High preset
7, Auto resolving FSR 4.1.1, cap 120, FG off and SDFGI off. Runtime was custom
Godot 4.7.2 `ed1daf0bf`, Forward+/DX12, RX 9070 driver `32.0.31041.1004`, Ryzen
5 5600X, 16 GB RAM, Windows 11 Pro build 26200.

| Run | Average rendered FPS | Median FPS | Frame p95 / p99 ms | GPU mean / p95 / p99 ms | Render CPU mean / p95 / p99 ms |
|---|---:|---:|---|---|---|
| 1 | 90.42 | 101.82 | 16.614 / 23.877 | 8.769 / 11.941 / 13.154 | 1.563 / 2.385 / 2.976 |
| 2 | 92.65 | 103.92 | 16.301 / 22.216 | 8.588 / 11.779 / 13.035 | 1.544 / 2.365 / 2.888 |
| 3 | 92.57 | 103.81 | 16.311 / 23.198 | 8.607 / 11.827 / 13.279 | 1.542 / 2.363 / 2.953 |
| Median of runs | 92.57 | 103.81 | 16.311 / 23.198 | 8.607 / 11.827 / 13.154 | 1.544 / 2.365 / 2.953 |

The sustained target remains **unmet**: every run misses p95 ≤11.1 ms and
p99 ≤16.7 ms. The median slowest-one-percent rate is 34.56 FPS; neither average
nor percentile statistics establish a hard minimum, display delivery or latency.
Mineral and forest radial bands have median average FPS 79.82 and 89.95, with
p95/p99 18.375/26.458 and 16.832/25.599 ms. Every measured forest-band frame has
resident forest regions (3,841 / 3,953 / 3,960 frames); maximum residency is
90 / 89 / 89 regions. Region residency is not a visible-tree count.

One shared startup took 3.826 s for physical-cache loading/validation and 58.123 s
for scene readiness; both physical and scenery caches hit. Scene submission
included 22.855 s minerals, 13.695 s forest and 8.326 s distant scenery. These
overlap aggregate job timings and must not be added to scene readiness again.
Cold generation was not measured; `original_bake_ms` is cached metadata. Each
trial then had its own 240-render-frame warmup and approximately 122.03 s of
measured gameplay. The entire guarded job took 444.179 s, plus 0.152 s queue wait.

| Run | Peak process working set / private GiB | Peak Windows GPU dedicated / shared allocation GiB | Minimum system free GiB |
|---|---|---|---:|
| 1 | 1.829 / 5.637 | 4.100 / 0.302 | 4.720 |
| 2 | 1.824 / 5.636 | 4.100 / 0.239 | 4.835 |
| 3 | 1.782 / 5.638 | 4.100 / 0.239 | 5.475 |

Engine-reported peak video memory was 3.538 GiB per run; static-memory peaks
were 1.153 / 1.148 / 1.148 GiB. Process, engine and Windows GPU allocation
counters measure different things; do not sum them or equate allocation with
physical VRAM residency. Two-second telemetry saw no other Godot or WoW workload.
Other applications and GPU allocations remained present and are retained in the
receipt. Sampled background CPU is limited to the wrapper's observed processes;
zero readings do not establish an idle computer. CPU scopes overlap: median
simulation and animation tick costs were 1.494 and 1.027 ms, and presentation
pose cost 1.539 ms per rendered update. Scope spikes identify profiling leads,
not proven causes of individual slow frames.

The user's route replaces a 297.242-second pilot route: 58.95% shorter simulation
duration, or 6:06.075 for three descents instead of 14:51.725, excluding setup.
The route and camera changed; this is reduced benchmark workload duration, not
an FPS optimization. The pilot matrix cancelled at the user's request and the
first player matrix interrupted for focus loss are excluded. Their provenance
remains under `artifacts/current_v15_4k_baseline/` and
`artifacts/player_v15_4k_baseline/`. Human/controller comfort, other faces, weather
and cameras remain separate acceptance.

Original producing commands (use fresh output/guard labels for a new measurement):

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','player-v15-4k-focused-20260912','-Version','15','-InputTrace','artifacts/player_recordings/player-20260911-221639/attempt_008.json','-Upscaler','auto','-RenderScale','0.75','-TerrainGI','off','-FrameGeneration','off','-FrameCap','120','-Repetitions','3','-ProfileFrameCosts') -Label player-v15-4k-focused -TimeoutSeconds 1200 -CollectGpuMemory
python tests/report_current_4k_baseline.py
```

The receipt producer defaults to these retained labels and verifies raw frame,
GPU, render-CPU and draw-call distributions before publishing. For a new run,
pass matching `--label`, `--guard`, `--trace`, `--evidence` and `--output`; the
evidence directory holds before/after personal-file hashes, the observed worker
binary identity and route provenance. Detailed samples stay in ignored
`artifacts/pc_environment/player-v15-4k-focused-20260912/`.

### Historical narrower workloads

Historical v14/model-26 full descents and model-28 short routes also missed tail
targets. Model-28 snow-contact laboratory samples at 4K/.75 FSR4 met their short
frame-time gate, with increased snow CPU/GPU cost for stronger output; they do
not establish sustained skiing.

2026-09-11 v15/model-28 interface protocol: preset 7 missed summit p95 and snowy
forest mean/p95/p99 targets; Ultra also missed tails. Preserve the exact rows,
identities and limits in [structured results](INTERFACE_PERFORMANCE_RESULTS.json).
This data remains byte-preserved from the original report. Fixed views, short
moving cases and UI cost are not a complete-descent result.

## Presentation evidence

2026-09-11 interface delivery inspected five output sizes, retained screens,
controller/mouse navigation, HUD editing and output recovery. The final native
matrix passed 125 checks with 111 captures; retained-screen checks passed 248,
native interface 122, and HUD/mouse 84. Later HUD refinements removed heavy
outlines and defaulted backgrounds off. Do not treat earlier outlined captures
as the current intended style. Producers are the named interface/HUD suites;
receipts live under `artifacts/interface_overhaul/` and guarded interface jobs.

Camera profiles and slope-following fixtures separately verified state isolation,
preview, look lifecycle and broad-grade framing. Native stationary preview is
not continuous skiing comfort. Snow tip-contact/GPU checks verified live ribbon
connection, displacement side and partial/full upload identity; close faceting
and full-route visual preference remain open. Producer:
`scripts/validate_snow_contact.ps1`; output `artifacts/snow_contact_20260911/`.

Current task: [presentation comfort](../backlog/tasks/AA-20260911-153904-presentation-comfort-review.md).

## Animation evidence

Durable findings/limits are in [Animation](ANIMATION.md#retained-findings-and-acceptance).
Reproduce with the animation skill, `tests/carve_entry_suite.gd`, production
motion/anatomy/attachment suites and frozen chronological capture/audit stages.
The carve-entry regression retained baseline clipping; it does not establish
production clearance or an artistic score. Current authoring direction is in
[Animation](ANIMATION.md#authoring-direction); retired trial results remain
historical evidence, not current production acceptance.

Source-pose diagnostics after editor removal verified 7,920 source joint samples
unchanged across 33 clips/five times/mirror states. Its six rendered diagnostic
views came from two historical frames; this proves the diagnostic path, not
current animation quality. Evidence: `artifacts/editor_removal_20260911/`.

### Tuck consistency

The original input-audit sequence now retains a compact initial tuck and returns
to it after steering. The shared [carving posture handoff](ANIMATION.md#carving)
also owns this correction; there is no separate tuck retune or input change.
The regression must launch along the sampled fall line, as Speed Lab does:
heading-aligned planar motion misses the small loaded edge that triggered the
defect. Isolated historical motion reproduced the original 265 mm hip-height
and 39-degree chest-pitch mismatch in `original-fixed-clock/` under the evidence
directory below, while the solver's tuck assertions still passed.
The 2026-09-12 native 1920x1080 capture contains 313 inspected chronological
frames, passing input/pose assertions and stable production source hashes.
All 313 paired frames have identical input, completed ticks, physical positions,
velocities, speed, tuck, grounding, rendered skis and camera transforms.
Initial/resumed support-relative hip height differs by 8.6 mm and chest pitch
by 0.12 degrees. Detailed measurements and source snapshots live in
`artifacts/tuck_consistency_20260912/current-fixed-clock/`; `paired-evidence.json`
and `tuck-comparison.jpg` in its parent compare the historical/current motion.

`tests/tuck_presentation_suite.gd` covers the laboratory and four planar speed/
grade cases through entry, steering, resumed hold and release. It passed 30 checks
with 4,200 identical paired physical snapshots/body-joint states; receipts are
`delivery-suite.json` and `delivery-sources.json` beside the native capture.
Reproduce with
`./scripts/test_pc_environment.ps1 -Suites tuck_presentation_suite`.
For the native router/pose chronology, choose an unused output directory:

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/tuck_presentation_playtest.gd','--','--output=res://artifacts/tuck_consistency/visual') -Label tuck-consistency -TimeoutSeconds 240
```

The capture refuses an existing output directory and disables records, preference
writes and hardware haptics through the inherited input-audit fixture. These are
automated and author-rendered results; human/controller acceptance and performance
remain separate. The shared change's full mesh audit has 130 affected frames
versus 33 in its baseline, concentrated in tucked-turn neighbors. This body-posture
regression does not clear that open pole/clothing issue; see
[retained animation findings](ANIMATION.md#retained-findings-and-acceptance).

## Audio evidence

Run `scripts/build_wind.ps1 -Test` for standalone 44.1/48 kHz DSP tests, then
native wind/SFX and equipment/crash observer fixtures. `wind_audio_suite.gd`
with `--wind-disable-native` exercises fallback. Offline WAV auditions and
`scripts/benchmark_wind.ps1` distinguish signal/listening and rendering/DSP cost;
its historical route default must be checked before calling it current evidence.
`tests/interface_art_playtest.gd -- --loading-audio-only` checks loading-loop
behavior and captures the bus; voice preparation/audit is in [Audio](AUDIO.md).

Voice's retained 138 lexical clips passed isolated transcription; 32 nonverbal
clips/breaths have provisional performance acceptance. Transcription, waveform
metrics and native callback tests do not establish delivery, long-session mix
or physical-device listening. Those remain user gates.

## Native and package evidence

The RX 9070 custom DX12 runtime has dispatched the retained FSR4/FSR3/FG providers
and passed resize/history/HUD/shutdown tests. Actual generated presentations are
distinct from physical monitor delivery/latency. `fidelityfx_playtest.gd`,
`fidelityfx_game_playtest.gd` and `fullscreen_generation_suite.gd` are the native
producers; activation ties their receipts to executable hashes.

The 2026-09-11 isolated collaboration checkout verified bundled setup/import,
physics/runtime and actual exported game operation on this PC. Retain package
hash/build receipts under `artifacts/github_collaboration_audit/`; this is not
acceptance on another computer. Repeat the [packaging smoke](DEVELOPMENT.md#windows-packaging)
for each delivered build.

## Race and player acceptance

For race-creator camera input, run the native `race_suite.gd --survey-only`
selection below. It injects keyboard/mouse events through production UI routing,
checks controller discovery and text focus, and captures the survey before/after
panning in `artifacts/race_survey_{before,after}.png`. Headless execution cannot
establish keyboard-window focus or rendered movement; physical controller feel
remains a separate acceptance check.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/race_suite.gd','--','--survey-only') -Label race-survey -TimeoutSeconds 120
```

Existing race/record suites cover authoring/import, finite crossings, splits,
eligibility and ghosts. Ordinary route discovery, retries and ghost readability
need the [race-loop audit](../backlog/tasks/AA-20260911-153905-race-loop-acceptance-audit.md).
The separate [player/controller task](../backlog/tasks/AA-20260911-153906-player-and-controller-acceptance.md)
is blocked on actual user playtesting after evidence preparation. Task files own
their status/dependencies; this guide does not mark them complete or duplicate
their checklists. Automated, rendered, performance, listening and human acceptance
must remain independently attributable.
