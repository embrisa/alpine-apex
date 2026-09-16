extends Node3D
## A skinned character driven only by the existing simulation. No root motion.
const Anatomy = preload("res://scripts/presentation/skier_anatomy.gd")
const PoseWriter = preload("res://scripts/presentation/skier_pose_writer.gd")
const Equipment = preload("res://scripts/presentation/skier_equipment.gd")
var preview_only = false
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
var snow_burial_enabled = false
var animation = preload("res://scripts/presentation/skier_animation.gd").new()
var animation_enabled = true
var rendered_joints: Dictionary = {}
var rendered_rotations: Dictionary = {}
var motion_comparison: CheckButton
var pose_microseconds = 0
var leg_fit_microseconds = 0

func reset_animation(sim) -> void:
	animation.reset(sim)

func step_animation(dt: float, sim, intent, surface) -> void:
	animation.step(dt,sim,intent,surface)

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
		var ski = _equipment("ski_detailed_v1" if side<0 else "ski_detailed_v1_left",self)
		ski.position = Vector3(side*.22,.015,.15)
		skis.append(ski)
		var binding = _equipment(Equipment.BINDING_MESH,ski)
		binding.position = Equipment.BINDING_ORIGIN
		var boot = _equipment("skier_v7_boot_right" if side<0 else "skier_v7_boot_left",ski)
		boot.position = Equipment.BOOT_ORIGIN
		poles.append(_equipment("pole_detailed_v1",body_pivot))

	_receive_gi_only(self)
	if not preview_only:
		ragdoll = preload("res://scripts/presentation/skier_ragdoll.gd").new()
		add_child(ragdoll)
		ragdoll.build(self)
		call_deferred("_install_motion_comparison")
	else:
		set_process_unhandled_input(false)

func _install_motion_comparison() -> void:
	# The character owns this presentation preference, including comparison in
	# the live game. Test/standalone characters need no game HUD dependency.
	var parent = get_parent()
	if parent==null or parent.get("hud")==null: return
	var hud = parent.get("hud")
	if hud.motion_toggle==null: return
	motion_comparison = CheckButton.new()
	motion_comparison.name = "FullSkierMotion"
	motion_comparison.text = "Full skier motion (F8 compares procedural animation)"
	motion_comparison.button_pressed = animation.full_motion.enabled
	motion_comparison.toggled.connect(func(value): animation.full_motion.enabled = value)
	hud.motion_toggle.get_parent().add_child(motion_comparison)
	var grab_choice = OptionButton.new()
	grab_choice.name = "SkierGrabStyle"
	grab_choice.add_item("Grab style: Safety")
	grab_choice.add_item("Grab style: Mute")
	grab_choice.item_selected.connect(func(index): animation.full_motion.grab_style = "safety" if index==0 else "mute")
	hud.motion_toggle.get_parent().add_child(grab_choice)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F8:
		animation.full_motion.enabled = not animation.full_motion.enabled
		if motion_comparison: motion_comparison.set_pressed_no_signal(animation.full_motion.enabled)
		var parent = get_parent()
		if parent and parent.get("hud"):
			parent.hud.toast("FULL SKIER MOTION" if animation.full_motion.enabled else "PROCEDURAL SKIER MOTION")
		get_viewport().set_input_as_handled()

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

