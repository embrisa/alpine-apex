extends RefCounted
## Completed production pose codec. No simulation or animation state machine.
const BONES = ["Hips","LeftUpLeg","LeftLeg","LeftFoot","LeftToeBase","RightUpLeg","RightLeg","RightFoot","RightToeBase","Spine02","Spine01","Spine","LeftShoulder","LeftArm","LeftForeArm","LeftHand","neck","Head","head_end","headfront","RightShoulder","RightArm","RightForeArm","RightHand"]
const TRANSFORMS = 29 # root, 24 local bones, two skis, two poles
const CONTACT_START = TRANSFORMS*7
const CONTACT_WIDTH = 10 # supported, track eligible, widths/depth/slip/crystal, throw xyz
const WIDTH = CONTACT_START+2*CONTACT_WIDTH+1 # physical ski length
const Response = preload("res://scripts/presentation/snow_response.gd")
const Writer = preload("res://scripts/presentation/skier_pose_writer.gd")

static func capture(visual, sim, field) -> PackedFloat32Array:
	var data = PackedFloat32Array()
	append_transform(data,visual.global_transform)
	for name_value in BONES:
		var index: int = visual.skeleton.find_bone(name_value)
		if index<0: return PackedFloat32Array()
		append_transform(data,visual.skeleton.get_bone_pose(index))
	for node in visual.skis: append_transform(data,visual.global_transform.affine_inverse()*node.global_transform)
	for node in visual.poles: append_transform(data,visual.global_transform.affine_inverse()*node.global_transform)
	for i in 2:
		var response = Response.new()
		response.sample(sim,sim.skis[1-i if sim.facing_backward else i],field)
		var equipment: Transform3D = visual.skis[i].global_transform
		response.contact_position = equipment.origin
		response.contact_forward = equipment.basis.z.normalized()
		# New carving owner may refine the accepted final footprint. Its recorded
		# result is authoritative for replay emission; never use live-rider load.
		response.resolve_track_contact(sim,sim.skis[1-i if sim.facing_backward else i],field)
		var contact: bool = response.track_contact
		var depth: float = response.track_depth_m
		data.append_array(PackedFloat32Array([float(response.supported),float(contact),response.width_m,response.contact_width_m,depth,response.slip,response.crystal_density,response.throw_world.x,response.throw_world.y,response.throw_world.z]))
	data.append(sim.tuning.ski_length)
	return data

static func append_transform(data: PackedFloat32Array, value: Transform3D) -> void:
	var q = value.basis.orthonormalized().get_rotation_quaternion().normalized()
	data.append_array(PackedFloat32Array([value.origin.x,value.origin.y,value.origin.z,q.x,q.y,q.z,q.w]))

static func transform_at(data: PackedFloat32Array, index: int) -> Transform3D:
	var start = index*7
	return Transform3D(Basis(Quaternion(data[start+3],data[start+4],data[start+5],data[start+6]).normalized()),Vector3(data[start],data[start+1],data[start+2]))

static func validate(data: PackedFloat32Array) -> bool:
	if data.size()!=WIDTH: return false
	for value in data:
		if not is_finite(value) or absf(value)>10000.0: return false
	for i in TRANSFORMS:
		var start = i*7
		var q = Quaternion(data[start+3],data[start+4],data[start+5],data[start+6])
		if absf(q.length_squared()-1.0)>.01: return false
		if i>0 and Vector3(data[start],data[start+1],data[start+2]).length()>8.0: return false
	for i in 2:
		var start = CONTACT_START+i*CONTACT_WIDTH
		if data[start] not in [0.0,1.0] or data[start+1] not in [0.0,1.0]: return false
		for offset in [2,3]:
			if data[start+offset]<.01 or data[start+offset]>4.0: return false
		if data[start+4]<0 or data[start+4]>1.0 or data[start+5]<0 or data[start+5]>1: return false
		if data[start+6]<0 or data[start+6]>4: return false
		if Vector3(data[start+7],data[start+8],data[start+9]).length()>1.1: return false
	return data[-1]>=.5 and data[-1]<=3.0

static func apply(visual, a: PackedFloat32Array, b: PackedFloat32Array, weight: float, responses: Array) -> void:
	visual.global_transform = transform_at(a,0).interpolate_with(transform_at(b,0),weight)
	visual.targets.clear()
	# Interpolate local rotations/positions hierarchically; a global blend would
	# shrink long limbs. The production writer remains the sole skeleton writer.
	for name_value in BONES:
		var index: int = visual.bone_ids[name_value]
		var slot = BONES.find(name_value)+1
		var local = transform_at(a,slot).interpolate_with(transform_at(b,slot),weight)
		var parent: int = visual.skeleton.get_bone_parent(index)
		visual.targets[index] = visual.targets[parent]*local if parent>=0 else local
	Writer.apply(visual.skeleton,visual.rest,visual.desired,visual.targets)
	for i in 2:
		var prefix = "Right" if i==0 else "Left"
		var foot_id: int = visual.bone_ids[prefix+"Foot"]
		var hand_id: int = visual.bone_ids[prefix+"Hand"]
		var foot_a = bone_global(a,visual,foot_id)
		var foot_b = bone_global(b,visual,foot_id)
		var hand_a = bone_global(a,visual,hand_id)
		var hand_b = bone_global(b,visual,hand_id)
		var ski_socket = (foot_a.affine_inverse()*transform_at(a,25+i)).interpolate_with(foot_b.affine_inverse()*transform_at(b,25+i),weight)
		var pole_socket = (hand_a.affine_inverse()*transform_at(a,27+i)).interpolate_with(hand_b.affine_inverse()*transform_at(b,27+i),weight)
		visual.skis[i].global_transform = visual.global_transform*visual.desired[foot_id]*ski_socket
		visual.poles[i].global_transform = visual.global_transform*visual.desired[hand_id]*pole_socket
		var start = CONTACT_START+i*CONTACT_WIDTH
		var response = responses[i]
		# Discrete support is left-continuous. Conservative interval gating avoids
		# projecting an airborne ski onto snow during takeoff/landing interpolation.
		response.supported = a[start]>.5 and (weight==0 or b[start]>.5)
		response.snow_contact = a[start+1]>.5 and (weight==0 or b[start+1]>.5)
		for pair in [["width_m",2],["contact_width_m",3],["depth_m",4],["slip",5],["crystal_density",6]]:
			response.set(pair[0],lerpf(a[start+pair[1]],b[start+pair[1]],weight))
		response.throw_world = Vector3(a[start+7],a[start+8],a[start+9]).lerp(Vector3(b[start+7],b[start+8],b[start+9]),weight)
		response.contact_position = visual.skis[i].global_position
		response.contact_forward = visual.skis[i].global_basis.z.normalized()
		response.track_contact = response.snow_contact
		response.track_depth_m = response.depth_m

static func bone_global(data: PackedFloat32Array, visual, index: int) -> Transform3D:
	var local = transform_at(data,BONES.find(visual.skeleton.get_bone_name(index))+1)
	var parent: int = visual.skeleton.get_bone_parent(index)
	return bone_global(data,visual,parent)*local if parent>=0 else local
