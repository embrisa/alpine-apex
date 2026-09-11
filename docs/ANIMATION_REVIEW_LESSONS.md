# Lessons from the downhill hand and pole review

## Steering entry: measure apparent body lean as well as clip direction

The user rejected the first direction-selection fix after playtesting: the
whole body / torso still leaned the wrong way when steering from straight.
On steep snow, the terrain-normal frame gains outward roll as heading changes.
A locally correct carve can therefore point the wrong way in a gravity-aligned
view. The follow-up in [CARVE_DIRECTION_FIX.md](CARVE_DIRECTION_FIX.md) aligns
the connected grounded body to an unbanked support frame before fitting it to
unchanged physical boots. Keep slope pitch, existing posture weights, local
joint limits and the final writer; never change physical contacts to fit this.

Use the renderer's `--world-up` option for this defect. The default camera's
initial-slope normalization can hide it. Assert final world/heading-relative
torso and foot-to-chest lateral motion, not only selected LEFT/RIGHT names or
slope-relative bank. Include varied animation phases, gradual input, both
directions, tuck and release. For a nearly horizontal tucked torso, normalize
the full axis instead of dividing by its small vertical projection.

## Steering direction and physical bank are distinct

The [2026-09-11 direction fix](CARVE_DIRECTION_FIX.md) reproduced opposite carve
clips when active steering opposed a cross-slope bank or the previous turn.
Completed ski response still controls bank and blend strength; active steering
selects the forward-carve clip side. After release, direction follows the loaded
edge. Keep both signals in diagnostics and preserve the existing pose tracker.
Tests that only compare the clip side to physical edges cannot catch this bug;
include mirrored counterbanks without filtering them out as invalid fixtures.

## R8: foot height belongs to support

The user wanted carving pressure to read through different boot heights. The
current final leg fit pins boots to physical skis, so changing a Cascadeur knee
pose alone cannot create that separation. After explicit authorization for
physical sinking, [R8](CASCADEUR_SNOW_LEGS_R8.md) supplies per-ski loose-snow support
and lets the existing constrained fit respond. Keep support queries pure, advance
response once per tick, share available depth with bank crushing, and reset on
departure/restart. Report normal-depth differences separately from world-Y boot
coordinates and from anatomical knee flexion.

A contact change requires separate physical runs with matched starts/inputs;
do not require or claim identical physics. Preserve the source snapshot if a
concurrent task updates the solver, and distinguish old rendered evidence from
new live compatibility. Passing attachment tests cannot certify clothing
clearance: R8 retains R7's two failed tuck-transition frames despite correct
bindings and independent leg response.

## Cascadeur R6: locate posture ownership before editing the source

The [R6 gameplay experiment](CASCADEUR_WORKFLOW_EVALUATION_R6.md) imports the source
correctly and keeps bindings, cuffs, fixed grips and clothing clearance valid,
yet the existing `Downhill.apply` substantially replaces its torso and arm pose.
At compression, the candidate's final joints differ from production by at most
1.59 cm; light steering permits a much larger hand/pole difference. Passing source
transfer and contact checks does not establish that the authored style survived.

Record raw clip mix, posture stages, tracked request and final support-fitted pose.
Compare bone names through the library's own order: its 24-bone order differs
from the visual rig order. Use local normalized quaternion angles to identify
correction ownership; a forearm rotation includes pronation, not just elbow bend.
Do not fix a correctly imported source to compensate for later pose replacement.
Keep any ownership experiment action-specific, retaining solver-owned equipment,
anatomy limits and the sole final writer. Custom Python timing and Cascadeur's
control solve are separate contributions; neither proves native AI time savings.

## Earlier downhill hand and pole review

The R2 and R3 reviews showed that valid joint lengths, joint limits and equipment
attachments do not establish a convincing pose. The user accepted the direction
of the correction but continued to reject hand placement and outward pole spread.
Author-assigned grades are provisional; a passing test cannot upgrade them into
user acceptance.

Apply these lessons when revising other animation actions:

- Measure the visible task, including the end of the equipment. A shaft can pass
  close beside the hip and still flare far outward behind it. Tuck review needs
  hand depth, elbow width, shaft angle and tip width, together with clearance.
- Evaluate the connected chain. Shoulder, elbow, forearm pronation, wrist and
  the fixed grip socket all affect the pole. Moving the pole independently or
  placing all rotation at the wrist can conceal an implausible arm solution.
- Inspect the final pose after every blend and limit. Repeated soft limits can
  move a requested pole path inward. Test actual rendered transforms, not the
  target that existed before those limits.
- Use actual clothing geometry for close equipment paths. Hip and thigh
  capsules missed jacket intersections. The mesh audit checks the shaft radius
  against the deformed skin; intentional handle contact is excluded explicitly.
