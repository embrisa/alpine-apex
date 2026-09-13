---
id: "AA-20260913-141128-reduce-pelvis-fitting-cpu-cost"
title: "Reduce repeated pelvis and anatomy fitting CPU cost"
status: ready
priority: P1
depends_on: []
created: "2026-09-13T14:11:28Z"
updated: "2026-09-13T14:11:28Z"
source_thread: "01a09aec-9f0a-71a3-b543-b8b9765e660d"
---

# Reduce repeated pelvis and anatomy fitting CPU cost

## Outcome

Increase rendered FPS by making shared pelvis/leg fitting cheaper while keeping
the skier connected, correctly supported and responsive. Investigate physical
and presentation callers independently, then retain a measured production gain
without degrading anatomy, equipment attachment, animation or skiing behavior.

## Current state and evidence

- The 2026-09-13 [FPS report](../../artifacts/fps_next/REPORT.md) and
  `artifacts/fps_next/fps-next-script-profile-0.json` recorded 15,110 `fit_hips`
  calls in a 15-second forest diagnostic. Call counts include physical and
  presentation use; profiler inheritance overlaps and output overhead mean
  inclusive times cannot be summed into an FPS saving.
- [RiderBody.fit_hips](../../scripts/core/rider_body.gd) permits up to 16
  two-leg projection iterations with early convergence. It repeatedly looks up
  rest-joint positions and recomputes immutable limb lengths, pelvis-relative
  offsets and boot basis transforms.
- [SkierAnatomy.fit_pelvis](../../scripts/presentation/skier_anatomy.gd) permits
  up to 12 anatomy iterations, calls `Body.fit_hips` within them and once again
  at return. Intermediate hips change, so repeated calls are not automatically
  redundant. Reach, cuff flexion and twist constraints are distinct.
- [Earlier animation work](../archive/AA-20260912-105301-reduce-animation-cpu-cost.md)
  already prepared immutable clips and arm ancestry; do not redo it. The current
  [animation cost contract](../../docs/ANIMATION.md#runtime-preparation-and-cost)
  and [connected anatomy](../../docs/ANIMATION.md#connected-anatomy-and-equipment)
  own pose lifetime and attachment rules. The separate
  [ten-ghost task](AA-20260912-132147-reduce-ten-ghost-presentation-cost.md)
  owns ghost-specific throughput.
- `d768808` is the preceding CPU milestone, not this task's before baseline.
  Its model-35/generator-15 trials had baseline drift and inconclusive ordinary
  FPS. Recheck current sources and regenerate stale inputs. Local ignored
  artifacts are useful provenance; recreate missing diagnostics from source.

## Agreed decisions and scope

The user requested this as a separate P1 investigation and fix. Own reusable
geometry and measured fitting computation in RiderBody/SkierAnatomy and narrow
caller changes in `scripts/presentation/skier_full_motion.gd`. The solver owns
physical state; presentation reads completed state. Preserve 120 Hz, 4 m support,
ordinary inputs, timing, replay/race identity and existing residual-carve fixes.

Begin with invariant hoisting and equivalent projections. Do not obtain FPS by
lowering iteration limits or convergence quality, relaxing reach/cuff limits,
stretching limbs, sliding bindings, moving physical skis from animation or
reducing visible animation cadence. Any floating-point rearrangement needs
documented numerical bounds plus rendered comparison. Preserve current visual
quality and full source/procedural transitions. Treat intentional pole-pose
edits and known tuck/contact findings as baseline inputs, not permission to
rewrite unrelated animation. Caches must not leak mutable poses between riders,
actions, evaluations or within the same tick.

This task is FPS-sensitive. Reserve literal overlapping source/read scopes;
comparisons use FpsCritical, and engine checks use the documented workload mode.
Rebaseline after concurrent terrain-query, feature or animation changes. No
dependency on the other new optimizations is required for independent work.

## Implementation approach

1. Reattribute current fitting call counts, iterations, early exits and caller
   cost across tuck, mirrored carve/reversal, upright, push, airborne and landing
   poses. Keep fixed-tick, final-pose and recorded-ghost scopes separate.
2. Hoist immutable rest lengths/offsets and per-call boot/pelvis invariants. Reuse
   existing prepared geometry where applicable. Identify truly unchanged inputs
   before eliminating a projection; later constraints can invalidate an earlier
   result. Measure full-call savings including preparation/allocation overhead.
3. Compare optimized fitting against frozen current results for supported and
   extreme poses, degenerate/reachable limits, both sides and partial/full source
   weights. Preserve explicit convergence quality and object/result isolation.
   Consider a narrow native kernel only for a remaining substantial measured
   cost, including conversion and packaging under the engine strategy.
4. Integrate the best candidate, then capture matched native stills and motion
   through transitions. Keep existing defects visible in before/after evidence;
   separate any unresolved baseline finding from a regression.

## Acceptance and verification

- [ ] Demonstrate reduced fitting work/cost and equivalent supported pose outputs
  under explicit numerical tolerances, with unchanged limb lengths, cuff/hinge
  constraints, glove/pole and boot/binding attachment. Preserve physical support,
  handling and render-schedule determinism.
- [ ] Use the [animation skill](../../.agents/skills/alpine-animation/SKILL.md)
  and [validation skill](../../.agents/skills/alpine-validation/SKILL.md). Run
  physics_suite, runtime_suite, animation_cpu_suite, skier_anatomy_suite,
  turn_anatomy_suite, ski_attachment_suite and skier_motion_suite as applicable
  through the guarded batch. Add focused fitting/convergence/isolation coverage
  and affected current carve/push/landing fixtures; inspect suite requirements
  before choosing headless versus native execution.
- [ ] Inspect separate matched native views and motion for tuck, both carve
  directions and release, push transitions, flight/landing, source blending and
  crash handoff. If shared fitting affects ghosts, check completed-pose playback
  without changing ghost count, cadence or the ghost task's ownership.
- [ ] Follow the [performance method](../../docs/VALIDATION.md#performance-method):
  three independently warmed 15-30 second capture-free repetitions before/after,
  fresh source/engine/trace identity, focused 4K High/Auto 75%, full effects and
  saved overrides. Include ordinary acceleration plus a fitting-heavy ordinary
  scenario and forest stress. Label 170 km/h immortal stress separately. Reject
  stale/focus/source failures; use a return-to-original or counterbalanced
  control to resolve drift. Profiling/capture overhead is diagnostic only.
- [ ] Retain a repeatable rendered-FPS or p95/p99 gain beyond run variation,
  with no reproducible control/visual regression. Report individual runs,
  medians, fixed-tick versus presentation CPU, GPU, memory/preparation costs and
  the remaining 90-120 FPS target gap. Run a separate normal 120-cap check.
  Isolated fitting savings do not establish completion; revert unsuccessful
  experiments and record blocked findings if no production gain survives.
- [ ] Update owning guides and affected skills when contracts change. Commit/push
  owned validated changes and retain task-specific comparisons/receipts, with
  safe cleanup after delivery. Preserve unrelated edits and existing findings.

Human acceptance: subjective animation quality, controller feel and comfort are
separate follow-ups, not worker-completion gates. Automated and rendered checks
do not establish the user's acceptance.

## Open questions

None

## Completion record

Pending implementation. Record retained/rejected candidates, numerical and
rendered comparisons, actual tests and per-run performance, baseline findings,
remaining acceptance, guide updates, commit/push and artifact retention/cleanup.
Record blocked findings rather than success if no qualifying gain is retained.
No implementation, worker dispatch or separate proposal occurred in authoring.
