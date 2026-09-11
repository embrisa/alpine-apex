extends Node3D
const AudioContactBone = preload("res://scripts/presentation/audio_contact_bone.gd")
## Crash-only Jolt skeleton. Normal skiing remains in the deterministic solver.
const LINKS = [
 ["Hips","Spine02",12.0,.12,35.0,18.0],
 ["Spine02","Spine",25.6,.15,35.0,18.0],
 ["Head","head_end",6.4,.115,40.0,30.0],
 ["RightArm","RightForeArm",2.4,.065,85.0,45.0],
 ["LeftArm","LeftForeArm",2.4,.065,85.0,45.0],
 ["RightForeArm","RightHand",2.0,.052,65.0,12.0],
 ["LeftForeArm","LeftHand",2.0,.052,65.0,12.0],
 ["RightHand","",.4,.045,30.0,20.0],
 ["LeftHand","",.4,.045,30.0,20.0],
 ["RightUpLeg","RightLeg",8.4,.085,65.0,20.0],
 ["LeftUpLeg","LeftLeg",8.4,.085,65.0,20.0],
 ["RightLeg","RightFoot",3.6,.065,65.0,8.0],
 ["LeftLeg","LeftFoot",3.6,.065,65.0,8.0],
 ["RightFoot","RightToeBase",1.2,.065,25.0,10.0],
 ["LeftFoot","LeftToeBase",1.2,.065,25.0,10.0]]
var visual
var simulator: PhysicalBoneSimulator3D
var bodies: Dictionary = {}
var running = false
var elapsed = 0.0
var equipment_offsets: Array[Transform3D] = []
var saved_close_view = false
var frozen = false
var saved_velocities: Dictionary = {}

func build(skier) -> void:
	visual = skier
	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "CrashPhysics"
	visual.skeleton.add_child(simulator)
	for link in LINKS:
		var id: String = link[0]
		var bone_id: int = visual.bone_ids[id]
		var rest: Transform3D = visual.rest[bone_id]
		var end: Vector3 = visual._origin(link[1]) if not link[1].is_empty() else rest.origin+Vector3(.07 if id.begins_with("Left") else -.07,0,0)
		var length_value = maxf(rest.origin.distance_to(end),link[3]*2.0)
		var shape_basis = Basis(Quaternion(Vector3.UP,(end-rest.origin).normalized()))
		var body = AudioContactBone.new()
		body.name = "Physical"+id
		simulator.add_child(body)
		body.bone_name = id
		body.body_offset = rest.affine_inverse()*Transform3D(shape_basis,rest.origin.lerp(end,.5))
		body.mass = link[2]
		body.friction = .38
		body.bounce = .02
		body.linear_damp = .06
		body.angular_damp = .8
		body.collision_layer = 16
		body.collision_mask = 8
		body.can_sleep = true
		body.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		# Cone's twist axis is X; align it with the capsule/limb's Y axis.
		body.joint_offset = Transform3D(Basis(Vector3.BACK,PI*.5),Vector3(0,-rest.origin.distance_to(end)*.5,0))
		var collider = CollisionShape3D.new()
		var capsule = CapsuleShape3D.new()
		capsule.radius = link[3]
		capsule.height = maxf(length_value,link[3]*2.0+.001)
		collider.shape = capsule
		body.add_child(collider)
		PhysicsServer3D.body_set_enable_continuous_collision_detection(body.get_rid(),true)
		PhysicsServer3D.body_set_max_contacts_reported(body.get_rid(),AudioContactBone.CAPACITY)
		bodies[id] = body
	# Internal skeleton collisions are excluded; limbs cannot explode from the
	# unavoidable overlap at joint capsules. Terrain/obstacle collision remains.
	simulator.physical_bones_stop_simulation()
	set_physics_process(false)

func start(sim) -> void:
	if running: return
	for bone in bodies.values(): bone.clear_audio_contacts()
	visual.pose(sim)
	visual.skeleton.force_update_all_bone_transforms()
	equipment_offsets.clear()
	for i in range(2):
		var prefix = "Right" if i==0 else "Left"
		var foot = visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(visual.bone_ids[prefix+"Foot"])
		var hand = visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(visual.bone_ids[prefix+"Hand"])
		equipment_offsets.append(foot.affine_inverse()*visual.skis[i].global_transform)
		equipment_offsets.append(hand.affine_inverse()*visual.poles[i].global_transform)
		# Skis stay in their bindings and contribute a collision footprint.
		var body: PhysicalBone3D = bodies[prefix+"Foot"]
		var ski_collision = CollisionShape3D.new()
		ski_collision.name = "SkiCollision"
		var box = BoxShape3D.new()
		box.size = Vector3(sim.tuning.ski_width,.055,sim.tuning.ski_length)
		ski_collision.shape = box
		body.add_child(ski_collision)
		ski_collision.transform = body.body_offset.affine_inverse()*equipment_offsets[i*2]
	running = true
	frozen = false
	elapsed = 0.0
	visual.body_pivot.visible = true
	simulator.physical_bones_start_simulation()
	# Seed every body from the last solved pose, then construct constraints.
	# Updating offsets alone does not rebuild a PhysicalBone's Jolt joint.
	for link in LINKS:
		var id: String = link[0]
		bodies[id].mass = link[2]*sim.tuning.rider_mass/80.0
		bodies[id].global_transform = visual.skeleton.global_transform*visual.desired[visual.bone_ids[id]]*bodies[id].body_offset
	for link in LINKS: _configure_joint(link)
	# Angular velocities belong to the physical handling frame, even when the
	# composed skeleton faces backward. Facing must not reverse world momentum.
	var omega: Vector3 = sim.body.pose_frame.basis*Vector3(sim.body.pitch_velocity,0,sim.body.roll_velocity)
	if sim.get("air_control")!=null: omega += sim.air_control.angular_velocity
	var center = Vector3.ZERO
	var total_mass = 0.0
	for id in bodies:
		center += bodies[id].global_position*bodies[id].mass
		total_mass += bodies[id].mass
	center /= total_mass
	for id in bodies:
		var body: PhysicalBone3D = bodies[id]
		# Rotation about the hips added net translation to the whole ragdoll.
		# Seed about its mass centre so banking preserves incoming momentum.
		body.linear_velocity = sim.velocity+omega.cross(body.global_position-center)
		body.angular_velocity = omega
	set_physics_process(true)

