extends "res://tests/pose_reference_capture.gd"
## Bounded production-pose sequences (15 seconds default); frozen review/audit format.
const Fixtures = preload("res://tests/pole_push_suite.gd")
const CASES = ["flat","gentle","steep15","steep10","steep5","cutoff","downhill","left","right","brake_departure","fast"]
var no_push = false
var ground_mesh: MeshInstance3D
var capture_seconds = 15.0

func run():
	probe = "--probe" in OS.get_cmdline_user_args()
	no_push = "--no-push" in OS.get_cmdline_user_args()
	scenarios = CASES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--scenarios="): scenarios = Array(arg.trim_prefix("--scenarios=").split(","))
		if arg.begins_with("--seconds="): capture_seconds = clampf(float(arg.trim_prefix("--seconds=")),3.0,15.0)
	if not probe and DisplayServer.get_name()=="headless": push_error("Native renderer required"); quit(2); return
	assert(not FileAccess.file_exists(output+"/manifest.json"),"Preserve prior pole review revision")
	DirAccess.make_dir_recursive_absolute(output)
	report = {"version":1,"created_utc":Time.get_datetime_string_from_system(true),"engine":Engine.get_version_info().string,
		"physics":Sim.MODEL_VERSION,"capture_fps":60,"simulation_hz":120,"frame_origin":0,"unranked":true,
		"source_verification":"metadata","sources":source_hashes(),"scenarios":[],"failures":[],"notes":["%s-second analytic snow fixtures; no PB/preferences/session."%capture_seconds,
		"No-push baseline is identical current model with the pole feature disabled.","Source/requested/final joint data plus loaded tip-gap and force telemetry retained. Native triptych is visual evidence, not a 4K FPS result."],"no_push":no_push}
	scene = Node3D.new(); root.add_child(scene)
	skier = Visual.new(); skier.preview_only = true
	skier.assets = preload("res://scripts/presentation/alpine_assets.gd").new(skier.lighting,preload("res://scripts/presentation/graphics_quality.gd").preset(2))
	scene.add_child(skier); await process_frame
	report.rig = {"names":[],"parents":[],"rest":[]}
	for i in skier.skeleton.get_bone_count():
		report.rig.names.append(skier.skeleton.get_bone_name(i)); report.rig.parents.append(skier.skeleton.get_bone_parent(i)); report.rig.rest.append(pack(skier.rest[i]))
	if not probe:
		setup_render()
		ground_mesh = MeshInstance3D.new(); var mesh = PlaneMesh.new(); mesh.size = Vector2(2000,2000)
		ground_mesh.mesh = mesh
		var material = ShaderMaterial.new(); var shader = Shader.new()
		# World-fixed metric reference on the SAME analytic plane. No offset,
		# collision/height changes, decals following the skier or production art.
		shader.code = """shader_type spatial;
render_mode specular_disabled;
varying vec2 plane_metres;
void vertex() { plane_metres = VERTEX.xz; }
float grid_line(vec2 p, float spacing, float half_width) {
    vec2 d = abs(fract(p / spacing + 0.5) - 0.5) * spacing;
    vec2 aa = max(fwidth(p), vec2(0.0001));
    vec2 line = 1.0 - smoothstep(vec2(half_width), vec2(half_width) + aa, d);
    return max(line.x, line.y);
}
void fragment() {
    float minor = grid_line(plane_metres, 0.5, 0.007);
    float major = grid_line(plane_metres, 2.0, 0.012);
    ALBEDO = mix(vec3(0.48, 0.50, 0.52), vec3(0.21, 0.23, 0.25), minor);
    ALBEDO = mix(ALBEDO, vec3(0.075, 0.085, 0.095), major);
    ROUGHNESS = 1.0;
}
"""
		material.shader = shader
		ground_mesh.material_override = material; scene.add_child(ground_mesh)
	for name in scenarios:
		assert(name in CASES,"Unknown pole fixture")
		var degrees = {"flat":0.0,"gentle":10.0,"steep15":20.0,"steep10":28.0,"steep5":34.0,"cutoff":42.0,"downhill":-12.0}.get(name,0.0)
		field = Fixtures.SlopePlane.new(degrees)
		if ground_mesh:
			var normal: Vector3 = field.sample(0,0).normal
			var forward = Vector3.BACK.slide(normal).normalized()
			ground_mesh.basis = Basis(normal.cross(forward),normal,forward)
		await capture_sequence(name,{"origin":Vector3.ZERO,"heading":0.0,"grade_degrees":degrees})
	report.sources_after = source_hashes(); report.stable_sources = report.sources==report.sources_after
	if not report.stable_sources: report.failures.append("Source changed during capture")
	preload("res://tests/test_report.gd").write(output+"/manifest.json",JSON.stringify(report,"\t"))
	print("POLE_PUSH_CAPTURE ",output," failures=",report.failures)
	scene.queue_free(); await process_frame; quit(0 if report.failures.is_empty() else 1)

