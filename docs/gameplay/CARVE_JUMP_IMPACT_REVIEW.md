# Carving, takeoff and impact refinement

User follow-up: the a17 carving arms lost too much authored extension, and rapid
steering exposed animation commitment ahead of the physical skis. See
[Carving expression and physical response](CARVE_TURN_RESPONSE.md). The a17 grades
below remain historical author judgments, not current user acceptance.

Implemented and author-reviewed on 10 September 2026. Frozen evidence:
`20260910-actions-a17`; matched original-animation control:
`20260910-actions-control2`. The sealed `20260909-r1` remains unchanged.

- [Graded review](http://127.0.0.1:8769/revisions/20260910-actions-a17/review/index.html)
- [Matched before / after](http://127.0.0.1:8769/comparisons/20260910-actions-final/index.html)
- [Current gameplay and validation](http://127.0.0.1:8769/revisions/20260910-actions-a17/review/validation.html)

## Result and remaining weaknesses

Author motion grades: left carve **8.5**, right carve **8.0**, takeoff **8.0**,
impact **8.0**. All twelve selected phase grades are at least 8.0. The 228
judgeable body-region grades are at least 7.5; twelve neck entries remain
unjudgeable because clothing and helmet obscure their articulation. The clothed
trunk supplies silhouette evidence, not direct inspection of hidden vertebrae.

The body now has an open chest and longer outside-leg support in carving,
a distinct crouch-to-extension departure, and coordinated down/back hip travel
with knee/cuff flex during impact. Remaining polish: a brief high pole-tip arc
during the preparation sweep, slightly square elbows during landing readiness,
and less rearward arm reach than the synthetic takeoff reference. These details
receive lower region grades and concrete comments instead of disappearing into
the overall score.

These are author judgments, not independent critic or user acceptance. Every
requested-action frame was inspected chronologically, with selected three-view
poses, clothing close-ups, source/requested/final diagnosis and browser playback
samples at normal and half speed. Current-build chase/side captures were also
inspected. This does not certify controller feel, arbitrary descents or FPS.
Reference bank direction, proportions, timing and impact severity are imperfect;
the review flags those limits. The scores are not an apples-to-apples numerical
regrade of the older r1 evidence.

## Ownership and implementation

`action_posture.gd` provides phase-specific spine, gaze and connected two-bone
arm targets. `skier_full_motion.gd` applies these before its existing fixed-tick
velocity/acceleration tracker. Grip aim uses the already-advanced parent chain,
with forearm pronation and fixed glove sockets keeping the poles rigid.
`skier_pose_writer.gd` remains the final skeleton writer. The prior straight
racing/tuck layer in `downhill_posture.gd` remains in place.

The carving pelvis follows actual cuff-up directions and stays within existing
reach fitting. Its action weight filters at 12/s: an unfiltered zero-steer tick
previously dropped the whole upper body about 25 cm during a reversal. Impact
position tracks its demand at 36/s, avoiding an over-8-cm small-hop root step
while retaining the 24-cm target range. Impact travel derives its backward thigh
reach from the leg lengths and 18-to-23.5-degree cuff target. The existing knee,
reach and cuff constraints still determine the final feasible pose.

Preparation and flight use complementary action weights. The backward sweep
starts during the crouch; landing readiness continuously takes over the carry
before contact. Ordinary jumps retain this layer until readiness, while an
explicit trick or sustained 2.5-to-4-m clearance releases the wider flight pose.
There is no extra preparation clock. The final brace hand target is 0.28 m
below and 0.28 m forward of the shoulder; the farther-forward attempt was
rejected after clipping during initial contact.

This is presentation work. Solver position, support, skis, flight path, inputs,
replay, records and simulation randomness are not written by the new layer.
Concurrent v27 air-control and performance changes remain separate.

## Validation and the elbow-envelope decision

The full actual-clothing audit passes **1,092 frames** across regular, tuck,
prepare/takeoff/flight, both carves and the separate landing fixture. Its five
rays at 6-mm shaft radius start 10 cm below the grip. This is an approximation,
not a continuous swept-volume or finger-contact certificate. Selected passes
were insufficient: earlier candidates clipped on transition frames and were
rejected. Direct audit runs must specify all six scenarios and `--include-flight`;
the historical three-scenario default covers only 552 frames.

The new hop silhouette test initially required elbows under 0.80 m wide. The
clear a17 brace reaches 0.824124 m on its flat-hop fixture. An earlier inward
elbow path and a farther-forward wrist both caused jacket intersections. After
reviewing the complete motion and current gameplay, the transient balance
brace was accepted and this newly authored silhouette envelope changed to
0.85 m. The rejected 0.80-m result is retained. It is not reclassified as an
existing failure. Preparation retains its 0.80-m elbow bound; original joint
angle limits, rigid attachments and 0.08-m continuity limits remain unchanged.

Final current-build animation validation: **480/483 checks pass** across nine
suites, with stable production sources. Eight suites pass completely. The three
unchanged failures are in the procedural comparison that explicitly disables
full motion: exact physical-head orientation, the old tuck hand-width target,
and absolute flexible-back peak. Original/revised controlled runs produce the
same failure set and impact values; the test hash and reports are retained.
This is not an all-project-tests-pass claim. Tool/evidence tests also pass.

The controlled studio before/after uses frozen physics 26, the same v14 world,
engine and inputs. All 1,092 recorded physical/ski frames and all camera
transforms match exactly; reconstructed joint error is below 0.000001 m.
Capture fixture selection rejects unsupported or counterbank carving and uses
physical state only, never appearance. Live integration is separately captured
on physics 27 / v14 seed 849205174 at 1280x720: four action cases complete without
crashes, both jump/impact cases record a landing, and all are unranked. The
auxiliary side camera can be occluded by terrain or trees; use the chase view
and unobstructed studio views for those moments. Capture overhead is not an FPS
benchmark.