func _physics_process(dt: float) -> void:
	if not running or frozen: return
	elapsed += dt
	if elapsed>15.0: set_frozen(true)

func focus() -> Vector3:
	return bodies.Hips.global_position if running else visual.global_position+Vector3.UP

func update_equipment() -> void:
	if not running: return
	for i in range(2):
		var prefix = "Right" if i==0 else "Left"
		visual.skis[i].global_transform = bone_world(prefix+"Foot")*equipment_offsets[i*2]
		visual.poles[i].global_transform = bone_world(prefix+"Hand")*equipment_offsets[i*2+1]

func set_frozen(value: bool) -> void:
	if not running or frozen==value: return
	for bone in bodies.values(): bone.clear_audio_contacts()
	frozen = value
	for id in bodies:
		var body: PhysicalBone3D = bodies[id]
		if frozen:
			saved_velocities[id] = [body.linear_velocity,body.angular_velocity]
			PhysicsServer3D.body_set_mode(body.get_rid(),PhysicsServer3D.BODY_MODE_STATIC)
		else:
			PhysicsServer3D.body_set_mode(body.get_rid(),PhysicsServer3D.BODY_MODE_RIGID)
			body.linear_velocity = saved_velocities[id][0]
			body.angular_velocity = saved_velocities[id][1]

func stop() -> void:
	if frozen: set_frozen(false)
	for bone in bodies.values(): bone.clear_audio_contacts()
	for id in bodies: bodies[id].joint_type = PhysicalBone3D.JOINT_TYPE_NONE
	simulator.physical_bones_stop_simulation()
	running = false
	elapsed = 0.0
	for id in ["RightFoot","LeftFoot"]:
		var shape = bodies[id].get_node_or_null("SkiCollision")
		if shape: bodies[id].remove_child(shape); shape.queue_free()
	equipment_offsets.clear()
	set_physics_process(false)

func bone_world(id: String) -> Transform3D:
	# SkeletonModifier restores the input pose after rendering. Read the actual
	# physical body transform here, not that restored procedural bone pose.
	return bodies[id].global_transform*bodies[id].body_offset.affine_inverse()

func _configure_joint(link: Array) -> void:
	var id: String = link[0]
	if id=="Hips": return
	var body: PhysicalBone3D = bodies[id]
	body.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
	var prefix = "Right" if id.begins_with("Right") else "Left"
	if id.ends_with("Foot"):
		# The rigid boot/binding stays with the foot. Its cuff permits forward
		# flexion, not the free side swing/twist of an ordinary ankle cone.
		var boot = bone_world(id).basis*visual.rest[visual.bone_ids[id]].basis.inverse()
		var shin = (bone_world(prefix+"Leg").origin-bone_world(id).origin).normalized()
		var flex = rad_to_deg(atan2(shin.dot(boot.z),shin.dot(boot.y)))
		var local_axis = body.global_basis.transposed()*boot.x
		var solved_transform = body.global_transform
		body.joint_rotation = Basis(Quaternion(Vector3.BACK,local_axis)).get_euler()
		body.global_transform = solved_transform
		body.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		body.set("joint_constraints/angular_limit_enabled",true)
		body.set("joint_constraints/angular_limit_lower",-flex)
		body.set("joint_constraints/angular_limit_upper",24.0-flex)
	elif id.ends_with("Leg") and not id.ends_with("UpLeg") or id.ends_with("ForeArm"):
		var upper = prefix+("UpLeg" if id.ends_with("Leg") else "Arm")
		var lower = prefix+("Foot" if id.ends_with("Leg") else "Hand")
		var a = (bone_world(id).origin-bone_world(upper).origin).normalized()
		var b = (bone_world(lower).origin-bone_world(id).origin).normalized()
		var hinge_axis = a.cross(b).normalized()
		if hinge_axis.length_squared()<.1: hinge_axis = visual.basis.x
		var local_axis = body.global_basis.transposed()*hinge_axis
		var solved_transform = body.global_transform
		body.joint_rotation = Basis(Quaternion(Vector3.BACK,local_axis)).get_euler()
		body.global_transform = solved_transform
		body.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		var bend = rad_to_deg(a.angle_to(b))
		body.set("joint_constraints/angular_limit_enabled",true)
		body.set("joint_constraints/angular_limit_lower",-bend)
		body.set("joint_constraints/angular_limit_upper",140.0-bend)
	else:
		body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		body.set("joint_constraints/swing_span",link[4])
		body.set("joint_constraints/twist_span",link[5])