func reset_sim(name: String, _fixture: Dictionary):
	return Fixtures.make_sim(field,10.0 if name=="fast" else 0.0,not no_push)

func setup_render():
	super.setup_render()
	# Project UI scaling stretched 600 px panels to 667 px and cropped the
	# actual side-view pole tips. Keep exact pixels and enough sagittal width.
	root.content_scale_size = Vector2i.ZERO; root.content_scale_factor = 1.0
	for camera in cameras: camera.size = 5.6
	# Fixture lighting only: the previous blue plane had no enabled shadows.
	# Neutral lower fill leaves the 0.5 m grid and pole/body shadows readable.
	var light_index = 0
	for node in scene.get_children():
		if node is WorldEnvironment:
			node.environment.ambient_light_color = Color.WHITE
			node.environment.ambient_light_energy = .30
		if node is DirectionalLight3D:
			node.light_energy = 1.1 if light_index==0 else .2
			node.shadow_enabled = light_index==0
			if light_index==0:
				node.directional_shadow_max_distance = 35.0
				node.shadow_bias = .02; node.shadow_normal_bias = .1
			light_index += 1
	report.notes.append("Fixture-only neutral lit plane with fixed 0.5 m minor/2 m major grid and key-light shadows. Grid is on the physical analytic plane; no production art/material/settings changed. Native readability still requires pixel inspection.")
	report.notes.append("Native panels are exact 600x1000 pixels; studio size5.6 retains full shafts. Production chase camera is unchanged by its child harness.")

func frame_count(_name: String) -> int: return int(round(capture_seconds*60.0))

func intent_at(name: String, tick: int):
	var intent = RiderInput.new()
	intent.tuck = 1.0 if tick<1500 else 0.0
	if name in ["left","right"] and tick>=480 and tick<840: intent.steer = -.25 if name=="left" else .25
	if name=="brake_departure":
		intent.brake = .5 if tick>=480 and tick<600 else 0.0
		intent.jump_held = tick>=960 and tick<990
		intent.jump = tick==990
	return intent

func source_hashes() -> Dictionary:
	# The inherited hook name is historical. Pole review uses scoped metadata,
	# never recursive source reads or asset hashes; runtime identities stay intact.
	var result = {}
	for path in ["tests/pose_reference_capture.gd","tests/pole_push_capture.gd","tests/pole_push_playtest.gd","tests/pole_push_suite.gd",
		"scripts/core/ski_simulation.gd","scripts/core/pole_propulsion.gd","scripts/core/ski_tuning.gd","scripts/core/rider_body.gd","config/ski_default.tres",
		"scripts/presentation/skier_full_motion.gd","scripts/presentation/pole_push_pose.gd","scripts/presentation/pole_push_motion.gd",
		"scripts/presentation/skier_visual.gd","scripts/presentation/skier_animation.gd","scripts/presentation/skier_anatomy.gd","scripts/presentation/skier_pose_writer.gd",
		"scripts/presentation/skier_equipment.gd","scripts/presentation/downhill_posture.gd","scripts/presentation/action_posture.gd","scripts/presentation/chase_camera.gd",
		"assets/animation/pole_push_cycle.tres","assets/animation/steep_ski_motion.res","assets/graphics/models/skier_v7.glb","project.godot"]:
		var resource = "res://"+path
		result[resource] = {"size":FileAccess.open(resource,FileAccess.READ).get_length(),"modified":FileAccess.get_modified_time(resource)}
	return result
