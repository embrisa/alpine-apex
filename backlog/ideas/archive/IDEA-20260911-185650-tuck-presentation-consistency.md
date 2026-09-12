---
id: "IDEA-20260911-185650-tuck-presentation-consistency"
title: "Investigate differing tuck postures at similar solver tuck values"
status: accepted
created: "2026-09-11T18:56:50Z"
source_task: "AA-20260911-153901-input-acceptance-evidence"
source_thread: null
accepted_task: "AA-20260911-161450-proportional-carving-lean"
---

# Investigate differing tuck postures at similar solver tuck values

## Why consider this

Consistent visual feedback can help players understand when tuck is engaged.
The input audit verifies the solver's tuck response, but two sampled postures
look different at nearly equal effective tuck. This is separate from input mapping
and does not establish a gameplay defect.

## Evidence and origin

The [input acceptance audit](../../archive/AA-20260911-153901-input-acceptance-evidence.md)
uses production snapshot `29b1767da65f8dc7d75c4937601381a2096ba5fa` plus its
test-only fixture correction. The final native 1920x1080 images are under
`artifacts/input_acceptance_20260911/visual/`: `01_forward_tuck.png` is more
upright than `03_tuck_resumes.png`, although `results.json` records effective
tuck 0.99475 and 0.99481. Terrain, speed, prior actions and pose history differ;
the screenshots alone cannot identify the cause. All input assertions passed.
See [the maintained evidence](../../../docs/VALIDATION.md#input-and-controller-evidence).

## Selected work

The user requested this fix on 2026-09-12. Chronological capture and focused
regression coverage use `tests/tuck_presentation_playtest.gd` and
`tests/tuck_presentation_suite.gd`. The shared
[proportional-carving task](../../archive/AA-20260911-161450-proportional-carving-lean.md)
also owns the initial-tuck correction; preserve that single owner
instead of adding another tuck adjustment. The solver and input mapping remain
unchanged. See [tuck validation](../../../docs/VALIDATION.md#tuck-consistency).

## Confirmed cause

Speed Lab launches along the sampled fall line, slightly across the rider's
heading. The resulting small loaded edge was enough to release nearly the entire
straight tuck through the old narrow posture threshold, despite negligible path
curvature. After steering, that edge settled and the straight tuck returned.
The shared correction uses completed path curvature gated by supported edging
and one proportional turn strength across the posture stages.

The isolated historical motion logic reproduced the first/resumed mismatch at
equal solver tuck: 265 mm in support-relative hip height and 39 degrees in chest
pitch. The new regression also fails against that historical logic; launching
only along the rider heading would miss the reported defect. Detailed source
provenance, paired traces and rendered review belong to the linked validation
record.

## Resolution

Implemented by the shared posture correction in
`9adf15ade944016b8fd9b049f66ab9fa4c300955`, with focused regression coverage and
rendered review completed on 2026-09-12. All 30 tuck checks passed across 4,200
paired physical snapshots. The 313-frame native historical/current comparison
preserves identical inputs, ticks, physical state, skis and camera transforms;
initial/resumed hip-height difference is now 8.6 mm and chest-pitch difference
0.12 degrees. Both captures and the complete current suite/render interval have
stable recorded source hashes. The accepted idea is archived under the project
convention; it does not create another queue task or animation owner.

## Decisions and risks

Do not infer animation quality from the numerical tuck assertion, or implement a
pose change from these two samples alone. A confirmed defect needs a scoped fix
and rendered review; visual preference remains the user's decision. This idea
does not block completion of the input evidence audit.

## User decision

Fix authorized by the user's direct request. Human visual/controller acceptance
remains separate from implementation and automated/rendered evidence. The shared
change retains a measured pole/clothing regression around tucked turns; the
linked validation record preserves that limitation separately from this initial-
versus-resumed body-posture defect.