- Make targets action-specific. Close carry belongs to straight downhill and
  tuck. Carving needs free counterbalance, grabs need contact reach, and landing
  needs a responsive recovery. Copy the validation method, not the tuck pose.
- Review entry, hold, release and adjacent actions in both directions. Include
  light steering and residual turning after release. The pose's bank channel
  includes load asymmetry, so it is not itself proof of an active carve.
- Select phases from physical events. Pre-jump compression ends at actual
  support loss, not a hard-coded video frame. Keep departure and recovery in the
  chronological evidence without grading them as a grounded tuck.
- Retain the frozen before/after captures and independent user scores. Use front,
  side and overhead close views as well as playback; one flattering angle can
  hide the defect the user is describing.

These principles are applied to regular/tuck/preparation in
`tests/compact_posture_suite.gd` and `tests/pose_pole_mesh_audit.gd`. The latter now
accepts `--scenarios=` and reads selected frames from each revision's selection
file, so the same final-mesh audit can be used for captured carving and landing
sequences. Preparation's audit boundary follows support loss automatically.

For the next landing or grab revision, use the existing
`tests/landing_absorption_suite.gd`, `tests/airborne_pose_suite.gd` and grab cases
in `tests/skier_anatomy_suite.gd` as regression foundations, then add the relevant
final-mesh and silhouette evidence. Their current mechanical coverage does not
certify clothing clearance or exact finger contact. This review does not change
those actions' targets or expand their joint limits.

All authored corrections still feed the existing tick tracker and final
`skier_pose_writer.gd`; animation remains separate from simulation and records.

## Cascadeur trial: verify what the tool generated

The [2026-09-10 Cascadeur follow-up](CASCADEUR_TRIAL_EVALUATION.md) found that the
generated stomach control pointed to `Spine` above the chest even though the
template requested `Spine02`. Verify the actual generated joint references and
role assignment, not just configuration text or a successful API response.
Explicit joint IDs repaired the rig; exported-transform compensation was not
needed. This finding does not establish the internal cause of template remapping.

Audit anatomy along with contacts between keys. The six-key scene kept feet
fixed at keys but drifted between them; interval fixation reduced drift while
stretching the shins. Re-solving each export sample through the rig retained
both contacts and proportions. A contact result alone would have approved the
wrong variant.

Separate authoring-display reliability, export compatibility and final artistic
quality. The reopened scene had corrupt-looking materials while its animation
transforms survived and original Godot materials rendered correctly. The repaired
clip was still a stiff blockout. An isolated shared-writer preview also does not
prove gameplay composition/fitting or solver-relative equipment contacts.

The user then rejected the R4 Cascadeur preview for collapsing shoulders and
wobbling shoulder/elbow regions. Its source had almost 180° of upper-spine/neck
twist and shoulder width shrank to 3.37 cm while lengths remained stable. The
final writer faithfully reproduced those source rotations. Inspect full rotation
frames, clavicle width and elbow planes through every phase, especially held poses;
main-point positions alone leave orientation helpers and arm controls unresolved.
Side-only chronology missed a defect obvious from the front. Record user
rejection as a separate result and preserve that revision for comparison.

R5's rest-calibrated torso orientation, explicit clavicle/shoulder targets and
stable elbow/forearm helpers retained the shoulder silhouette through all 61
front-view samples. Source-to-writer rotation checks now accompany position checks.
Matched cameras and zero pole/clothing intersections support this narrow correction;
they do not turn a stiff symmetric blockout into accepted skiing animation.

R6's user feedback was “they look very similar?” Existing gameplay posture targets
can overwrite a faithfully imported source change. The separately authorized
[R7 carving variant](CASCADEUR_CARVING_R7.md) therefore blends a small local
upper-body difference after action composition but before the shared limits and
tracker. It still follows completed physical ski edges and leaves the same final
writer in charge. This establishes a visible alternative, not a Cascadeur adoption
decision or proof of AI authoring value. Its higher, broader hand carry can also
look more extended or stiff at strong banks; preference remains open.

R7's full final-clothing audit found the same two tuck-to-turn failure frames in
current and candidate motion, despite passing grip/binding checks and zero hits
in five other scenarios. Keep baseline and candidate failures visible and paired.
No new intersecting frame is a useful regression result, not an all-clear audit.


## 2026-09-11: stronger physical foot separation (R9)

The user requested about 17 cm at deepest carve. The R9 trial reaches 16.94 cm
during the strong-turn fixture; a world-Y gap is not the same as contact-normal
sinking, and slope/fore-aft position can increase it to 19.12 cm later. Stronger
physical support differences can introduce pole/clothing contact even when the
hand source is unchanged: complete audits found two new affected frames that
the small chronological front sheets did not clearly expose. Keep numerical
height, attachment checks and visual acceptance separate. See
[the R9 handoff](CASCADEUR_DEEP_CARVING_R9.md) for exact cases and receipts.
