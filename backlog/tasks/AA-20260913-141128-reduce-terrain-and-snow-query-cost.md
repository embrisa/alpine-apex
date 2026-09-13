---
id: "AA-20260913-141128-reduce-terrain-and-snow-query-cost"
title: "Reduce repeated terrain and physical snow query cost"
status: ready
priority: P1
depends_on: []
created: "2026-09-13T14:11:28Z"
updated: "2026-09-13T14:11:28Z"
source_thread: "01a09aec-9f0a-71a3-b543-b8b9765e660d"
---

# Reduce repeated terrain and physical snow query cost

## Outcome

Increase rendered FPS and reduce CPU frame tails by eliminating redundant terrain
and physical snow calculations, while preserving skiing support, snow response
and the exact shared 4 m terrain. Investigate the measured callers, implement the
best supported reduction and retain it only after production FPS verification.

## Current state and evidence

- The 2026-09-13 [diagnostics report](../../artifacts/fps_next/REPORT.md) and
  `artifacts/fps_next/fps-next-script-profile-0.json` recorded 241,997 triangle
  samples and 32,197 snow-depth queries during a 15-second forest diagnostic.
  `snow_depth_at` took 1.121 seconds inclusive; `channel_values` dominated nested
  work. These instrumented totals identify leads, not additive frame costs or
  an accepted gain. The profiler has inherited-call overlap and output overhead.
- [HeightfieldSurface](../../scripts/world/heightfield_surface.gd) returns height
  and a normalized triangle normal from `sample`; `contact_normal` takes four
  samples and consumes only height. Preserve virtual/adapter behavior when
  considering a narrower query API.
- Current-v15 [snow depth](../../scripts/world/generators/alpine_massif_v15.gd)
  combines noise, adjacent-face powder regions and tree-snow deposits. The
  [face generator](../../scripts/world/generators/alpine_face_v15.gd) already
  indexes channels spatially. Identify repeated work in these existing paths.
- The preceding session delivered HUD/audio/collision savings in `d768808`.
  Model 35/generator 15, seed 849205174, 4K High/Auto 75% were its identity;
  verify current identity and regenerate stale traces before new measurements.
  Its ordinary acceleration result was inconclusive and its forest baseline
  drifted: repeat current before/after controls, not historical comparisons.
- [World](../../docs/WORLD.md#physical-snow),
  [Physics](../../docs/PHYSICS.md#snow-contact-and-small-banks) and
  [Architecture](../../docs/ARCHITECTURE.md#authority-and-timing) own the contracts.
  Evidence under artifacts is local and ignored; if absent, recreate diagnostics
  from current source rather than requiring the old report to run the task.

## Agreed decisions and scope

The user requested an investigation-and-improvement backlog item for this next
step. Own query computation, result allocation and proven reuse at the shared
terrain/snow boundary and its callers in `scripts/core/ski_simulation.gd`.
Start with equivalent calculations. Do not coarsen support, quantize continuous
snow, reduce 120 Hz work cadence, retune handling or substitute cosmetic powder
for physical depth. Preserve 4K High, actual internal pixels, enabled effects,
scenery density/ranges, ordinary inputs, replay/race authority and personal data.

Use world- or call-owned bounded data. Cross-query caches need explicit field,
seed, generation, parameter and mutation lifetime; mutable lab/case adapters
must not reuse stale values. Avoid a global coordinate-only cache. If a genuine
identity change is necessary, reject/regenerate incompatible data under the
repository policy; do not introduce compatibility shims.

This task is FPS-sensitive. Coordinate literal read/write scopes with any active
workers and use the existing FpsCritical guard for comparisons. The pelvis,
forest-publication and GPU items are separate owners; no dependency chain is
needed merely to serialize measurements. Rebaseline after overlapping changes.

## Implementation approach

1. Profile current ordinary and forest/rock stress sections. Separate per-tick
   solver queries, per-render observers and preparation; count call sites,
   repeated inputs and allocation, without summing overlapping inclusive scopes.
2. Test height-only sampling, call-local sample reuse, immutable coefficients
   and avoiding unused channel/normal results. Preserve triangle choice,
   clamping, material interpolation, physical snow values and subclass overrides.
   Compare complete output/call overhead before adding any cache.
3. If a substantial kernel remains, evaluate batching or a narrow native kernel
   under the [engine strategy](../../docs/ARCHITECTURE.md#engine-strategy), including
   marshaling, synchronization, cache/load cost, memory and packaging. Native
   conversion alone is not a performance result.
4. Add focused differential coverage for both triangle halves, edges/diagonals,
   bounds, face/channel transitions, tree deposits, reload/seed changes and
   mutable adapters. Keep a frozen reference only as an explicit current test.

## Acceptance and verification

- [ ] Attribute a current expensive query/caller, record the retained algorithm
  and demonstrate reduced cost including allocation/reuse overhead.
- [ ] Query outputs and physical response remain equivalent within explicit,
  justified numerical tolerances. Run physics_suite and runtime_suite through
  `./scripts/test_pc_environment.ps1 -Suites physics_suite,runtime_suite` and add
  relevant snow_grounding_suite, snow_crush_suite, terrain_settle_suite and
  generation_v15_contract_suite coverage where the changed dependency requires it.
  Verify deterministic ordinary input across render schedules and exact trace
  endpoints; do not bypass incompatible trace preflight.
- [ ] Follow the [performance skill](../../.agents/skills/alpine-performance/SKILL.md)
  and [bounded method](../../docs/VALIDATION.md#performance-method): use fresh
  labels, 15-30 second scenarios, three independently warmed capture-free
  repetitions before/after, matched 4K High/Auto 75% and saved overrides. Include
  an ordinary-input control plus affected forest/rock sections; label immortal
  170 km/h stress separately. Return to original or counterbalance when drift
  or overlapping run ranges make attribution uncertain. Reject focus/source/
  trace/query failures; retain background telemetry and rejected attempts.
- [ ] Show a repeatable rendered-FPS or p95/p99 gain beyond observed variation,
  without a reproducible control regression. Report individual runs, medians,
  CPU/GPU cost, memory and load/preparation tradeoffs; separately check the normal
  120 cap. Do not declare completion for a microbenchmark alone. If no beneficial
  candidate survives, revert owned experiments and record blocked findings and
  remaining work. The global 90-120 FPS target is not a mandatory local gain size.
- [ ] Inspect affected rendered snow/contact behavior in separate native captures;
  no readbacks in acceptance timing. Update owning guides and affected skills if
  their contracts change. Commit/push validated owned changes and record receipts
  under a task-owned artifacts directory, followed by safe task-only cleanup.

Human acceptance: controller feel and continuous skiing/snow comfort remain a
separate follow-up, not a worker-completion gate. Do not claim user acceptance.

## Open questions

None

## Completion record

Pending implementation. Record retained and rejected candidates, actual checks,
individual matched runs, remaining target gap and human acceptance, authoritative
documentation updates, commit/push references and artifact retention/cleanup.
If no qualifying gain is found, record the blocker and unfinished work. Link any
separate proposals; no implementation or dispatch occurred during authoring.
