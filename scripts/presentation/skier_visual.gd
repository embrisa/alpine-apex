extends Node3D
## A skinned character driven only by the existing simulation. No root motion.
var body_pivot = Node3D.new()
var skis: Array[MeshInstance3D] = []
var poles: Array[MeshInstance3D] = []
var skeleton: Skeleton3D
var character: Node3D
var assets
var lighting = preload("res://scripts/presentation/cloud_lighting.gd").new()
var rest: Array[Transform3D] = []
var desired: Array[Transform3D] = []
var bone_ids: Dictionary = {}
var targets: Dictionary = {}
var probes: Dictionary = {}
var jacket_material: ShaderMaterial
var ragdoll
var appearance

func _ready() -> void:
	if assets==null:
		assets = preload("res://scripts/presentation/alpine_assets.gd").new(lighting,preload("res://scripts/presentation/graphics_quality.gd").preset(1))
	add_child(body_pivot)
	character = preload("res://assets/graphics/models/skier_v7.glb").instantiate()
	body_pivot.add_child(character)
	skeleton = _find_skeleton(character)
	assert(skeleton!=null,"Skier GLB must contain its verified skeleton")
	assets.convert_node(character)
	jacket_material = assets.named_materials.get("SkierV7Clothing",_find_material(character))
	appearance = preload("res://scripts/presentation/skier_appearance.gd").new()
	appearance.bind(assets)
	for i in range(skeleton.get_bone_count()):
		bone_ids[skeleton.get_bone_name(i)] = i
		rest.append(skeleton.get_bone_global_rest(i))
		desired.append(rest[i])
	for side in [-1.0,1.0]:
		var ski = _equipment("ski",self)
		ski.position = Vector3(side*.22,.015,.15)
		skis.append(ski)
		var binding = _equipment("binding",ski)
		binding.position = Vector3(0,.018,-.15)
		var boot = _equipment("skier_v7_boot_right" if side<0 else "skier_v7_boot_left",ski)
		boot.position = Vector3(0,.095,-.15)
		poles.append(_equipment("pole",body_pivot))

	_receive_gi_only(self)
	ragdoll = preload("res://scripts/presentation/skier_ragdoll.gd").new()
	add_child(ragdoll)
	ragdoll.build(self)

func _receive_gi_only(node: Node) -> void:
	# SDFGI cannot rebake moving rider/equipment geometry each frame.
	if node is GeometryInstance3D:
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for child in node.get_children():
		_receive_gi_only(child)

func _equipment(id: String, parent: Node3D) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = assets.mesh(id)
	parent.add_child(node)
	return node

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result: return result
	return null

func _find_material(node: Node) -> ShaderMaterial:
	if node is MeshInstance3D:
		return node.get_active_material(0)
	for child in node.get_children():
		var result = _find_material(child)
		if result: return result
	return null

func material_probe() -> ShaderMaterial:
	return jacket_material

func pose_probe(id: String) -> Vector3:
	return to_global(probes.get(id,Vector3.ZERO))

func _origin(id: String) -> Vector3:
	return rest[bone_ids[id]].origin

func _target(id: String, origin_value: Vector3, rotation_value: Basis) -> void:
	targets[bone_ids[id]] = Transform3D(rotation_value*rest[bone_ids[id]].basis,origin_value)

func _aim(id: String, child: String, a: Vector3, b: Vector3) -> Basis:
	var rotation_value = Basis(Quaternion((_origin(child)-_origin(id)).normalized(),(b-a).normalized()))
	_target(id,a,rotation_value)
	return rotation_value

func _aim_leg(id: String, child: String, a: Vector3, b: Vector3, boot: Basis) -> void:
	# Joint positions alone leave axial twist unconstrained. Carry the boot's
	# hinge axis up the shin and thigh so the cuff does not twist the skin.
	var original = _limb_frame((_origin(id)-_origin(child)).normalized(),Vector3.RIGHT)
	var posed = _limb_frame((a-b).normalized(),boot.x)
	_target(id,a,posed*original.transposed())

func _limb_frame(up: Vector3, side: Vector3) -> Basis:
	var right = side.slide(up).normalized()
	return Basis(right,up,right.cross(up).normalized())

