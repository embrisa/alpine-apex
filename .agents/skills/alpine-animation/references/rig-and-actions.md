# Rig, coordinates and ownership

Read the live functions before changing them. These paths are the current map,
not a promise that an old revision's implementation remains current.

## Choose the route

| Work | Starting points | Evidence to preserve |
|---|---|---|
| Preview curve edit, clip variant, feedback ZIP | `docs/ANIMATION_WORKSHOP.md`; `scripts/workshop/motion_project.gd`, `pose_evaluator.gd`, `motion_export.gd` | `.apexmotion`, original/edit/constrained comparison, exported ZIP and package verification |
| Source import or retarget | `docs/STEEP_MOTION_GAMEPLAY.md`, `docs/SKIER_ANATOMY.md`, `assets/animation/steep_ski_motion.res` | Source frame/time, names/parents/rest axes, rotation conventions, source and output hashes |
| Gameplay pose, blend or transition | `scripts/presentation/skier_animation.gd`, `skier_full_motion.gd`, `downhill_posture.gd` | Real solver inputs/events and final rendered pose, not only a Workshop preview |
| Constraint, contact fitting or attachment | `skier_anatomy.gd`, `skier_visual.gd`, `skier_equipment.gd` in `scripts/presentation/` | Requested versus final joints, local rotations, cuff/grip errors, actual clothing clearance |
| Mesh, weighting, rest pose or socket | `docs/SKIER.md`, `docs/EQUIPMENT.md`, `assets/graphics/models/skier_v7.glb` | Skin/rest compatibility, new rig hashes, attachment checks and rendered asset review |

Workshop projects are preview-only. Saving/exporting a project does not apply it
to gameplay. The package may embed source data, corrections and evidence; do not
treat imported project data as executable code. Use `docs/ANIMATION_WORKSHOP.md`
for recovery and export semantics. Source root motion/spins do not transfer
wholesale into solver-owned gameplay.

## Trace the final result

`skier_animation.gd` derives presentation channels from physics ticks and input.
`skier_full_motion.gd` selects/blends the source library, applies scoped posture
corrections and local limits, and advances its existing tick tracker.
`skier_visual.gd` samples/composes that motion with support and anatomical fitting,
then attaches equipment. `skier_pose_writer.gd` converts model-space targets to
local Skeleton3D poses. It is the shared final writer for gameplay and Workshop.

Read `step`, `compose`, `Downhill.apply`, `Anatomy.local_limit`, `fit_hinge`,
`present_authored` and the grip attachment code when relevant. There are multiple
limit/fitting stages: a requested target can look correct before the final chain
moves it. Avoid another final writer or a late visual-only override that bypasses
the same constraints elsewhere.

`scripts/core/rider_body.gd` provides physical/rest anatomy; it is not a convenient
place for a cosmetic correction. Read `docs/ARCHITECTURE.md` before a change that
actually involves simulation/contact. Such a change needs its own physics scope
and physics/runtime validation.

## Coordinate and bone map

The reviewed rig has 24 bones. Check the live library and capture's `rig` metadata
for exact names, parents and rest transforms. Name-based access is safer than
remembering numeric indices.

| Review label | Rig name / chain |
|---|---|
| Pelvis | `Hips` |
| Lower / middle / upper spine | `Spine02` → `Spine01` → `Spine` (order is easy to misread) |
| Neck / head | `neck` → `Head` (lowercase `neck`) |
| Shoulder / upper arm / forearm / hand | `LeftShoulder` → `LeftArm` → `LeftForeArm` → `LeftHand`; same for `Right` |
| Thigh / shin / foot / toe | `LeftUpLeg` → `LeftLeg` → `LeftFoot` → `LeftToeBase`; same for `Right` |

- Metres, seconds, radians internally. Workshop UI uses degrees for local YXZ
  correction curves; source animation is quaternions. Do not interchange Euler,
  quaternion, rest-local and model-space rotations.
- The skier model uses +Z forward, +Y up and +X toward anatomical left in these
  pose targets. Godot's `Vector3.FORWARD` is -Z. Camera-left is not anatomical left.
- Capture `joints`, `rotations`, `requested`, `requested_rotations` and
  `final_bones` are model-space. `root`, `poles` and `skis` are world transforms.
- Serialized `basis` arrays are **columns** `[x,y,z]`. For a rigid root, dotting
  the world vector with each root column converts it to model space. Do not
  silently transpose twice or treat points as directions.
- For support-relative measurements: normalize the sum of foot Y axes, project
  the summed foot Z axes off that up axis, then normalize; lateral = up × forward.
  Chest-relative widths use the upper spine's X axis. Label which frame is used.
- A shaft runs along the pole's local -Y. The reviewed mesh is 1.18 m from grip
  to tip; audit radius is 6 mm. Verify geometry when equipment changes.
- The current glove socket is hand-local `(side * .070, 0, .018)`; side is -1
  for right and +1 for left. The mesh's wrist-to-grip offset is intentional.
  A stretched wrist seam is not permission to slide the hand off its chain.
- Forearm axial pronation and elbow hinge bending are different degrees of freedom.
  Evaluate hinge axes with pronation removed. Aim the fixed grip through the whole
  arm chain; do not put all pole roll into wrist twist.

## Action targets and regression neighbors

| Action | Visual purpose | Neighbors / failure modes |
|---|---|---|
| Regular downhill | Ready hands, modest knee advancement, open chest and travel gaze; narrower stance per user feedback | Entry toward tuck, uneven-load asymmetry; avoid chest pointing into snow |
| Straight tuck | Compact hands near chest, elbows beside ribs, shafts close outside hips and trailing along body | Entry/hold/release, full tip flare, sleeve/torso collisions |
| Pre-jump compression | Lower pelvis and closed thigh/shin angle within rigid cuff envelope; continuous spine and forward gaze | Actual support loss ends grounded preparation; keep departure and recovery visible |
| Carving | Free arms and poles for counterbalance | Light and strong steer, left/right, input release while bank/turn rate persists; no forced hip-hugging poles |
| Flight and grabs | Reach/contact and appropriate air balance with connected chain | Ordinary hop vs sustained flight, right/left semantic differences in source clips, grip reach and release |
| Landing | Responsive absorption/recovery with body and equipment clearance | First contact, compression, rebound, blend back to steering; tuck bounds are not landing targets |

Existing carve channel can include load asymmetry even when straight. Diagnose
actual steer, bank and `turn_follow` rather than assuming any nonzero channel is
a turn. R4 numerical thresholds apply to its specific action and rig; do not copy
them into grabs, landing or other equipment.
