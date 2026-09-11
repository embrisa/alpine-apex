extends SceneTree
## Standalone research viewer. Imports ignored GLBs directly; never loads the game.
## ./godotw.ps1 --script scripts/art/ski_motion_research_preview.gd
## Add '--' --verify for headless export round-trip validation, --capture for a PNG.

const DIRECTORY = "res://artifacts/steep_motion_fidelity/"
const MODEL = DIRECTORY + "Apex_Steep_Retarget_Research.glb"
var world: Node3D
var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var camera: Camera3D
var clips: PackedStringArray
var clip_index := 0
var time := 0.0
var speed := 1.0
var clip_paused := false
var slider: HSlider
var timing_label: Label
var pause_button: Button
var orbit := Vector2(0.55, 0.20)
var distance := 4.5
var previous_mouse := Vector2.ZERO
var ready_to_play := false
var verification := false
var equipment: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func find_type(node: Node, wanted: String) -> Node:
	if node.is_class(wanted): return node
	for child in node.get_children():
		var found := find_type(child, wanted)
		if found != null: return found
	return null

func run() -> void:
	verification = "--verify" in OS.get_cmdline_user_args()
	if not FileAccess.file_exists(MODEL):
		printerr("Build the research GLB first; see docs/ASSETS.md.")
		quit(2)
		return
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(ProjectSettings.globalize_path(MODEL), state)
	if error != OK:
		printerr("Research GLB import failed: ", error)
		quit(2)
		return
	model = document.generate_scene(state)
	world.add_child(model)
	skeleton = find_type(model, "Skeleton3D") as Skeleton3D
	player = find_type(model, "AnimationPlayer") as AnimationPlayer
	if skeleton == null or player == null:
		printerr("Missing skeleton or animation player")
		quit(2)
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name in player.get_animation_list():
		if name.begins_with("Research_"): clips.append(name)
	await process_frame
	if verification:
		verify_export()
		return
	root.title = "Alpine Apex — native motion research"
	root.size = Vector2i(1440, 1000)
	root.content_scale_size = Vector2i(1440, 1000)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("141d2b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b2c9e0")
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	for rotation in [Vector3(-45, -35, 0), Vector3(-25, 145, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = rotation
		light.light_energy = 1.1 if rotation.y < 0 else 0.6
		world.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.28
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("202d3d")
	material.roughness = 0.9
	floor_mesh.material_override = material
	world.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 42
	camera.near = 0.01
	world.add_child(camera)
	camera.make_current()
	build_equipment()
	build_ui()
	previous_mouse = root.get_mouse_position()
	clip_index = maxi(0, clips.find("Research_NAV_MED_LEFT"))
	select_clip(clip_index)
	ready_to_play = true
	if "--capture" in OS.get_cmdline_user_args():
		clip_paused = true
		time = 1.0
		apply_pose()
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIRECTORY + "godot-native-motion-preview.png")
		print("RESEARCH_PREVIEW_CAPTURED")
		quit()

func build_equipment() -> void:
	# Props follow the sampled bones only in this viewer. This is deliberately
	# different from gameplay, where solver-owned skis must constrain the bones.
	for side in ["Left", "Right"]:
		var foot := Node3D.new()
		world.add_child(foot)
		var boot: Node3D = load("res://assets/graphics/models/skier_v7_boot_" + side.to_lower() + ".glb").instantiate()
		foot.add_child(boot)
		var ski_name := "ski_detailed_v1_left" if side == "Left" else "ski_detailed_v1"
		var ski: Node3D = load("res://assets/graphics/models/" + ski_name + ".glb").instantiate()
		foot.add_child(ski)
		ski.position = Vector3(0, -0.095, 0.15)
		var binding: Node3D = load("res://assets/graphics/models/binding_detailed_v1.glb").instantiate()
		ski.add_child(binding)
		binding.position = Vector3(0, 0.018, -0.15)
		var pole: Node3D = load("res://assets/graphics/models/pole_detailed_v1.glb").instantiate()
		world.add_child(pole)
		equipment[side] = {"foot": foot, "pole": pole}

func update_equipment() -> void:
	for side in equipment:
		var index := skeleton.find_bone(side + "Foot")
		var rest := skeleton.get_bone_global_rest(index)
		var pose := skeleton.get_bone_global_pose(index)
		var rotation := pose.basis * rest.basis.inverse()
		equipment[side].foot.global_transform = skeleton.global_transform * Transform3D(rotation, pose.origin-rotation*Vector3.UP*rest.origin.y)
		index = skeleton.find_bone(side + "Hand")
		rest = skeleton.get_bone_global_rest(index)
		pose = skeleton.get_bone_global_pose(index)
		rotation = pose.basis * rest.basis.inverse()
		var sign_side := 1.0 if side == "Left" else -1.0
		var grip := pose.origin+rotation*Vector3(sign_side*0.07, 0, 0.018)
		var pole_basis := Basis(Quaternion(Vector3.DOWN, -rotation.z.normalized()))
		equipment[side].pole.global_transform = skeleton.global_transform * Transform3D(pole_basis, grip)

func verify_export() -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "retarget-validation.json"))
	var failures: Array[String] = []
	var max_error := 0.0
	var comparisons := 0
	if skeleton.get_bone_count() != 24: failures.append("Expected 24 target bones")
	if clips.size() != 8: failures.append("Expected exactly 8 retargeted clips")
	for clip in report.clips:
		if not player.has_animation(clip.name):
			failures.append("Missing " + clip.name)
			continue
		var animation := player.get_animation(clip.name)
		if absf(animation.length-float(clip.duration_s)) > 0.0001:
			failures.append("Duration mismatch: " + clip.name)
		player.play(clip.name)
		player.advance(0.0)
		for sample in clip.validation_samples:
			player.seek(float(sample.seconds), true)
			for bone_name in sample.positions_blender_z_up:
				var index := skeleton.find_bone(bone_name)
				if index < 0:
					failures.append("Missing bone " + bone_name)
					continue
				var p: Array = sample.positions_blender_z_up[bone_name]
				var expected := Vector3(float(p[0]), float(p[2]), -float(p[1]))
				var actual := (skeleton.global_transform * skeleton.get_bone_global_pose(index)).origin
				max_error = maxf(max_error, actual.distance_to(expected))
				comparisons += 1
	if max_error > 0.0001: failures.append("Joint position export error exceeds 0.1 mm")
	var result := {"godot_version": Engine.get_version_info().string,
		"clips": clips.size(), "bones": skeleton.get_bone_count(),
		"joint_position_comparisons": comparisons, "max_position_error_m": max_error,
		"failures": failures, "scope": "GLB import, clip durations and sampled bone transforms; no gameplay or transition acceptance."}
	FileAccess.open(DIRECTORY + "godot-roundtrip-validation.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("RESEARCH_ROUNDTRIP ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	world.add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 22)
	panel.custom_minimum_size = Vector2(1396, 0)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "STEEP MOTION / APEX MESH — 24 bones, full skeletal curves"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var note := Label.new()
	note.text = "Stored clips only. Props follow bones here; physical ski constraints, grip IK and game transitions are not applied."
	box.add_child(note)
	var row := HBoxContainer.new()
	box.add_child(row)
	var choices := OptionButton.new()
	choices.focus_mode = Control.FOCUS_NONE
	for name in clips: choices.add_item(name.trim_prefix("Research_"))
	choices.selected = maxi(0, clips.find("Research_NAV_MED_LEFT"))
	choices.item_selected.connect(select_clip)
	row.add_child(choices)
	pause_button = Button.new()
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.text = "Pause"
	pause_button.pressed.connect(toggle_playback)
	row.add_child(pause_button)
	var speeds := OptionButton.new()
	speeds.focus_mode = Control.FOCUS_NONE
	for rate in [0.25, 0.5, 1.0, 2.0]: speeds.add_item(str(rate) + "x speed")
	speeds.selected = 2
	speeds.item_selected.connect(func(index: int): speed = [0.25, 0.5, 1.0, 2.0][index])
	row.add_child(speeds)
	timing_label = Label.new()
	row.add_child(timing_label)
	slider = HSlider.new()
	slider.focus_mode = Control.FOCUS_NONE
	slider.step = 0.001
	slider.value_changed.connect(func(value: float): time = value; apply_pose())
	box.add_child(slider)
	var help := Label.new()
	help.text = "Right-drag: orbit | Hold middle mouse + move vertically: zoom | Space: pause | Clip ends pause for inspection."
	box.add_child(help)

