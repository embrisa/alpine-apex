# Cascadeur R6: authoring cycle and gameplay fitting

Completed 2026-09-10. [Task scope](../tasks/CASCADEUR_WORKFLOW_AND_GAMEPLAY_EVALUATION.md).

**Playable follow-up:** at the user's request, R6 is now available through the
separate [in-game playtest launcher](CASCADEUR_R6_PLAYTEST.md), with F9 comparison
and F10 replay. It keeps existing fitting and does not implement the ownership
experiment recommended below. The sealed R6 evaluation remains unchanged.

The bounded edit/save/reopen/export cycle works, and the candidate passes the
existing gameplay attachment and clothing checks. However, straight compression
retains little of the authored posture: the existing downhill corrections take
ownership of the torso and arms. Steering exposes a larger source difference,
without a demonstrated visual improvement. This answers the integration question
but does not establish a useful production authoring advantage.

**Recommendation:** continue with one isolated presentation experiment that lets
the source own this grounded posture while retaining anatomy limits, tracking,
solver bindings and rigid equipment. Compare the same entry/release and steering
cases. Do that before authoring more Cascadeur clips or considering adoption.
Keep the current production workflow. A constrained Blender comparison and native
Cascadeur AI/AutoPhysics evaluation remain unperformed.

## Review and editable delivery

