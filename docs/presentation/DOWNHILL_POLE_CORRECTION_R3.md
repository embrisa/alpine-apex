# Hands and poles: R3 correction

The user rejected R2's hands and poles. Its author-assigned passing grades
were too generous: the tests required clearance but did not require proximity
to the hips. R2 remains frozen as rejected comparison evidence. Its grades
are not acceptance of the current animation.

R3 keeps the chest, gaze, leg compression and 0.38 m stance from that pass.
It changes the connected arm articulation in regular downhill, tuck and jump
preparation. The elbow path gathers the forearms across the body as the chest
lowers. The existing ForeArm bone now carries bounded axial rotation in this
downhill contribution; that rotation does not move the wrist or change the
elbow hinge plane. This avoids forcing both pronation and pole aiming through
the short wrist junction. The hand limit for this contribution is 80 degrees
swing and 30 degrees twist; authored targets use approximately 40–68 degrees
swing and almost zero twist. Other source contributions retain
their existing limits as the downhill contribution releases.

The same fixed palm socket aims the shaft through a passage beside the hip:
25 cm lateral from the pelvis centre, from 12 cm below the hip in relaxed
carry to 7 cm above it in the deep tuck. The handle offset and pole mesh are
unchanged. Small palm-offset iterations solve that fixed socket; there is no
per-frame search over alternative wrist roll solutions. The arm targets still
pass through the existing tick tracker and the one final skeleton writer.
Forearm rotation is enabled during initialisation as well as running ticks.

Following the user's additional feedback, tuck elbow centres are approximately
52 cm apart, down from roughly 67 cm in the wider intermediate prototype; the
hands are approximately 20 cm apart. Straight carry releases for light steering
and remains released while appreciable bank or turn rate persists. The bank
threshold excludes the carve channel's separate 0.20 load-asymmetry component,
so uneven loading alone cannot repeatedly trigger a turn pose while travelling
straight. Light carving in both directions is included in regression, and
separate left/right carving videos show the source's free arm expression.

The tighter regression measures both minimum clearance and maximum lateral
and vertical distance at the actual hip plane, in the ski support frame.
It also checks both thigh volumes, hand/elbow spacing, rigid cuffs, connected
joint lengths, continuity, source transitions and identical physical runs.
The elbow test removes only axial pronation before measuring off-axis flexion;
it does not treat pronation as a second elbow bend.

An additional audit deforms every clothing vertex using the captured final
bone transforms and the real skin bind/weight data. Five rays per shaft test
the centreline and 6 mm radius against that mesh, excluding the intentional
first 10 cm of handle contact. It covers every regular/tuck frame and all
supported preparation frames. This caught jacket intersections that the
capsule-only checks missed during development.

Evidence is in `artifacts/pose_review/revisions/20260909-r3/`: 552 chronological
production frames in three views, closer oblique/overhead/side photographs,
reference comparisons, source/requested/final diagnostics, and separate
animation/attachment regression logs. Preparation card 3 now uses frame 65,
the last supported frame, so its pose judgment actually covers pre-jump
compression. The full video retains departure and recovery as context.

All four animation/attachment suites pass. Physics remains model 25. This is
a presentation correction; it does not change simulation, tuning, terrain,
source clips or the rig asset. No new hardware benchmark is claimed.
Any R3 visual grades are the implementing reviewer's estimates from the new
render, not new user scores or an independent external Astra assessment.
