---
id: "AA-20260911-153903-current-4k-performance-baseline"
title: "Measure the current v15 full-descent performance baseline"
status: "ready"
priority: "P1"
depends_on: []
created: "2026-09-11T15:39:00Z"
updated: "2026-09-11T19:06:07Z"
source_thread: "01a090fe-2a8c-7fe0-8b5b-fa6446206ea9"
---

# Measure the current v15 full-descent performance baseline

## Outcome

Establish current complete-descent performance and memory evidence on the target PC before choosing more optimizations.

## Current state and evidence

[The FPS report](../../docs/FPS_OPTIMIZATION.md) records a dated v14/model-26 comparison with unmet p95 goals. [Engine strategy](../../docs/ENGINE_STRATEGY.md) distinguishes later v15 generation improvements from rendered gameplay cost. Neither is a current v15/model-28 full-descent result.

## Agreed decisions and scope

Measurement and maintained reporting only; no renderer, density, quality or solver optimization in this task. Follow current graphics policy: actual 3840x2160 output, High, Auto FSR at 75%, 120 rendered FPS cap, frame generation off and optional SDFGI off. Saved user settings must remain unchanged. Record actual resolved settings and renderer/engine identities.

## Implementation approach

Inspect scripts/benchmark_pc.ps1, tests/performance_trace.gd and tests/performance_descent.gd. Produce a current valid ordinary-input trace with at most two bounded trace-generation attempts; block if a complete uncrashed trace cannot be obtained. Run three serial capture-free full descents through the guard. Report each run and medians of per-run statistics, including forest coverage, rendered FPS, p95/p99, CPU/GPU timings, loading and memory. Record competing workloads and source hashes before/after; unstable runs are invalid.

## Acceptance and verification

- [ ] Three complete source-stable descents or an explicit workload/trace blocker.
- [ ] Report actual pixels, settings, p95/p99 and CPU/GPU/memory measures separately.
- [ ] Compare results to current 11.1 ms p95 / 16.7 ms p99 goals without claiming a hard FPS minimum from averages.
- [ ] Keep cold generation, cache loading, scene construction and rendered gameplay distinct.
- [ ] Update docs/FPS_OPTIMIZATION.md and the current validation summary; commit/push.

A valid measured miss of the target is an acceptable audit result, not permission for an unplanned optimization. Suggest evidenced optimization ideas separately for the user. Human smoothness acceptance remains a follow-up.

## Open questions

None.

## Completion record

Imported from the existing roadmap during backlog setup. Pending implementation. Any worker follow-up ideas belong in `backlog/ideas/` for the user's review.

## Satisfied prerequisite history

On 2026-09-11, [AA-20260911-153900-baseline-acceptance-index](AA-20260911-153900-baseline-acceptance-index.md) was retired at the user's request after completion. Its satisfied dependency was removed; this task's scope and acceptance requirements are unchanged.