func pose(sim, fraction: float = 1.0, preview: Dictionary = {}) -> void:
	pose_microseconds = 0; leg_fit_microseconds = 0
	var pose_start = Time.get_ticks_usec()
	if ragdoll and ragdoll.running:
		ragdoll.update_equipment()
		return
	if skeleton==null or not sim.body.initialized: return
	# One explicit timestamp for root, support frame, joints and equipment.
	# Tools/stopped sessions default to the completed tick, not a cycling clock.
	var blend = 1.0 if sim.crashed else clampf(fraction,0.0,1.0)
	var facing = sim.facing_pose
	global_transform = facing.previous_frame.interpolate_with(facing.frame,blend)
	var joints: Dictionary = {}
	var rotations: Dictionary = {}
	for id in facing.joints:
		joints[id] = facing.previous_joints.get(id,facing.joints[id]).lerp(facing.joints[id],blend)
	for id in facing.rotations:
		rotations[id] = facing.previous_rotations.get(id,facing.rotations[id]).slerp(facing.rotations[id],blend)
	# Removing the spacer lowers the entire visible rider equally. Keep the
	# physical COM, contact solution and replay untouched, and reclose each leg
	# against its actual rendered cuff below (including independent ski edges).
	var support_up: Vector3 = (facing.previous_orientations[0].slerp(facing.orientations[0],blend).y+facing.previous_orientations[1].slerp(facing.orientations[1],blend).y).normalized()
	var lowering = global_basis.transposed()*support_up*Equipment.BODY_LOWERING
	for id in joints: joints[id] -= lowering
	for i in range(2):
		var prefix = "Right" if i==0 else "Left"
		var ski = sim.skis[1-i if sim.facing_backward else i]
		var ski_basis: Basis = facing.previous_orientations[i].slerp(facing.orientations[i],blend)
		var ski_position: Vector3 = facing.previous_positions[i].lerp(facing.positions[i],blend)
		# Keep only a shallow cosmetic bite: the loose surface already surrounds
		# the skis. Physical depth must not hide the equipment below that surface.
		# Binding/ankle share one frame; render IK closes the legs independently.
		if snow_burial_enabled and ski.grounded and not sim.crashed:
			# Physical yield already supplies burial. Subtract only the cosmetic
			# remainder, so entering/leaving a bank cannot double it or pop 2 cm.
			ski_position.y -= maxf(0.0,clampf(ski.penetration*.15,0.0,.02)-ski.crush_vertical_m)
		skis[i].global_transform = Transform3D(ski_basis,ski_position+ski_basis*Vector3(0,.015,.15))
		# The rigid boot and the skin share this exact ankle frame even between
		# ticks. Interpolating two independently transformed ankles breaks that
		# constraint as the support plane rotates.
		# Use the actual boot child in rider-local coordinates. Reconstructing
		# its ankle separately in world space adds rounding gaps at altitude.
		joints[prefix+"Foot"] = skis[i].transform*skis[i].get_child(1).transform*Vector3(0,_origin(prefix+"Foot").y,0)
		rotations[prefix+"Foot"] = global_basis.transposed()*ski_basis
	var motion: Dictionary = animation.sample(blend) if animation_enabled else {}
	if sim.facing_backward and not motion.is_empty():
		for key in ["steer","carve","impact_side","recoil_x","recoil_z"]:
			if motion.has(key): motion[key] = -motion[key]
	var base_joints = joints.duplicate()
	var base_rotations = rotations.duplicate()
	var skeletal = animation.full_motion.sample(blend) if animation_enabled else {}
	if not preview.is_empty():
		skeletal = preview.duplicate(true)
	var retention_full = 1.0
	var support_alignment = animation.full_motion.upright_support(global_basis)
	for attempt in range(4):
		var procedural_started = animation.full_motion.frame_costs.begin()
		animation.compose(sim.Body,joints,rotations,motion)
		# The full source replaces limb rotations at weight one. Partial F8 and
		# clearance blends still need the procedural side of that handover.
		if skeletal.get("amount",0.0)*retention_full!=1.0:
			_procedural_limb_rotations(joints,rotations,motion,sim.effective_tuck)
		animation.full_motion.frame_costs.end(&"pose_procedural",procedural_started)
		animation.full_motion.compose(sim.Body,joints,rotations,skeletal,motion,retention_full,base_joints.Hips,support_alignment)
		var leg_start = Time.get_ticks_usec()
		_solve_render_legs(sim.Body,joints,rotations,skeletal.get("amount",0.0)*retention_full)
		leg_fit_microseconds += Time.get_ticks_usec()-leg_start
		if motion.is_empty() or not sim.grounded or not animation.has_method("clearance_margin"): break
		var margin: float = animation.clearance_margin(joints,global_transform)
		if margin>=0.0 or attempt==3: break
		# Reduce overlapping expression inside the anatomical envelope, then
		# close limbs again. Never lift the skis or stretch a leg to gain height.
		var retention: float = clampf(1.0+margin/.12,0.0,.75)
		retention_full *= retention
		for key in ["tuck","prepare","impact_drop","impact","carve","recoil","recoil_x","recoil_z"]:
			if motion.has(key): motion[key] *= retention
		motion.spine_flex *= retention
		joints = base_joints.duplicate()
		rotations = base_rotations.duplicate()
	var pole_fit_start = Time.get_ticks_usec()
	var pole_fit = animation.full_motion.PolePose.fit_tips(joints,rotations,global_transform,skeletal.get("pole_targets",skeletal.get("pole_anchors",[])),skeletal.get("pole_target_normals",skeletal.get("pole_normals",[])),skeletal.get("pole_plant",0.0),skeletal.get("pole_phase",0.0),skeletal.get("pole_carry",0.0))
	animation.full_motion.diagnostics.merge(pole_fit,true)
	animation.full_motion.diagnostics.pole_target_stage = skeletal.get("pole_target_stage","inactive")
	animation.full_motion.diagnostics.pole_contact_cpu_us = Time.get_ticks_usec()-pole_fit_start
	rendered_joints = joints
	rendered_rotations = rotations
	targets.clear()
	var equipment_started = animation.full_motion.frame_costs.begin()
	for id in ["Hips","Spine02","Spine01","Spine","neck","Head"]:
		_target(id,joints[id],rotations[id])
	probes.chest = joints.Spine01+rotations.Spine01*Vector3(0,.06,.04)
	probes.head = joints.Head
	for i in range(2):
		var side = -1.0 if i==0 else 1.0
		var prefix = "Right" if i==0 else "Left"
		Anatomy.fit_hinge(prefix,false,joints,rotations)
		for pair in [["UpLeg","Leg"],["Leg","Foot"]]:
			var id = prefix+pair[0]
			var child = prefix+pair[1]
			rotations[id] = _fitted_rotation(id,child,joints,rotations[id])
			_target(id,joints[id],rotations[id])
		for pair in [["Shoulder","Arm"],["Arm","ForeArm"],["ForeArm","Hand"]]:
			var id = prefix+pair[0]
			var child = prefix+pair[1]
			rotations[id] = _fitted_rotation(id,child,joints,rotations[id])
			_target(id,joints[id],rotations[id])
		_target(prefix+"Foot",joints[prefix+"Foot"],rotations[prefix+"Foot"])
		var hand: Vector3 = joints[prefix+"Hand"]
		var elbow: Vector3 = joints[prefix+"ForeArm"]
		# A palm frame fixes the handle through the closed fingers. Its shaft
		# trails the forearm; the wrist turns instead of letting the grip slide.
		var grip_rotation: Basis = rotations[prefix+"Hand"]
		# Generated glove's rest frame: X points out along hand; Y is palm normal.
		_target(prefix+"Hand",hand,grip_rotation)
		var grip = hand+grip_rotation*Vector3(side*.070,0,.018)
		poles[i].position = grip
		poles[i].basis = Basis(Quaternion(Vector3.DOWN,(grip_rotation*Vector3(0,0,-1)).normalized()))
		probes[prefix.to_lower()+"_hand"] = grip
		probes[prefix.to_lower()+"_ankle"] = joints[prefix+"Foot"]
		if i==1: probes.jacket = joints.LeftArm.lerp(joints.LeftForeArm,.36)
	animation.full_motion.frame_costs.end(&"pose_equipment",equipment_started)
	var writer_started = animation.full_motion.frame_costs.begin()
	PoseWriter.apply(skeleton,rest,desired,targets)
	animation.full_motion.frame_costs.end(&"pose_writer",writer_started)
	# Toes are rigid children of the boots, solved by the final writer. The
	# interpolated physical markers precede the render-time ankle refit and
	# can disagree during fast rotations. Report the actual rendered markers.
	for prefix in ["Right","Left"]:
		var toe = prefix+"ToeBase"
		rendered_joints[toe] = desired[bone_ids[toe]].origin
	pose_microseconds = Time.get_ticks_usec()-pose_start