func pose(sim, fraction: float = 1.0) -> void:
	if ragdoll and ragdoll.running:
		ragdoll.update_equipment()
		return
	if skeleton==null or not sim.body.initialized: return
	# One explicit timestamp for root, support frame, joints and equipment.
	# Tools/stopped sessions default to the completed tick, not a cycling clock.
	var blend = 1.0 if sim.crashed else clampf(fraction,0.0,1.0)
	global_transform = sim.body.previous_pose_frame.interpolate_with(sim.body.pose_frame,blend)
	var joints: Dictionary = {}
	var rotations: Dictionary = {}
	for id in sim.body.joints:
		joints[id] = sim.body.previous_joints.get(id,sim.body.joints[id]).lerp(sim.body.joints[id],blend)
	for id in sim.body.rotations:
		rotations[id] = sim.body.previous_rotations.get(id,sim.body.rotations[id]).slerp(sim.body.rotations[id],blend)
	for i in range(2):
		var prefix = "Right" if i==0 else "Left"
		var ski = sim.skis[i]
		var ski_basis: Basis = ski.previous_orientation.slerp(ski.orientation,blend)
		var ski_position: Vector3 = ski.previous_position.lerp(ski.position,blend)
		skis[i].global_transform = Transform3D(ski_basis,ski_position+ski_basis*Vector3(0,.015,.15))
		# The rigid boot and the skin share this exact ankle frame even between
		# ticks. Interpolating two independently transformed ankles breaks that
		# constraint as the support plane rotates.
		joints[prefix+"Foot"] = to_local(ski_position+ski_basis.y*(.110+_origin(prefix+"Foot").y))
		rotations[prefix+"Foot"] = global_basis.transposed()*ski_basis
	_solve_render_legs(sim.Body,joints,rotations)
	targets.clear()
	for id in ["Hips","Spine02","Spine01","Spine","neck","Head"]:
		_target(id,joints[id],rotations[id])
	probes.chest = joints.Spine01+rotations.Spine01*Vector3(0,.06,.04)
	probes.head = joints.Head
	for i in range(2):
		var side = -1.0 if i==0 else 1.0
		var prefix = "Right" if i==0 else "Left"
		for pair in [["UpLeg","Leg"],["Leg","Foot"]]:
			_aim_leg(prefix+pair[0],prefix+pair[1],joints[prefix+pair[0]],joints[prefix+pair[1]],rotations[prefix+"Foot"])
		for pair in [["Shoulder","Arm"],["Arm","ForeArm"],["ForeArm","Hand"]]:
			_aim(prefix+pair[0],prefix+pair[1],joints[prefix+pair[0]],joints[prefix+pair[1]])
		_target(prefix+"Foot",joints[prefix+"Foot"],rotations[prefix+"Foot"])
		var hand: Vector3 = joints[prefix+"Hand"]
		var elbow: Vector3 = joints[prefix+"ForeArm"]
		# A palm frame fixes the handle through the closed fingers. Its shaft
		# trails the forearm; the wrist turns instead of letting the grip slide.
		var along = (hand-elbow).normalized()
		var pole_direction = Vector3(side*.08,-.65+sim.effective_tuck*.20,-.75-sim.effective_tuck*.18).normalized()
		var wrist_axis = along.slide(pole_direction).normalized()*side
		var grip_rotation = Basis(wrist_axis,(-pole_direction).cross(wrist_axis),-pole_direction)
		# Generated glove's rest frame: X points out along hand; Y is palm normal.
		_target(prefix+"Hand",hand,grip_rotation)
		var grip = hand+grip_rotation*Vector3(side*.070,0,.018)
		poles[i].position = grip
		poles[i].basis = Basis(Quaternion(Vector3.DOWN,(grip_rotation*Vector3(0,0,-1)).normalized()))
		probes[prefix.to_lower()+"_hand"] = grip
		probes[prefix.to_lower()+"_ankle"] = joints[prefix+"Foot"]
		if i==1: probes.jacket = joints.LeftArm.lerp(joints.LeftForeArm,.36)
	for i in range(skeleton.get_bone_count()):
		var parent = skeleton.get_bone_parent(i)
		desired[i] = targets[i] if targets.has(i) else (desired[parent]*skeleton.get_bone_rest(i) if parent>=0 else rest[i])
		var local = desired[parent].affine_inverse()*desired[i] if parent>=0 else desired[i]
		skeleton.set_bone_pose_position(i,local.origin)
		skeleton.set_bone_pose_rotation(i,local.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(i,Vector3.ONE)

func _solve_render_legs(body, joints: Dictionary, rotations: Dictionary) -> void:
	# Interpolation describes an arc between solved poses. Reclose both chains
	# against the rendered bindings without stretching a shin or splitting the
	# pelvis. This correction is visual only; no feedback enters the solver.
	var hips: Vector3 = joints.Hips
	var pelvis: Basis = rotations.Hips
	var ankles: Array[Vector3] = [joints.RightFoot,joints.LeftFoot]
	var boots: Array[Basis] = [rotations.RightFoot,rotations.LeftFoot]
	hips = body.fit_hips(hips,pelvis,ankles,boots)
	var shift: Vector3 = hips-joints.Hips
	for id in joints:
		if not id.ends_with("Foot") and not id.ends_with("ToeBase"):
			joints[id] += shift
	for prefix in ["Right","Left"]:
		var hip = hips+pelvis*(_origin(prefix+"UpLeg")-_origin("Hips"))
		var ankle: Vector3 = joints[prefix+"Foot"]
		var thigh = _origin(prefix+"UpLeg").distance_to(_origin(prefix+"Leg"))
		var shin = _origin(prefix+"Leg").distance_to(_origin(prefix+"Foot"))
		joints[prefix+"UpLeg"] = hip
		joints[prefix+"Leg"] = body.leg_joint(hip,ankle,thigh,shin,rotations[prefix+"Foot"])
