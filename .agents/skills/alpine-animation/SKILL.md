---
name: alpine-animation
description: Improve, author, debug, retarget or review Alpine Apex skier animations, including downhill, tuck, carving, takeoff, landing, grabs, connected hands and ski poles, anatomy, equipment attachment and Animation Workshop evidence. Use for animation quality work and animation handoffs in this project. Covers the production pose pipeline, action-specific targets, frozen visual comparisons and honest grading; does not replace the skiing solver or define physics behavior.
---

# Alpine animation

Work from the existing rig, production pipeline and accumulated review evidence.
The project root is three directories above this file. Run commands there.

## Start with the current defect

1. Read the user's latest corrections and [review lessons](../../../docs/ANIMATION_REVIEW_LESSONS.md).
   Identify the action, phase, body/equipment chain and requested visible result.
   For downhill carry, read [R4](../../../docs/DOWNHILL_TUCK_ALIGNMENT_R4.md):
   it records the current refinement, **not final user acceptance or an 8.0 grade**.
2. Read [rig and action ownership](references/rig-and-actions.md), then locate
   the live function that owns the defect. Verify current source/engine identity;
   dated evidence and constants are snapshots. Preserve concurrent changes and
   unsaved authoring sessions.
3. Choose the route. Workshop edits are preview projects; source retargeting is
   an asset task; production state/blend/fitting changes belong in presentation.
   Read the matching route in the rig guide before editing. Do not start by
   rewriting the entire pose pipeline or copying code from disposable artifacts.
4. Establish a usable before capture, reusing an existing frozen one when its
   phase, inputs and provenance match. Use [tool recipes](references/tool-recipes.md).
   List the specific acceptance evidence and neighboring actions to inspect.

## Improve and verify

Follow [the review loop](references/review-loop.md). Compare source, requested and
final poses; diagnose which stage creates the defect. Change one coherent cause
at a time, then check the resulting full chain and transitions before expanding.

- Keep one final `skier_pose_writer.gd`. Presentation reads solver-owned state;
  it does not alter contacts, trajectory, replay, COM or records to fit a picture.
- Aim connected shoulder/elbow/forearm/wrist chains with fixed grip attachments.
  Inspect actual final skinned clothing and full pole shafts/tips after all limits.
  Do not detach hands, slide sockets or bend rigid boots/poles to conceal a pose error.
- Targets follow the action. Straight tuck uses compact carry; carving restores
  free balance arms. Include light steering, both directions and residual turning.
  Reuse the method for landing/grabs, not the tuck coordinates or thresholds.
- Use generated references only when they resolve a visual ambiguity. Follow the
  available imagegen skill and label synthetic references. They are qualitative
  evidence, not calibrated anatomy, hidden bone positions or timed motion capture.
- Mechanical tests, source fidelity, visible quality and user acceptance are
  distinct results. Never infer passing grades from tests or your own desired target.

Run the relevant suites and a rendered review, using the recipes' shared guard
for Godot/Blender. Check complete chronological evidence before claiming motion
quality. If a numerical target is requested, use the per-phase/per-bone rubric;
unrated entries cannot satisfy it, and unjudgeable exclusions need a reason.

## Leave a usable handoff

Use [handoff and critique format](references/handoff.md). Save raw captures,
commands, hashes, selected-frame reasons, test logs and independent feedback in a
new revision; preserve sealed evidence. Put durable new reasoning in the relevant
project documentation. Rejected attempts need a cause and disposition, not another
unexplained parameter set. Future agents should know what is live, what was
rejected, what was verified and what still needs visual/user review.
