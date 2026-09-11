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

Generate ordinary-input traces with `tests/performance_trace.gd` under the guard.
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
[tuck consistency idea](../backlog/ideas/IDEA-20260911-185650-tuck-presentation-consistency.md).

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

The sustained target remains **unmet**. Historical v14/model-26 full descents
and model-28 short routes do not meet all tail targets. Model-28 snow-contact
laboratory samples at 4K/.75 FSR4 met their short frame-time gate, with increased
snow CPU/GPU cost for stronger output; they do not establish sustained skiing.

2026-09-11 v15/model-28 interface protocol: preset 7 missed summit p95 and snowy
forest mean/p95/p99 targets; Ultra also missed tails. Preserve the exact rows,
identities and limits in [structured results](INTERFACE_PERFORMANCE_RESULTS.json).
This data remains byte-preserved from the original report. Fixed views, short
moving cases and UI cost are not a complete-descent result. Current task:
[4K baseline](../backlog/tasks/AA-20260911-153903-current-4k-performance-baseline.md).

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
The carve-entry regression retained baseline clipping; R9's 16.94 cm height
target introduced two new pole/clothing contact frames. Neither establishes
production clearance, an artistic score or Cascadeur adoption.

Source-pose diagnostics after editor removal verified 7,920 source joint samples
unchanged across 33 clips/five times/mirror states. Its six rendered diagnostic
views came from two historical frames; this proves the diagnostic path, not
current animation quality. Evidence: `artifacts/editor_removal_20260911/`.

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

Existing race/record suites cover authoring/import, finite crossings, splits,
eligibility and ghosts. Ordinary route discovery, retries and ghost readability
need the [race-loop audit](../backlog/tasks/AA-20260911-153905-race-loop-acceptance-audit.md).
The separate [player/controller task](../backlog/tasks/AA-20260911-153906-player-and-controller-acceptance.md)
is blocked on actual user playtesting after evidence preparation. Task files own
their status/dependencies; this guide does not mark them complete or duplicate
their checklists. Automated, rendered, performance, listening and human acceptance
must remain independently attributable.
