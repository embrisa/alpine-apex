extends RefCounted
## Shared final writer. Targets are model-space transforms including bind axes.
static func apply(skeleton: Skeleton3D, rest: Array[Transform3D], desired: Array[Transform3D], targets: Dictionary) -> void:
	for i in range(skeleton.get_bone_count()):
		var parent = skeleton.get_bone_parent(i)
		desired[i] = targets[i] if targets.has(i) else (desired[parent]*skeleton.get_bone_rest(i) if parent>=0 else rest[i])
		var local = desired[parent].affine_inverse()*desired[i] if parent>=0 else desired[i]
		skeleton.set_bone_pose_position(i,local.origin)
		skeleton.set_bone_pose_rotation(i,local.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(i,Vector3.ONE)
