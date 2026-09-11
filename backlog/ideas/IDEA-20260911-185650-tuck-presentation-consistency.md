---
id: "IDEA-20260911-185650-tuck-presentation-consistency"
title: "Investigate differing tuck postures at similar solver tuck values"
status: proposed
created: "2026-09-11T18:56:50Z"
source_task: "AA-20260911-153901-input-acceptance-evidence"
source_thread: null
accepted_task: null
---

# Investigate differing tuck postures at similar solver tuck values

## Why consider this

Consistent visual feedback can help players understand when tuck is engaged.
The input audit verifies the solver's tuck response, but two sampled postures
look different at nearly equal effective tuck. This is separate from input mapping
and does not establish a gameplay defect.

## Evidence and origin

The [input acceptance audit](../tasks/AA-20260911-153901-input-acceptance-evidence.md)
uses production snapshot `29b1767da65f8dc7d75c4937601381a2096ba5fa` plus its
test-only fixture correction. The final native 1920x1080 images are under
`artifacts/input_acceptance_20260911/visual/`: `01_forward_tuck.png` is more
upright than `03_tuck_resumes.png`, although `results.json` records effective
tuck 0.99475 and 0.99481. Terrain, speed, prior actions and pose history differ;
the screenshots alone cannot identify the cause. All input assertions passed.
See [the maintained evidence](../../docs/CONTROLLER_FEEDBACK.md#rendered-inspection-and-limits).

## Suggested next step

If selected, use the animation workflow to make a bounded chronological capture
with action/pose telemetry around initial and resumed tuck. First distinguish
expected speed/terrain/transition behavior from a stale fixture or presentation
state. The existing presentation-comfort task may incorporate this observation
without authorizing a separate retune. Preserve the ski solver and input mapping.

## Decisions and risks

Do not infer animation quality from the numerical tuck assertion, or implement a
pose change from these two samples alone. A confirmed defect needs a scoped fix
and rendered review; visual preference remains the user's decision. This idea
does not block completion of the input evidence audit.

## User decision

Pending user review. No animation or gameplay implementation is authorized.