- [Interactive comparison](http://127.0.0.1:8769/comparisons/cascadeur-20260910-r6/review.html):
  R5/R6 source timing, production/R6 fitting, three views or individual views,
  chase camera, normal/half speed, exact frames and source/requested/final diagnosis.
- [Detailed matched frames and overhead equipment](http://127.0.0.1:8769/comparisons/cascadeur-20260910-r6/index.html).
- [Editable source and reproduction instructions](../../art_source/animation/cascadeur_evaluation_20260910_r6/README.md).
- [Assessment](../../artifacts/pose_review/comparisons/cascadeur-20260910-r6/assessment.json),
  [execution receipts](../../artifacts/pose_review/comparisons/cascadeur-20260910-r6/execution_summary.json)
  and [final integrity verification](../../artifacts/pose_review/comparisons/cascadeur-20260910-r6/integrity.json).

The review server is local only. Its tested startup is in the source README.
R4/R5 sealed evidence remains unchanged. R5 is the accepted baseline for continuing:
the user's exact feedback was **“It looks decent to me.”** R6 source retention is
the author's decision for this experiment; R6 gameplay acceptance remains pending.

## What actually authored R6

Opened a task-owned copy of the saved R5 scene, without overwriting its original
or the existing R4 tab. Exported the reopened baseline, then moved the recovery
beat from frame 44 to 48, a 0.133-second delay. The other meaningful beats remain
0, 12, 24, 30 and 60. A custom Python monotone Hermite time mapping resamples R5's
31 oriented control targets; Cascadeur solves all 61 frames through its existing
rig. There was one timing edit and one solve, with no manual per-frame repair,
new rig build, exported transform patch or production skeleton writer.

This is a small timing interface over a solved bake. It proves a repeatable
script-assisted edit, **not** convenient native sparse-key authoring or AI
time savings. Cascadeur supplied the control/constraint solve and native save/export;
Python supplied the timing and targets. The measured MCP calls took 5.01 seconds
for solve and 18.89 seconds for save. From starting the R5-copy load to the final reopened
export took about 5 minutes, including inspection and scripting. These
are observed interactive steps under concurrent workloads, not an authoring
benchmark. Building the gameplay fixture and review took substantially longer.

The reopened native scene still displays corrupt orange/black materials.
[The native screenshot](../../art_source/animation/cascadeur_evaluation_20260910_r6/native_reopened_frame30.png)
records that unresolved authoring inconvenience. Exported animation transforms and
the original Godot skin/materials are valid. Native video export was not retried.

| Source check | R6 result |
|---|---|
| Export | Animation only; 24 joints, 61 samples, 2 s, 30 FPS, 83,956 bytes |
| Export SHA-256 | `8b25cba89e0f0977cf63d37c8c31080e0dbf8a7b786a15d55d5c60c1e00b5a57` |
| Reopened R5 vs preserved R5 | Max joint position difference 0.000596 mm |
| Saved/reopened R6 vs pre-save export | Max joint position difference 0.000608 mm |
| Original bind rest vs exported default node rest | Names/parents match; position error 0.00166 mm, basis coefficient error 7.65e-6 |
| Stationary authored foot/toe drift | Below 0.001 mm |
| Maximum segment-length variation | 0.03555 mm |
| Shoulder-joint width | 35.296–35.325 cm |
| Maximum upper-spine / forearm / hand step | 0.403° / 1.854° / 2.387° per 30 FPS sample |
| Source import / isolated final writer error | 0.00656 mm / 0.00218 mm |
| Gameplay 60 Hz local-pose reconstruction | Max FK error 0.1023 mm; rest position error 0.00145 mm |

Rotation continuity uses orthonormalized matrices, separating tiny exported scale
errors from actual rotation. The early `r5_reopen_audit.json` predates that audit
normalization; its transform comparison is valid, but its step angles are not used
as a continuity verdict. R6's final audit records all basis matrices and scale errors.

## Gameplay experiment and ownership

`evaluation_motion.gd` is a test-only subclass of the current full-motion owner.
It substitutes the candidate in forward navigation slots only. Both variants run
the same inherited composition, posture corrections, anatomy limits, 120 Hz
tracker, support/pelvis and cuff fitting, and sole final pose writer. The production
variant uses the same instrumentation with substitution disabled. Diagnostic
copies never feed the pose. No production script, library, mesh or equipment changed.

One real 120 Hz solver drives both variants on the deterministic 0.25-gradient
plane, starting at 18 m/s after a 120-tick warm-up. Five four-second scenarios
produce 121 samples each: straight supported travel, partial-tuck compression,
light/strong steering left and right, and full-tuck overlap. Each presentation
call is checked for solver-state mutation. All 605 paired physical/input/root/ski
and recorded chase-camera states match exactly. All samples remain supported.
No races, personal bests or replay records are written.

The clip phase is `clamp(time - 0.7, 0, 2)` seconds, except straight travel holds
the ready pose. Substitution fades in at 0.2–0.7 seconds and out at 2.7–3.2 seconds.
Steering uses a light 0.12 input during 0.3–1.3 seconds and a stronger 0.65 input
during 1.45–2.5 seconds, including ramps. Residual turning persists after release;
the last sample does not imply physically straight travel. Existing turn clips
continue to participate in the production blend. This phase mapping is a grounded
evaluation fixture, not a general landing or jump integration.

At compression frame 51 (1.7 s, authored peak frame 30), the downhill stage has
weight 1. Its local changes after arm-carry correction include 11.45° at Hips,
8.41° at Spine02, 33.53° at RightArm, 112.15° at RightForeArm and 62.02° at
RightHand. The forearm angle includes pronation; it is not an elbow flexion angle.
The ground action stage adds no change there. Tracking and supported pelvis/leg
fitting follow. The diagnostic triptychs show the source's forward ready carry
becoming the established compact horizontal-pole carry before the final foot fit.

Those changes are existing action policies, not evidence of a bad GLB transfer.
Further source sculpting cannot by itself preserve a pose that a later owner
replaces. Supported pelvis placement also limits how much authored vertical motion
survives. The remaining experiment should target this presentation ownership,
without loosening global limits or moving the physical skis to match the source.

| Final candidate vs production, same solver inputs | Largest joint position difference |
|---|---|
| Straight | 1.13 cm |
| Grounded compression | 1.59 cm |
| Steering left | 21.78 cm, frame 42 |
| Steering right | 21.59 cm, frame 42 |
| Full tuck overlap | 2.55 cm |

These are maximum per-joint distances, not average body displacement or quality
scores. The larger light-steering difference is primarily visible in the hand/pole
carry. The source is not a turn-specific balance animation, so a larger difference
is not automatically better. After substitution fades out, frame-96 differences
are approximately 0.02–0.12 cm, reflecting tracker convergence.

## Validation, visual review and limits

All 605 candidate final poses pass the measured attachment and cuff constraints:
maximum binding error 0.01363 mm; fixed-grip error 0.00404 mm; segment error
0.000464 mm. Cuff forward flex stays between −0.051° and 22.134°, with maximum
lateral flex 6.644°. Full deformed-clothing audits report zero pole-shaft
intersections in 605 production, 605 candidate and 61 isolated source poses.
The audit includes the 6 mm shaft radius through its five-ray method and excludes
the intentional first 10 cm below the handle. It is a sampled geometry check,
not a proof about every continuous time or finger contact; this rig has no fingers.

The five selected suites passed 236 checks: skier motion 19, skier anatomy 84,
steep motion 77, compact posture 36 and ski attachment 20. The interrupted initial
batch completed its first two suites; the remaining three finished in a separate
guarded run. Completed result lines and receipts are retained. An interrupted
batch itself is not labeled successful. No unrelated physics batch was required.

Rendered evidence contains all chronological front/side/oblique samples: 61 source,
605 production and 605 candidate triptychs; 86 selected equipment triptychs; and
605 chase-camera frames per gameplay variant. Ninety additional source/requested
diagnostic triptychs cover nine meaningful frames in each scenario. The front
chronology was inspected in full for both gameplay variants and R5/R6 source.
Selected full, side, oblique and overhead views checked the compression and tuck
holds, hand/pole differences and steering transitions. Browser playback and exact
frame controls were exercised; coverage is recorded in `assessment.json`.

Author observations: the source preserves connected shoulders and a modest smooth
recovery; it remains symmetric and restrained. Straight compression and full tuck
look nearly production-like. Light steering lifts the hands and changes pole
direction more visibly, without an established advantage over the existing freer
carry. Strong-turn and exit silhouettes remain continuous in the front chronology.
The chase view renders correctly with matching framing, but its plain slope and
small character scale limit close pose judgment. No controller session, mountain
descent, independent critic acceptance or rendered-FPS measurement is claimed.

Worst remaining issue: source posture ownership is inconsistent across action
weights, making the payoff from source authoring uncertain. Native material
reliability and the still-unproven convenience of native sparse-key editing are
additional workflow costs. R6 is retained as an evaluation asset, not adopted.

Runtime identity: Cascadeur 2026.2.2.0.16638 with available trial export; Godot
4.7.2 custom `ed1daf0bf001b61586d9930840f2f1394092c079`, executable SHA-256
`a18ddc9f3ee8fa1915a47d54c3e0d05ec4b10f8ee9deb15d7206b4e23d29bcc9`, physics 27,
replay 5. Frozen revisions pin source hashes separately from user acceptance.
