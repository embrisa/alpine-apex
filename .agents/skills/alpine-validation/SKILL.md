---
name: alpine-validation
description: Select, run and interpret Alpine Apex checks for a code change or acceptance review. Use for regression planning, guarded test execution, bounded descents and evidence assessment. Performance experiments and reported-bug diagnosis have dedicated skills; documentation-only changes need only relevant static checks.
---

# Alpine validation

Run commands from the repository root. Read the affected change and
[check selection](../../../docs/VALIDATION.md#check-selection), then only the
relevant domain guide. Use [execution](../../../docs/VALIDATION.md#execution)
for wrapper behavior and [current identity](../../../docs/ARCHITECTURE.md#current-identity)
for source/runtime contracts. Identify the behavior being verified before choosing
tests; a profile is a focused selection, not universal acceptance.

## Select and run

1. Map owned changes and their read dependencies to affected behavior. Include
   required physics/runtime checks for physics, input or session edits. Add the
   relevant rendered inspection for camera, rendering or effects; use the
   [animation skill](../alpine-animation/SKILL.md) for final-pose review.
2. Inspect existing suites and fixtures before adding a harness. Run focused
   checks while iterating and the required complete suites once the change is
   stable. Reuse passing evidence only while its tested inputs remain unchanged;
   repeat for new changes, failures or a specific unresolved concern.
3. Resolve the actual engine through the repository wrapper. Inspect preserved
   dirty read inputs and identify the bytes used; unrelated edits do not require
   cleanup. Recheck affected source for drift before claiming acceptance.
4. Use the existing batch runner or an owning wrapper under the workload guard.
   Use `Shared` for isolated functional checks, `FpsCritical` for comparative
   timing and `Exclusive` for imports/builds/shared cache mutations. Compatible
   shared runs may overlap; reserve common outputs and wait for conflicting leases.
   Never nest guards or interrupt another owner's workload. Choose fresh
   task-specific output directories so results cannot be confused with old runs.

The batch runner supports a read-only plan before taking the guard:

```powershell
./scripts/test_pc_environment.ps1 -Profile input -PlanOnly
```

Select either `-Profile` or `-Suites` and use `-OutputDirectory` for the actual
batch. Read the live runner and execution guide for supported selections and
PowerShell argument handling. Do not copy a full suite list from an old report.
For missing/incompatible mountain fixtures, follow the preparation route in the
execution guide; cold generation and warm-cache checks establish different things.

## Select the smallest map

Follow [targeted maps](../../../docs/VALIDATION.md#targeted-test-maps). Inspect
`-PlanOnly` before engine work. Use pure logic/compact fixtures for local checks;
the scenario catalog exposes supported terrain events. Keep required complete
physics/runtime checks, including necessary headless laboratory calibration.
For targeted benchmark metadata changes, use the synthetic wrapper and shared
edit-detection tests in [targeted FPS maps](../../../docs/VALIDATION.md#targeted-rendering-and-fps-maps),
plus a headless producer/metadata bridge check. Preserve original nanosecond
sidecars and native measurement gates; do not rerun FPS just to verify receipts.

Compact menu/crash changes also use the native/headless `bright_ui_suite` in
[presentation evidence](../../../docs/VALIDATION.md#presentation-evidence).
The ordinary interface suite is compact; its full generation/reload assertions
are explicitly selected with `interface_mountain_suite`.

Full mountains and scenery-rich laboratory scenes require `-FullMountain` plus
`-FullMountainReason` at the owning guard/batch. Record the specific assertion
that needs that scale. Missing caches fail; prepare the exact recipe explicitly
under Exclusive admission, never retry hoping for an automatic bake. Fixture
boundaries cannot silently shorten required coverage. Report selected dimensions,
object counts and setup versus execution time with the evidence.

For local scenery/FPS work, use the explicitly selected
[targeted rendering maps](../../../docs/VALIDATION.md#targeted-rendering-and-fps-maps)
through `scripts/benchmark_targeted.ps1 -Map rocks -PlanOnly`. Slopes, rocks,
vegetation and mixed maps preserve the production components and shared terrain.
Run `performance_map_suite` for their terrain, population, collision and bounded
input contracts. Use the performance skill for native measurements and inspect
separate captures; local fixture FPS does not establish mountain-scale acceptance.
Inspect its riding, detail and overview images. The default diagnostic
`-Camera scenery` shows the approaching terrain and crowns; `-Camera riding`
retains the existing riding configuration. Record framing and keep comparisons
matched; these diagnostic profiles never save personal camera preferences.

## Collect only the needed evidence

Apply the [small experiment budget and reusable baseline policy](../../../docs/VALIDATION.md#reusable-baselines-and-experiment-budget)
for performance work. Existing valid averages are reusable; do not automatically
repeat original controls, broad matrices or content-hash verification. Static
instruction changes need static checks only, with no game run.

For riding data, follow [bounded descents](../../../docs/VALIDATION.md#bounded-test-descents):
state the question, event, measured window and clean stop condition; separate
setup/warmup from riding. A guard timeout is a failure backstop, not a successful
sample boundary. Required complete suites retain their full coverage.

For small hops, uneven snow or sustained carving, discover the existing
[standard scenarios](../../../docs/VALIDATION.md#standard-scenarios-and-synchronized-comparison)
with `scripts/scenario.ps1 -List`. Use the common manifest/telemetry and synchronized
comparison page; preserve stimulus, source/tuning identities and coverage limits.
Nearest captured images do not necessarily represent the selected exact tick.

Use [bug investigation](../alpine-bug-investigation/SKILL.md) for a reported defect
or `.apexcase`, and [performance](../alpine-performance/SKILL.md) for comparative
timing. Headless stage duration does not establish rendered FPS. Keep test
preferences and records isolated as specified by the selected producer.

For beam/navigation acceptance, use the selective
[beacon producers](../../../docs/VALIDATION.md#beacon-and-navigation-producers).
Capture the current-input note before native execution and preserve historical
source/engine mismatch receipts. The `counts` follow-up exercises 0/5/32 markers
without timing; do not run the legacy cost matrix during a functional-only pass.
For the separately requested near/far beam cost, use `beacon_cost_playtest.gd`
in that guide: inspect the capture-only views, then reuse their coordinates for
one capture-free FpsCritical comparison. It uses current metadata and avoids
repeating the old visual matrix. Stationary scene FPS is not descent FPS.

For ghost selection, use the selector-only native route in
[ghost producers](../../../docs/VALIDATION.md#crash-recovery-and-ghost-producers).
It uses synthetic recordings solely for Records input/selection. Use the focused
actual-solver producer for contact and palette images; verify receiving geometry
and real shadow darkening before accepting its visual evidence.
For ghost lifecycle integration, select `--lifecycle-only` on the native
producer to check opacity, pause/toggle, independent finish and replacement
without repeating the full chronology or selector matrix. Keep it capped and
separate from FPS timing; maximum-duration storage uses the explicit archive
producer and reuses its isolated payloads for the retry check.
For material-only overlap changes, use `--overlap-only` and the focused palette
producer. Inspect the camera's actual sightline as well as the numerical alpha
floor; several individually translucent bodies can still obscure the whole view.
For ghost playback cost, select the needed `--profile-ghosts` case and bounded
`--profile-seconds` interval in that producer, with capture-free FpsCritical
timing after visual review. Keep the separate pose CPU probe distinct from frame
and GPU measurements; a zero/one/ten matrix is only needed for attribution gaps.
For replay numeric-validator changes, build the native skier library under an
Exclusive guard and run `ghost_validation_kernel_suite` plus archive/cache,
exact-clock and crash-replay checks. Retain physics/runtime checks after rebuilding
the shared library. The native suite requires the new helper; script fallback is
not evidence that the native path ran. Loading benchmarks use FpsCritical and
separate empty decoded-cache timing from OS disk-cache state and rendered FPS.

Read `run.json`, `results.json`, relevant logs and emitted captures. Confirm the
expected suites actually ran; `not_run`, engine errors, incomplete output or a
timeout cannot be reported as a pass. Inspect rendered output when required;
successful capture creation alone does not establish visual quality.

Report the tested source/runtime, commands and evidence paths, completed checks
and failures, actual scenario coverage and outstanding acceptance. Distinguish
automated, rendered, performance and human/controller/listening results. Name
the specific missing fixture, conflict or failure when a check cannot complete.

Follow [skill maintenance](../../../docs/DEVELOPMENT.md#agent-skill-maintenance)
when runner behavior, fixtures, check selection or evidence meanings change.

For optional distant mountain shadows, use the [bounded shadow checks](../../../docs/VALIDATION.md#distant-mountain-shadow-checks).
Compile natively before loading the warm Standard fixture, reject poor visuals
before capture-free Off/Low/High timing, and keep quality, loading and memory
limits explicit. Never rebake companions during startup or settings changes.
The explicit physical-fixture producer accepts `--seed=N`; leave it omitted for
Standard, and prepare another seed only when the selected check requires it.

## Internal development identity

For distant snow, use the [material comparison](../../../docs/VALIDATION.md#scenery-snow-material-comparison).
Restore the current warm fixture, inspect matched material-only captures first,
and use the separate bounded cost producer for timing. Keep shared cloud includes
current when restoring the original snow material. Snapshot metadata uses paths
and sizes; do not revive the legacy source/capture hash recipe.

Follow [development versioning](../../../docs/DEVELOPMENT.md#internal-development-versions)
for each committed milestone, including documentation/backlog authoring. Use
`python scripts/versioning.py identity --json` to identify the current checkout;
keep Dev labels separate from compatibility and evidence source/runtime hashes.
Reserve a unique note and all owned/read inputs, capture scoped metadata with
`python scripts/versioning.py capture --note changes/ID.json --metadata-only` before final
verification, record actual checks, and run the scoped note check before commit.
Report the final Dev ID after push. Preserve unrelated dirty inputs; do not refresh
evidence after an affected check without rerunning that check. Skip hash audits.
Recorded case identity and
current rerun identity are different observations. A version label is neither
performance evidence nor human/controller acceptance.

For the isolated full tree-family source pack, follow
[the source review](../../../docs/VALIDATION.md#premium-tree-source-review).
Bake after recipe changes, finalize portable far assets, then capture the sealed
manifest. Keep all-family/transition inspection and independent source audits
separate from production integration and measured forest FPS.

For asset milestones, follow the LFS pointer/hydration validation boundary in
[Development](../../../docs/DEVELOPMENT.md#milestone-workflow) before recording
the staged or delivered-note check as passed.

For opening, loading handoff, reduced motion or startup audio, follow
[startup evidence](../../../docs/VALIDATION.md#startup-evidence). Use the compact
startup and cosmetic scheduling suites; separate rendered captures, clean entry
timings and native mixer evidence from human listening/controller acceptance.

For cross-platform shader/streaming integration, select the bounded
[Windows producers](../../../docs/VALIDATION.md#windows-shader-and-streaming-integration).
Inspect actual dense-tree shader ranges and cloud-active views; profile macro
publication only after validating all texture channels. Keep local capped CPU
scope and summit UI costs separate from the reusable dense-route baseline.

For sky radiance updates, use the native fixture in
[weather evidence](../../../docs/VALIDATION.md#weather-and-storm-race-evidence).
Check camera-only, coverage-only and colour updates separately: an unchanged
reflection after movement does not prove that a later weather change refreshes it.
Keep its panorama readbacks out of performance measurements.

For powder publication changes, use the native local-boundary suite in
[snow checks](../../../docs/VALIDATION.md#snow-contact-and-local-boundary-producers).
Check new ghost receivers and fresh strokes while both centres stay fixed,
not just recentering. Readbacks validate mapping; rendered views still assess relief.

For ragdoll terrain representation, use the focused
[Jolt grid/contact checks](../../../docs/VALIDATION.md#ragdoll-terrain-collision)
and bounded native crash inspection. Preserve clipped perimeter holes and report
contact approximation separately from ski-solver/replay compatibility. Keep
shape preparation timing separate from whole-frame measurements.

For cosmetic gravel, follow [gravel checks](../../../docs/VALIDATION.md#cosmetic-gravel-checks).
Select `-Map gravel`; isolate `-Gravel off|dense|sparse|all` while keeping grass
and physical minerals unchanged. Frozen local and Standard comparisons have
separate scopes; reject measured cache misses and underground review cameras.

For physical forest and opening changes, follow
[natural opening checks](../../../docs/VALIDATION.md#natural-opening-checks).
Current generator 18 fixtures require fresh actual traces. Dev94 generator 16
forest receipts and the older dense-route averages are historical; changed
placement, support and controls cannot certify a matched FPS gain. Inspect
matched world views and keep graph connectivity separate from human skiing.

For scene-motion blur, use the [bounded native and production-component checks](../../../docs/VALIDATION.md#scene-motion-blur-checks). Apply display changes through the production helper for FG, check actual output pixels, and capture air/landing transitions from events rather than fixed frame guesses.

For generated snow banks and terrain joins, use the compact
[production-stage check](../../../docs/VALIDATION.md#terrain-snow-banks-and-rounded-joins)
and matched native views. Validate local prominence rather than added grid height
alone, and preserve snow material after rebuilding the changed surface normals.
