# Rig and action routing

[Animation](../../../../docs/ANIMATION.md) owns the pipeline, coordinate contract,
action targets and experiment status. [Assets](../../../../docs/ASSETS.md#skier-and-animation-sources)
owns editable sources and rebuilds.

| Change | Source entrypoints | Required comparison |
|---|---|---|
| Import/retarget | `assets/animation/steep_ski_motion.res`, source manifests | Source frame/time, parents/rest axes, rotation conventions and hashes |
| State/blend/posture | `scripts/presentation/{skier_animation,skier_full_motion,downhill_posture}.gd` | Real solver events and final pose |
| Limits/support/equipment | `scripts/presentation/{skier_anatomy,skier_visual,skier_equipment}.gd` | Requested/final joints, local rotations, cuff/grip error and clothing clearance |
| Mesh/weight/rest/socket | `assets/graphics/models/skier_v7.glb` | Rest/skin compatibility, rig identity, attachment and rendered checks |

Trace `step`, `compose`, `Downhill.apply`, `Anatomy.local_limit`, `fit_hinge`,
`present_authored` and grip fitting before changing their output. Multiple stages
can move an initially correct target. `skier_pose_writer.gd` remains the shared
final writer; `scripts/core/rider_body.gd` owns physical/rest anatomy, not cosmetic
corrections. Simulation/contact work requires its own scope and
[architecture](../../../../docs/ARCHITECTURE.md).

Bone names are case-sensitive: pelvis `Hips`; lower-to-upper spine
`Spine02 -> Spine01 -> Spine`; `neck -> Head`; arm chain
`LeftShoulder -> LeftArm -> LeftForeArm -> LeftHand`; leg chain
`LeftUpLeg -> LeftLeg -> LeftFoot -> LeftToeBase` (corresponding Right names).
Use capture rig metadata for rest transforms rather than numeric indices.

Use [the coordinate contract](../../../../docs/ANIMATION.md#coordinates-and-diagnostics)
for support/chest measurements and forearm pronation. Fixed-grip aiming involves
the whole arm, not wrist twist.

A nonzero carve channel can reflect straight-line load asymmetry. Inspect steer,
bank and `turn_follow`. Preparation's grounded phase ends at actual support loss.
Preserve entry/release and neighboring actions; use the guide's action envelope.
