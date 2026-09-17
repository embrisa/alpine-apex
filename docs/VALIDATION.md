# Validation and acceptance

## Execution

Follow [internal development versioning](DEVELOPMENT.md#internal-development-versions)
for milestone notes and tested input snapshots. Regression `run.json`/result rows,
scenario envelopes and new `.apexcase` recordings carry build identity alongside
existing source/runtime hashes. Recorded and current rerun identities remain
separate. Older optional diagnostic metadata may lack a build label; that does
not supply missing provenance or require a gameplay schema reset. Dev equality
alone never establishes source equivalence, comparable performance or acceptance.
Regression reports retain test-script hashes and reject game/build/test-input drift.

Suites write their reports through `tests/test_report.gd` (`write`, `write_line`,
`write_bytes`, `write_var`, or `open_write` for a retained handle). It creates
the report folder and reports a failed open instead of dereferencing a null
`FileAccess`; the old chained `FileAccess.open(path, WRITE).store_string()` on a
missing `artifacts/` folder raised a script error after every check had passed
and left the headless suite running until killed. New suites must not open
report files directly.

Use [current source identities](ARCHITECTURE.md#current-identity), not the version
embedded in an old filename. Run engine workloads through
`scripts/run_guarded.ps1` or an owning wrapper; do not nest guards. The guard
admits compatible `-WorkloadMode Shared` runs concurrently by default.
`FpsCritical` measurements and `Exclusive` mutations wait for all existing runs
and block new admissions until finished. Queued exclusive requests also block
new shared runs, so measurements cannot be starved by arriving checks.
The guard waits automatically (up to
`-WaitTimeoutSeconds 3600` by default), reports the owner when available, and
records queue time separately from `-TimeoutSeconds` for the workload. A wait
timeout writes a separate request receipt without replacing the active owner's
logs. The guard owns only its launched process tree and records timeout/engine/
driver failures. Existing user apps are preserved.
Concurrent functional checks cannot establish performance. There is no fixed
instance cap; choose a sensible memory budget for the fixtures being launched.

Use `-WorkloadMode FpsCritical` for comparative FPS, CPU/GPU, loading or generation
timing, even in a headless test. Known benchmark/profiling entry points are promoted
automatically; this is a backstop, not a substitute for classifying new producers.
Use `Exclusive` for imports, exports, builds and shared cache/native mutations.
Unregistered scripted Godot/Blender workloads remain blockers and are preserved;
exclusive work also waits for unregistered interactive Godot instances.

Each request holds a process-owned lease under `artifacts/validation_leases/` and
the original `validation.lock`. OS handle lifetime releases cancelled/dead owners;
stale metadata is reclaimed at admission. Old exclusive guards remain compatible.
Never delete either lock or live lease files to force admission. Unique labels
protect guard logs; default resource reservations serialize the same producer.
`-ResourceKeys @('output:ABSOLUTE_PATH', 'cache:KEY')` replaces that producer
reservation only when all its shared writes are identified. Different scripts
that write a common destination must reserve the same key or use `Exclusive`.
The scenario wrapper reserves its fresh output; no session/cache writes occur.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/physics_suite.gd') -Label physics
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/runtime_suite.gd') -Label runtime
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/animation_cpu_suite.gd') -Label animation-cpu -WorkloadMode FpsCritical
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
an inherited guard when wrapped. It reserves its suites and output directory;
disjoint batches with distinct outputs may overlap. A batch containing a known
timing suite requires exclusive admission; an inherited shared guard is rejected.
An inherited shared guard must also reserve every selected suite and the output;
use the direct batch wrapper when that outer scope has not been declared.
It runs suites within each batch serially, stops after
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
`tests/prepare_validation_mountain.gd` under an Exclusive guard with full-mountain selection before rerunning. Cold generation,
cancellation, determinism, capacity and export checks remain separately selected;
the warm profile does not replace them or skip source/engine validation.

## Targeted test maps

Automated checks select the smallest surface that covers their assertion. Start
with no map for pure logic, then a compact fixture for local integration. Full
mountains and the scenery-rich laboratory require an explicit coverage reason;
a short descent alone does not make a large map necessary.

`tests/fixtures/test_maps.json` owns map dimensions, explicit object placements
and producer requirements. `scripts/diagnostics/test_map.gd` constructs the same
4 m triangulated surface used by the production 120 Hz solver. Maps use distinct
`targeted-v1-*` identities; automated test race references reconstruct these maps
and are rejected outside automated processes. Gameplay/save identities are unchanged.

| Map | Extent | Population / use |
|---|---|---|
| `flat-pad` | 128 x 128 m | 0 objects; UI, input and settings |
| `smooth-slope` | 256 x 512 m | 0 objects; handling, pose and camera |
| `rough-snow` | 256 x 512 m | 0 objects; uneven snow and recovery |
| `terrain-transitions` | 256 x 512 m | 0 objects; crest, compression, small drop |
| `obstacle-patch` | 128 x 256 m | 18 explicit objects, all tree/rock families |
| `short-course` | 256 x 512 m | 0 objects; session, finish and replay checks |

Compact scene tests set SceneTree metadata `test_map_fixture` before adding the
real main scene. Selection survives reload; records use disposable per-process
paths and fixture attempts remain unranked. The production terrain, lighting,
scenery, camera and skier components remain in use. The fixture path never builds
distant terrain, wilderness, scrub, huts or randomly scattered obstacles. Routine object
fixtures are capped at 64 placements; explicitly selected performance maps below
have their own bounded populations. Add a needed terrain/event to this catalog
before defaulting a new local check to a full world.

```powershell
./scripts/test_pc_environment.ps1 -Profile core -PlanOnly
./scripts/test_pc_environment.ps1 -Suites targeted_map_suite,scenario_suite
./scripts/scenario.ps1 -List
./scripts/scenario.ps1 -Scenario compression -Capture -Output artifacts/my-task/compression
```

Batch and guard `-PlanOnly` show registered map dimensions/populations and full
mountain requirements. Uncatalogued/inline producers remain explicitly labelled
as producer-owned; the runtime gate still prevents accidental full-world loads.
The core physics suite retains its necessary headless laboratory calibration,
including route finish/speed/contact assertions, without constructing scenery.
`interface_suite` covers local UI; `interface_mountain_suite` retains its separate
generation, preview and full-mountain reload assertions. Neither replaces the other.

For a necessary full world, supply both `-FullMountain` and a nonempty
`-FullMountainReason` on the owning guard or batch. Child wrappers inherit the
selection; no additional approval is needed. The guard, batch, recorder,
benchmark and case wrappers preserve it. Receipts record the reason. Missing
selection fails before registered producers launch, and generator/restoration/
world entry points reject indirect loads too. Normal interactive startup is unaffected.

Valid reasons include actual generator/cache contracts, mountain-scale streaming,
dense production FPS, exact recorded-mountain reproduction and whole-route
assertions. Finish, replay and UI work normally use a short course instead.

```powershell
./scripts/test_pc_environment.ps1 -Suites interface_mountain_suite -FullMountain -FullMountainReason 'Verify actual generation, preview and full mountain reload'
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/prepare_validation_mountain.gd') -Label prepare-standard -WorkloadMode Exclusive -FullMountain -FullMountainReason 'Explicit preparation of the current Standard validation archive'
```

Automated cache loading never falls back to a cold bake, even with full-world
access. The explicit preparation command above bakes Standard once; retained
legacy/custom recipes need their matching explicit preparation. Full scene cache
publication uses Exclusive admission; uncontended timing uses FpsCritical.

Keep setup time separate from simulation/capture time. Original hop, rough-snow
and carving stimuli are unchanged; their default 4-6 second windows remain valid.
An unexpected fixture boundary fails required scenario coverage rather than
silently reporting an early pass. Local captures establish local behavior;
they do not establish whole-mountain FPS or human/controller acceptance.

## Targeted rendering and FPS maps

For local slope, rock, tree/forest or combined rendering work, select an authored
performance map before using a mountain. `tests/fixtures/performance_maps.json`
owns four 256 x 512 m maps (8,385 height samples each):

| Selection | Ragdoll terrain collision | `terrain_collision_suite.gd`, `streaming_collision_suite.gd`, required physics/runtime; bounded native crash on `perf-slopes` |
| Trees | Rocks | Intended checks |
|---|---:|---:|---|
| `slopes` | 0 | 0 | Terrain shading, crest/compression, contact and snow effects |
| `rocks` | 0 | 48 | Real mineral meshes/hulls, textures, shadows and macro texture residency |
| `vegetation` | 384 | 0 | Production forest batches, crowns, shadows, wind, LOD and local residency |
| `mixed` | 384 | 48 | The exact same rocks and trees together; combined rendering cost |

The common terrain has a clear 24 m central lane, a crest at z=196 m, compression
at z=286 m and outboard ripple strips. Trees have explicit anchors and species
palettes; rocks include 46 medium/large samples and two distant macro boulders.
The component-only and combined maps share identical terrain and placements.
There is no full-world generation, distant terrain, random scattering, wilderness
or scenery-preparation cache. Only the selected production components load. These
performance fixtures allow at most 448 placements and never replace the smaller
routine functional fixtures.

```powershell
./scripts/benchmark_targeted.ps1 -Map rocks -PlanOnly
./scripts/benchmark_targeted.ps1 -Map vegetation -Output artifacts/my-task/vegetation
./scripts/benchmark_targeted.ps1 -Map mixed -Capture -Resolution 1280x720 -FrameCap 60 -Output artifacts/my-task/mixed-captures
./scripts/test_pc_environment.ps1 -Suites performance_map_suite,targeted_map_suite
```

Use `-Map slopes`, `rocks`, `vegetation` or `mixed`. The owning wrapper reserves
FpsCritical admission (including native captures); do not add another guard.
Default measurement is three independently launched scenes at 4K High, FSR Auto
0.75, uncapped, with three seconds of preparation and six seconds of ordinary
120 Hz skiing per scene. `-Seconds` accepts 4–10 seconds. The runner rejects a
crash, early boundary, incomplete tick window, source drift, wrong output pixels,
focus loss, invalid timing samples or an end state different from the reference.
No personal preferences or records are written. Captures use a separate run and
produce riding/detail/overview images; they never count as FPS evidence.

The explicit default is `-Camera scenery`: an in-memory chase profile with 12°
downward tilt, 68° FOV, 5 m distance, 3 m height and no slope-follow tilt. It shows
the approaching terrain and tree crowns instead of aiming into nearby snow.
`-Camera riding` retains the scene's existing camera configuration. Reports record
the profile, settings and rendered transform. Neither writes personal preferences.
Use matched camera profiles for timing; older snow-facing trials are not scenery-
framed baselines. `tests/scenery_trace.gd -- --input=PATH --output=FRESH_PATH`
adds the same presentation framing to a preserved compatible ordinary-input trace,
records its source hash, and refuses to overwrite an output or reframe a recorded
camera-sample/stress trace. Exact replay validation still applies.

`plan.json`, per-trial `results.json`/`samples.json` and `summary.json` record
fixture identity/population, source and engine hashes, effective graphics/output,
setup time, complete process time, ordinary-input coverage, FPS and frame tails.
Compare matched maps/settings using medians of the individual trial statistics.
Local component FPS is distinct from whole-mountain FPS: retain the explicitly
justified production benchmark for mountain-scale streaming, dense-scene
acceptance and exact route/data reproductions. Human/controller acceptance is
reported separately.

## Premium tree source review

The prepared family at `art_source/trees/premium_lod_v1/` has a separate native
source review. Its `prepare.ps1 -Mode Build|Bake|Review` owns Exclusive admission
and never loads the game scene or changes production imports. Use `-Sample`
for three medium conifers during iteration; final review covers all 30 IDs.
`-Mode Audit` independently checks GLB structure, actual counts/bounds, portable
materials, source hashes, atlas framing/coverage and complete catalog membership.
The package README retains the guarded Blender source/roundtrip command.

Run Bake after geometry changes, then Review after far-material finalization.
Run `python art_source/trees/premium_lod_v1/report.py` to generate
`artifacts/premium_tree_review/review.html` from the native captures. Inspect
all family tiers, close branches, the mixed stand, distant slope, elevated and
backlit views, and the chronological near/mid and mid/far transitions. Native
receipts identify the sealed source manifest and separate assets from production
placement, wind, visibility assistance, residency, physical terrain and skiing.
The capped isolated review is not performance evidence. Production integration
requires its own conversion, grounding/LOD/material regression, rendered review
and matched FpsCritical timing. Asset triangle reductions do not establish FPS.

## Colorful tree checks

[The integration receipt](COLORFUL_FOREST_RESULTS.json) records the delivered
assets, matched views, valid timing pair, rejected/preliminary runs and remaining
performance/human acceptance limits. Raw review media and frozen inputs remain
under `artifacts/colorful_forest_variety/`.

`colorful_forest_suite.gd` uses two inline 512 m/4 m fixtures with 961 trees each
for deterministic assignment, same-stand silhouette variety, complete catalog
participation, physical-byte preservation, quality/material receiver registration
and scenery-only source dependencies. Run it with the affected collection,
density-LOD, grounding and foliage-sight suites; forest preparation also requires
its native-renderer check described below.

`colorful_forest_playtest.gd` defaults to `perf-vegetation`. It uses actual game
materials and forest residency at 1920×1080, native rendering and 60 FPS cap;
captures do not establish timing. `--standard` requires FullMountain and a warm
physical seed archive, then permits explicit scenery refresh under Exclusive.
It does not bake a missing physical mountain. Optional `--seed=638201943` selects
the second prepared seed. The receipt compares physical bytes before/after and
records family populations, selected tree indices, camera transforms and source
identity. Inspect material closeups, roots, dominant pockets, strength 0/50/100,
quality tiers, daylight/snowfall and both six-second chronological LOD sequences.
For a frozen old/new catalog pair, `--standard --comparison-only` selects three
identical woodland, edge and scattered-tree views from physical positions and
ecology alone. Copy the current producer to a new `artifacts/` path in each
snapshot after timing; preserve all frozen timing inputs. Compare its positions,
camera transforms and physical hashes before judging the images.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/colorful_forest_suite.gd') -Label colorful-contract -WorkloadMode Shared -TimeoutSeconds 120
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/colorful_forest_playtest.gd','--','--standard','--graphics-quality=high','--upscaler=native','--frame-generation=off','--output=artifacts/colorful-current') -Label colorful-current -WorkloadMode Exclusive -FullMountain -FullMountainReason 'Actual new forest families on unchanged physical Standard, with scenery refresh and bounded visual review' -TimeoutSeconds 900
```

The separately authored natural-forest generation task owns the later population
reduction and sparse upper-altitude placement. This art producer does not change
the physical tree population or certify a regenerated world.

For a shared-checkout tree comparison, `snapshot_forest_comparison.py` freezes
private code/metadata copies and immutable binary inputs under a fresh artifacts
directory. The baseline overrides exactly nine forest source/catalog paths from
an explicit Git revision; the candidate retains the captured working source.
All other runtime inputs and the scenery-framed ordinary trace are identical.
It never changes the live checkout or Git state. `compare_forest.ps1 -Mode Measure`
warms each arm's scenery immediately before its timing, under a separate
Exclusive lease, then owns a FpsCritical pass of three
warmed 15-second Standard repetitions and three six-second local vegetation
trials per arm. Binary/source hashes are checked around timing.
The shared physical archive has one scenery slot; preparing both arms in advance
does not keep both scenery versions warm. A cache miss during timing is rejected.
Keep snapshot code and receipts until the comparison is reviewed; never treat a
source-drift run as the baseline.
If the live copy drifts during freezing, retain it and inspect the reported
paths. Explicit `--resume-candidate` freezes that observed copy and records its
differences from live source; it refuses a drift in any forest override path.
This reconstructs an isolated comparison, not a claim that all copied files
came from one atomic checkout revision.

```powershell
./scripts/run_guarded.ps1 -FilePath python -Arguments @('scripts/snapshot_forest_comparison.py','--output','artifacts/forest-pair','--baseline','BASELINE_COMMIT','--trace','artifacts/current/forest_trace.json') -Label forest-freeze -WorkloadMode Exclusive -TimeoutSeconds 180
./scripts/compare_forest.ps1 -Snapshot artifacts/forest-pair -Mode Prepare -Label forest-pair-prepare
./scripts/compare_forest.ps1 -Snapshot artifacts/forest-pair -Mode Measure -Label forest-pair-measure
```

## Standard scenarios and synchronized comparison

`scripts/scenario.ps1` adapts the existing small-landing/ripple fixtures to
named, bounded scenarios including `small-hop`, `rough-snow`, `steady-carve`,
`crest`, `compression` and `small-drop`. Discover
live defaults and inputs through `-List` or inspect a command with `-PlanOnly`.
These are focused synthetic snow fixtures, using the production 120 Hz solver
and shared 4 m surface, not a whole mountain or performance benchmark.

```powershell
./scripts/scenario.ps1 -List
./scripts/scenario.ps1 -Scenario small-hop -Capture -Output artifacts/scenarios/hop-before
./scripts/scenario.ps1 -Scenario small-hop -Capture -Output artifacts/scenarios/hop-after
python scripts/pose_review/compare_scenarios.py artifacts/scenarios/hop-before artifacts/scenarios/hop-after --output artifacts/scenarios/hop-review
```

Default windows are 4–6 seconds; `-Seconds` permits 0.25–60 seconds with a clean
duration/crash/fixture-boundary stop. `-Capture` adds final production poses and
images, `-CaptureFps` controls sampling (1–30, default 15), and `-View side|chase`
selects the camera. The fixture uses the solver's constructed tuning, recorded
in full, rather than silently assuming the default resource. Records/preferences
are never created. Capture runs produce visual evidence; wall times are diagnostic
only. Headless runs retain the same completed tick/input/state telemetry.

Every run writes `manifest.json` and `telemetry.json` in the common
`alpine-scenario-evidence` schema. Manifests record exact source/engine/model,
fixture/input/tuning, requested and actual coverage, stop reason, source stability,
events, camera and capture origins. Loads are summed ski forces in newtons;
impact speed is metres/second. Changing a producer's meaning requires a schema
review and updates to its comparer/tests and affected skills in the same milestone.

Open the generated `index.html`, or serve the common artifact parent using
`python scripts/pose_review/serve_review.py --root artifacts --port 8771`.
Keep the two source evidence directories beside the review; images are linked,
not duplicated. The page synchronizes telemetry by tick, shows nearest image
times and offsets, plots selected metrics and jumps to contact/crash events or
the first shared-state divergence. JSON records changed source/tuning, compared
and unavailable fields, coverage and numeric tolerance (default `1e-6`).
Different inputs, failed/source-drifting runs, unmatched tails, missing captures
and camera/engine differences remain visible. No overlap or malformed evidence
is rejected. Differences are observations, not automatic improvement/fix grades.

Tool checks: `python tests/test_scenario_comparison.py` and
`python tests/test_validation_runner.py`. Browser checks use
`node tests/scenario_review_browser.test.cjs REVIEW/index.html INSPECTION_OUTPUT`
with the installed Playwright runtime. Run `tests/scenario_suite.gd` through the
guard for fixture determinism, telemetry units and event coverage.

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
- One sample is enough for an initial diagnostic and candidate screening against
  a saved matching baseline. Follow the experiment budget below; repeated
  before/after runs are not the default.
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
timed stop; do not assume the wrapper timeout saves a clip. The benchmark now
defaults to a 15-second window from a validated trace, and mandatory physics/runtime suites still
run in full when required by the agent contract.

## Check selection

Paths in this table are under `tests/` unless noted.

| Change | Relevant checks |
|---|---|
| Physics/input/session | Required physics/runtime; focused contact, carving, jump, flight, impact, race/replay tests |
| Controller/haptics | `controller_input_suite.gd`, `haptics_suite.gd`, native `controller_input_playtest.gd`; actual hardware acceptance separate |
| Snow contact | Focused response/contact/GPU and [causal boundary/carving producers](#snow-contact-and-local-boundary-producers); historical wrapper/source swaps are not matched current baselines |
| Recovery/ghosts | [Focused replay/archive/lifecycle producers](#crash-recovery-and-ghost-producers), shared physics/runtime/race checks and separate native final-pose review |
| Pole propulsion | [Force/pose/authoring producers](#pole-propulsion-and-animation-producers), shared physics/runtime and final shaft/clothing review |
| Animation/fitting | Animation skill's Regression stages; anatomy, attachment, motion, relevant flight/landing and full clothing audit; chronological rendered review |
| Pose-review tools | `pose_review_tools_test.py`, affected real-capture commands, `pose_review_state.test.cjs` for feedback state; native smoke if rendering changes |
| Generation/cache | Existing v15 generation/cache/recipe/cancellation/export suites; cold/worker determinism and actual requested/achieved populations |
| Default-v15 routes | `alpine_v15_route_audit.gd`, then `python tests/report_v15_route_audit.py`; six surveys and one bounded ordinary-input pilot per face; human/multiple-seed acceptance separate |
| Geology/assets | `geology_asset_suite.gd`, collision/seating/proxy checks as affected; source hashes plus native gallery/gameplay |
| Trees | `density_lod_suite.gd`, `foliage_sight_suite.gd`, native mask/settings/stand review, actual near/mid/far transition and bounded dense-route cost |
| Camera/UI | Camera/profile/menu-camera, interface/settings/retained-screen/HUD suites; native `hud_dial_suite.gd` paint/retention checks and multi-size/controller/popup/display matrix |
| Graphics/native | Graphics/PC settings, FidelityFX settings plus actual DX12 provider/resize/fullscreen/HUD/history/shutdown tests |
| Audio | Wind/SFX offline/native/lifecycle, equipment observer and voice fixtures; actual listening separate |
| Packaging | `playtest_bake_suite.gd`, `scripts/test_windows_playtest.ps1` on the actual packaged executable/PCK with isolated APPDATA |
| Backlog/skills/docs | `python tests/test_backlog.py`, `./scripts/backlog.ps1 validate`, skill-creator `quick_validate.py`, local links/anchors and source-path checks |
| Validation tooling | `python tests/test_validation_runner.py` (disposable Windows process/lock/pipe fixtures), physics/runtime timings, `validation_mountain_suite.gd`, `performance_trace_contract_suite.gd` |

Fixtures stay unranked and use disposable preferences/records. Generated evidence
belongs in ignored `artifacts/`, not personal bests. Source snapshots, actual
commands, versions/settings, coverage and missing evidence accompany new claims. Historical
missing output must be regenerated from a known baseline; a path is not a receipt.

## Performance method

Apply [the rendering target](RENDERING.md#performance-policy). Finish source edits,
identify the runtime path/version and record driver/OS, recipe/seed/model, camera,
physical/scenery cache status, actual pixels and effective settings. Warm up the
workload; exclude screenshot/readback/video encoding and GPU validation layers
from timing. Capture visuals separately.

### Ragdoll terrain collision

Run `scripts/test_pc_environment.ps1 -Suites terrain_collision_suite,streaming_collision_suite,physics_suite,runtime_suite`
with a fresh `-OutputDirectory`. The terrain suite uses the production `perf-slopes`
field and actual Jolt contacts against an exact triangle reference: 65/33-point
square grids, a clipped hole, complete interior coverage, normals, retirement
and return. Keep sub-millimetre contact tolerances separate from deterministic
skiing-state equality. Inspect a short native crash for fall-through or separation.
Headless shape build-and-attachment timings establish preparation CPU cost;
they do not establish rendered FPS or frame-stall attribution.

### Reusable baselines and experiment budget

Session stall costs (finish save, crash placement, retry roster) come from
`tests/session_stall_probe.gd` (headless, full-mountain flags): it records a
synthetic 150 s eligible run on the Standard mountain, times `to_bytes`,
SHA-256, Zstandard, the one-run and ten-run save transactions, five
`crash_recovery.resolve` calls along the descent and the cold and cached
`Records.selected` roster loads for ten ghosts, writing
`artifacts/session_stall/<label>.json`; `--stall-ticks=N` shortens the run.

Grass worker thread safety uses `tests/grass_worker_stress.gd` (headless, full-mountain
flags): eight pool tasks prepare cells while the main thread queries the field and
blocks on in-flight tasks; a clean 240-second run is the expected result.

For solver attribution that specifically needs Standard terrain,
`tests/solver_tick_benchmark.gd` requires `-FullMountain`, a recorded reason and
`-WorkloadMode FpsCritical` at the guard. Prefer compact fixtures for local kernels.
The optional harness runs 3,000 scripted ticks per pass and records CPU time and
position/velocity/heading/support samples, with a digest for those channels.
Matching digests establish equality only for those recorded fields, not all solver
state. Inspect `crashed_at`: a pass that continues after a crash cannot establish
ordinary riding cost. Fable's reported minimum-pass Mac figures are retained as
attribution; use the normal warmed-sample policy below for new acceptance work.

Reuse a saved baseline instead of rerunning the original setup for every change.
The current dense-forest reference is
[DENSE_FOREST_BASELINE.json](DENSE_FOREST_BASELINE.json): **Dev78 / fb625ab3**, three
15-second warmed trials recorded on 17 September with the installed Windows DX12
runtime, 4K High / Auto 75% FSR 4.1.1 / FG off / uncapped, and normal 20 Hz ghost
recording. The first route traversal is retained but excluded. Mean **9.180 ms /
108.93 FPS**, GPU **7.517 ms**; individual runs **107.82-109.52 FPS**. Median run
p95/p99 are **12.247 / 14.289 ms**. This replaces the historical Dev40 / 71.94 FPS
reference for current matching work; it does not establish whole-descent FPS.
Scenery rebuilt before warmup; this receipt provides no startup comparison.

Preserve the compact trace, timed-recording harness, repeat command and environment
receipt in `artifacts/fps_baseline_20260917/`, plus the raw results in
`artifacts/pc_environment/dense-baseline-20260917/`. The harness extends the maintained
`tests/performance_descent.gd`, enables normal timed recording with isolated record
paths, and disables CPU profiling for every trial. Native viewport GPU timing is
included; separate depth/opaque profiling is not part of this FPS reference.

Retain each trial, the arithmetic average of run mean frame times, FPS derived as
1000 / average ms, the observed range and separately aggregated run p95/p99 values.
Do not average unrelated routes, settings, profiled runs, candidates or invalid
trials together. The 1.57% observed frame-mean range comes from one process, not
cross-session confidence; a smaller candidate delta alone is inconclusive.

Baseline matching uses the recorded source/Dev version and relevant intervening
changes, runtime build/path, GPU/driver, route/event, camera, actual output/internal
pixels, graphics, density, cache state and profiling mode. A new candidate is
compared against this reference; its intended edit is not a reason to remeasure
the unchanged original. Documentation-only changes and age alone do not expire
the reference. Create a replacement reference when an accepted production change
alters that original workload, the engine/driver/hardware or settings change, or
repeatable observations indicate drift. Prefer existing qualified results first.

Default budget: **one hypothesis, one candidate, one focused visual check and one
15-second warmed candidate sample**. Include only the warmup needed by that route.
Reject visibly poor candidates before timing. A clear loss or result within the
saved baseline's observed variation can end the experiment immediately. A promising
gain gets at most one confirmation sample; add a short fresh original control only
if the comparison is ambiguous or drift is suspected. Beyond that budget, state
the specific unresolved question before running more. Do not automatically run
A/A matrices, A/B/A return cycles, every map, native pass profiling or RenderDoc.
Collect extra attribution only if it will decide the next change.

Skip manual/source/asset/snapshot/executable hash verification and before/after
hash inventories. Existing runtime compatibility checks still enforce usable
replays/caches; this policy does not change those formats. Use versions, Git
status/diffs, paths, settings and existing receipts for task bookkeeping. Hash
audits are opt-in only on explicit user request. This section supersedes older
repeat-count, fresh-control and hash-audit recipes below and in linked skills.

Report the saved baseline date/profile, actual candidate frame time/FPS and its
distance from the observed control range. Do not describe a historical average as
a simultaneously measured control. Preserve small timing summaries, representative
images and unique source assets; retire duplicate project/import copies and large
captures once their useful data has been extracted.

For a full-descent baseline justified under the bounded descent policy, generate
ordinary-input traces with `tests/performance_trace.gd` under the guard.
Only complete uncrashed descents become valid traces; the pilot supplies inputs,
not position/solver changes. Validate trace/core/generator/tuning/terrain identity
before playback. A failed pilot is a workload blocker, not license to substitute
a scripted teleport descent. Check the test's selected version against the current
baseline before producing or accepting a trace.

`scripts/benchmark_pc.ps1` defaults to `-TrialSeconds 15 -TrialStartSeconds 90`;
the duration is bounded to 1–60 seconds. It pre-rolls ordinary recorded input
offline to the selected section, warms the unchanged scene, then measures only
the requested window. An independent solver replay verifies the exact endpoint.
Source identity pins movement code; `run_session.gd` is excluded because it does
not execute during trace generation. Results explicitly use `short_production_trial`
scope, never complete-descent acceptance. Loading/pre-roll are separate costs.

Playback rejects stale source/model/generator identity and unsuccessful traces
before mountain/scene setup, then still verifies terrain identity and exact
replay completion. Use the fewest repetitions needed for warmup and the selected
sample; `-Repetitions` reuses the loaded scene. Saved FPS baselines can be reused
under the policy above. This does not replace a specifically requested cold-start
measurement.
`scripts/benchmark_pc.ps1` relays the engine's loading, trace and per-run progress
while preserving full logs; the outer guard no longer hides this second layer.

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','current-v15','-Version','15','-InputTrace','artifacts/current/input.json','-Upscaler','auto','-TerrainGI','off','-FrameGeneration','off','-FrameCap','0','-Repetitions','3','-ProfileFrameCosts') -Label current-v15 -TimeoutSeconds 2400 -CollectGpuMemory -FullMountain -FullMountainReason 'Representative production mountain timing and exact route inputs'
```

The example requires a separately prepared matching complete trace. Follow with
the 120 FPS capped configuration and independently selected FG if assessing it.
Report individual runs and medians of run statistics; do not pool percentiles.
`production.json` contains route/section frame distributions, CPU scopes in μs,
GPU/render-thread ms, draw calls and engine memory; `system.json` records source
stability, engine hash and process/system/GPU allocation telemetry. Windows
allocation and engine memory are not precise physical VRAM occupancy. Radial
route sections are labels for that trace, not universal terrain classifications.
The CPU `hud` scope covers HUD updates, not deferred CanvasItem `_draw()` calls.
Likewise, engine submission and callbacks can fall outside main's explicit scopes.
When attribution is incomplete, inspect a separately instrumented native script
profile; its debugger/profiler output and overhead are excluded from acceptance
timing. Inherited `super` calls can overlap profiler totals, so do not sum them.

Keep the game window focused during the measured descents. The current baseline
receipt producer rejects any unfocused measured frames, source drift, incomplete
replays or changed personal settings/records; preserve rejected attempts as
diagnostic evidence and use a fresh label for replacements.

### Rendering baseline receipt audit

Use [rendering_baseline_report.py](../scripts/rendering_baseline_report.py) to
build a machine-readable table from existing production receipts. The manifest
has a `runs` array; each entry supplies `label`, repository-relative output `path`,
`workload`, `phase`, and expected `repetitions` (default three). Give unchanged
return controls the same `control_group`. Keep native profiles in a separate
phase and omit their control group. Missing/invalid runs remain visible with
reasons; the analyzer never launches or repairs a run.

```powershell
python scripts/rendering_baseline_report.py --manifest artifacts/rendering-baseline/manifest.json --output artifacts/rendering-baseline/results.json
python -m unittest discover -s tests -p test_rendering_baseline_report.py
```

The table retains individual distributions, invocation-counted CPU scopes,
one-second completed-tick bins, streaming events, measured-window system samples,
startup and first-encounter/re-entry labels. GPU samples lag those CPU bins.
Comparison identity includes source/engine receipts, trace, camera, quality,
provider, cap, feature switches and collision mode. Identify the executable behind
the launcher and preserve existing physical/scenery receipts. Do not add binary
or personal-data hash audits.

For this bounded baseline method, predeclare process-median frame/GPU spread
at most 3% and p95/p99 spread at most 15%; permit at most one additional return
sequence when those gates fail. These observed ranges are not confidence
intervals. The analyzer reports the gate result without declaring an optimization
or accepting a historical run as current. Review route coverage and visual
qualification separately; scalar validity alone does not establish suitability.
Native interval aggregation uses the starting timestamp label, sums repeated
labels within each resolved frame, excludes four boundary frames per end, and
counts absent intervals as zero. On the pinned renderer, the timestamp precedes
the named pass. Do not add nested scope totals.

### Dense-forest A/A controls

The [unchanged forest control receipt](FOREST_REPEATABILITY_RESULTS.json) records
five processes measured at Dev 35 with 4K High, Auto 0.75, FG/GI off and no cap.
Its numerical spread passes with the explicit Codex-connected exception; it does
not certify zero desktop activity or uniquely explain the process-median drift.
Detailed evidence and the executed driver remain in
`artifacts/forest_repeatability_20260914/REPORT.md`.

The historical qualification used five fresh processes with the ordinary forest
trace and the unchanged `benchmark_pc.ps1` with `-ScenarioReplay`,
`-TrialStartSeconds 0 -TrialSeconds 15 -Repetitions 4`, `-FrameCap 0`,
`-Upscaler auto -RenderScale 0.75`, `-FrameGeneration off -TerrainGI off`, and
`-ProfileFrameCosts`. Keep one FpsCritical owner, fresh labels, an explicit
FullMountain reason, and fixed inter-process rest. Preserve traversal 1 as both
first-entry evidence and deterministic full-route prewarm; only traversals 2-4
are the three warmed acceptance repetitions. The harness additionally renders
240 stationary warmup frames before each traversal. A warm re-entry can still
perform collision, region and publication work; retain these costs.

Record raw per-run frame/GPU p50 medians as well as the existing medians of run
means, without pooling percentiles. Apply the 3% median and 15% p95/p99 spread
limits to the five process values; exclude a separate ETW diagnostic. This is a
reference procedure, not a required rerun for each candidate. No rehash is needed.
Sensor polling needs effective CPU clocks and GPU
clock/power/temperature; its wall-clock cadence limits hitch-level attribution.
Audit actual ETW event loss and GPU queue/residency decoder coverage. Allocation
counters and a partial GPU packet table do not establish physical residency or
full GPU busy time.

The current `benchmark_pc.ps1` background CPU percentages are quantized because
`[Math]::Max(0, double_delta)` selects an integer overload in PowerShell. Retain
them as coarse observations, not precise scheduling or zero-activity proof.
Use separately recorded ETW context switches/ReadyThread events for precise
scheduling, and qualify any remaining uncertainty about unrecorded controls.

### Terrain grass performance

The [terrain-grass receipt](TERRAIN_GRASS_PERFORMANCE_RESULTS.json) owns the
individual 4K High trials, medians, identity, preparation, CPU/GPU and memory
results from the completed grass follow-up. The bounded optimization reduced
forest spikes while retaining populations and pixels. Both controls still miss
the whole-game goals. The receipt discloses desktop workload variation, small
observed allocation growth and separately labelled high-speed/GPU diagnostics;
it is not complete-descent or human acceptance.

`tests/terrain_grass_trace.gd` uses the ordinary route pilot and production solver
to produce two collision-free 15-second traces at the surveyed Standard forest
origin `(1608,1416)` and rock/snow transition `(-244,-2224)`. It rejects surviving
obstacle contacts as well as crashes; failed search attempts stay in the output.
No velocity, contact, obstacle or position override occurs after the local launch.
`scenario_origin` is a finite XZ launch on exact terrain support; it requires
`-ScenarioReplay`, cannot mix with a stress driver, and cannot claim a complete
descent. Runtime playback checks terrain bounds, initial state, checkpoints and
the independent solver endpoint. Regenerate after relevant identity changes.

The production benchmark accepts `-Grass on|off` (default on). After ordinary
graphics application, off clones the effective profile and changes only
`scrub_density` for `world.grass` and `world.minerals`. Other scrub, trees,
minerals, shadows, textures, tracks, weather and simulation retain their settings.
For grass cost comparisons, qualify zero ground/mineral grass off and nonzero
ground grass on. The general benchmark permits enabled vegetation to be naturally
absent on bare-snow routes; an empty on-arm cannot establish grass cost.
Receipts retain start/end populations, resident/pending/inflight cells, worker
preparation milliseconds, exact final state and the normal CPU/GPU/streaming
telemetry. `stream_grass` measures main-thread streaming/submission in microseconds;
worker preparation statistics are separate and must not be summed with frame time.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/terrain_grass_trace.gd','--','--output=artifacts/grass-current/traces') -Label grass-inputs -WorkloadMode Shared -TimeoutSeconds 300 -FullMountain -FullMountainReason 'Current bounded ordinary inputs through production grass habitats'
# Repeat independently with fresh labels; pair on/off for each habitat.
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','grass-forest-on-1','-InputTrace','artifacts/grass-current/traces/forest.json','-ScenarioReplay','-TrialStartSeconds','0','-TrialSeconds','15','-Repetitions','3','-Grass','on','-FrameCap','120','-Upscaler','auto','-RenderScale','0.75','-TerrainGI','off','-FrameGeneration','off','-ProfileFrameCosts') -Label grass-forest-on-1 -WorkloadMode FpsCritical -TimeoutSeconds 600 -CollectGpuMemory -FullMountain -FullMountainReason 'Matched production grass-only 4K High cost'
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/terrain_grass_lod_playtest.gd') -Label grass-lod-pixels -WorkloadMode Shared -TimeoutSeconds 120
```

Keep three independently launched matched pairs and three warmed repetitions per
launch separate in reports. Reset/replay revisits the same cells; retain per-trial
memory, streaming chronology and identical settled populations. Use the existing
explicit 170 km/h stress route separately for fast traversal; its collision
policy cannot substitute for ordinary-input evidence. GPU pass captures are
separate from acceptance timings and only attribute pass time, not exact overdraw
pixel counts. Follow the same source/focus/personal-data validity gates above.

### Immortal high-speed stress trials

For high-speed rendering/streaming investigations, the user-selected workload
is **170 km/h**, full tuck and no braking, for independently warmed 15-second
sections. `benchmark_pc.ps1 -ScenarioReplay -StressSpeedKmh 170` explicitly loads
`tests/performance_stress.gd` into that benchmark only. Ordinary gameplay,
recordings and crash/handling regression suites retain the production solver.

The driver normalizes velocity magnitude before/after each 120 Hz tick while
retaining direction, terrain support, flight, body/animation and observers.
Obstacle broad/narrow-phase queries and hit observations still execute; their
translation stops and fatal transitions do not interrupt this stress workload.
This is a speed-controlled performance scenario, not handling/crash acceptance.
Completed motion telemetry receives the same regulated velocity.

Generate a fresh, source-identified fixture with
`tests/performance_stress_trace.gd`; optional `--origin=x,z` starts directly in a
selected terrain/forest region, with its exact terrain height and downhill
heading. No long braking pre-roll is needed. The driver hash, speed, immortality,
collision policy and start are part of the fixture, so ordinary/stress modes
cannot silently consume each other's traces. Preserve current terrain/model and
per-second trajectory checks. A changed driver requires regenerating fixtures.

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--headless','--script','tests/performance_stress_trace.gd','--','--stress-speed-kmh=170','--seconds=15','--trace-output=artifacts/high_speed_stress/open.json') -Label prepare-high-speed -TimeoutSeconds 300 -FullMountain -FullMountainReason 'Representative production mountain timing and exact route inputs'
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','high-speed-open','-InputTrace','artifacts/high_speed_stress/open.json','-ScenarioReplay','-StressSpeedKmh','170','-TrialStartSeconds','0','-TrialSeconds','15','-Repetitions','3','-FrameCap','0') -Label high-speed-open -TimeoutSeconds 900 -CollectGpuMemory -FullMountain -FullMountainReason 'Representative production mountain timing and exact route inputs'
```

Receipts use `scope: speed_controlled_stress` and retain actual minimum/mean/
maximum speed, travelled metres, grounded ticks, collision queries, nonblocking
contacts and prevented crash reasons. Reject a run outside 0.01 km/h of its
requested speed or below 90% of speed x duration in travelled distance; a HUD
speed alone is insufficient. Focus, source, endpoint, display and personal-data
checks still apply. `performance_stress_suite.gd` covers repeatability, continued
movement through impacts, telemetry and isolation; run physics/runtime suites
when changing this harness. Compare fresh matched before/after stress runs.

The saved workload locations below share Standard seed `849205174`, generator
15, 15 seconds, 170 km/h, full tuck and no braking. These are source-pinned
trace snapshots: after solver or driver edits, regenerate at the listed X/Z
with `--origin=x,z`; never bypass the stale-trace check. The generator derives
height and initial heading from the same authoritative terrain.

| Saved case | Origin X/Z (m) | Selection evidence |
|---|---|---|
| [Dense forest](../tests/fixtures/performance_stress_forest_170.json) | `583.4906616210938,-997.8701171875` | User-selected descent; 274-900 trees within 175 m in the saved trace. |
| [Rock field](../tests/fixtures/performance_stress_rocks_170.json) | `-736,288` | Rendered rock field/shelves; 48-196 nearby rock bounds per second, 398 distinct rocks across 15 s. |

Rock counts exclude glaciers and use distance to collision AABBs, not screen
coverage. Its retained native selection run travelled 707.66 m and matched all
trajectory checkpoints at 170 km/h. Selection captures are in
`artifacts/pc_environment/high-speed-rock-visual/`; they do not establish FPS.
Use fresh capture-free repetitions for performance comparisons at both sites.

### Native GPU pass attribution

`scripts/benchmark_pc.ps1 -ProfileGpuPasses` selects
`tests/performance_gpu_profile.gd` and supplies Godot's native `--gpu-profile`
flag. Keep the ordinary trace/scenario, settings and endpoint checks. Use this
only for attribution; omit the switch for the three capture-free acceptance
repetitions. `-ProfileFrameCosts` remains independent CPU instrumentation.

`gpu_passes.json` retains resolved RenderingDevice frame IDs and named GPU
nanosecond / CPU microsecond timestamps, read on the render thread without a
new device synchronization. Subtract consecutive timestamps within a frame;
ignore `<`/`>` scope markers as pass names, and never sum nested scope totals.
The requesting simulation tick is not the delayed GPU frame's exact tick.
Discard boundary frames when aggregating each trial. The 10,000-frame bound
fails explicitly on overflow; missing native opaque-pass markers also fail.

On the pinned custom DX12 renderer, the engine's **FSR2** timestamp wraps the
selected native FidelityFX provider, including its reactive copy and dispatch
boundaries. Read the actual provider from `display.fidelityfx`; the marker name
alone does not identify FSR2. Viewport timing does not isolate external powder
reconstruction. Additional compute query boundaries can change submission cost;
measure that instrumentation separately before comparing performance.

Example with a validated current short scenario:

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','gpu-attribution','-InputTrace',$fpsTracePath,'-ScenarioReplay','-TrialStartSeconds','0','-TrialSeconds','15','-Repetitions','1','-FrameCap','0','-ProfileGpuPasses') -Label gpu-attribution -TimeoutSeconds 600 -CollectGpuMemory -FullMountain -FullMountainReason 'Representative production mountain timing and exact route inputs'
```

### Forest batch submission

`performance_descent.gd` retains `submitted_primitives` and `submitted_objects`
alongside draw calls in each row and raw frame file. These use the engine's
[last-rendered-frame monitors](https://docs.godotengine.org/en/stable/classes/class_performance.html#enumerations)
after object culling. Primitives count vertices or indices across depth/shadow passes; they are not unique triangles, logical tree
counts or pixels that survive individual LOD/foliage shader rejection. Keep
stored population, resident regions/batches, these submission counters and
native visible output distinct. Both sides of a comparison use the same two
monitor reads; detailed spatial readbacks belong outside acceptance timing.

`forest_preparation_suite.gd` requires a native renderer (the generic suite
runner is headless). It checks bulk-upload equivalence, all 24 tree variants,
conservative wind/card bounds, signed partition edges, individual LOD reach,
quality consumers and repeated residency retirement/re-entry with valid slots.

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--script','tests/forest_preparation_suite.gd') -Label forest-batch-native -TimeoutSeconds 180
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--script','tests/forest_batch_visibility_playtest.gd') -Label forest-batch-visual -TimeoutSeconds 300
```

The visual producer compares the current grouping with an explicit 192 m
reference at identical frozen camera/wind states: 63 paired native 1280x720
frames cover presets 1/7/10, turns, signed region crossings, maximum wind,
50/100% visibility aid and low-sun off-camera shadows. This is rendered
regression evidence, not 4K performance, whole-route or controller acceptance.
Its readbacks and receipt are in `artifacts/spatial_batch_visibility/visual/`.
Use fresh 15-second forest/rock/open workloads from the stress-trial instructions
above for capture-free FPS, CPU/GPU, memory and repeated-entry comparisons.

## Recorded bug cases

Use in-game **Test Cases** for new human demonstrations that need visual evidence,
trimming or independent speed/immunity/obstacle controls. Start by reading the
user's title, observed/expected notes, selected original time range, endpoint and
active settings. Never infer ordinary gameplay from a modified scenario.

```powershell
./scripts/test_case.ps1 -Case 'C:\path\bug.apexcase' -Mode Inspect
./scripts/test_case.ps1 -Case 'C:\path\bug.apexcase' -Mode Capture -FullMountain -FullMountainReason 'Reproduce the exact mountain recorded in this case'
./scripts/test_case.ps1 -Case 'C:\path\bug.apexcase' -Mode Rerun -FullMountain -FullMountainReason 'Reproduce the exact mountain recorded in this case'
./scripts/test_case.ps1 -Case 'C:\path\bug.apexcase' -Mode RerunCapture -FullMountain -FullMountainReason 'Reproduce the exact mountain recorded in this case'
```

Each mode uses the workload guard and creates a fresh output folder under
`artifacts/test_cases/` (or explicit `-Output`). Inspect exports metadata, notes,
selected completed telemetry and all accepted control-event times to `result.json`.
Capture reconstructs the recorded mountain and emits eight PNGs by default
(`-CaptureFrames 2..120`) and a contact
sheet with original timestamps; JSON distinguishes requested time from captured
frame time. It preserves saved poses/camera using current rendering. Rerun retains
recorded tuning and applies the launch-to-Out input/control prefix through the
current production solver and diagnostic policy, reporting every selected tick's
actual telemetry, trajectory difference, contact/impact state, speed injections,
prevented damage and termination. The original file is never modified.

`RerunCapture` adds captures of the actual current solver's completed final poses
to Rerun, using saved camera/weather samples. It does not seek back to old poses
between solver steps. Fresh crash captures remain fresh Jolt observations.
The capture HUD is suppressed; the comparison page supplies telemetry from the
correct state origin. This is a final-pose comparison against reconstructed
terrain, not recreation of complete effect/audio history.
Capture, Rerun and RerunCapture also emit the common scenario manifest/telemetry;
compare Capture versus RerunCapture directories with `compare_scenarios.py`.
The page identifies recorded poses versus current-solver poses, selected tick
versus actual captured time, retained tuning and source changes. Rerun remains
headless telemetry when visuals are unnecessary. A default-tuning change still
requires a separate fixture using the new tuning; case reruns retain recorded values.
Case wrappers retain a producer reservation because mountain preparation can share
cache outputs. A bounded recording fixture can use `tests/test_case_playtest.gd`
with `--recording-only --output=artifacts/...`; its report explicitly excludes the
crash lifecycle. Omitting that flag retains the complete existing playtest.

`comparison` distinguishes `matching_source_verification` from
`changed_code_comparison` using source/engine identity and capture stability.
Matching-source skiing divergence fails validation. Changed-code differences are
observations to compare against the notes, not automatic failures or fixes. Fresh
Jolt crash motion is separately reported as a new observation. A successful exit
never proves the bug is fixed. Incompatible input/policy or terrain reconstruction
is rejected; the tool never supplies controls beyond saved coverage. Unsupported
format/rig/assets give a clear error. Physics changes alone do not invalidate
captured visual evidence. These cases are diagnostic and cannot qualify as ordinary
gameplay or full-descent performance baselines; the existing benchmark compatibility
checks remain strict.

Run focused contracts and required shared suites through the existing batch guard:

```powershell
./scripts/test_pc_environment.ps1 -Suites test_case_suite,controller_input_suite,performance_recording_suite,performance_trace_contract_suite,physics_suite,runtime_suite -OutputDirectory artifacts/test_cases/regression
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/test_case_playtest.gd','--','--ui-staged-loading','--graphics-quality=high','--upscaler=auto','--render-scale=0.75','--fps-limit=120','--frame-generation=off','--terrain-gi=off','--benchmark-no-captures') -Label test-cases-native -TimeoutSeconds 600 -FullMountain -FullMountainReason 'Exact mountain case-recording and replay integration'
```

The native fixture exercises pause, controller focus/text entry, trimming/reopening,
seek/camera restoration, airborne/crash capture and record isolation. Append
`--case-performance` to its user arguments for three matched pairs: two-second
warmup plus 15 measured seconds each, 3840×2160 High, identical diagnostic scenario,
unchanged rendering settings. Reject unfocused trials and differing trajectories.
Report this capture overhead separately from ordinary/full-descent performance,
rendered inspection and human/controller acceptance. The earlier input-only recorder
below remains a separate strict benchmark tool. Package/session contracts belong
to [Racing](RACING.md#diagnostic-test-cases); UI controls to
[Presentation](PRESENTATION.md#test-cases).

Implementation verification (2026-09-13): 49 package/policy checks, 51 controller,
12 input-recorder, 13 trace-contract, 56 physics and 192 runtime checks passed.
The native lifecycle fixture passed 23 checks, including focus/save retry and
controller text entry. Skiing, airborne and crash reconstructions were visually
inspected. Selected and retained-prefix clips plus crash skiing reran exactly with
matching source; a changed-source case was correctly classified separately. Three
matched 15-second 4K High samples measured mean capture cost increases of
0.57–1.94 ms/frame (same diagnostic trajectory, all focused). This is bounded
capture overhead, not an ordinary-gameplay baseline. Human/physical-controller
acceptance remains open. Detailed local evidence: `artifacts/test_cases/DELIVERY.json`.

### Player recordings and short scenarios

Streaming investigations can add `-ProfileFrameCosts` to the benchmark to retain
`streaming_events_N.json`. Events contain scope, process-frame ID and absolute
begin/end microseconds; matching frame intervals also carry tick and position.
Correlate overlapping events with those intervals instead of adding nested
scope maxima. The opt-in event buffer caps at 20,000 entries per trial and is
reset between trials; disk output happens after measurement. Subscopes distinguish
collision terrain/obstacles/minerals/prefetch, mineral scans/textures, and forest
scan/eviction, region upload and publication. These CPU scopes do not measure
asynchronous GPU upload completion. Ordinary benchmark runs also reject any
unfocused measured frames and reacquire window focus before each warmup.

`-ColdCollision` replaces only the ragdoll collision owner before each trial's
normal warmup, retaining the current mountain, renderer and input/endpoint
validation. Use it to distinguish first convex preparation from repeated entry
with the shared collision cache. It is an explicit test setup, not a gameplay
restart or a cold process/renderer measurement. Omit it for ordinary repeated
entry. `collision_streaming` reports body/shape counts, queue peaks and shape
point bytes; point bytes exclude Jolt's native allocations. Keep render captures
separate from these timing runs.

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

Scenario playback defaults to the recording's exact endpoint, including fractional
seconds. The benchmark's default 15-second window starting at 90 seconds is not
applied. Supplying `-TrialSeconds` or `-TrialStartSeconds` directly to
`benchmark_pc.ps1 -ScenarioReplay` opts into a window; duration alone starts at
zero. Ordinary benchmark defaults are unchanged.

The same normal physics/render loop checks the original trajectory and stops at
the captured tick. Partial/crashed clips require explicit scenario mode and produce
`scope: recorded_scenario`; they cannot count as full-descent evidence. Only a
complete uncrashed player recording may replace the pilot trace in
`scripts/benchmark_pc.ps1 -InputTrace ... -Repetitions 3`. Old eight-field benchmark
traces must be regenerated. Personal competitive replays separately use current
format 7 with nine inputs and lossless clocks; incompatible older recordings are rejected without
migration. The input-only recorder and replay helpers live under `tests/`, sharing the exact input codec in `scripts/diagnostics/case_inputs.gd`; the production scene is inherited.
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
phase (default all); `--interface-no-captures` omits visual evidence.
`--interface-compact-ui` selects only the five normal-motion UI cases. The
producer restores the validated warm Standard fixture and fails if absent; it
uses scoped file metadata, not recursive source or executable hash audits. Paired
layout runs keep both HUDs resident/updated while toggling visibility, so they
isolate layout cost, not the whole historical engine. Ordinary production moving
routes are measured separately. Never imply omitted phases passed.

### Windows shader and streaming integration

Use `tests/windows_forest_integration_playtest.gd` under a Shared native DX12
guard for thirteen capped 4K views: production spruce/fir/pine at 6–82 m,
actual dense-tree 12/64 m shader transitions and frozen-camera clear/active/shifted
clouds. `--output=artifacts/FRESH/forest` selects isolated output. No FPS claim.

`tests/windows_streaming_integration_playtest.gd -- --map=perf-mixed
--output=artifacts/FRESH/mixed` selects the 256×512 m production component fixture.
Use `--map=perf-gravel` for qualified nonzero gravel. Inspect the eight capped 1080p
views: cell crossings and 280/420 m macro texture hysteresis. The producer checks
all three texture channels each frame and preserves physical data. Camera height
stays above support; these local views do not establish full-mountain visuals.
After inspection, add `--no-captures` under FpsCritical for one 900-step CPU sample
after 90-step warmup. Report teleport/eviction peaks separately from ordinary
skiing and retain the saved matching dense-route FPS baseline.

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

### Firm-carve response producer

`tests/firm_carve_suite.gd` measures ordinary 120 Hz commands on a planar snow
surface exactly representable by the shared 4 m terrain authority. The default
24 cases cover full sideways and forward-diagonal entry/reversal at 60, 120 and
160 km/h in 2 cm and 16 cm snow. `--full` expands to 432 cases with both steering
directions, mirrored 20% cross-slopes, small corrections, release and rapid
reversals. It never creates a session or writes personal bests.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/firm_carve_suite.gd','--','--full','--output=artifacts/firm_carve/current-full.json') -Label firm-carve
```

The explicitly retained `tests/fixtures/firm_carve_v34.json` contains the captured
pre-change model-34 response at source commit `607c92a`; it is a numeric regression
reference, not a compatible production replay. Metrics separate input, requested
and applied ski yaw, pressure transfer, actual edges, slip and travel yaw at
0.25/0.5/1 second. `--trace` also retains every tick. A reversal starts after the
same 30-degree travel excursion so different entry speeds cannot select different
turn phases. The suite measures entry to 1 degree, reversal to sustained opposite
travel yaw, and distance through a 45-degree arc. Radius targets are aggregate
calibration checks, with individual speed/slip/support guards; they do not claim
that every snow/input combination improves equally.

`tests/firm_carve_capture.gd` renders a fixed 15-second sequence using the production
skier and chase camera, with `--view=side` for equipment review, `--depth=0.02` or
`0.16`, and a fresh `--output=artifacts/...`. Pass arguments through the guard's
string array. It records source hashes, physical states and final skinned poses
for `pose_pole_mesh_audit.gd`. `--reference` requires the deliberately frozen
model/tuning under `artifacts/firm_carve/baseline-source`; missing historical
sources are unavailable evidence, never a reason to relabel current source.
These controlled snow-plane captures establish pose/handling evidence, not world
scenery performance or human controller acceptance. Current model-35 paired
captures, matched-speed diagnostics and retained findings live under
`artifacts/firm_carve/EVIDENCE.md` and its linked captures/receipts. The strict
pole/clothing clearance audit remains failing, with more intersecting frames
in the faster-turn clips; equipment attachment checks and controller acceptance
do not establish clean clothing clearance.

## Mountain evidence

2026-09-10 v15 matched Standard work established deterministic outputs across
worker counts, source/engine-validated caches and faster generation/loading.
Initial means: cold generation 422.634 s v14 →135.579 s v15, physical-cache
loading 10.349→5.402 s, cached rendered readiness 144.683→64.324 s. A later
dependency-hash optimization brought v15 cold mean to 130.843 s. These retain
their original workloads; readiness includes scene submission and is not FPS.
Producers/receipts are the v15 generation suites and `artifacts/generation_v15/`.

Current default-v15 route scenario coverage, source identity and reproduction
commands are in [World's bounded route evidence](WORLD.md#current-bounded-default-v15-route-evidence)
and its [current source-hashed receipt](CURRENT_V15_BOUNDED_ROUTE_RESULTS.json).
It contains six graph surveys and three matched 15-second 170 km/h
speed-controlled probes per face. This is automated bounded scenario evidence,
not route acceptance: ordinary player handling, rendered inspection, frame
performance, controller acceptance, alternate-path coverage and other seeds
remain separate. The [model-28 route receipt](V15_ROUTE_AUDIT_RESULTS.json) is
historical provenance only and must not be used as current acceptance.

## Performance evidence

### Bounded high-speed scenario recorded on 2026-09-13

The [recorded bounded high-speed receipt](CURRENT_V15_BOUNDED_HIGH_SPEED_PERFORMANCE_RESULTS.json)
uses its recorded source/runtime identity, three independently warmed 15-second
capture-free 4K High repetitions, and the agreed 170 km/h full-tuck/no-brake
control protocol. Its source table predates subsequent presentation changes;
revalidate it before a new comparison. It is not a whole-route baseline, visual inspection, or human/controller
acceptance. Its individual runs and medians remain the source of any current
frame-time claim.

On 2026-09-13, the source-hashed model-35/generator-15 receipt recorded the
following focused, source-stable repetitions. These are per-run measurements;
the median row is the median of run statistics, not a pooled distribution.

| Run | Frames | Average FPS | Mean ms | p95 ms | p99 ms | 1%-low FPS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1,116 | 74.38 | 13.44 | 19.09 | 29.17 | 25.98 |
| 2 | 1,177 | 78.42 | 12.75 | 17.49 | 23.66 | 35.51 |
| 3 | 1,175 | 78.37 | 12.76 | 18.03 | 24.81 | 32.43 |
| Median statistic | — | 78.37 | 12.76 | 18.03 | 24.81 | 32.43 |

The run held the Standard seed's dense-forest trace at 170 km/h for exactly
1,800 solver ticks per repetition, at 3840x2160 output and 2880x1620 internal
pixels (High preset 7, Auto FSR 4.1.1 at 0.75 scale, frame cap 0, frame
generation and terrain GI off). It used a warm, source/engine-validated
physical archive; 50.27 seconds of one-time scene preparation is reported
separately and is not included in the 15-second frame samples.

Recreate the trace and measured receipt with fresh labels after rechecking
source identity; this production-mountain request is intentionally explicit:

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/performance_stress_trace.gd','--','--stress-speed-kmh=170','--seconds=15','--origin=583.4906616210938,-997.8701171875','--trace-output=artifacts/current_high_speed_stress/dense_forest_170.json') -Label current-v15-high-speed-trace -TimeoutSeconds 300 -FullMountain -FullMountainReason 'Generate the current dense-forest bounded speed-controlled performance trace'
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','current-v15-high-speed-170','-InputTrace','artifacts/current_high_speed_stress/dense_forest_170.json','-ScenarioReplay','-StressSpeedKmh','170','-TrialStartSeconds','0','-TrialSeconds','15','-Repetitions','3','-FrameCap','0','-Upscaler','auto','-RenderScale','0.75','-TerrainGI','off','-FrameGeneration','off','-ProfileFrameCosts') -Label current-v15-high-speed-170 -WorkloadMode FpsCritical -TimeoutSeconds 1200 -CollectGpuMemory -FullMountain -FullMountainReason 'Current dense-forest 4K High speed-controlled performance evidence'
python tests/report_current_bounded_high_speed.py --label current-v15-high-speed-170 --guard current-v15-high-speed-170 --trace artifacts/current_high_speed_stress/dense_forest_170.json --output docs/CURRENT_V15_BOUNDED_HIGH_SPEED_PERFORMANCE_RESULTS.json
```

### Historical v15 player-descent baseline (model 28)

This retained model-28 measurement predates later pole/recovery/ghost and
physics changes. Its [receipt](V15_PERFORMANCE_BASELINE_RESULTS.json) remains
valid for its recorded sources, but it does not measure the combined current
build and is not current performance acceptance.

2026-09-12: three capture-free replays of the user's **attempt 8**, a complete
122.025-second descent, reproduced all 14,643 solver ticks and 122 checkpoints.
All three stayed focused; 1,008 source hashes and 32 personal settings/record
files stayed unchanged. The [structured receipt](V15_PERFORMANCE_BASELINE_RESULTS.json)
retains each run, medians of run statistics, full identities and raw-evidence
hashes. This completed the historical [baseline audit](../backlog/abandoned/AA-20260911-153903-current-4k-performance-baseline.md).

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
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','player-v15-4k-focused-20260912','-Version','15','-InputTrace','artifacts/player_recordings/player-20260911-221639/attempt_008.json','-Upscaler','auto','-RenderScale','0.75','-TerrainGI','off','-FrameGeneration','off','-FrameCap','120','-Repetitions','3','-ProfileFrameCosts') -Label player-v15-4k-focused -TimeoutSeconds 1200 -CollectGpuMemory -FullMountain -FullMountainReason 'Representative production mountain timing and exact route inputs'
python tests/report_current_4k_baseline.py
```

The receipt producer defaults to these retained labels and verifies raw frame,
GPU, render-CPU and draw-call distributions before publishing. For a new run,
pass matching `--label`, `--guard`, `--trace`, `--evidence` and `--output`; the
evidence directory holds before/after personal-file hashes, the observed worker
binary identity and route provenance. Detailed samples stay in ignored
`artifacts/pc_environment/player-v15-4k-focused-20260912/`.

### Historical narrower workloads (including interface)

Historical v14/model-26 full descents and model-28 short routes also missed tail
targets. Model-28 snow-contact laboratory samples at 4K/.75 FSR4 met their short
frame-time gate, with increased snow CPU/GPU cost for stronger output; they do
not establish sustained skiing.

2026-09-11 v15/model-28 interface protocol: preset 7 missed summit p95 and snowy
forest mean/p95/p99 targets; Ultra also missed tails. Preserve the exact rows,
identities and limits in the [historical structured results](INTERFACE_PERFORMANCE_RESULTS.json).
This data remains byte-preserved from the original report and is not current
interface or skiing performance acceptance. Fixed views, short moving cases and
UI cost are not a complete-descent result.

## Presentation evidence

`tests/bright_ui_suite.gd` uses the short-course fixture (256 x 512 m, 4 m cells,
zero objects), isolated records and controlled focus. It exercises direct crash
shortcuts, pause/settings return, unavailable recovery, device badges and compact
bounds. Native mode captures start/pause/crash/settings/HUD at 720p, 1080p, 4K and
ultrawide, plus night, enlarged UI, Reduced Motion and device variants. Output is
`artifacts/bright_ui/native/`; headless output is `artifacts/bright_ui/functional/`.
Run it under the existing Shared guard with `--headless --script` for logic or
`--script` for native rendering. Reserve the producer/output; screenshots and
simulated controller input are not FPS or physical-controller acceptance.


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

The [presentation comfort review and listening/controller checklist](PRESENTATION_COMFORT_REVIEW.md)
records the 2026-09-12 bounded current laboratory chronology, HUD visibility,
pause/settings/resume and separate motion controls. Preparation is complete;
full-mountain, close-fitting and actual human/controller/listening acceptance
remain explicitly separate.

### Forest transparency producers

`foliage_sight_suite.gd` checks independent strength/reach, lifecycle, isolated
preferences and material propagation. Native `foliage_sight_mask_playtest.gd`
checks the production include at five strengths/depth boundaries across nine
screen tiles and stacked layers. Synthetic coverage cannot establish real-tree
appearance. `foliage_sight_settings_playtest.gd` checks actual controls and both
preview views; `foliage_sight_playtest.gd` captures matched first-person/chase
strengths, chronology, quality changes and fallback cards.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/foliage_sight_settings_playtest.gd') -Label forest-settings
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/foliage_sight_playtest.gd','--','--graphics-quality=high','--frame-generation=off') -Label forest-stand -TimeoutSeconds 600
```

The optional world/benchmark producers require a current validated ordinary-input
trace and matching Standard cache. `foliage_sight_world_playtest.gd` captures
15-second cases; `foliage_sight_benchmark.gd` cycles 0/50/100% for three warmed
15-second repetitions each at fixed 60% reach. Supply `--input-trace=PATH` and
`--trial-start-seconds=N`, verify actual dense-forest coverage and keep captures
out of timing. Reuse combined bounded riding evidence; do not generate a full
route solely for FPS during this concurrent run. Default review outputs are fresh
worker directories, but inherited `--label` / `--benchmark-label` override them.

### Beacon and navigation producers

`finish_beam_suite.gd` checks geometry, true bounds, independent resources and
halo-free navigation style. `finish_beam_lab_playtest.gd` exercises the actual
lab caller. `race_beams_playtest.gd` requires the current Standard cache and
compares the explicitly retained `tests/fixtures/finish_beam_800m/` reference
with current production at normal Connected chase framing. Candidate selection
checks actual camera near/far/frustum and terrain LOS; captures require exposed
shaft, including above 800 m for the dedicated lower-finish 2 km/ridge views.
These geometric checks still need pixel/fog/prop inspection. A supplemental
upward view does not establish distant riding usefulness. Existing output paths
are refused.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/race_beams_playtest.gd','--','--output=artifacts/finish-current-review','--views-only','--distant-only') -Label finish-review -WorkloadMode Shared -FullMountain -FullMountainReason 'Fixed distant views require the current Standard mountain and production scenery.' -TimeoutSeconds 900
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/session_navigation_playtest.gd','--','--navigation-smoke') -Label navigation-review -WorkloadMode Shared -FullMountain -FullMountainReason 'Native map and riding visibility require current Standard terrain and scenery.' -TimeoutSeconds 900
```

`--diagnostics-only --search-seconds=30 --candidate-limit=6` performs bounded
selection before Main construction; limits are 5–120 seconds and 1–16 valid
finish candidates. Inspect its rejection receipts and selected complete view
bundle before native capture. `--distant-only --selection-report=PATH` reuses
that source-pinned selection. `--500m-only` restricts it to four images;
`--weather-only` produces twelve matched images covering Low Clear/Dusk,
Balanced Clear/Night and High Snowfall/Day at 1080p/4K. Both subsets require
`--distant-only` and the selection report. These are producers, not proof
of visibility. Preserve accepted historical 2 km/ridge and twelve weather images;
the weather review records pale, low-contrast snowfall visibility. The old
forest-obstructed 500 m view remains a rejected control.
See [finish review](../artifacts/orchestration_20260912/finish/WEATHER_NATIVE_REVIEW.md).

`--views-only --distant-only --navigation-500m` produces exactly four amber
hidden/shown 1080p/4K stills at the pinned navigation observer. Its old point-only
qualification omitted the gate's wider clearing. The route records that rejected
anchor and checks at most 33 candidates within 16 m, retaining the observer and
heading and enforcing complete race/gate plus shaft/terrain/tree predicates.
Record the selected anchor and actual distance, never call a shifted endpoint
identical to the historical point. All four stills need pixel inspection.

`--navigation-input-note=changes/ID.json` explicitly revalidates historical
coordinates against a development note captured before the run. Include every
historical source, current producer dependency and resolved executable in its
owned/read inputs. Missing inputs, changed captured bytes, runtime mismatch and
real engine-version changes fail. Engine dictionaries normalize JSON numeric
types before comparison; this does not waive build/hash/timestamp differences.
Reports retain old/new source hashes and current camera geometry. Old accepted
pixels are historical evidence, not current-source certification.

`session_navigation_playtest.gd --navigation-followup=ui,chronology,counts,reduced-motion`
uses one cached Main load and requires that captured input note plus a fresh
`--navigation-output=artifacts/PATH`. It selects native keyboard/controller map
views and race-state checks, a five-point 15-second input chronology, capped
1080p near/far 0/5/32 render ownership, and normal/reduced/normal shader phase
checks. These follow-ups never call the timing producer; `cost` is deliberately
not a supported follow-up selector. Use the Shared guard with `-FullMountain`
and a reason naming this fixed Standard terrain/route, not a benchmark guard.
The count images are functional evidence; matched screenshot-free frame/GPU
cost and variance remain a separately authorized performance requirement.
Physical-controller comfort and subjective visual approval remain separate.

Ordinary start/close/fade and broader capture routes remain separate.
For the remaining stationary finish/navigation cost question, prefer
`beacon_cost_playtest.gd`. It reuses the navigation producer's supported anchors,
settled production chase and effect updates without the legacy visual matrix or
hash receipt audit. Run `--capture --output=artifacts/UNIQUE-VISUAL` under Shared
with explicit Standard-mountain admission; inspect its near/far images. Then run
`--views=artifacts/UNIQUE-VISUAL/report.json --output=artifacts/UNIQUE-TIMING` under
FpsCritical. Timing reuses those exact anchors/cameras, with one warmed 15-second
sample for the retained 800 m finish, current 2,000 m finish and 0/5/32 personal
markers at each camera. It records frame/GPU/render-thread distributions, actual
4K pixels, effective settings and focus; no captures occur during timing. The
full Standard scene remains loaded but stationary: these are beacon cost
comparisons, not ordinary-input descent FPS. Current rendered review, source
metadata and isolated stores remain required. No performance acceptance follows
from a successful producer exit alone.

`--timings-only` uses one warmed 15-second
baseline/proposed pair per near/far view (four samples), not repeated ABBA;
`report_finish_beam.py` reports these stationary costs, not descent FPS.
Navigation `--navigation-views-only` omits its cost matrix;
smoke is a subset. Its marked ordinary-input descent stops at 15 seconds or
an earlier crash, and 0/5/32-marker timing is a separate static-view comparison.
Preserve `artifacts/session_navigation_render/` before another capture run.

`session_navigation_suite.gd` covers memory lifetime, identity changes, rebuild,
map pointer/controller ownership and limits; `session_navigation_checks.gd`
exposes checks for an already-loaded isolated main scene. It changes fixture
state and must not run on a user's active descent. Batch shared menu, interface,
race, prompts and physics/runtime checks once, rather than per marker feature.

### Snow contact and local boundary producers

Batch `snow_response_suite.gd`, `snow_contact_visual_suite.gd` and the existing
powder upload checks. Native `carving_raised_ski_tracks_gpu_suite.gd` checks live
stroke parity and exclusions; `local_snow_boundary_suite.gd` checks support,
recenter/atlas bytes and atomic material publication, including new/removed
ghost receivers, same-centre reopen, independently moving visual centres and
fresh strokes with unchanged mapping. Passing byte/flag checks
does not reproduce or resolve a visible gap or boundary.

For the raised-ski cause, the private TestSlope fixture omits placed trees/rocks
before world construction, preserving its actual 4 m terrain/snow/materials and
ordinary steering. Capture identical five-second cases with only cosmetic
eligibility disabled, then enabled, under identical final physics/equipment:

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/carving_raised_ski_tracks_capture.gd','--','--eligibility-reference','--qualities=balanced','--output=artifacts/carving-gate-before') -Label carving-before -TimeoutSeconds 300
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/carving_raised_ski_tracks_capture.gd','--','--qualities=balanced','--output=artifacts/carving-gate-after') -Label carving-after -TimeoutSeconds 300
python tests/carving_raised_ski_tracks_compare.py artifacts/carving-gate-before artifacts/carving-gate-after --output artifacts/carving-gate-comparison.json
```

The pair runs left/right/reversal/jump, 20 seconds total riding per invocation;
`--cases=reversal` focuses one case. Require low-load grounded and independent
near-surface candidates in entry/hold and after reversal; jump must execute once
with genuine airborne exclusions. All cases must reach 300 frames/bounded_limit.
Native/100% reconstruction is reapplied after preset selection in both modes.
Use fresh directories and compare only this revised fixture pair; the earlier
control crashed into a tree and used different reconstruction. Expand to Low/High
after focused reproduction. A reference with no gap means not reproduced;
rescued eligibility alone does not establish visible continuity.
The older snow wrapper/source reference also changes powder implementation and
cannot isolate this cause. `--timing` runs three warmed five-second capture-free
submission samples; this CPU proxy is separate from rendered FPS.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/local_snow_boundary_playtest.gd','--','--scenario=boundary','--preset=7','--upscaler=native','--seconds=15') -Label boundary-review -TimeoutSeconds 900
```

Repeat with `--reference` for the frozen baseline. Boundary/terrain-edge cases
are synthetic diagnostics; `ride_glide` and `ride_carve` use ordinary solver input
and stop after 15 seconds or an earlier crash. The current cached Standard fixture
is required; cache failure does not start cold generation. Compare native/Auto,
low sun/overcast, deformation on/off and relevant quality tiers. Inspect chronology
for relief/shading seams, recenter swim, holes and temporal trails. The boundary reference freezes the original boundary sources while the paired
scene retains the integrated carving path. Match completed and rendered poses,
not merely root inputs. In v5 the compute hashes match, but frozen/current crystal
includes differ; wider glitter/material changes are not a boundary-only result. `--timing --repeats=3` separates warmed
15-second capture-free samples; record recenter queries/uploads and CPU/GPU cost.

The current producer also accepts comma-separated `--scenarios` and a shared
`--selection=PATH --selection-mode=create|reuse` for the 15-second ordinary
glide/carve pair. Synthetic cases update the completed facing pose without solver
steps and report `solver_ticks=0`. `--matrix=remaining` requires 15-second visual
cases, one repeat and the exact `--route-proof=PATH --route-proof-sha256=HASH`;
it covers preset-10/low-sun and preset-4/Cloudy override cases in one world.
Its retained-edge case is synthetic. Current remaining coverage has six cases:
`low_sun`, `retained_edge`, `overcast_on`, `overcast_off`, `overcast_carve` and
`snow_reset`. The last uses ordinary snowy riding through on/off/reenable,
including fresh GPU packets and old-world-point relief probes. Both modes pin
actual Main render interpolation to 1.0 through private fixture copies; the
original stationary-render-root comparison remains rejected motion evidence.
Proof-backed timing is selected glide only, with matching origin/heading,
three 15-second repeats at 4K/Auto75% and no captures. The
[snow-reset handoff](../artifacts/orchestration_20260912/boundary/snow_reset_fix/HANDOFF.md)
and [matrix handoff](../artifacts/orchestration_20260912/boundary/matrix_fix/HANDOFF.md)
retain pinned commands and fixture limits. Configured coverage alone is not a pass.

### Current combined evidence boundary

The parent accepts scoped forest-strength, raised-ski continuity and boundary
rendering for the 2026-09-12 concurrent run. Forest has232 focused and430 native
mask checks, settings/preview failures[], and the accepted11-result production-tree
scene review covering both views/strengths, motion, quality and fallback. The
scene has no solver session and three-second motion clips; it is not ordinary
Standard-mountain riding or a capture-free0/50/100 timing comparison.

Carving continuity v3 audited2,400 rows/4,800 ski records and every600-tick case
trace. Balanced right/reversal restored278 samples across the three Balanced
cases; both skis remain live on every grounded right/reversal frame. Low/High
reversal and actual jump/rock exclusions pass. All900 paired Balanced physical
hashes and final ski transforms match. This is full physical trace evidence,
not a replay-file round trip, every-frame pixel review or fresh sustained-left/
switch capture. The legacy visual/timing wrapper stages are not reported passed.

Boundary q7 Clear/Day v3 supplies ordinary glide/carve and synthetic movement.
The final v5 pair completed six cases per mode,450 rows/JPGs each:5,400 total,
with exact-zero paired roots/cameras/skis/bases/FOV and central findings[].
[Forest's three-case review](../artifacts/orchestration_20260912/forest/matrix_v5_review/NATIVE_REVIEW.md)
inspected424 source images; [boundary's three-case review](../artifacts/orchestration_20260912/boundary/FINAL_MATRIX_REVIEW.md)
inspected468 plus eight GPU snapshots. Thus all six have independent scoped
pixel review;5,400 individually viewed images are not claimed. Synthetic timelines
have zero solver ticks, ordinary rides1,800/15 seconds. Genuine snowy reenable
rebuilds fresh relief and clears old in-atlas marks (R2); rendered pose matching
closes R4. q10 native dusk and q4 Cloudy Auto75/active FSR4.1.1 on/off are covered.

Loaded scalloped banks (R1), the unisolated carving spacing contribution,
foreground/spray contact occlusion and shared temporal rider/ski/shadow fringes
remain limits. Crystal closures differ while v5 compute hashes match; not every
white-fleck change belongs to the boundary correction. Captured C-pole/replay6/
archive3 scope is retained despite later lossless replay7/archive4 integration.
See [Rendering](RENDERING.md#snow-presentation) for the durable shape contract.

[Three warmed capture-free 4K pairs](../artifacts/orchestration_20260912/finish/boundary_timing_review.md)
found variable whole-frame results and an uncached snow/powder p99 increase to
3.115–4.889 ms. The [bounded previous-grid cache](../artifacts/orchestration_20260912/boundary/SUPPORT_CACHE_REVIEW.md)
passed24 byte/query/invalidation,22 boundary and7 carving-GPU checks. Its one
justified15-second follow-up made738 queries/reused5,904 knots, retaining82 support
uploads and1,800 dispatches; snow/powder mean/p95/p99 was.243/.533/.814 ms.
The cache holds1,296 CPU bytes and preserves published bytes. This addresses the
query cost; it is not three repeated final-cache timings or a full-frame speedup
guarantee. FPS caps/misses are advisory under the user's concurrent-run waiver.
Strict clean timing, full descent and human/controller acceptance remain separate.

The [four-record evidence map](../artifacts/orchestration_20260912/forest/final_four_records/CHECKLIST_MAP.md)
records passed and incomplete compound checklist items. Historical `PROGRESS.md`
checkpoints and private proposals are not current acceptance. Crash's completed
105-check native review and subsequent lossless-codec checks are distinguished
below. Navigation/ghost/finish retain their separate owning reviews and limits;
pole transition validation is recorded separately below. No additional matrix is requested here.

## Animation evidence

The captured steering regression uses `steering_recording_suite.gd` and the
15-second `steering_snow_suite.gd` neighbors. Frozen source/requested/final poses,
paired chase/body playback, handling changes and rejected candidates are indexed
in [Attempt 001 evidence](../artifacts/steering_jank/20260913/EVIDENCE.md).
The recorded opposite-direction defect passes automated and rendered checks.
Fresh controller Attempt 005 confirms much smoother steering, with a smaller
repeated rise toward center during sustained carving still reported. Its exact
2,924-tick replay and rejected balance experiments are retained in the same
evidence index; this is partial controller acceptance, not an all-clear. Existing
tuck clothing contacts and a pole-push hand-snap check also remain open.

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

### Pole propulsion and animation producers

`pole_push_suite.gd` records paired 30-second force/slope/exclusion fixtures;
`pole_push_pose_suite.gd` checks final fitting, connected grips, continuity and
articulated replay. Batch physics/runtime and relevant animation/equipment/input
regressions under the existing suite runner. The default curve's limits and
intended climb speeds require actual receipts; constants are not observed speeds.

```powershell
./scripts/test_pc_environment.ps1 -Suites pole_push_suite,pole_push_pose_suite,physics_suite,runtime_suite
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/pole_push_playtest.gd','--','--output=artifacts/pose_review/revisions/poles-current','--scenarios=flat,gentle,steep15,steep10,steep5,cutoff,downhill,left,right,brake_departure,fast') -Label poles-review -TimeoutSeconds 1800
python scripts/pose_review/freeze_sources.py --revision poles-current
```

Every named case is 15 seconds; select fewer cases for focused iteration.
`pole_push_capture.gd -- --probe` provides headless frozen pose data; `--no-push`
is the feature-off comparison. Enabled/disabled propulsion intentionally changes
physics, so do not demand physics equality between those variants. Within each,
presentation must preserve completed physics. Inspect source/requested/final
poses, loaded tip sliding, wrists, hips/jacket and complete shafts through turn,
release, high-speed plants and brake/departure flight. Full relevant clothing
coverage remains required; prior failed tuck-neighbor audits are not superseded.

The Blender source/export command belongs to [Assets](ASSETS.md#pole-action-source).
The editable `pole_push.blend` and `export_provenance.json` now exist; the receipt
identifies Blender 5.2.1 LTS and matching source/blend/runtime/builder hashes.
Its historical `runtime_pose_accepted` remains false: that export receipt is
provenance, not a runtime acceptance record. Source export does not clear contact,
shaft/clothing, mechanical, timing or human acceptance.

The committed-but-unvalidated 2026-09-13 model-32 recovery WIP snapshot reproduces the current
D failures, then passes existing contact 87/87 and pose 36/36 with the unchanged
14 cm bound. Worst brake/landing, steep10 and steep5 steps improve from
15.18/14.20/14.13 cm to 13.54/13.20/13.64 cm. Paired solver/phase, torso/legs,
fixed-grip, wrist-limit and both loaded-stroke checks pass in those fixtures.

The expanded native eleven-case matrix captures 900 frames per case (9,900
total), including 38 airborne frames and actual landing. All-frame maximum
joint step is 13.75 cm. Actual skinned-clothing audit fails in 89 frames:
cutoff 15-19 and 84 downhill frames, including cancellation 179-181. The other
86 intersections occur with pole fitting inactive. This wider matrix has no
matched full-mesh D baseline, so it does not establish a clipping regression
count. The previous 720-frame smoke does not clear this broader coverage.

The retained downhill reproducer also fails four existing limits: 23.89 cm tip
height (4 cm gate), 76.92 cm anchor residual (18 cm), 52.46 cm loaded tip step
(10 cm), and 3.64 cm minimum loaded wrist sweep (12 cm). Presentation begins
cancelling while the completed solver still has tiny positive thrust near the
speed cap. Merely retaining contact until zero force fixes height but leaves
anchor/step/stroke failures; that trial was rejected and restored. The task
remains blocked; the recovery candidate is preserved as an explicit WIP snapshot and is not shipped.
Affected anatomy/compact/attachment/landing/flight/settle checks pass; the full
seven-suite set is 344/345. The sole failure is the previously baseline-reproduced
120 Hz tuck hand-easing check. No assertion was relaxed.

Detailed source/engine/authoring hashes, old/new neighbors, rejected patch,
reproducer and regression receipts are in `artifacts/pole_transitions_20260913/`.
`artifacts/pose_review/revisions/20260913-poles-final/` contains the candidate's
native chronology, videos, selected pixel neighborhoods, full mesh report and
frozen 181-source snapshot; its directory name is not an acceptance claim.
Contact fitting averages 0.517-0.610 ms and total final fitting 1.426-1.539 ms
in the earlier paired diagnostic sample. These scopes overlap and are not
summed; they establish neither an FPS gain nor uncontended performance acceptance.
Controller feel, listening and subjective user approval remain separate. No
physics/input/session owner or editable asset changed.

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
remain unverified by the [race-loop audit](../backlog/abandoned/AA-20260911-153905-race-loop-acceptance-audit.md),
which the user retired before execution on 2026-09-12. The separate
[player/controller task](../backlog/abandoned/AA-20260911-153906-player-and-controller-acceptance.md)
was also retired without recorded human acceptance. These are no longer queued
requirements; their retirement does not establish acceptance. Task files own
their status/dependencies; this guide does not mark them complete or duplicate
their checklists. Automated, rendered, performance, listening and human acceptance
must remain independently attributable.

### Crash recovery and ghost producers

Batch `crash_recovery_suite.gd`, `crash_replay_suite.gd`, `ghost_archive_suite.gd`,
`competitive_suite.gd`, `race_suite.gd` and required physics/runtime after identities
and capture hooks settle. Recovery core tests cover local 4 m support/active props,
rest initialization and clock rules; replay/archive tests cover inactive masks,
exact boundaries, final poses, selection/eviction and malformed bounded payloads.
Do not weaken strict pose/identity checks to retain old eight-field or archive-v2
fixtures. `crash_recovery_lifecycle.gd` uses a disposable eligible short lab race:
**do not add `--test-lab`**, which would deliberately disable that eligibility.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/crash_recovery_lifecycle.gd') -Label recovery-review -TimeoutSeconds 240
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/ghost_playtest.gd') -Label ghost-review -TimeoutSeconds 600
```

Recovery `--small` selects 960×540; normal is 1440×900. Inspect advancing/paused
crash time, unavailable recovery, neutral-gated rest, attached equipment, restored
camera and clean player/ghost trail origins. The current validated lab gate runs from (0,25) to (-3,70) in XZ, about
45.1 m horizontally, with a 15-second riding budget; it is not a mountain descent. It mutes audio/haptics; listening and real-controller
acceptance require separate ordinary play. Also sample a bounded warm natural-
mountain obstacle/cliff/boundary case; planar query counts do not establish cost
or placement usefulness on that terrain.

The final [crash lifecycle review](../artifacts/orchestration_20260912/crash/FINAL_VALIDATION.md)
passes105 checks with all26 frames reviewed cumulatively. The submitted equipment
alignment issue is resolved by fixture render ordering:80 current-frame mesh
submissions agree with final skin attachments within0.127 mm. Free-ski and timed
actions, exact crash clocks, neutral rest, same-attempt eligible PB and local ghost
resumption are covered. Timed onset is injected; active-prop impact is a separate
probe. Prior small layout coverage is an earlier visual revision. Audio/haptics
were suppressed; no listening or physical-controller acceptance is claimed.
This native receipt remains C-pole/replay6/archive3, and its combined guard's pole
failures are not crash failures. It is not a capture of later pole fitting.

Current lossless replay7/archive4 checks separately pass exact-clock95,
archive119, crash-replay36 and small-cache37, plus required physics56/runtime192.
[Exact-clock evidence](../artifacts/orchestration_20260912/carving/exact_clock/results.json)
retains the decimal one-ULP counterexample and proves exact float 64 clocks through
the new codec, archive and cache. Old identities are rejected without migration.
No unchanged crash-native105 rerun is required solely for this codec change;
these checks do not retroactively update captured identity or maximum-load timing.

`ghost_archive_suite.gd -- --max-duration` produces ten maximum-length payloads;
short codec fixtures do not measure their cost. `ghost_retry_cache_suite.gd`
checks validated reuse, corruption, identity changes and roster pruning. Its
`--maximum-only --reuse-maximum=PATH` mode reads an existing isolated maximum
manifest without recreating it; the fixture must still match current identity.

The 17 September replay-7 maximum fixture passes 172 archive checks: ten
600-second recordings at 30 Hz stress density, 255,615,110 declared raw bytes,
3,119,802 compressed disk bytes, 1,027.747 ms initial selection and 284,566,964
bytes of decoded static-memory increase. A separate process reuses those exact
payloads: seven checks pass, empty-cache loading is 1,003.795 ms and cached
retry is 8.263 ms with ten hits, zero new decodes and 7,636 added bytes. This
simple bounds fixture compresses unusually well; use the varied 150-second
fixture for comparative loading work. Neither controls the OS disk cache or
proves a total-process memory bound. Compact receipts are in
`artifacts/ghost_integration_20260917/{maximum.json,maximum-reuse.json}`.

Current Windows replay 7 loading was measured on 17 September with ten varied
150-second synthetic recordings at 30 Hz stress density (production records at
20 Hz). Empty decoded-cache selection improved from **3,340.649 to 261.554 ms**
with the native numeric validator, a **92.17% reduction**. Unchanged cached retry
was 14.228 / 13.214 ms. Both used 63,915,140 declared raw bytes and a 71,970,800-byte
static-memory delta. This does not prove a 320 MiB process bound, maximum-duration
latency, a disk-cold load or rendered FPS. OS file-cache state was uncontrolled.
The old replay 6 ten-minute timings are historical, not a current latency claim.

`tests/ghost_load_benchmark.gd` explicitly prepares/reuses isolated fixtures:

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/ghost_load_benchmark.gd','--','--prepare','--fixture=res://artifacts/ghost-load-new/fixture/race.json','--output=res://artifacts/ghost-load-new/results.json') -Label ghost-load-new -WorkloadMode FpsCritical
```

Default duration is 150 seconds; `--seconds=N` must match an existing fixture
when reusing it. `--course=NAME` selects the fixture's identity without bypassing
runtime compatibility. Omit `--prepare` to reuse; missing/incompatible fixtures
fail rather than silently regenerate. Retained matched evidence and attribution:
`artifacts/ghost_load_20260917/{baseline.json,candidate.json,REVIEW.md}`. The initial
single-payload profile spent 161.814 ms in snapshots, 383.070 ms in poses and
200.232 ms in input validation; decompression was 3.652 ms. This motivated the
bulk numeric kernel, while the script still owns identity, exact clocks and crash
semantics. Other platforms keep the reference validator until their library has
`AlpineReplayValidation`; macOS acceleration was not measured or packaged here.

`ghost_validation_kernel_suite.gd` requires that kernel and compares its decisions
with script validation across malformed numbers, field/vector/quaternion bounds,
input channels and complete decode arrays. Run it with archive/cache, exact-clock
and crash-replay suites; rebuilding the shared skier library also requires
physics/runtime suites. No pose rendering changes are made by this optimization.

The ghost native producer captures actual final production poses, then runs a
15-second playback/selector/lifecycle review. `--profile` substitutes 20-second
0/1/10-ghost and ten-without-tracks cases, excluding initial warmup and captures.
For a single relevant candidate, select `--profile --profile-ghosts=10
--profile-seconds=15 --fps-limit=0` with a fresh output. `--profile-no-tracks`
is an explicit diagnostic alternative; the ordinary selected case keeps tracks.
The producer checks focus during the measured interval and reports a separate
pose-application CPU probe outside frame timing. That probe is not rendered FPS.
`ghost_pose_cache_suite.gd` checks current interpolated roots, bones, equipment
and contacts against uncached decoding, reverse/skip/replacement samples and
the bounded two-frame cache. Pair it with `ghost_capture_reuse_suite` and the
focused native contact cases when changing frame preparation or pose playback.
These are diagnostic lab costs, not a full route or a three-repetition benchmark.
For a comparative cost claim, reuse a matching saved reference and one short
warmed candidate under the current experiment-budget policy. Expand only to
resolve a specific ambiguity; retain actual output/internal pixels, quality,
renderer and memory. Default-v15 High
cost needs a matched bounded natural-scene fixture; the laboratory is not that
acceptance. Preserve fixed `artifacts/ghost/native/` outputs before rerunning. Inspect
multiple outfits, ten colors, body/equipment continuity, close overlap, occlusion,
independent finishes, pause/hide/reenable and crash discontinuities. Codec fixtures
are not animation-quality evidence. The native crash result above and ghost's separate review do not establish
natural-mountain placement usefulness, full-route behavior or human comfort.

For Records-only edits, use `tests/ghost_playtest.gd -- --selector-only
--output=artifacts/<unique-label> --fps-limit=60` under a Shared guard. This
isolated synthetic recording fixture checks mouse, keyboard and controller
selection at 1024×720 and 3840×2160, including empty manual selection, automatic
counts and frozen active rosters. It does not establish animation or FPS quality.
Injected main-window mouse coordinates use the root's final transform; popup
events target the popup's host window ID. Mouse coordinates include the panel
offset and, for an embedded popup, its position within the transformed host.

For lifecycle-only integration, use `--lifecycle-only` with a fresh output and
`--fps-limit=60`. It captures actual production poses, then checks opacity across
the former near/far cutoffs, independent finishes/replacement, pause, hide/show,
time reversal, overlap and material isolation. It skips the already-covered
selector and full animation chronology. This is rendered functional evidence,
not a new FPS sample; use the focused lineup for actual light/cyan outfits.
Add `--with-chronology` only when a current 15-second ten-ghost playback sequence
is missing; it captures that sequence before the lifecycle checks.
For a material-only overlap change, `--overlap-only` captures just the actual
production starting pose plus 0.1 seconds and the four chase/first-person outfit
pairs. Pair it with the focused palette producer for normal-distance appearance.
It does not claim action chronology, independent finish or loading performance.

`tests/ghost_focused_native.gd -- --output=artifacts/<unique-label>
--fps-limit=60` covers the six actual-solver contact cases and all ten colors
against default/dark/light/cyan outfits. Its analytic receiving quads use
clockwise front faces and production snow/rock materials; the sun shares the
stage camera's visibility layer. An actual shadow
caster must darken the snow probe by at least 10%; inspect the images as well.
For palette-only fixes, add `--palette-only`: it records one actual production
sample interval to supply the starting pose, then captures only the lineup.
Default clothing retains its atlas; the contrast stress cases use solid dark,
light and cyan albedo with the production lit shader and normal map. They test
color separation, not additional player wardrobe assets. The snow probe converts
the camera projection into framebuffer pixels before sampling.
Both native producers currently load the integrated laboratory and require
`-FullMountain` with a specific `-FullMountainReason` on the guard. They keep
source paths and file metadata without content-hash audits. Keep their rendered
evidence separate from the storage, physics/runtime and human acceptance layers.

## Weather and storm-race evidence

The original weather evidence below used race schema 5 / weather rules 1;
current race schema 6 retains those weather rules and adds recovery rules 1.
Focused tests cover launch preferences and private RNG, 3,600-second days, front/storm boundaries, complete
snapshot continuation, fixed race schedules and practice-record protection.
Run `weather_suite.gd` headlessly and `weather_lifecycle_suite.gd` headlessly or
natively through the guard. The lifecycle fixture uses isolated records and can
capture the authored start, practice result and restored free-ski state.

`tests/weather_motion_review.gd` captures one-second chronological clips for six
conditions, four daylight bands and both cameras; `--matrix` covers 54 independent
graphics/FX/lightning/reduced-motion combinations. `weather_sky_review.gd` captures
15-second accelerated storm approach/peak/recovery and short Full/Reduced/Off
lightning sequences. `storm_audio_capture.gd` records the actual native mixer,
including delayed thunder with lightning Off, mute and pause/resume. Use native
DX12 for these checks; screenshots/audio captures are excluded from performance.

2026-09-12 evidence is retained under `artifacts/weather_upgrade/`: regression
receipts, 48 condition clips, 54 quality clips, native interfaces, lightning and
thunder capture. World-only submission (100 cloud receivers and one wind
material) measured median means of 54.50 us before, 59.43 us after Clear and
59.00 us Thunderstorm, each from three 480-sample runs. This isolates submission
CPU cost; it is not whole-game or GPU performance. Human readability, controller
comfort and listening acceptance remain open.

Matched 2026-09-12 trials use v15 seed 849205174, face 3, trace seconds 90-105,
High at 3840x2160 / 2880x1620 internal, Auto FSR 4.1.1, 120 cap, FG/SDFGI off.
CPU: Ryzen 5 5600X; GPU: RX 9070, driver 32.0.31041.1004. Each row is the
median of three 15-second runs; p95/p99 are medians of run percentiles. All final
runs matched the expected solver endpoint, stayed focused and kept source hashes
stable. Engine/hash, complete source inventory and time/seed metadata are in
`artifacts/pc_environment/weather-final-*/system.json`; raw distributions and
measured-period memory/background summaries are in `artifacts/weather_upgrade/`.

| Condition | Rendered FPS | p95 / p99 ms | Render CPU / GPU ms | Weather CPU us | Engine / video GiB |
|---|---:|---:|---:|---:|---:|
| pre-clear-short | 78.44 | 18.56 / 25.70 | 1.76 / 9.73 | 151.4 | 1.072 / 3.452 |
| pre-snow-short | 80.07 | 17.27 / 24.12 | 1.72 / 9.71 | 149.0 | 1.072 / 3.404 |
| final-clear | 78.35 | 18.28 / 24.24 | 1.82 / 8.15 | 175.1 | 1.074 / 3.452 |
| final-snowfall | 75.69 | 20.01 / 24.75 | 1.85 / 8.30 | 178.9 | 1.075 / 3.404 |
| final-snowstorm | 78.88 | 18.74 / 25.51 | 1.77 / 8.39 | 176.5 | 1.074 / 3.404 |
| final-thunderstorm | 78.73 | 17.67 / 21.41 | 1.79 / 8.04 | 179.6 | 1.074 / 3.404 |

Final Clear differs by -0.12% and Snowfall by -5.47%
from their pre-change FPS medians. The initial cloud warp was replaced with three
independent octaves to avoid a serial dependency on every lit receiver. Final
Clear matches baseline closely; Snowfall's end-to-end decrease remains a finding
despite lower measured GPU time. Background activity varied; existing apps were
left running, so the whole FPS difference is not attributed to weather alone.
The 90-120 FPS, p95 <=11.1 ms and p99 <=16.7 ms targets remain **unmet**, including
in the pre-change baseline. This is not regression-free performance acceptance.
No full-descent/forest-coverage or generated-frame throughput claim is made.
The before/after isolated submission means above remain a separate CPU measure.

## Startup evidence

Startup checks use the compact short-course fixture (256 x 512 m, 4 m grid,
zero objects) and the actual startup/main scenes. No full mountain or cold bake:

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/startup_suite.gd') -Label startup-functional
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/startup_suite.gd','--','--startup-capture','--startup-reduced','--startup-fullscreen','--startup-output=artifacts/my-startup/reduced') -Label startup-render
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/startup_suite.gd','--','--startup-timing','--startup-fullscreen','--startup-output=artifacts/my-startup/timing') -Label startup-timing -WorkloadMode FpsCritical
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/startup_audio_capture.gd') -Label startup-audio
```

Use `--startup-timing` without `--startup-capture` for timing and repeat in fresh
processes. Timing skips unit/optional-effect setup before the actual entry scene;
fullscreen timing starts in the project window mode without a harness mode switch. Capture at
explicit `--startup-size=1920x1080` or use native fullscreen. Select
`--startup-skip=key|mouse|controller` for event-injection coverage. Report engine
startup separately from the scene-to-menu timer, and sequence dismissal separately
from interactive readiness. A short-course fixture and two-frame injected input
observation cannot establish ordinary full-mountain startup or hardware latency.
`--startup-stages` emits actual stage timestamps. Warm asset caches, first-use
shader compilation and screenshot readbacks materially affect these values.

`menu_cosmetics_suite.gd` checks deferred admission, cancellation/teardown, a
separate data worker, optional-resource failure and exact vertex/normal/index
equality with the original decorative mesh path. It uses spies and a planar
sampler, with no generated mountain. Run it with `startup_suite`, `runtime_suite`
and `interface_suite` after scheduling changes.

`startup_photo_gallery.gd -- --snow-motion --output=artifacts/my-startup/weather`
writes 60 native 1280x720 frames at explicit 30 Hz presentation time under Shared
admission. Omit `--snow-motion` for all six static 1920x1080 photograph compositions.
Use fresh output paths and inspect the rendered files. This is motion-review
evidence, not actual loading timing.

The audio producer records a pre-Master-gain WAV effect tap and separately measures
post-gain bus peaks. Validate dispatch count, completion, interface mute, Master
attenuation and Master mute; reserve perceived balance/quality for listening.

The timing fixture bypasses distant scenery entirely. Its startup/menu timings
cannot demonstrate whole-mountain savings from deferring that work. Cooperative
CPU loop yields and main-thread resource/mesh submission are not asynchronous
GPU streaming or a hard frame-time guarantee.

## Cosmetic gravel checks

`rock_gravel_suite` checks immutable source/resources, centimetre limits, packing
clearances, material attributes, habitat exclusions, halo agreement between
adjacent cells, bounded workers/batches, mode isolation and unchanged physical
data. `performance_map_suite` includes `perf-gravel`: the exact 48 mineral
placements and 4 m geometry of `perf-rocks`, with a separately authored exposed
rock/snow material boundary. Existing performance-map recipes remain unchanged.

```powershell
./scripts/test_pc_environment.ps1 -Suites rock_gravel_suite,performance_map_suite,terrain_grass_suite -OutputDirectory artifacts/my-gravel/regression
./scripts/benchmark_targeted.ps1 -Map gravel -Gravel all -Camera scenery -PlanOnly
./scripts/benchmark_targeted.ps1 -Map gravel -Gravel dense -Output artifacts/my-gravel/dense
```

The targeted wrapper defaults to three independent six-second ordinary-input
trials. `-Gravel off|dense|sparse|all` affects only cosmetic gravel. Preserve grass,
physical minerals, all other scenery and display settings. Check zero/nonzero
populations, identical final states, actual pixels, stable sources, focus and
complete duration. Keep each run and compare medians of per-run statistics.

For capped native review, use `tests/rock_gravel_playtest.gd` through the guard
with `--graphics-quality=high --upscaler=native --render-scale=1.0 --fps-limit=60`.
Select a fresh `--output=artifacts/...`; it defaults to the local gravel map.
`--standard` requires explicit `-FullMountain` and a reason and restores the warm
physical archive. It reads the surveyed route below. Views show actual terrain,
centimetre detail, the snow edge, LOD, quality and weather. Camera clearance is
checked against terrain; an underground capture cannot pass visual acceptance.
Captures are not performance or human/controller evidence.

`tests/rock_gravel_trace.gd` restores the current Standard physical fixture under
an Exclusive guard with `-FullMountain` and a reason. It surveys existing exposed
rock and records one 15-second ordinary-input route to
`artifacts/rock_gravel/standard_trace.json`. It never regenerates terrain. Coverage
records include rock fraction, speed and every 120-tick checkpoint; reject crashes
and obstacle contact. Its shelf-to-snow route is a qualified local mountain sample,
not sustained dense-forest or full-descent acceptance.

When other tasks are editing runtime inputs, freeze one observed project copy:

```powershell
./scripts/run_guarded.ps1 -FilePath python -Arguments @('scripts/snapshot_gravel_comparison.py','--output','artifacts/my-gravel/frozen') -Label gravel-freeze -WorkloadMode Exclusive -TimeoutSeconds 600
./scripts/compare_gravel.ps1 -Snapshot artifacts/my-gravel/frozen -Scope local -Gravel off -Label gravel-local-off
./scripts/compare_gravel.ps1 -Snapshot artifacts/my-gravel/frozen -Scope local -Gravel all -Label gravel-local-all
./scripts/compare_gravel.ps1 -Snapshot artifacts/my-gravel/frozen -Scope standard -Prepare -Label gravel-standard-prepare
./scripts/compare_gravel.ps1 -Snapshot artifacts/my-gravel/frozen -Scope standard -Gravel off -Label gravel-standard-off
./scripts/compare_gravel.ps1 -Snapshot artifacts/my-gravel/frozen -Scope standard -Gravel all -Label gravel-standard-all
```

Repeat dense and sparse modes separately with fresh labels. These wrappers own
their guard; never nest them. Standard uses three 15-second repetitions with
240-frame warmups, 4K High, Auto FSR at 0.75, no frame generation/GI and cap 120.
Preparation has a separate Exclusive lease; measured scenery cache misses are
rejected. All modes share one identified runtime, engine and trace. Source and
binary hashes are checked before/after measurement. Inspect snapshot drift and
any explicit premeasurement updates; do not claim an atomic live-checkout
revision. The retained acceptance receipt is [ROCK_GRAVEL_RESULTS.json](ROCK_GRAVEL_RESULTS.json).
