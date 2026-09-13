extends RefCounted
## Read completed production transforms; playback uses the existing final writer.
const Writer = preload("res://scripts/presentation/skier_pose_writer.gd")
const GhostPose = preload("res://scripts/presentation/ghost_pose.gd")
const MODEL = "res://assets/graphics/models/skier_v7.glb"

static func rig(visual) -> Dictionary:
	var names: Array = []; var parents: Array = []
	for i in visual.skeleton.get_bone_count():
		names.append(visual.skeleton.get_bone_name(i)); parents.append(visual.skeleton.get_bone_parent(i))
	return {"names":names,"parents":parents,"asset_sha256":FileAccess.get_sha256(MODEL)}

static func compatible(recorded: Dictionary, visual) -> bool:
	var current = rig(visual)
	if recorded.get("asset_sha256")!=current.asset_sha256 or recorded.get("names")!=current.names or not recorded.get("parents") is Array or recorded.parents.size()!=current.parents.size(): return false
	for i in current.parents.size():
		if int(recorded.parents[i])!=current.parents[i]: return false
	return true

static func capture(visual) -> PackedFloat32Array:
	var data = PackedFloat32Array()
	GhostPose.append_transform(data,visual.global_transform)
	GhostPose.append_transform(data,visual.skeleton.global_transform)
	var globals: Array[Transform3D] = []
	var ragdoll = visual.ragdoll
	for i in visual.skeleton.get_bone_count():
		var name_value: String = visual.skeleton.get_bone_name(i)
		var pose: Transform3D = visual.skeleton.get_bone_global_pose(i)
		if ragdoll and ragdoll.running:
			if ragdoll.bodies.has(name_value):
				pose = visual.skeleton.global_transform.affine_inverse()*ragdoll.bone_world(name_value)
			else:
				var parent: int = visual.skeleton.get_bone_parent(i)
				if parent>=0:
					var old_parent: Transform3D = visual.skeleton.get_bone_global_pose(parent)
					pose = globals[parent]*old_parent.affine_inverse()*pose
		globals.append(pose); GhostPose.append_transform(data,pose)
	for node in visual.skis: GhostPose.append_transform(data,node.global_transform)
	for node in visual.poles: GhostPose.append_transform(data,node.global_transform)
	return data

static func apply(visual, data: PackedFloat32Array) -> void:
	visual.global_transform = GhostPose.transform_at(data,0)
	visual.skeleton.global_transform = GhostPose.transform_at(data,1)
	visual.targets.clear()
	var count: int = visual.skeleton.get_bone_count()
	for i in count: visual.targets[i] = GhostPose.transform_at(data,i+2)
	Writer.apply(visual.skeleton,visual.rest,visual.desired,visual.targets)
	for i in 2:
		visual.skis[i].global_transform = GhostPose.transform_at(data,count+2+i)
		visual.poles[i].global_transform = GhostPose.transform_at(data,count+4+i)
	visual.body_pivot.visible = true

static func camera_capture(camera: Camera3D) -> PackedFloat64Array:
	var pose = camera.global_transform
	return PackedFloat64Array([pose.origin.x,pose.origin.y,pose.origin.z,pose.basis.x.x,pose.basis.x.y,pose.basis.x.z,pose.basis.y.x,pose.basis.y.y,pose.basis.y.z,pose.basis.z.x,pose.basis.z.y,pose.basis.z.z,camera.fov])

static func camera_apply(camera: Camera3D, data: PackedFloat64Array) -> void:
	camera.global_transform = Transform3D(Basis(Vector3(data[3],data[4],data[5]),Vector3(data[6],data[7],data[8]),Vector3(data[9],data[10],data[11])),Vector3(data[0],data[1],data[2]))
	camera.fov = data[12]
