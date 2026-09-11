extends Node3D
## Cheap, non-colliding snapshot silhouette. No solver, contact, audio or tracks.
var enabled: bool = true
var material: StandardMaterial3D
var torso: MeshInstance3D
var head: MeshInstance3D
var limbs: Array[MeshInstance3D] = []
var skis: Array[MeshInstance3D] = []
var last_pose: Dictionary = {}

func _ready() -> void:
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.3,0.93,1.0,0.45)
	material.no_depth_test = false
	var body_mesh = CapsuleMesh.new()
	body_mesh.radius = 0.19
	body_mesh.height = 0.65
	body_mesh.radial_segments = 8
	body_mesh.rings = 2
	torso = _mesh(body_mesh)
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.14
	head_mesh.height = 0.28
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	head = _mesh(head_mesh)
	var limb_mesh = CylinderMesh.new()
	limb_mesh.top_radius = 0.065
	limb_mesh.bottom_radius = 0.065
	limb_mesh.height = 1.0
	limb_mesh.radial_segments = 6
	for i in range(8): limbs.append(_mesh(limb_mesh))
	var ski_mesh = BoxMesh.new()
	ski_mesh.size = Vector3(0.10,0.055,1.90)
	for side in [-1.0,1.0]:
		var ski = _mesh(ski_mesh)
		ski.position = Vector3(side*0.22,0.05,0.12)
		skis.append(ski)
	visible = false

func _mesh(mesh: Mesh) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(instance)
	return instance

func update_ghost(replay, time: float, rider_position: Vector3, show_in_world: bool) -> void:
	visible = false
	if not enabled or not show_in_world or replay==null or time>replay.duration+0.25: return
	var pose: Dictionary = replay.pose_at(time)
	if pose.is_empty(): return
	last_pose = pose
	var distance: float = pose.position.distance_to(rider_position)
	# Avoid covering the real skier or first-person camera on identical lines.
	if distance<1.2 or distance>750.0: return
	visible = true
	material.albedo_color.a = 0.46*smoothstep(1.2,4.0,distance)
	position = pose.position
	basis = pose.basis
	var joints: Dictionary = pose.joints
	var hips: Vector3 = joints.Hips
	var chest: Vector3 = joints.Spine
	torso.position = hips.lerp(chest,.5)
	torso.basis = Basis(Quaternion(Vector3.UP,(chest-hips).normalized()))
	head.position = joints.Head+Vector3(0,.09,0)
	for i in range(2):
		var prefix = "Right" if i==0 else "Left"
		_segment(limbs[i*4],joints[prefix+"UpLeg"],joints[prefix+"Leg"])
		_segment(limbs[i*4+1],joints[prefix+"Leg"],joints[prefix+"Foot"])
		_segment(limbs[i*4+2],joints[prefix+"Arm"],joints[prefix+"ForeArm"])
		_segment(limbs[i*4+3],joints[prefix+"ForeArm"],joints[prefix+"Hand"])
		var ski: Dictionary = pose.skis[i]
		var ski_basis: Basis = ski.basis
		skis[i].global_transform = Transform3D(ski_basis,position+ski.offset+ski_basis*Vector3(0,.015,.15))

func _segment(node: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	node.position = a.lerp(b,0.5)
	node.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized())).scaled_local(Vector3(1,a.distance_to(b),1))
