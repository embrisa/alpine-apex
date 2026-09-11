# Skier animation

Use [the animation skill](../.agents/skills/alpine-animation/SKILL.md) for work.
It routes to capture/audit recipes and review formats; this guide owns production
contracts, action targets and durable findings.

## Production pipeline

`presentation/skier_full_motion.gd` samples 33 retargeted clips at the verified
60 Hz source timebase from `assets/animation/steep_ski_motion.res`. The body GLB
supplies 24 weighted joints. `skier_animation.gd` and `skier_animation_tuning.gd`
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
| Preparation | Lower pelvis and close thigh/shin within cuffs; physical support loss ends grounded preparation |
| Carving | Free balance arms/poles; light/strong steer, both directions and residual bank after release, not permanent hip-hugging tuck bounds |
| Flight/grabs | Correct semantic side/style, connected reach, grip entry/release and actual air ownership |
| Landing | First contact/compression/rebound/recovery with full equipment clearance; tuck thresholds are not landing targets |

## Carving

Active steer chooses clip direction; completed bank/load still controls physical
strength. Cross-slope bank or residual previous-turn bank cannot select the
opposite clip during an explicit new steer. A nonzero carve channel can include
load asymmetry even while travelling straight.

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
vertical projection. The proportional/overlean backlog item remains separate
from the earlier direction correction.

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
- Cascadeur R4 source shoulders collapsed and torso/neck rotations approached
  180° despite stable positions. R5's rest-calibrated orientations, explicit
  clavicles and elbow planes retained shoulders. The user said R5 looked decent;
  that approves a source-preview baseline, not gameplay or tool adoption.
- R6 source changes looked similar in game because downstream posture ownership
  overwrote them. Identify the actual authoring method and evaluated stage;
  successful export does not prove useful AI authoring. R7 adds a visible local
  upper-body difference before limits/tracking, with its own stiffness/preference
  question and paired transition-clipping limits.
- R8/R9 are optional physical snow-support experiments with R7 hands. Foot height
  follows physical support, not cosmetic leg displacement. R9's requested deepest
  carve achieved 0.169428061 m world-Y boot separation; slope/fore-aft differences
  can produce larger later gaps. World-Y separation is not normal sinking.
  Full audit found two new affected pole/clothing frames. The numerical target
  does not establish production clearance, adoption or a Blender comparison.

Cascadeur sources, experiment scenes and sealed evidence remain retained.
Launchers are in `scripts/launchers/`: R6, Carving (R7), Snow Carving (R8) and
Deep Carving (R9); each accepts `-QuickSlope`, with its existing capture/control
options. These are isolated unranked trials, not replacement production defaults.

Current evidence and unresolved player review are in [Validation](VALIDATION.md#animation-evidence).
Reuse durable lessons rather than obsolete assignment briefs or copied artifact scripts.
