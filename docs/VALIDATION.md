# Validation

This page describes how to validate the current game. Feature documents own their
implementation details; generated logs, reports and captures belong in `artifacts/`.
Old local comparison evidence was deleted on 2026-09-09 and is not part of a fresh project copy.

## Current identity and acceptance

Source inspected on **2026-09-11**, at commit
[`f7b44ed8cb71a5591dd45cdd70336340fc25cf3f`](https://github.com/embrisa/alpine-apex/commit/f7b44ed8cb71a5591dd45cdd70336340fc25cf3f):
[startup](../scripts/main.gd) selects the default through
[MountainDefinition](../scripts/world/mountain_definition.gd), whose current
[generator](../scripts/world/generators/alpine_massif_v15.gd) declares v15 and
seed 849205174. Empty settings resolve to **Standard** through the
[v15 cache](../scripts/world/mountain_cache_v15.gd) and
[generation settings](../scripts/world/generation_settings.gd).
[SkiSimulation](../scripts/core/ski_simulation.gd) declares model **28**;
[RunReplay](../scripts/racing/run_replay.gd) declares version **5** and eight
input fields; [RaceDefinition](../scripts/racing/race_definition.gd) declares
schema **4**. Recheck these sources after changes; this inspection is not a new
gameplay, rendering or performance result.

| Area | Current contract / remaining gate |
|---|---|
| Skiing | Model 28 [grounded snow](GROUNDED_SNOW_V28.md), retained [carving calibration](ARCADE_CARVING_V20.md), [auto tuck/contact](TUCK_CONTACT_V21.md), and [aerial control with direct-stick flips](ARCADE_AIR_V27.md). Player handling and controller feel remain open; subsystem reports retain their known fixture failures and coverage limits. |
| Mountain | [v15 Standard, seed 849205174](GENERATION_V15.md); retained [v13 density](ALPINE_V13.md), [v12 landforms](ALPINE_V12.md) and [geology fitting](GEOLOGY_V11.md) share one 4 m support surface. |
| Routes | The historical [v13 survey](ALPINE_V13.md) found branching paths; its pilot completed face 3 and crashed/stalled on the other faces. This does not establish v15 six-face coverage or player acceptance. |
| Racing | Replay v5 (eight input fields) and race schema 4. Replay compatibility also checks engine, course, physics model, tuning and 120 Hz tick rate; v5 alone does not make an older recording compatible. Test, lab, autoplay and modified-physics runs must not replace personal bests. |
| Rendering | [Graphics policy](GRAPHICS.md#performance-policy): 4K High, Auto FSR at 75%, 120 rendered cap, frame generation and SDFGI initially off. Saved overrides remain authoritative. Target frame p95 ≤11.1 ms and p99 ≤16.7 ms after warmup. |
| Performance | Historical shared-load v13 measurements and the [2026-09-10 v14/model-26 comparison](FPS_OPTIMIZATION.md#2026-09-10-measured-comparison) miss the full frame-time gate. Later [model-28 short routes](GROUNDED_SNOW_V28.md#rendered-evidence-and-performance) also miss the target; [v15 generation/cache and scene diagnostics](GENERATION_V15.md#measurements-and-acceptance) do not establish current complete-descent performance. |
| Presentation | [Camera profiles and slope following](CAMERA.md), [snow readability](SNOW_READABILITY.md), [interface](INTERFACE.md), animation and [skiing audio](SKIING_AUDIO.md) retain subsystem evidence. Continuous-motion comfort, listening and user skiing acceptance remain open. |

These are carried-forward implementation limits, not results from a fresh benchmark.
Use stable source hashes and record the engine, generator, seed, model and settings
for any new acceptance claim.

## Current acceptance checklist

The [2026-09-11 backlog import](../backlog/IMPORT.md) separates bounded evidence
work from the user's acceptance. The following follow-ups remain open at this
inspection; linked task files own their current status and detailed criteria.

- [ ] [Skiing/input evidence](../backlog/tasks/AA-20260911-153901-input-acceptance-evidence.md): refresh automated and rendered coverage and the real-device checklist; maintain [controller feedback evidence](CONTROLLER_FEEDBACK.md).
- [ ] [V15 six-face route audit](../backlog/tasks/AA-20260911-153902-v15-six-face-route-audit.md): survey Standard seed 849205174 and report each face's pilot coverage and limitations in [v15 generation](GENERATION_V15.md). Other seeds remain follow-up skiing work.
- [ ] [Current 4K performance baseline](../backlog/tasks/AA-20260911-153903-current-4k-performance-baseline.md): three complete, stable-source descents or a precise trace/workload blocker; update [FPS evidence](FPS_OPTIMIZATION.md). Keep generation, cache reading, scene construction, rendered frames and generated frames separate.
- [ ] [Presentation comfort review](../backlog/tasks/AA-20260911-153904-presentation-comfort-review.md): prepare current continuous-motion, camera/interface and animation evidence plus a listening/player checklist in the maintained subsystem pages.
- [ ] [Racing-loop audit](../backlog/tasks/AA-20260911-153905-race-loop-acceptance-audit.md): refresh authoring, retries, splits, finish and ghost evidence in [races](RACES.md) and [the competitive loop](COMPETITIVE_LOOP.md), with test saves isolated.
- [ ] [Player/controller acceptance](../backlog/tasks/AA-20260911-153906-player-and-controller-acceptance.md): **blocked for the user's actual playtest and feedback**, after the evidence tasks. Record only evaluated devices, skiing transitions, faces/seeds, comfort, listening and racing usefulness.

Automated correctness, rendered inspection, measured performance, listening and
player/controller acceptance are distinct. Historical measurements keep their
original date, generator/model and workload; none were rerun for this index.

## Routine checks

Run engine workloads one at a time from the project root. `artifacts/.gdignore`
keeps the output directory present on a fresh project copy. On Windows:

```powershell
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --headless --script tests/arcade_carving_suite.gd
```

Physics/input/session changes require the first two suites. Add focused suites
for changed contact, jumping, landing, race or replay behavior. Use the checked-in
fixtures; older optional before/after modes can require a new local baseline.
Inspect exit codes and engine errors, not just the presence of a result JSON.

For a selected batch with saved logs:

```powershell
./scripts/test_pc_environment.ps1 -Suites physics_suite,runtime_suite,graphics_suite,pc_graphics_suite
```

The runner's full default suite list includes archived generator/determinism
checks and is deliberately heavier. Do not run it for every documentation edit.
For long/native work, use `scripts/run_guarded.ps1` or a wrapper that invokes it;
it serializes validation with `artifacts/validation.lock`, cleans up the owned
process tree, and stops on engine, timeout or display-driver failures.

## Full-mountain and rendered checks

Reuse `MountainDefinition.generate(849205174, 15)` or
`mountain_cache_v15.gd.generate(849205174)` as described in
[v15 caches and export](GENERATION_V15.md#caches-and-export). The shared default bake lives at
`user://mountain_cache_v15/<default recipe SHA>.physical`; source/engine validation is mandatory. Explicit v14/v13 comparisons use separate historical caches.
Direct generator construction and `--repeat` are for cold generation/determinism
work. Cache reconstruction and rendered scene construction are different costs.

Camera, rendering, animation and effects changes need a rendered inspection.
Use the relevant subsystem's native harness, then review continuous gameplay
where temporal behavior matters. Headless checks cannot verify visual feel.

Capture-free PC timing is available through `scripts/benchmark_pc.ps1` (v15 production loop by
default); see [the matched-descent workflow](FPS_OPTIMIZATION.md). Record actual output/internal pixels, frame p95/p99, CPU/GPU timings,
memory, loading and competing workloads. An average FPS or a capture-run FPS
counter does not prove a hard minimum. A pilot crash/stall also limits route coverage.

## Output lifecycle

[Clean artifacts](../artifacts/README.md) after review with
`./scripts/clean_artifacts.ps1`; preview with `-WhatIf`. The cleaner retains the
output directory, documentation and validation lock, and never cleans the normal
engine/import cache, user saves or shared mountain bake.

Reports that consume generated files must run after their producer. Old geology
v11 contract/descent probes need `tests/geology_generation_suite.gd` first.
Asset masters, build recipes and regression fixtures belong in the source
folders, never only inside disposable comparison projects.