func select_clip(index: int) -> void:
	clip_index = index
	time = 0.0
	clip_paused = false
	player.play(clips[index])
	player.advance(0.0)
	slider.max_value = player.get_animation(clips[index]).length
	apply_pose()

func apply_pose() -> void:
	player.seek(time, true)
	update_equipment()
	if slider != null: slider.set_value_no_signal(time)
	if timing_label != null:
		timing_label.text = "  %.3f / %.3f s" % [time, slider.max_value]

func toggle_playback() -> void:
	if clip_paused and time >= slider.max_value:
		time = 0.0
	clip_paused = not clip_paused

func _process(delta: float) -> bool:
	if not ready_to_play: return false
	if Input.is_action_just_pressed("ui_accept"): toggle_playback()
	if not clip_paused:
		time = minf(time+delta*speed, slider.max_value)
		if time >= slider.max_value: clip_paused = true
		apply_pose()
	pause_button.text = "Resume" if clip_paused else "Pause"
	var mouse := root.get_mouse_position()
	var movement := mouse-previous_mouse
	previous_mouse = mouse
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		orbit.x -= movement.x*0.007
		orbit.y = clampf(orbit.y+movement.y*0.007, -0.6, 1.2)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		distance = clampf(distance+movement.y*0.015, 1.5, 7.0)
	var center := Vector3(0, 0.80, 0)
	camera.position = center+Vector3(sin(orbit.x)*cos(orbit.y), sin(orbit.y), cos(orbit.x)*cos(orbit.y))*distance
	camera.look_at(center)
	return false
