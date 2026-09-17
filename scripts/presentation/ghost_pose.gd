extends RefCounted
## Completed production pose codec. No simulation or animation state machine.
const BONES = ["Hips","LeftUpLeg","LeftLeg","LeftFoot","LeftToeBase","RightUpLeg","RightLeg","RightFoot","RightToeBase","Spine02","Spine01","Spine","LeftShoulder","LeftArm","LeftForeArm","LeftHand","neck","Head","head_end","headfront","RightShoulder","RightArm","RightForeArm","RightHand"]
const TRANSFORMS = 29 # root, 24 local bones, two skis, two poles
const CONTACT_START = TRANSFORMS*7
const CONTACT_WIDTH = 10 # supported, track eligible, widths/depth/slip/crystal, throw xyz
const WIDTH = CONTACT_START+2*CONTACT_WIDTH+1 # physical ski length
const Response = preload("res://scripts/presentation/snow_response.gd")
const Writer = preload("res://scripts/presentation/skier_pose_writer.gd")

static func capture_completed(visual, sim, field, fraction: float = 1.0, reuse_recent: bool = true) -> PackedFloat32Array:
	# Keep the displayed rider untouched. Only ghost limb motion may lag by up
	# to three fixed ticks; root position follows this exact recording sample.
	var age: float = sim.ticks-visual.pose_tick+1.0-visual.pose_fraction
	var reuse: bool = reuse_recent and fraction==1.0 and not sim.crashed and visual.pose_tick>=0 and age>=0.0 and age<=3.0 and visual.pose_grounded==sim.grounded and visual.pose_backward==sim.facing_backward
	if not reuse: visual.pose(sim,fraction)
	return capture(visual,sim,field,reuse)

static func capture(visual, sim, field, rebase_root: bool = false) -> PackedFloat32Array:
	var data = PackedFloat32Array()
	var source_root: Transform3D = visual.global_transform
	var recorded_root: Transform3D = sim.facing_pose.previous_frame.interpolate_with(sim.facing_pose.frame,1.0) if rebase_root else source_root
	var inverse_root = source_root.affine_inverse()
	append_transform(data,recorded_root)
	for name_value in BONES:
		var index: int = visual.skeleton.find_bone(name_value)
		if index<0: return PackedFloat32Array()
		append_transform(data,visual.skeleton.get_bone_pose(index))
	for node in visual.skis: append_transform(data,inverse_root*node.global_transform)
	for node in visual.poles: append_transform(data,inverse_root*node.global_transform)
	for i in 2:
		var response = Response.new()
		response.sample(sim,sim.skis[1-i if sim.facing_backward else i],field)
		var equipment: Transform3D = visual.skis[i].global_transform
		if rebase_root: equipment = recorded_root*(inverse_root*equipment)
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
	var frames = _prepared_pair(visual,a,b)
	var first: Dictionary = frames[0]
	var second: Dictionary = frames[1]
	visual.global_transform = first.root.interpolate_with(second.root,weight)
	visual.targets.clear()
	# Interpolate local rotations/positions hierarchically; a global blend would
	# shrink long limbs. The production writer remains the sole skeleton writer.
	for slot in BONES.size():
		var name_value: String = BONES[slot]
		var index: int = visual.bone_ids[name_value]
		var local: Transform3D = first.local[slot].interpolate_with(second.local[slot],weight)
		var parent: int = visual.skeleton.get_bone_parent(index)
		visual.targets[index] = visual.targets[parent]*local if parent>=0 else local
	Writer.apply(visual.skeleton,visual.rest,visual.desired,visual.targets)
	for i in 2:
		var prefix = "Right" if i==0 else "Left"
		var foot_id: int = visual.bone_ids[prefix+"Foot"]
		var hand_id: int = visual.bone_ids[prefix+"Hand"]
		var ski_socket: Transform3D = first.skis[i].interpolate_with(second.skis[i],weight)
		var pole_socket: Transform3D = first.poles[i].interpolate_with(second.poles[i],weight)
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

static func _prepared_pair(visual, a: PackedFloat32Array, b: PackedFloat32Array) -> Array:
	# Each visual retains only its two current immutable recording frames. Root
	# and limb interpolation still runs every render frame; socket derivation and
	# packed quaternion decoding run once per new recording sample instead.
	var prior: Array = visual.get_meta(&"ghost_pose_frames",[])
	if prior.size()==2 and prior[0].data==a and prior[1].data==b: return prior
	var frames: Array = []
	for data in [a,b]:
		var prepared: Dictionary = {}
		for item in prior+frames:
			if item.data==data: prepared=item; break
		if prepared.is_empty(): prepared=_prepare_frame(visual,data)
		frames.append(prepared)
	visual.set_meta(&"ghost_pose_frames",frames)
	return frames

static func _prepare_frame(visual, data: PackedFloat32Array) -> Dictionary:
	var frame = {"data":data,"root":transform_at(data,0),"local":[],"skis":[],"poles":[]}
	for slot in BONES.size(): frame.local.append(transform_at(data,slot+1))
	for i in 2:
		var prefix = "Right" if i==0 else "Left"
		frame.skis.append(bone_global(data,visual,visual.bone_ids[prefix+"Foot"]).affine_inverse()*transform_at(data,25+i))
		frame.poles.append(bone_global(data,visual,visual.bone_ids[prefix+"Hand"]).affine_inverse()*transform_at(data,27+i))
	return frame

static func bone_global(data: PackedFloat32Array, visual, index: int) -> Transform3D:
	var local = transform_at(data,BONES.find(visual.skeleton.get_bone_name(index))+1)
	var parent: int = visual.skeleton.get_bone_parent(index)
	return bone_global(data,visual,parent)*local if parent>=0 else local
