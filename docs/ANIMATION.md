# Skier animation

Use [the animation skill](../.agents/skills/alpine-animation/SKILL.md) for work.
It routes to capture/audit recipes and review formats; this guide owns production
contracts, action targets and durable findings.

## Production pipeline

`presentation/skier_full_motion.gd` samples 33 retargeted clips at the verified
60 Hz source timebase from `assets/animation/steep_ski_motion.res`, plus the
original double-pole control action in `assets/animation/pole_push_cycle.tres`.
The body GLB supplies 24 weighted joints. `skier_animation.gd` and `skier_animation_tuning.gd`
retain the procedural presentation used by the F8 comparison. This is a live
presentation path, not a historical solver. Apex chooses clip/event weights;
the recovered data is not Steep's complete evaluated animation graph.

The solver owns root/equipment motion, ski contacts, physical mass/COM and air
rotation. Curves supply support-relative local body shape: calibrated sole/ankle
offsets are decomposed offline, and source world bank, heading, root translation
and apparent complete flips are not reapplied. Fixed-tick body targets and
physical boots/skis share the same render interpolation fraction.

Production composition proceeds through source/procedural weights, posture/frame
alignment, shared pelvis fit, connected leg/arm fitting, anatomy limits,
equipment/grip clearance and the single `skier_pose_writer.gd`. The relevant
owners include `skier_full_motion.gd`, `downhill_posture.gd`, `skier_anatomy.gd`,
`skier_visual.gd` and `skier_equipment.gd`. Diagnose the first stage that introduces
the defect rather than editing another layer to counteract it.

Navigation consumes speed, steering, bank/slip, tuck and support. Held preparation,
actual hop/support loss, read-only landing prediction and grouped landing episodes
drive their corresponding clocks. Switch, skid, recovery and grabs have explicit
mappings. Loops overlap ends; one-shots hold endpoints. Grab release continues
its phase while weight decays; style latches across brief re-grabs. Relative
joint tracking preserves angular velocity across target changes (12 rad/s and
160 rad/s² bounds), without limiting physical actor rotation. Pause collapses
interpolation; restart resets state. Settled procedural comparison disables full
sampling cost while lightweight event clocks retain the correct re-entry phase.

## Runtime preparation and cost

`skier_full_motion.gd` prepares the 33 immutable source clips once per loaded
script resource, before riding. The read-only table retains normalized source
quaternions and packed root positions for all 3,985 frames (95,640 joint samples).
Sampling still uses the original 60 Hz timebase, interpolation, loop seams and
mirror rules. Each call returns its own mutable pose. After asset reimport, a new
runtime/script load rebuilds preparation; live mutation of the loaded source
table is unsupported. There is no cache of simulation, action,
equipment, settings or interpolated poses and no per-frame invalidation protocol.

Grip tracking evaluates only the requested arm's root-to-forearm ancestors.
It rebuilds that chain on each wrist/forearm request because parent joints advance
within the same fixed tick. Final composition computes pose-wide carry weights
once. At exactly full source weight it omits the replaced procedural limb frames
and their zero-contribution blend; partial F8/clearance blends keep both sides.
The direct source rotation avoids a redundant quaternion round trip, so final
floating-point transforms need not be bit-identical. Anatomy, fitting, grip and
attachment limits remain unchanged.

