extends RefCounted
## Visual attachment contract, independent of the physical body mass model.
const BINDING_MESH = "binding_detailed_v2"
const SKI_ORIGIN = Vector3(0,.015,.15)
const BINDING_ORIGIN = Vector3(0,0,-.15)
const BOOT_ORIGIN = Vector3(0,.017,-.15)
const SOLE_ABOVE_SUPPORT = .032
const BODY_LOWERING = .078 # Remove the old cosmetic spacer, not physical COM.
