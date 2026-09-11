---
id: "AA-20260911-153903-current-4k-performance-baseline"
title: "Measure the current v15 full-descent performance baseline"
status: "blocked"
priority: "P1"
depends_on: []
created: "2026-09-11T15:39:00Z"
updated: "2026-09-11T22:06:25Z"
source_thread: "01a090fe-2a8c-7fe0-8b5b-fa6446206ea9"
---

# Measure the current v15 full-descent performance baseline

## Outcome

Establish current complete-descent performance and memory evidence on the target PC before choosing more optimizations.

## Current state and evidence

[The FPS report](../../docs/VALIDATION.md#performance-evidence) records a dated v14/model-26 comparison with unmet p95 goals. [Engine strategy](../../docs/ARCHITECTURE.md#engine-strategy) distinguishes later v15 generation improvements from rendered gameplay cost. Neither is a current v15/model-28 full-descent result.

## Agreed decisions and scope

Measurement and maintained reporting only; no renderer, density, quality or solver optimization in this task. Follow current graphics policy: actual 3840x2160 output, High, Auto FSR at 75%, 120 rendered FPS cap, frame generation off and optional SDFGI off. Saved user settings must remain unchanged. Record actual resolved settings and renderer/engine identities.

## Implementation approach

Inspect scripts/benchmark_pc.ps1, tests/performance_trace.gd and tests/performance_descent.gd. The user now prefers to record a faster, representative descent using scripts/record_run.ps1. Wait for their complete uncrashed recording, verify its current identity and recorded checkpoints, then use it as InputTrace. Short/crashed scenario clips are useful for reproductions but do not satisfy this full-descent workload. If returning to pilot generation with the user's agreement, retain the original bound of at most two attempts. Run three serial capture-free full descents through the guard. Report each run and medians of per-run statistics, including forest coverage, rendered FPS, p95/p99, CPU/GPU timings, loading and memory. Record competing workloads and source hashes before/after; unstable runs are invalid.

## Acceptance and verification

- [ ] Three complete source-stable descents or an explicit workload/trace blocker.
- [ ] Report actual pixels, settings, p95/p99 and CPU/GPU/memory measures separately.
- [ ] Compare results to current 11.1 ms p95 / 16.7 ms p99 goals without claiming a hard FPS minimum from averages.
- [ ] Keep cold generation, cache loading, scene construction and rendered gameplay distinct.
- [ ] Update docs/VALIDATION.md and the current validation summary; commit/push.

A valid measured miss of the target is an acceptable audit result, not permission for an unplanned optimization. Suggest evidenced optimization ideas separately for the user. Human smoothness acceptance remains a follow-up.

## Open questions

Waiting for the user's complete recorded descent. The user explicitly requested
stopping the pilot-driven matrix and preparing their recording instead.

## Completion record

Pending the user recording; this audit is not complete. On 2026-09-11, the first
bounded pilot attempt produced a current v15/model-28, 297.242-second successful
trace. The user stopped the subsequent 4K matrix during its first descent to
replace it with their faster route. No complete three-run baseline or tail-target
acceptance is claimed. The cancellation receipt is
`artifacts/current_v15_4k_baseline/cancellation.json`.

Commit `1679949` added separate physical-cache/scene loading timings, effective
graphics/renderer identity, forest residency/focus evidence, and background CPU/
GPU-allocation telemetry. Recording/replay setup and controls are maintained in
[Validation](../../docs/VALIDATION.md#player-recordings-and-short-scenarios).
Resume only after the player has saved a complete uncrashed recording; run all
three descents against a stable source snapshot and finish the unchecked criteria.

## Satisfied prerequisite history

On 2026-09-11, [AA-20260911-153900-baseline-acceptance-index](../archive/AA-20260911-153900-baseline-acceptance-index.md) was retired at the user's request after completion. Its satisfied dependency was removed; this task's scope and acceptance requirements are unchanged.
