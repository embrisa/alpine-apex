# Task: evaluate Cascadeur authoring and gameplay fitting from R5

**Latest: [R9 deeper carving](../CASCADEUR_DEEP_CARVING_R9.md)** follows the request for about 17 cm
between boot heights at the deepest carve. The optional trial reaches 16.94 cm
during the strong-turn fixture; its fresh model-28 comparison uses R8 and R9
pressure profiles with the same R7 hands. Earlier sealed evidence is preserved.

Created: 2026-09-10. Project: `C:\Users\hp\Downloads\alpine-apex`.
Audience: a new agent continuing the Cascadeur evaluation.
Latest follow-up: [R8 snow and leg response](../CASCADEUR_SNOW_LEGS_R8.md) implements
the user's explicit choice, **“Include soft-snow sinking and leg motion,”** after
R7 hands were considered okay but the legs lacked feeling. R8 retains R7 hands;
this separately authorized trial changes physical contacts. Its frozen movies
use base model 27; check the later live compatibility receipt before comparing
against concurrent model-28 snow-handling work.
Follow-up: the user requested a distinct carving candidate after the R6 in-game
comparison looked similar. See [R7 carving](../CASCADEUR_CARVING_R7.md) for that
separately authorized experiment and its launcher. The original scope below is
historical and does not limit that subsequent request.
Status: completed with a diagnosed presentation-ownership limitation. See the
[R6 report](../CASCADEUR_WORKFLOW_EVALUATION_R6.md),
[editable source](../../art_source/animation/cascadeur_evaluation_20260910_r6/README.md)
and [interactive review](http://127.0.0.1:8769/comparisons/cascadeur-20260910-r6/review.html).
R6 user acceptance and Cascadeur adoption remain open. The scope below is retained
as the acceptance checklist. This file supersedes the execution plan in
[the previous handoff](CASCADEUR_ANIMATION_HANDOFF.md).

## User direction and objective

After reviewing the R4/R5 comparison, the user said **“It looks decent to me”**
and requested a new task file for the next evaluation step. Treat R5 as a
satisfactory visual baseline for continuing. The author's earlier observation
that it is stiff and symmetric remains a possible improvement, not a user
rejection or a requirement to keep polishing before moving forward.

Determine whether this Cascadeur workflow is practical to edit and whether the
result survives Alpine Apex's existing gameplay composition and fitting. Use the
same short ready → grounded compression → recovery sequence. Deliver one bounded
authoring experiment and a comparison through the real presentation pipeline.
Do not expand into a landing clip or animation library in this task.

Cascadeur adoption remains undecided. The user's positive visual feedback is not
approval to replace the production library or to purchase anything. A useful
outcome is a supported recommendation to continue, choose another workflow, or
run one specific remaining test.

## Read and inspect first

1. `AGENTS.md`, [the animation skill](../../.agents/skills/alpine-animation/SKILL.md)
   and its rig/action, review, tool and handoff references.
2. [Current evaluation](../CASCADEUR_TRIAL_EVALUATION.md), especially R5;
   [review lessons](../ANIMATION_REVIEW_LESSONS.md).
3. [R5 source README](../../art_source/animation/cascadeur_evaluation_20260910_r5/README.md),
   source manifest, export helper and final rotation audit.
4. [Gameplay motion ownership](../STEEP_MOTION_GAMEPLAY.md),
   [anatomy](../SKIER_ANATOMY.md), [equipment](../EQUIPMENT.md), then the live
   functions involved. Historical physics/version numbers in these documents are
   not the current runtime identity; verify live source and engine hashes.

The [R4/R5 browser comparison](http://127.0.0.1:8769/revisions/cascadeur-20260910-r5/index.html)
provides normal/half-speed playback, matched frames, front close-up and three-view
options. It needs the local review server. Start at compression frame 30 and
inspect the whole sequence before editing.

## Baseline and evidence

| Item | Location or verified result |
|---|---|
| Editable R5 source | `art_source/animation/cascadeur_evaluation_20260910_r5/ready_compression_r5.casc` |
| Animation-only export | Same folder, `ready_compression_r5_animation.glb` |
| Export and control recipes | Same folder: `export_animation.py`, `build_control_targets.py`, `solve_oriented_controls.py`, `control_targets.json` |
| Frozen R5 evidence | `artifacts/pose_review/revisions/cascadeur-20260910-r5/` |
| R5 diagnostics | `artifacts/cascadeur_rig_20260910_r5/` |
| Clip | 2 seconds, 30 FPS, 61 samples; original beats 0, 12, 24, 30, 44, 60 |
| Export | 24 joints, no meshes, 83,956 bytes |
| Shoulder width | 35.296–35.324 cm across R5 |
| Contact/anatomy | Stationary foot/toe drift below 0.001 mm; maximum segment-length variation 0.04431 mm |
| Source transfer | Position and rotation checks pass through `present_authored` and the shared final writer |
| Render and clearance | 61 three-view frames, 6 detail triptychs; zero pole-shaft/clothing intersections over all 61 samples |
| Integrity at handoff | R5 seal verified; all 66 captured sources matched both snapshot and live files |

These results describe the completed run. Recheck integrity/current files before
new work. R4 and R5 review folders are sealed: preserve them and record later
feedback in new evidence or maintained documentation. Their embedded assessments
say R5 acceptance was pending because they predate the user's feedback above.

R5 is **only an isolated authored preview**. `present_authored` bypasses gameplay
composition/fitting. Its recorded ticks are authored frame index × 4; they are not
executed physics ticks, and its grounded flags describe authored intent. It does
not establish behavior on moving skis, slopes, steering or real contact events.

## Work to perform

### 1. Prove a usable edit and re-export cycle

Inspect the active Cascadeur scene and unsaved state. Open a task-owned copy of
the preserved R5 scene; never overwrite it. Verify a saved copy reopens with the
same animation transforms. R5 save and re-export succeeded previously, but R5
reopen was not separately tested.

Make one intentional, reviewable source edit, for example a modest recovery-timing
change or smoother arm recovery, while keeping the accepted shoulder silhouette.
Use a small set of meaningful controls/keys and retain the torso, clavicle and
elbow orientation constraints. R5's export is a 61-frame solved bake, not evidence
that a convenient sparse-key authoring workflow has already been established.
Show how the edit regenerates a clean bake without manually fixing every frame.

Record what actually did the work: Cascadeur controls/constraints/interpolation,
custom Python target generation, or manual edits. Record authoring effort,
interventions and save/export reliability. Do not credit Cascadeur's AI for a
custom procedural solve. Native AI interpolation or AutoPhysics may be tested on
a separate copy if it resolves a specific question; neither is required. Avoid an
open-ended sequence of guessed coordinates or repeated rig rebuilds.

Keep the edited candidate only if it retains or improves the user's baseline.
An edit that looks worse can still establish workflow limitations; preserve and
report it, then use unchanged R5 for the fitting experiment.

### 2. Evaluate the clip through gameplay presentation

Inspect these live owners before choosing the smallest test fixture:

- `scripts/presentation/skier_animation.gd`: solver/input-derived channels.
- `scripts/presentation/skier_full_motion.gd`: clip sampling, composition,
  posture corrections and the existing tick tracker.
- `scripts/presentation/skier_visual.gd`, `skier_anatomy.gd`,
  `skier_equipment.gd`: support fitting, anatomy and rigid equipment.
- `scripts/presentation/skier_pose_writer.gd`: the single final skeleton writer.

Build an explicit evaluation fixture that feeds the candidate through those
stages using recorded or deterministic solver-owned inputs and equipment. Keep
candidate selection local to the test; preserve the production default/library.
An isolated test hook is acceptable if necessary, but avoid a parallel animation
system or a broad runtime refactor. Use existing clip/root-motion conventions;
the solver retains world translation, heading and physical spin.

Compare existing production motion and the candidate under identical inputs and
cameras. Cover straight supported travel, a grounded compression/recovery, entry
and exit blends, light/strong steering both directions, and release with residual
turning. Check nearby tuck entry/release where the candidate overlaps that action.
Record which phase mapping is being tested; do not pretend the clip is already a
general-purpose landing or jump animation.

Capture **source → requested → final** transforms and explain material deviations.
Judge feet against solver-owned bindings/support, not stationary world coordinates.
If fitting destroys a good source pose, locate the responsible blend/limit/fitting
stage before changing the source. Keep the proposed remedy within presentation;
do not alter physics or move equipment to satisfy the animation.

### 3. Produce a new review and recommendation

Choose a fresh revision ID. Reuse the maintained `scripts/pose_review/` tooling
for freezing, rendering, encoding, inspection and audits. The R5 diagnostic scripts
are useful evidence but contain fixed paths and assumptions: inspect/adapt them;
do not execute them blindly or copy them into production as a framework.

Include complete chronological front/side/oblique evidence, selected overhead
equipment details and a gameplay-camera view. Supply normal and half-speed playback,
frame scrubbing, matched comparison labels, and phase-selection reasons. Inspect
all front-view samples: side-only review missed R4's collapsed shoulders.

Verify names/parents/rest axes, units, timing, scales, segment lengths, rotation
continuity, source transfer, cuff/boot alignment, fixed grips and final skinned
clothing clearance across the relevant sequence. Select regressions for actual
changes: `skier_motion_suite.gd`, `skier_anatomy_suite.gd`, `steep_motion_suite.gd`
and posture/attachment checks as appropriate. Untouched physics needs no unrelated
physics test batch. Read test output even when the process exits zero.

Separate mechanical pass results, rendered observations, author review and user
acceptance. No numerical artistic grade is requested. Compare quality, effort,
repeatability and integration behavior, and identify the worst remaining issue.
Conclude with one recommendation and the evidence supporting it. A constrained
Blender comparison has not been performed; do not claim it wins an unrun comparison.

## Execution constraints and known traps

- Preserve the Node-independent 120 Hz solver, terrain/contact authority, inputs,
  trajectory, COM, replay and records. Do not add a second skeleton writer.
- Preserve the existing mesh/skin, rigid skis/boots/poles and fixed glove sockets.
  The rig has 24 bones and no finger bones. Do not conceal errors with stretching,
  wider global limits or sliding sockets.
- Spine order is `Hips → Spine02 → Spine01 → Spine → neck → Head`. R4's generated
  stomach incorrectly mapped to `Spine`; explicit Joint ObjectIds fixed it.
  R5 additionally constrains orientation helpers and elbow planes. Those are
  established corrections, not new setup tasks.
- Model convention: +Z forward, +Y up, +X anatomical left. Use metres/seconds/
  radians internally. Cascadeur import/export used 100×/0.01×. Review basis arrays
  store columns; verify rest and local/model transforms before adapting data.
- Last tested Cascadeur: 2026.2.2.0.16638 with Pro trial; Godot: 4.7.2 custom
  `ed1daf0bf`. Resolve the current executables and pin engine identity per comparison.
- Local Cascadeur MCP was `http://127.0.0.1:8765/mcp`; verify availability and use
  its installed API documentation. Separate edit/solve/save calls and inspect their
  results. An idle-event timeout previously followed a completed edit and save;
  inspect current state and outputs before retrying a mutation.
- R4 reopened with corrupt orange/black native materials even though transforms
  survived and original Godot materials rendered correctly. Track this separately.
  Scripted native video export previously froze the app; render review video in
  Godot. Preserve unrelated/unsaved DCC sessions.
- The user explicitly authorized concurrent isolated animation checks rather than
  waiting for a whole generation batch. Use `scripts/run_guarded.ps1` with
  `-AllowConcurrent`, unique output labels and sequential stages within this review.
  Retain timeout, error detection and owned-process cleanup; leave other workloads
  alone. Concurrent timings are not performance baselines. `run_stage.ps1` does not
  currently forward this switch; use the direct guard when concurrency is needed.
  Quote `'--'` when invoking `godotw.ps1` with user arguments. Do not nest guards.
- Follow the root `AGENTS.md` Git workflow: work on `main`, and commit/push
  validated milestones frequently. Unrelated cleanup, production rollout, paid
  Cascadeur commitment or release of trial assets is outside this evaluation.

## Completion and handoff

Deliver an editable source copy, animation-only export and tested reproduction
instructions; evidence of the edit/save/reopen/re-export cycle; matched source and
gameplay-fitted review with hashes/logs; and a concise recommendation. Preserve
rejected attempts and reasons. Update the evaluation and relevant review lessons.

A diagnosed failure with reviewable evidence is a valid evaluation outcome. A
successful import or an isolated `present_authored` preview alone does not answer
this task's gameplay-fitting question. Keep broader Cascadeur adoption and final
gameplay acceptance separate from the user's positive R5 feedback.
