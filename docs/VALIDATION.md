# Validation

This page describes how to validate the current game. Feature documents own their
implementation details; generated logs, reports and captures belong in `artifacts/`.
Old local comparison evidence was deleted on 2026-09-09 and is not part of a fresh project copy.

## Current identity and acceptance

| Area | Current contract / remaining gate |
|---|---|
| Skiing | [Carving calibration](ARCADE_CARVING_V20.md) and [auto tuck/contact v21](TUCK_CONTACT_V21.md); the solver source owns the active model version. Player handling and controller feel require playtesting. |
| Mountain | [v15 Standard, seed 849205174](GENERATION_V15.md); retained [v13 density](ALPINE_V13.md), [v12 landforms](ALPINE_V12.md) and [geology fitting](GEOLOGY_V11.md) share one 4 m support surface. |
| Routes | The documented v13 survey finds branching paths. Its test pilot completes face 3 but crashes or stalls on other faces; all-face skiing acceptance remains open. |
| Racing | Replay v5 (eight input fields) and race schema 3. Test, lab, autoplay and modified-physics runs must not replace personal bests. |
| Rendering | [Graphics policy](GRAPHICS.md#performance-policy): 4K High, Auto FSR at 75%, 120 rendered cap, frame generation and SDFGI initially off. Saved overrides remain authoritative. Target frame p95 ≤11.1 ms and p99 ≤16.7 ms after warmup. |
| Performance | Documented shared-load v13 full-descent/forest measurements miss the frame-time gate. Short laboratory measurements do not establish full-mountain performance. |
| Presentation | Continuous motion, camera comfort, audio listening and user skiing acceptance remain separate from automated checks. |

These are carried-forward implementation limits, not results from a fresh benchmark.
Use stable source hashes and record the engine, generator, seed, model and settings
for any new acceptance claim.

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
`mountain_cache_v15.gd.generate(849205174)` as described in [planted snow](PLANTED_SNOW.md) and
[fast v13 setup](ALPINE_V13.md#fast-test-setup). The shared default bake lives at
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
