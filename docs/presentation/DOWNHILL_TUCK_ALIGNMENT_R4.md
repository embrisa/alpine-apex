# Tuck alignment refinement: R4

The user found R3 substantially better but still wanted the hands and poles
closer to the body's outline. R4 refines the connected arm targets while
retaining the chest, gaze, leg posture, straight poles and fixed glove sockets.

The tuck wrist targets sit 2.5 cm further back and 3.5 cm lower than R3.
Their lateral spacing increases from 20 to 28 cm; this still gathers the hands
in front of the chest while letting the straight shafts trail with less flare.
The shafts pass near hip height. A small gap between the hands helps the poles
follow the body more closely without forcing them through the sleeves.

The extra narrowing settles in near full compression, after the chest has
folded. Entry and release retain the earlier carry, leaving enough room
between the sleeve and torso for the shaft as the chest rises. The correction
continues to release during carving, braking, grabs and flight. No joint limits,
equipment meshes, grip offsets, simulation or source clips change in R4.

Regression now measures shaft lateral angle, full pole-tip width and hand depth
relative to the chest, in addition to hip/thigh clearance and hand/elbow spans.
These measurements use actual final equipment transforms. Moving just the
requested hip passage was insufficient because subsequent soft limits could
alter the shaft direction.

The final-mesh audit accepts additional captured scenarios through
`--scenarios=`, derives preparation's endpoint from physical support loss, and
reads selected frames from revision metadata. It refuses a changed rig, unstable
capture, empty requested coverage or writes into sealed evidence. The same
method can now be used when revising landing and other equipment-carry actions;
their current appearance has not been certified by this tuck refinement.

Evidence and validation results are stored under
`artifacts/pose_review/revisions/20260909-r4/`. The focused page compares R3 and R4
in identical front, side and overhead views and includes full chronological
sequences. R3 remains frozen. No new passing grades are assigned in this pass;
rendered improvement and automated checks remain separate from user acceptance.

The four animation/attachment suites pass, including 40 compact-posture checks
and light carving in both directions. The deformed-clothing audit passes all
426 supported regular/tuck/preparation poses with a 6 mm shaft radius. Source
capture remains 552 chronological frames at 60 FPS over the 120 Hz simulation.

See [Animation review lessons](ANIMATION_REVIEW_LESSONS.md) for the changes to
apply in future pose reviews.
