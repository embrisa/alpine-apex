# Compact arm carry and deeper tuck

**Superseded after user rejection:** see [binding and posture corrections](BOOT_POSTURE_CORRECTION.md).
The measurements below describe the earlier pass, not current acceptance.

The user accepted the direction of the pelvis correction but requested more knee
and thigh fold, closer hands/poles in deep tuck, quieter arms while skiing, and
less outward arm motion during ordinary jumps.

`skier_full_motion.gd` now corrects arm articulation before the existing fixed-tick
velocity tracker. Shoulder swing brings elbows alongside the ribs; humeral twist
gathers the forearms. The wrist then aims the attached pole rearward through the
existing wrist envelope. There is no independent pole repositioning or joint
translation. Original local curves continue to supply fore/aft motion and flexion.

Grounded skiing, jump preparation and short hops keep a compact carry. The source
arms gradually regain room after 0.35–0.85 seconds of flight with 0.8–2.5 metres
of measured ski clearance. Landing readiness closes that allowance. Grab weight
fades the carry correction so Safety/Mute retain their authored reach. This is a
presentation read of completed support state, not a new flight or force model.

The extra deep-tuck pelvis offset ramps only through the upper half of tuck:
up to 4.5 cm down and 1.2 cm back, on top of the previous support-relative pose.
Both leg chains are refitted against the existing boot frames. The controlled
sample retains about 4.3 cm of lowering, 1.1 cm of rearward movement and 5.5 degrees
more knee bend; terrain and cuff fitting can reduce the requested displacement.

Source clips, physical segment mass, ski forces, input, replay and workshop
project authority are unchanged. The animation correction is visible in gameplay;
workshop projects still do not install themselves into gameplay.

## Validation

`tests/compact_posture_suite.gd` measures final pelvis placement, knee fold, hand
and elbow spacing, pole spread and continuous movement in glide, carving, deep
tuck, preparation, a hop and larger flight. It also compares physical snapshots
with an independent simulation that never runs presentation.

`tests/deep_tuck_suite.gd` retains the existing full-motion, anatomy, grab, replay,
interpolation and F8 checks. Attachment and workshop suites provide adjacent
coverage. `tests/steep_motion_gameplay.gd -- --compact-review` captures matched
production v13 scenarios; `--motion-baseline=res://...` loads a saved full-motion
implementation for an explicit comparison and records that file's hash.

Current acceptance and comparisons: `artifacts/compact_posture/ACCEPTANCE.md`.
Rendered inspection, automated checks, performance and user animation acceptance
remain separate. Numerical silhouette bounds do not establish animation feel.
