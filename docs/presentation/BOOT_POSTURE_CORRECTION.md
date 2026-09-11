# Bindings and carried posture

This supersedes the compacting pass in `COMPACT_POSTURE.md`, which the user
rejected for forward knee deformation, over-gathered arms and crossed poles.

`skier_equipment.gd` defines a low visual binding seat. The v2 binding removes
all riser plates/columns from the retained v1 asset, fits the housing to the
lower seat, and flattens its existing toe and heel mounting faces against the
ski top. No replacement spacer is added. The boot sole sits 17 mm above the
ski top. Both the boot and visible rider move down 78 mm from the old offset.
The original character mesh, rig, animation library, physical mass model and
120 Hz ski simulation remain unchanged. Workshop authored/constrained views
use the same seat; crash equipment captures these actual final transforms.

The additional 45 mm deep-tuck drop and 12 mm rearward offset from the rejected
pass are removed. The earlier rearward pelvis transfer remains. Presentation
fitting caps forward shin flexion at 24 degrees rather than 32, moving the shared
pelvis to satisfy both connected legs. Bone lengths and rigid boot frames remain
exact. This does not move physical COM or change skiing response.

Glide and carving again use source arm counterbalance. Tuck carry fades out
between 0.02 and 0.20 steering input. Preparation and ordinary takeoff retain
the bounded carry; sustained larger flight retains its wider motion.
Tuck holds elbows close and allows the forearms/gloves to clear the thighs.
Its wrist swing blends from 28 to 60 degrees so the attached shafts can trail
back beside the hips; the old 28-degree stop forced them downward through the
thighs. Wrist twist stays bounded at 55 degrees. Corrections run before the
existing pose velocity tracker and final anatomical fitting.

Validation checks the actual toe/heel mounting patches, final boot-to-skeleton
attachment, leg lengths, cuff limits, source-loop continuity, and pole segments
against hip and thigh volumes. Broader anatomy checks use the context-dependent
wrist envelope. The previous tests that rewarded narrower hands and deeper
forced knee compression have been replaced with these spatial checks.

Evidence and separate automated, rendered, performance and user-acceptance
results are recorded in `artifacts/boot_posture_correction/ACCEPTANCE.md`.
Rebuild the binding with background Blender and
`scripts/art/prepare_binding_v2.py`; v1 and all original sources are retained.