func present_authored(joints: Dictionary, rotations: Dictionary) -> void:
	# Authored-pose diagnostics use the same bind conversion/final writer.
	assert(preview_only)
	rendered_joints = joints.duplicate(); rendered_rotations = rotations.duplicate()
	targets.clear()
	for id in joints:
		if bone_ids.has(id): _target(id,joints[id],rotations[id])
	PoseWriter.apply(skeleton,rest,desired,targets)
	for i in 2:
		var prefix = "Right" if i==0 else "Left"
		var foot: Vector3 = joints[prefix+"Foot"]
		var boot: Basis = rotations[prefix+"Foot"]
		skis[i].transform = Transform3D(boot,foot-boot.y*(Equipment.SOLE_ABOVE_SUPPORT+_origin(prefix+"Foot").y)+boot*Equipment.SKI_ORIGIN)
		var grip: Basis = rotations[prefix+"Hand"]
		poles[i].position = joints[prefix+"Hand"]+grip*Vector3(-.070 if i==0 else .070,0,.018)
		poles[i].basis = Basis(Quaternion(Vector3.DOWN,(grip*Vector3(0,0,-1)).normalized()))

func _solve_render_legs(body, joints: Dictionary, rotations: Dictionary, native_weight: float = 0.0) -> void:
	# Interpolation describes an arc between solved poses. Reclose both chains
	# against the rendered bindings without stretching a shin or splitting the
	# pelvis. This correction is visual only; no feedback enters the solver.
	var hips: Vector3 = joints.Hips
	var pelvis: Basis = rotations.Hips
	var ankles: Array[Vector3] = [joints.RightFoot,joints.LeftFoot]
	var boots: Array[Basis] = [rotations.RightFoot,rotations.LeftFoot]
	hips = Anatomy.fit_pelvis(hips,pelvis,ankles,boots)
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
		var wanted: Vector3 = body.joint(hip,ankle,thigh,shin,joints[prefix+"Leg"]-hip)
		var knee = Anatomy.fit_render_knee(prefix,hip,ankle,joints[prefix+"Leg"],rotations[prefix+"Foot"],thigh,shin,native_weight)
		joints[prefix+"Leg"] = knee
		animation.full_motion.diagnostics[prefix.to_lower()+"_knee_correction_m"] = knee.distance_to(wanted)

