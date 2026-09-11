extends SceneTree
## Strip textures/mesh and decompose source equipment motion offline.
const INPUT = "res://artifacts/steep_motion_gameplay/retarget/"
const OUTPUT = "res://assets/animation/steep_ski_motion.res"

func _initialize() -> void:
	call_deferred("run")

func find_type(node: Node, wanted: String) -> Node:
	if node.is_class(wanted): return node
	for child in node.get_children():
		var found = find_type(child,wanted)
		if found: return found
	return null

func run() -> void:
	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(INPUT+"Apex_Steep_Retarget_Research.glb"),state)==OK)
	var scene = doc.generate_scene(state)
	root.add_child(scene)
	var skeleton: Skeleton3D = find_type(scene,"Skeleton3D")
	var player: AnimationPlayer = find_type(scene,"AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var names: Array[String] = []
	var parents: Array[int] = []
	var rests: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(i))
		parents.append(skeleton.get_bone_parent(i))
		rests.append(skeleton.get_bone_global_rest(i))
	var clips = {}
	var max_reconstruction = 0.0
	var max_length_error = 0.0
	var comparisons = 0
	var report_clips = []
	for name in player.get_animation_list():
		if not name.begins_with("Research_"): continue
		var length = player.get_animation(name).length
		var frames = roundi(length*60)+1
		var values = PackedFloat32Array()
		var previous: Array[Quaternion] = []
		var max_step = 0.0
		var prior: Array[Quaternion] = []
		player.play(name); player.advance(0.0)
		for frame in frames:
			player.seek(frame/60.0,true)
			var left = names.find("LeftFoot")
			var right = names.find("RightFoot")
			var lp = skeleton.get_bone_global_pose(left)
			var rp = skeleton.get_bone_global_pose(right)
			# The mean calibrated sole frame owns the source's world bank, pitch
			# and heading. It is removed, never added to Apex's physical frame.
			var support = (lp.basis*rests[left].basis.inverse()).orthonormalized().slerp((rp.basis*rests[right].basis.inverse()).orthonormalized(),.5)
			var center = (lp.origin+rp.origin)*.5
			var globals: Array[Basis] = []
			var positions: Array[Vector3] = []
			var this_frame: Array[Quaternion] = []
			for i in names.size():
				var pose = skeleton.get_bone_global_pose(i)
				var delta = (support.transposed()*pose.basis*rests[i].basis.inverse()).orthonormalized()
				var p = support.transposed()*(pose.origin-center)
				globals.append(delta); positions.append(p)
				var parent = parents[i]
				var local = globals[parent].transposed()*delta if parent>=0 else delta
				var q = local.get_rotation_quaternion().normalized()
				if frame>0 and previous[i].dot(q)<0.0: q = -q
				this_frame.append(q)
				if frame>0: max_step = maxf(max_step,prior[i].angle_to(q))
				# Preserve root-relative landmarks as independent fitting evidence.
				values.append_array(PackedFloat32Array([p.x,p.y,p.z,q.x,q.y,q.z,q.w]))
				if parent>=0:
					var rebuilt = positions[parent]+globals[parent]*(rests[i].origin-rests[parent].origin)
					max_reconstruction = maxf(max_reconstruction,rebuilt.distance_to(p))
					max_length_error = maxf(max_length_error,absf(p.distance_to(positions[parent])-rests[i].origin.distance_to(rests[parent].origin)))
				comparisons += 1
			previous = this_frame; prior = this_frame
		clips[name.trim_prefix("Research_")] = {"duration":length,"frames":frames,"values":values}
		report_clips.append({"name":name,"frames":frames,"duration_s":length,"source_local_step_degrees":rad_to_deg(max_step)})
		print("EXPORTED ",name," ",frames)
	var data = {"version":1,"fps":60,"names":names,"parents":parents,"rest":rests,"clips":clips}
	var resource = preload("res://scripts/presentation/ski_motion_library.gd").new()
	resource.data = data
	assert(ResourceSaver.save(resource,OUTPUT,ResourceSaver.FLAG_COMPRESS)==OK)
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT+"retarget-validation.json"))
	var manifest = {"format_version":1,"output":OUTPUT,"output_sha256":FileAccess.get_sha256(OUTPUT),"bytes":FileAccess.get_file_as_bytes(OUTPUT).size(),
		"source_sha256":provenance.source_sha256,"target_sha256":provenance.target_sha256,"mapping":provenance.mapping_target_to_source,
		"retarget_sha256":FileAccess.get_sha256(INPUT+"Apex_Steep_Retarget_Research.glb"),"timebase_hz":60,"bones":names.size(),"clips":report_clips,
		"support_frame":"Mean calibrated left/right sole rotation, mean ankle origin. Store body in this frame; discard equipment/world motion at runtime.",
		"local_frame":"Parent-relative rotation deltas in Apex model axes, plus support-relative landmarks. Reconstruct with invariant target rest links.",
		"joint_comparisons":comparisons,"max_fk_reconstruction_m":max_reconstruction,"max_segment_drift_m":max_length_error,
		"limitations":["Local retarget prototype; Steep evaluated graph and target timing are not recovered.","Gloves have fixed fingers; pole grip calibration and full grasp deformation remain limited."]}
	manifest.recovery = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/steep_motion_gameplay/recovery-manifest.json"))
	manifest.builders = {}
	for source in ["scripts/art/recover_ski_motion.py","scripts/art/retarget_ski_research.py","scripts/art/export_ski_motion.gd"]:
		manifest.builders[source] = FileAccess.get_sha256("res://"+source)
	DirAccess.make_dir_recursive_absolute("res://art_source/animation/steep_full_curves")
	FileAccess.open("res://art_source/animation/steep_full_curves/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	assert(max_reconstruction<.0001)
	print("MOTION_EXPORT ",clips.size()," clips / ",manifest.bytes," bytes / FK error ",max_reconstruction)
	scene.queue_free()
	quit()
