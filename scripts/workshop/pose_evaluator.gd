extends RefCounted
## Isolated fixture. No access to the live rider, session, terrain or records.
const Simulation = preload("res://scripts/core/ski_simulation.gd")
var sim = Simulation.new()
var plane = SupportPlane.new()
var context_cache: Dictionary = {}
class SupportPlane extends RefCounted:
	var slope = 0.0
	func sample(_x: float, z: float) -> Dictionary:
		return {"height":-z*tan(slope),"normal":Vector3(0,1,tan(slope)).normalized()}
	func sweep_obstacle(_a: Vector3, _b: Vector3) -> String: return ""

func configure(context: Dictionary, visual) -> void:
	if context_cache==context: return
	context_cache = context.duplicate(true)
	plane.slope = deg_to_rad(context.slope)
	sim.tuning.half_stance = context.stance*.5
	sim.reset(Vector3.ZERO)
	sim.effective_tuck = context.tuck
	sim.prime_contacts(plane)
	sim.grounded = context.context=="grounded"
	sim.reset_pose_history()
	visual.reset_animation(sim)
	visual.animation.current.grab = context.grab if context.context in ["safety","mute"] else 0.0
	visual.animation.previous = visual.animation.current.duplicate()
	visual.animation.full_motion.active_grab_style = "mute" if context.context=="mute" else "safety"
	visual.animation.clearance_surface = plane if sim.grounded else null

func evaluate(project, pose: Dictionary, context: Dictionary, visual) -> Dictionary:
	configure(context,visual)
	var sampled = project.fk(pose)
	sampled.amount = 1.0
	sampled.grip = context.grab if context.context in ["safety","mute"] else 0.0
	visual.pose(sim,1.0,sampled)
	var joints = {}; var rotations = {}
	for bone in project.data.rig.names:
		var index: int = visual.bone_ids[bone]
		joints[bone] = visual.desired[index].origin
		rotations[bone] = visual.desired[index].basis*visual.rest[index].basis.inverse()
	var original = authored(project,pose)
	var changes = {}
	for bone in original.joints:
		var distance: float = original.joints[bone].distance_to(joints[bone])
		var angle: float = original.rotations[bone].get_rotation_quaternion().angle_to(rotations[bone].get_rotation_quaternion())
		changes[bone] = {"position_m":distance,"rotation_rad":angle}
	return {"joints":joints,"rotations":rotations,"changes":changes,"fitting":visual.animation.full_motion.diagnostics.duplicate(true)}

static func authored(project, pose: Dictionary) -> Dictionary:
	var result = project.fk(pose)
	var rest = preload("res://scripts/core/rider_body.gd").REST
	var height: float = preload("res://scripts/presentation/skier_equipment.gd").SOLE_ABOVE_SUPPORT+(rest.RightFoot.y+rest.LeftFoot.y)*.5
	for bone in result.joints: result.joints[bone] += Vector3.UP*height
	return result