func _fitted_rotation(id: String, child: String, joints: Dictionary, rotation_value: Basis) -> Basis:
	# Minimal swing onto the fitted segment, retaining authored axial twist.
	var from = (rotation_value*(_origin(child)-_origin(id))).normalized()
	var to: Vector3 = (joints[child]-joints[id]).normalized()
	return (Basis(Quaternion(from,to))*rotation_value).orthonormalized()

func _procedural_limb_rotations(joints: Dictionary, rotations: Dictionary, motion: Dictionary, tuck: float) -> void:
	for i in 2:
		var side = -1.0 if i==0 else 1.0
		var prefix = "Right" if i==0 else "Left"
		for pair in [["UpLeg","Leg"],["Leg","Foot"]]:
			var id = prefix+pair[0]; var child = prefix+pair[1]
			var original = _limb_frame((_origin(id)-_origin(child)).normalized(),Vector3.RIGHT)
			rotations[id] = _limb_frame((joints[id]-joints[child]).normalized(),rotations[prefix+"Foot"].x)*original.transposed()
		for pair in [["Shoulder","Arm"],["Arm","ForeArm"],["ForeArm","Hand"]]:
			var id = prefix+pair[0]; var child = prefix+pair[1]
			rotations[id] = Basis(Quaternion((_origin(child)-_origin(id)).normalized(),(joints[child]-joints[id]).normalized()))
		var along: Vector3 = (joints[prefix+"Hand"]-joints[prefix+"ForeArm"]).normalized()
		var direction = Vector3(side*.08,-.65+tuck*.20,-.75-tuck*.18).normalized()
		if not motion.is_empty(): direction = animation.pole_direction(side,motion)
		var axis = along.slide(direction).normalized()*side
		rotations[prefix+"Hand"] = Basis(axis,(-direction).cross(axis),-direction)