`tests/animation_cpu_suite.gd` compares prepared sampling to raw asset decoding
at endpoints, fractional frames and loop seams, and verifies result isolation
and complete grip ancestry. `tests/performance_descent.gd` connects the opt-in
frame profiler to source/blend, posture, tracking, pelvis, hierarchy, grip,
procedural, equipment and writer subscopes. These overlap the outer fixed-tick
and render scopes and must not be summed. Completed ghost evaluations
remain separate from visible render interpolation. Follow [Validation](VALIDATION.md#performance-method)
for matched bounded production comparisons; detailed optimization evidence is
in `artifacts/animation_cpu/`.

On Windows x64 and macOS arm64 the native skier kernel batches the 120 Hz quaternion tracker, joint
limits and grip-target reconstruction. It updates the rider-owned rotation and
velocity arrays in bone order, rebuilding each grip from parents that have
already advanced. Only immutable names, rest offsets and arm ancestry are shared.
The same acceleration/speed bounds, gains and tick cadence remain in force;
root tracking, posture selection and the final skeleton writer keep their owners.
Other platforms use `SkierFullMotion.reference_track_pose`. The native batch and
the retained script path are compared by `tests/skier_tracking_suite.gd` across
all source clips, action/grip blends and cumulative updates. It also checks that
requested poses and saved interpolation history remain independent.

The same native module evaluates each leg's final ten-iteration knee search.
`SkierAnatomy.fit_render_knee` retains the source-pole fade, cuff flex/side limits,
twist limit and search order; it receives the actual visual thigh/shin lengths.
`reference_render_knee` is the portable implementation and numerical oracle.
This reduces both visible-pose and completed ghost-pose cost without sharing
poses across timestamps, changing capture cadence or moving physical skis.
`tests/render_knee_suite.gd` checks both legs, full/partial/zero source weight
and nearly undefined pole directions against the native implementation.

## Connected anatomy and equipment

The initial full-curve result was rejected as rubbery despite bone-length and
attachment passes. Independent global rotations, axial twist and forced grab
reach were the causes. `skier_anatomy.gd` owns the calibrated game-pose envelope,
not a universal anatomical model. Limits apply before tracking and during final
hierarchical composition, including zero source weight during F8 transitions.

Fit the shared pelvis against both rigid cuffs and limb reach circles; reconstruct
connected segment frames and retain source axial twist only within calibrated
hinge/cuff bounds. Ordinary spinal/wrist and action-specific tuck limits differ;
read the owner rather than copying a dated numerical table. Do not stretch limbs,
move physical skis or slide sockets to satisfy a target. Grab accommodation is
distributed over bounded hip/spine/clavicle motion. Unreachable targets remain
visible reaches; contact diagnostics follow actual glove-to-target gap. Fixed
fingers limit close-up contact, and an unweighted extra joint cannot solve it.

Equipment GLBs have transforms baked into the extracted mesh; scene corrective
rotations would be lost. Metres, Y up, +Z forward. The ski's authored shovel
extends beyond the unchanged physical support. Binding/boot offsets are owned
by `skier_equipment.gd`; poles grip at their origin with shaft along local −Y
and tip approximately −1.18 m. Left ski is an X-reflected derivative with UVs
attached to reflected vertices; Node/boot/binding handedness stays intact.
Equipment uses its own two-sided lit material for thin/open generated surfaces.
Straps/binding mechanisms are static; equipment stays attached during crashes.
Editable source/provenance is in [Assets](ASSETS.md#skier-and-animation-sources).

## Recorded ghost presentation

`ghost_pose.gd` captures completed writer output at the session-owned sample
cadence described in [Racing](RACING.md#recording-and-ghosts), plus exact
initial/finish/crash/recovery boundaries. It records 24 named
local bone transforms, root, both skis/poles and final accepted track data.
Routine capture reuses a recent completed `SkierVisual.pose`, including fitting,
without modifying the live rider. `GhostPose.capture_completed` records that local
rig at the exact current root; limb motion may be up to 25 ms old. The pose cache
records its fixed tick, interpolation fraction, grounded state and facing mode.
An unavailable, stale/future, authored-preview or support/facing-mismatched pose
gets a fresh solve. Reset invalidates reuse. Initial/final/crash/recovery boundaries
also retain fresh poses, including fractional finishes. The solver and live-rider
render interpolation keep their existing cadence. Per-ski track eligibility uses
current physical support and the rebased equipment footprint.

`tests/ghost_capture_reuse_suite.gd` checks unchanged visible state, connected
boots/grips, root placement and fresh-pose fallback. Separately review fast pole,
carve and grab motion when changing the age limit; numeric root equality alone
cannot accept ghost animation quality.

Playback composes local transforms hierarchically through `SkierPoseWriter`.
Each visual retains a bounded pair of decoded recording frames in
`ghost_pose_frames` metadata. Packed local transforms and equipment sockets are
prepared only when their immutable source frame changes; promotion of the old
second frame reuses it as the next first frame. Root, limbs, equipment and track
responses still interpolate at the existing render cadence. The cache belongs
to one fixed visual rig and is released with it; content comparison handles
retries, reverse time and replacement recordings. `ghost_pose_cache_suite.gd`
compares this path with the uncached reference, including those transitions.
Recorded equipment-to-foot/hand transforms interpolate relative to connected
bones so cuffs/grips remain attached between samples while matching recorded
equipment at endpoints. Preview-only setup shares the production mesh/equipment
path without loading player appearance preferences, running clips or creating a
simulation/ragdoll. Final attachment and action chronology still need native
review. [Racing](RACING.md#recording-and-ghosts) owns serialization/discontinuities;
[Rendering](RENDERING.md#snow-presentation) owns independent cosmetic tracks.

## Coordinates and diagnostics

Skier model right is −X, left +X, forward +Z, up +Y; Godot's `Vector3.FORWARD`
is −Z. Camera-left is not anatomical left. Captured `joints`, `rotations`,
`requested`, `requested_rotations` and `final_bones` are model-space; `root`,
`poles` and `skis` are world transforms. Serialized basis arrays are **columns**.
For a rigid root, dot with its columns to convert a world vector to model space;
avoid double transposition and point/direction confusion.

Support-relative measurements average foot Y axes, project summed foot Z off
that up axis, then use lateral = up × forward. Chest widths use upper-spine X.
State the frame. The glove socket is hand-local `(side * .070, 0, .018)` with
side −1 right/+1 left; wrist-to-grip offset is intentional. Forearm pronation
and elbow hinge bending are separate; remove pronation when assessing hinge axes.

`tests/pose_reference_render.gd::source_pose()` samples actual imported curves
with an isolated production sampler and existing boot/support offset.
Diagnostic source/requested/final views help locate overwriting by composition,
tracking or fitting; `present_authored` previews are explanatory reconstructions,
not alternate simulations. Compare raw rotations as well as joint positions.

## Action targets

| Action | Target and required neighbors |
|---|---|
| Downhill | Ready connected hands, modest knee advancement, open chest/forward gaze; inspect tuck entry and uneven support |
| Straight tuck | Separated hands near chest, elbows near ribs, whole shafts outside hips and trailing close; inspect entry/hold/release and clothing |
| Pole pushing | Reach, simultaneous plant, loaded backward sweep, release/recovery; inspect slopes, grips, whole shafts and tuck/turn/departure neighbors |
| Preparation | Lower pelvis and close thigh/shin within cuffs; physical support loss ends grounded preparation |
| Carving | Free balance arms/poles; light/strong steer, both directions and residual bank after release, not permanent hip-hugging tuck bounds |
| Flight/grabs | Correct semantic side/style, connected reach, grip entry/release and actual air ownership |
| Landing | First contact/compression/rebound/recovery with full equipment clearance; tuck thresholds are not landing targets |

## Landing compression and recovery

`skier_animation.gd` measures additional physical leg flex from the height at
touchdown. An existing flight/tuck crouch cannot consume the new landing's entire
cosmetic budget. `assets/animation/apex_ski_motion.gd` owns the small/medium/large
drop and recovery profiles. The full-motion impact channel also scales by that
depth, preventing a small hop from playing the full hard-impact pelvis pulse.
Small impacts retain compression longer and recover more slowly than the former
quarter-second dip/pop. These are completed-tick presentation values; they do
not change translation, contact, reserve, flight or recording identity.

Brief recontacts can strengthen the current recovery without restarting it.
After the normal contact-group interval, a deliberate jump or at least 100 ms of
actual flight rearms a new landing; otherwise recovery must finish first. Reset
clears the episode and pause holds it. The original large-impact profile remains.

`tests/landing_settle_suite.gd` checks actual hop/contact behavior, proportional
final-pose compression, recovery speed, episode ownership and identical paired
solver state. `scripts/capture_small_landing.ps1 -OutputDirectory artifacts/landing-review -View side`
captures four seconds of final production motion on a 4 m fixture. `-View chase`
or `-View first_person`, `-Uneven` and `-Tuck` select focused neighbors. The wrapper
uses the normal guard and a temporary offscreen/no-focus project, then unlinks
its shared directories without touching their targets. Its capture manifest and
`capture/landing.json` also support the existing full pole-mesh audit with
`--scenarios=landing --include-flight`. These fixtures do not establish human
feel or uncontended FPS.

## Pole pushing

`pole_push_motion.gd` samples the editable control action; `pole_push_pose.gd`
composes its torso/connected-arm targets after ordinary tuck/downhill/action
shaping and before the bounded tracker. Those channels retain the reach and
backward sweep through final fitting. The shared pelvis, rigid cuffs, anatomy
limits, fixed grips and sole PoseWriter remain authoritative. The action also
participates in the procedural F8 comparison.

Completed solver phase/intensity/power drive the action and its loaded interval;
presentation never advances the actuator. Cosmetic plant anchors are sampled
at completed ticks on authoritative snow. The connected-arm fitter allows up to
30 cm of cosmetic wrist accommodation, retains rigid pole/limb lengths and fixed
grips, and keeps unloaded shafts in an outboard carry lane. Separate completed-tick
carry smooths cancellation independently of snow-contact weight; rendering only
samples it. Unreachable `tip_gap_m` remains a reported visual miss, never a force
or moved ski. While the solver still supplies positive thrust, the presentation
retains at least half of the authored stroke instead of shrinking it into tuck.
At the speed cap it completes the current release, then stops starting plants.
The palm target is blended once before solving forearm pronation and wrist
limits, avoiding the previous repeated orientation blends during cancellation.
The source uses a 28-30 cm lateral grip lane and lower, rearward elbows, and keeps
the torso folded until force release. Contact fitting preserves that tracked
elbow direction with one connected arm solve. The previous ten-candidate outward
bend search widened the final pose. A strict frontal elbow plane also caused
fast transition jumps, so alignment belongs in the authored arm rather than a
plane lock. The fitter retains ten percent of bounded unloaded reach and mixes
45 percent of the authored fore/aft wrist target. Lateral carry blends once from
the source wrist. Initial contact grows linearly over solver phase 0-.06,
reaching full weight before force starts;
double blending the lateral reach caused a right-turn re-entry snap.
At a standing start the cosmetic plant sits 6 cm behind the support origin,
blending to the existing 25 cm forward lead by 2 m/s before travel anticipation.
The same rule owns next-plant previews. The former standing lead held the hands
high beside the chest as the torso folded, creating the rejected 0.5-second pose.
The shorter standing lead allows a downward push without widening the elbows.

After contact fitting, `fit_carry_clearance` keeps unloaded shafts outside five
small torso/own-arm/thigh capsules. It runs only during active or fading pole
carry while grounded, contact weight is at most .001 and thrust is zero.
Ordinary downhill/tuck keeps its existing pose and incurs no clearance work.
Up to three geometric passes aim the shaft away
from those envelopes, capped at 20 degrees. Torso/thigh clearance escapes to the
side rather than asking an already folded wrist to lift farther. The final
correction uses the current action's hard pronation/wrist envelope: repeating
the source's soft easing here pulled the pole back into the thigh. It does not move joint positions,
grip offsets, physical contacts or solver state, and
has no history or terrain queries. The capsules approximate clothing: the actual
skinned mesh audit and rendered review remain the acceptance checks. The
diagnostic `pole_carry_clearance_enabled` flag defaults on and is not a setting.
[Validation](VALIDATION.md#pole-propulsion-and-animation-producers) owns the
retained evidence and exact remaining limits.

Source/export ownership is in [Assets](ASSETS.md#pole-action-source). Bounded
probe/chase/front/side captures and enabled/disabled comparisons are in
[Validation](VALIDATION.md#pole-propulsion-and-animation-producers). A source export,
good grips or stable joint transforms do not clear tip sliding, shaft/clothing
intersections or the retained tuck-neighbor findings below.

## Carving

Active steer chooses clip direction; completed path turning and loaded ski edges
control its strength. `skier_full_motion.step` computes signed balance from
`-atan(turn_rate_rad_s * speed_mps / 9.81) / .65`, bounded by the magnitude of
the supported edge channel. Motion turn rate is positive toward model +X (rider
left), hence the minus sign. Input alone and residual edging alone cannot commit
the posture. A reversal may retain the old balance while the real path unwinds.

Source clips, straight-posture release and action-posture activation share
`turn_strength = smoothstep(.02,.85,abs(balance))`. The former straight release
at .06 made even a 5% hold fully activate the action posture. A .10 tap could
activate it by 84%. The procedural F8 comparison retains its own channel mapping.

Partial sequential posture blends also retained opposite source roll, while the
old edge-signed torso target could disagree with clip direction on cross-slopes.
`Action.balance_roll` gives the grounded hip/spine chain one proportional signed
target before the existing joint tracker, retaining small source sway and spinal
counterbalance. It releases through the existing ground/action weights. Pelvis
stance inclination uses a tick-tracked ratio of balance to supported edge; final
rigid-cuff fitting, physical boots/skis, COM and the sole writer remain unchanged.

The user found the first clip-sign fix insufficient: on steep cross-slopes, a
correct local pose still leaned outward because the terrain-normal frame rolled
with changing heading. `upright_support()` keeps forward/slope pitch while
removing that unwanted support-frame roll. `skier_visual` supplies the interpolated
frame; grounded body alignment precedes pelvis/leg fitting and releases through
air-action weights. It does not bend the spine to disguise a coordinate error
or change physical boots/contacts.

Use `--world-up` in the pose renderer for this defect: ordinary studio initial-
slope normalization concealed it. Measure final torso and foot-to-chest axes in
a gravity/heading frame, across phases, gradual/hard steer, left/right, tuck and
release. Normalize the whole axis for deep tuck instead of dividing by its tiny
vertical projection. `tests/carve_proportional_capture.gd` adds matched 5/10/20%
corrections, taps, 55/100% turns, mirrored cross-slopes, reversal and tuck;
`tests/carve_proportional_suite.gd` varies phase, speed and 50/150 ms taps across
114 cases. Use `tests/carve_direction_playtest.gd -- --proportional` for the same
fixtures with the production chase camera. `scripts/pose_review/measure_carving.py`
reports gravity/heading lean, pelvis offset, path acceleration, weights and timing.

The residual reversal stance was traced to the bank-following physical edge-goal
window: released or weak intent could not flatten deeply edged boots, and rigid
cuff fitting kept the pelvis sideways. Model 30 releases that restriction through
the existing rate-limited ski motors; see
[Physics](PHYSICS.md#carving-skidding-and-tuck). Connected legs can then return
without weakening anatomy or counter-posing the physical stance. Production
animation code and its CPU preparation remain unchanged.

`tests/carve_residual_suite.gd` rejects the retained 25/40 m/s mirrored reversals
independently of edge saturation. It measures whole-body lean and lateral pelvis
relative to each neutral control, using 12 degrees / 15 cm bounds after release
and a sustained low-curvature interval. Strong loaded release retains its natural
return; mild holds and 50/150 ms taps have separate controls. The capture companion
records production final bones/equipment, two-second warm-up, turn/release and
tuck/hop/landing neighbors. New evidence lives in
`artifacts/pelvis_residual/20260912-fix/`; retain the original
`artifacts/pelvis_residual/20260912-baseline/` through review. Acceptance and exact
receipts are recorded in [the residual pelvis task](../backlog/completed/AA-20260912-153317-fix-residual-carve-pelvis-lean.md).
The matched mesh audit introduces no new intersecting frames; existing tuck
pole/clothing intersections remain documented in that completion record.

The 2026-09-12 frozen comparison lives in
`artifacts/pose_review/revisions/20260912-proportional-{before,final}/`; matrix,
engine identity and regression receipts are in `artifacts/carve_proportional/`.
The 114-case matrix passes 575 checks. All 3,150 frozen frames retain exact
recorded physics/COM/skis; 1,155 paired chase frames also retain identical cameras.
At 25 m/s, 5% holds peak at 1.7% action activation, 10% holds at 12.8%, and
100 ms 10% taps at 2.2%, versus the previous 100%/100%/84%. Loaded 55-100%
turns retain roughly 38-42 degrees of whole-body inclination. The matched
capture CPU proxy (two 120 Hz steps plus one 60 Hz fit) is 2.394 -> 2.445 ms;
this small measured increase is not a rendered-FPS or 4K performance acceptance.

Clothing clearance **does not pass**: the complete 3,150-frame mesh audit finds
33 affected frames before and 130 after (114 `tuck_10_right`, 16 `tuck_55_left`).
There are 117 newly affected frame/scenario pairs, 13 retained pairs and 20
removed pairs. All other 13 scenarios remain clear. Keeping a light turn tucked
exposes the compact-arm shaft path for longer; this is a measured neighboring
regression, not an all-clear or merely the historical ten-contact result.
Pole-target/arm-carry trials were rejected: they retained intersections or caused
large wrist snaps. Production retains the existing tracked arms, joint limits,
fixed grips and sole writer. Detailed rejected captures remain in the revision
folders; none of those pole corrections ships with the carving change.

Automated lean/continuity checks, rendered lean review, failed clothing clearance,
measured CPU cost and real-controller acceptance remain separate. Human
visual/controller acceptance is pending.

## Recorded steering regression

Final ankle targets read the actual rigid boot child in rider-local coordinates.
Reconstructing the same attachment separately in world space introduced rounding
gaps at mountain altitude; the cuff/attachment suites retain their existing limits.

`tests/steering_recording_suite.gd` reruns the explicitly retained 9.2-second
Attempt 001 input stimulus and mirrored steering on Standard terrain. It judges
final body and torso direction, pelvis excursion and steering-joint continuity
at render alpha 0, 0.5 and 1; clip-side checks alone missed this defect. The first
wrong-way stage was the physical bank-following cuff command, not the authored
turn or clearance fitting. The correction belongs to [Physics](PHYSICS.md#carving-skidding-and-tuck).

`tests/steering_recording_capture.gd` freezes every completed tick and intermediate
pose metrics, including path turn, bank, COP, both edges/loads, tuck, source and
requested animation, clearance and final bones. Its explicit `--regression-fixture`
mode reruns only this retained stimulus and emits a new current-model diagnostic
recording; it does not migrate or accept an incompatible player replay. Use the
ordinary `--input-trace` path for exact current-recording verification. The
15-second uneven-snow neighbors are in `tests/steering_snow_suite.gd`.

Fresh controller Attempt 005 (model 33, 24.367 seconds) confirms that the main
wrong-direction jank is much smoother but retains repeated rises toward center
during held carving. Exact replay traces this to physical bank/recovery cycling
and fitted pelvis height, before clip or clearance changes. Earlier recovery
and stance experiments remain rejected: they either retain the cycle or fail
reversal continuity/leg anatomy. No follow-up physics or pose change was accepted.
Keep the recording, full pose capture and candidate failures under
`artifacts/steering_jank/20260913/controller-005/` for the unresolved balance work.

## Retained findings and acceptance

- Downhill R1/R2 were rejected despite plausible metrics/provisional author
  scores. R3 improved hip routing but full tips still flared. R4's successful
  narrowing arrives near full compression; slightly wider hands produced a
  narrower full-pole silhouette. Transition-only tightening caused jacket
  intersections. R4 is a retained refinement, not final user acceptance or an
  established ≥8.0 grade.
- Pole/clothing checks must deform final skinned meshes. Grip/binding passes
  cannot establish shaft clearance. The five-ray, 6 mm audit is approximate;
  selected stills missed transition failures. Coverage rules live in the skill.
- The carve-entry correction passed 64 checks with 720 paired physical frames
  unchanged, but retained ten baseline tuck-transition intersection frames.
  Preserve that limitation; no new intersections is not an all-clear result.
- Downstream posture ownership can overwrite an imported source shape. Inspect
  source, requested and final poses to locate that stage before authoring more
  clips. Successful export and stable joint positions do not establish useful
  gameplay motion or correct joint rotations.

## Authoring direction

The user retired Cascadeur on 2026-09-12 after the matched visual comparison
showed insufficient benefit. Its trial sources, scenes, launchers, report builder
and alternate simulation hook are removed. Use the existing Blender/Godot route
for new animation work; future tasks do not require another tool trial.

The review remains in `artifacts/animation_comparison_20260912/`. Its dated
captures establish neither current gameplay quality nor acceptance of the trial
poses. The rejected trial's source/fitting findings and unresolved clothing
contacts remain in the sealed historical evidence. Removal provenance and
validation are in `artifacts/animation_trial_retirement_20260912/`.

Current evidence and unresolved player review are in [Validation](VALIDATION.md#animation-evidence).
Reuse durable lessons rather than obsolete assignment briefs or copied artifact scripts.
