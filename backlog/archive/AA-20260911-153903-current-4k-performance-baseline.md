---
id: "AA-20260911-153903-current-4k-performance-baseline"
title: "Measure the current v15 full-descent performance baseline"
status: "done"
priority: "P1"
depends_on: []
created: "2026-09-11T15:39:00Z"
updated: "2026-09-11T22:48:31Z"
source_thread: "01a090fe-2a8c-7fe0-8b5b-fa6446206ea9"
---

# Measure the current v15 full-descent performance baseline

## Outcome

Establish current complete-descent performance and memory evidence on the target PC before choosing more optimizations.

## Current state and evidence

At task creation, [the FPS report](../../docs/VALIDATION.md#performance-evidence) had a dated v14/model-26 comparison with unmet p95 goals. [Engine strategy](../../docs/ARCHITECTURE.md#engine-strategy) distinguished later v15 generation improvements from rendered gameplay cost. The completion record below now supplies the missing v15/model-28 full-descent result.

## Agreed decisions and scope

Measurement and maintained reporting only; no renderer, density, quality or solver optimization in this task. Follow current graphics policy: actual 3840x2160 output, High, Auto FSR at 75%, 120 rendered FPS cap, frame generation off and optional SDFGI off. Saved user settings must remain unchanged. Record actual resolved settings and renderer/engine identities.

## Implementation approach

Use scripts/benchmark_pc.ps1, tests/performance_trace.gd and tests/performance_descent.gd with the user's faster recording from scripts/record_run.ps1. Verify its current identity, complete uncrashed outcome and recorded checkpoints, then use it as InputTrace. Short/crashed scenario clips are useful for reproductions but do not satisfy this full-descent workload. The original pilot-generation bound was at most two attempts; the user replaced that approach with their recording. Run three serial capture-free full descents through the guard. Report each run and medians of per-run statistics, including forest coverage, rendered FPS, p95/p99, CPU/GPU timings, loading and memory. Record competing workloads and source hashes before/after; unstable runs are invalid.

## Acceptance and verification

- [x] Three complete source-stable descents or an explicit workload/trace blocker.
- [x] Report actual pixels, settings, p95/p99 and CPU/GPU/memory measures separately.
- [x] Compare results to current 11.1 ms p95 / 16.7 ms p99 goals without claiming a hard FPS minimum from averages.
- [x] Keep cold generation, cache loading, scene construction and rendered gameplay distinct.
- [x] Update docs/VALIDATION.md and the current validation summary; commit/push.

A valid measured miss of the target is an acceptable audit result, not permission for an unplanned optimization. Suggest evidenced optimization ideas separately for the user. Human smoothness acceptance remains a follow-up.

## Open questions

None. Human/controller smoothness remains separate acceptance.

## Completion record

Completed manually on 2026-09-12 using the user's attempt 8, saved under
`artifacts/player_recordings/player-20260911-221639/attempt_008.json`. No scheduled
claim was taken. The three focused, capture-free native descents reproduced all
14,643 ticks and 122 recorded checkpoints without crashes. All 1,008 measured
source hashes and 32 checked personal settings/record files remained unchanged.

[Validation](../../docs/VALIDATION.md#current-v15-player-descent-baseline) owns the
method, per-run measurements, loading/memory distinctions and reproduction
commands. The [tracked receipt](../../docs/V15_PERFORMANCE_BASELINE_RESULTS.json)
is regenerated and verified by [the producer](../../tests/report_current_4k_baseline.py).
Median average rendered FPS is 92.568; p95/p99 are 16.311/23.198 ms. Every run
misses both tail targets. This is a completed measurement audit, not performance
or human-comfort acceptance. Each lower forest section retained resident trees.

The guarded job took 444.179 seconds, including one shared startup and three
independent warmups. Player input duration is 58.95% shorter than the old pilot;
the changed route is not a like-for-like FPS optimization. Full evidence lives in
`artifacts/pc_environment/player-v15-4k-focused-20260912/`,
`artifacts/guarded/player-v15-4k-focused/` and
`artifacts/player_v15_4k_baseline/`. Source/recording milestones are `1679949`
and `1c2c836`; measured checkout HEAD was `be69d1d`. This closure adds reporting
only and is committed with the receipt and guide. Receipt distribution checks,
backlog validation and link checks passed; no production change required another
physics/runtime batch.

Retained cancellation history: on 2026-09-11, the first
bounded pilot attempt produced a current v15/model-28, 297.242-second successful
trace. The user stopped the subsequent 4K matrix during its first descent to
replace it with their faster route. That attempt supplies no accepted baseline.
The cancellation receipt is
`artifacts/current_v15_4k_baseline/cancellation.json`.

Commit `1679949` added separate physical-cache/scene loading timings, effective
graphics/renderer identity, forest residency/focus evidence, and background CPU/
GPU-allocation telemetry. Recording/replay setup and controls are maintained in
[Validation](../../docs/VALIDATION.md#player-recordings-and-short-scenarios).
The first player matrix was also cancelled after run 1 recorded 3,254 unfocused
frames. The user authorized a fresh focused matrix, which produced the accepted
three runs above. The excluded batch and reason remain in
`artifacts/player_v15_4k_baseline/focus_retry.json`; its timings are not used.

## Satisfied prerequisite history

On 2026-09-11, [AA-20260911-153900-baseline-acceptance-index](AA-20260911-153900-baseline-acceptance-index.md) was retired at the user's request after completion. Its satisfied dependency was removed; this task's scope and acceptance requirements are unchanged.
