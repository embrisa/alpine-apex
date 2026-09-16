extends RefCounted
## One warm field -> bounded minimal selection -> at most one Main load and 4 or 8 PNGs.
const Probe = preload("res://tests/session_navigation_landmark_probe.gd")
const Fixture = preload("res://tests/validation_mountain.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const Chase = preload("res://scripts/presentation/chase_camera.gd")
const CameraSettings = preload("res://scripts/presentation/camera_settings.gd")
const PersonalBeams = preload("res://scripts/presentation/session_navigation_beams.gd")
const SEED_PATH = "res://artifacts/orchestration_20260912/finish/selection-diag-parent-v2/report.json"
const SEED_SHA256 = "c06fb7ee2858cb1c453df3b87043205a960d1603d0f37aaa71ea87b1d240a606"
const SEED_PRODUCER = "4126615a8ace84d4f916c1e95700b9e176b1380b7e34f2b305328c65b2f6b765"
var tree: SceneTree
var root: Window
var game
var field
var probe = Probe.new()
var output = "res://artifacts/orchestration_20260912/navigation/landmark-preflight-parent-v4"
var report = {"failures":[],"checks":[],"captures":[],"selection":{},"sources":{},
	"main_loads":0,"coverage_failures":[],"probe_version":4,"visual_acceptance":"pending parent pixel inspection","performance_acceptance":"not_measured",
	"scope":"High Clear/Day stationary Connected 60 km/h. Fixed lower 2 km/ridge plus at most one upper 500 m candidate; hidden/shown at 1080p and 4K. No full matrix or UI/lifecycle rerun."}
var personal_files: Dictionary = {}

func check(ok: bool, caption: String) -> bool:
	report.checks.append({"ok":ok,"caption":caption})
	print("PASS: " if ok else "FAIL: ",caption)
	if not ok: report.failures.append(caption)
	return ok

func run(owner: SceneTree) -> void:
	tree = owner
	root = tree.root
	var seconds = 30.0
	var diagnostics_only = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--navigation-output="): output = arg.trim_prefix("--navigation-output=")
		if arg.begins_with("--navigation-search-seconds="): seconds = clampf(float(arg.get_slice("=",1)),5,45)
		if arg=="--navigation-selection-only": diagnostics_only = true
	if not output.begins_with("res://"): output = "res://"+output
	var resolved = ProjectSettings.globalize_path(output).simplify_path().replace("\\","/")
	var artifacts = ProjectSettings.globalize_path("res://artifacts/").simplify_path().replace("\\","/").trim_suffix("/")+"/"
	if not resolved.begins_with(artifacts) or DirAccess.dir_exists_absolute(output):
		printerr("Navigation preflight requires a fresh output inside artifacts: ",output)
		tree.quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	report.arguments = OS.get_cmdline_user_args()
	report.engine = Engine.get_version_info()
	report.device = RenderingServer.get_video_adapter_name()
	report.search_seconds = seconds
	if not check(FileAccess.get_sha256(SEED_PATH)==SEED_SHA256,"Exact sibling finish selection report retained"):
		finish(); return
	var seed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SEED_PATH))
	if not check(seed.get("geometry_selection_complete",false) and seed.failures.is_empty(),"Seed contains a complete original geometry selection"):
		finish(); return
	for path in seed.source_sha256:
		if path=="tests/race_beams_playtest.gd":
			check(seed.source_sha256[path]==SEED_PRODUCER,"Acknowledge exact old fixture producer; do not modify sibling harness")
			continue
		check(FileAccess.get_sha256("res://"+path)==seed.source_sha256[path],"Retained seed source identity: "+path)
		report.sources[path] = FileAccess.get_sha256("res://"+path)
	for path in ["tests/session_navigation_playtest.gd","tests/session_navigation_landmark_probe.gd",
		"tests/session_navigation_landmark_preflight.gd","scripts/racing/session_navigation.gd",
		"scripts/presentation/session_navigation_beams.gd","scripts/presentation/forest_placement.gd",
		"scripts/world/packed_trees.gd","scripts/presentation/foliage_sight.gd","scripts/presentation/alpine_assets.gd",
		"assets/graphics/foliage_sight.gdshaderinc","assets/graphics/pc_forest_tree.gdshader","assets/graphics/pc_tree_impostor.gdshader"]:
		report.sources[path] = FileAccess.get_sha256("res://"+path)
	report.seed_provenance = {"path":SEED_PATH,"sha256":SEED_SHA256,"producer":SEED_PRODUCER,
		"accepted_roles":"Parent reviewed amber 2 km/ridge; navigation must be independently inspected",
		"rejected_500m_pixels":"artifacts/orchestration_20260912/finish/500m-foliage-parent-v3/report.json"}
	if not report.failures.is_empty(): finish(); return
	for path in ["user://camera_v2.cfg","user://graphics_v2.cfg","user://display_v1.cfg","user://weather_v1.cfg","user://benchmark_v1.json"]:
		personal_files[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	field = Fixture.load_standard()
	if not check(field!=null,"Warm current Standard cache exists; no cold generation"):
		finish(); return
	check(field.height_checksum==seed.height_sha256 and field.obstacle_checksum==seed.obstacle_sha256,"Same physical terrain and obstacle fingerprints as accepted sibling evidence")
	report.height_sha256 = field.height_checksum
	report.obstacle_sha256 = field.obstacle_checksum
	report.mountain_identity = Definition.from_field(field).identity()
	if not report.failures.is_empty(): finish(); return
	var minimal_camera = Chase.new()
	minimal_camera.settings = CameraSettings.new()
	minimal_camera.near = .15; minimal_camera.far = 32000.0
	root.size = Vector2i(1920,1080)
	root.add_child(minimal_camera)
	for frame in 2: await tree.process_frame
	var tuning = preload("res://config/ski_default.tres").duplicate(true)
	tuning.vibration_intensity = 0.0
	tuning.ground_assist_enabled = "--ground-assist" in OS.get_cmdline_user_args()
	tuning.landing_assist_enabled = "--air-assist" in OS.get_cmdline_user_args()
	probe.field = field
	probe.sim = Race.Simulation.new(tuning)
	probe.camera = minimal_camera
	probe.style = PersonalBeams.style()
	report.navigation_style = probe.style.duplicate()
	var started = Time.get_ticks_msec()
	report.selection = probe.select_views(seed,seconds)
	report.selection_ms = Time.get_ticks_msec()-started
	# Keep missing 500 m coverage explicit, but finish the independently qualified
	# 2 km/ridge pixels before final failure reporting. Source/load errors still stop.
	report.coverage_failures = report.selection.failures.duplicate()
	for path in probe.bounds_sources: report.sources[path] = probe.bounds_sources[path]
	if not report.coverage_failures.is_empty():
		print("NAVIGATION_PARTIAL_COVERAGE ",report.coverage_failures,"; qualified view count=",report.selection.views.size())
	preload("res://tests/test_report.gd").write(output+"/selection.json",JSON.stringify(Probe.json_safe({
		"selection":report.selection,"sources":report.sources,"seed_provenance":report.seed_provenance,
		"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,
		"navigation_style":probe.style,"visual_acceptance":"not_attempted"}),"\t"))
	root.remove_child(minimal_camera)
	minimal_camera.free()
	probe.camera = null
	probe.deadline_ms = 0
	# A 500 m hole must not cancel valid violet 2 km/ridge captures.
	if report.selection.views.is_empty():
		finish(); return
	if diagnostics_only:
		report.visual_acceptance = "not_attempted_selection_only"
		finish(); return
	# Any independent qualified view is enough for one scenery load; never a matrix.
	tree.set_meta("test_lab_fixture",true)
	tree.set_meta("mountain_to_load",{"definition":Definition.from_field(field),"field":field})
	game = load("res://main.tscn").instantiate()
	game.automated = true
	game.benchmark_no_captures = true
	root.add_child(game)
	tree.current_scene = game
	report.main_loads = 1
	var load_started = Time.get_ticks_msec()
	while not game.initialized or (game.loading and game.loading.busy):
		if Time.get_ticks_msec()-load_started>180000:
			check(false,"Main initialization exceeded the 180 s bound")
			finish(); return
		await tree.process_frame
	game.set_process(false); game.set_physics_process(false)
	game.workshop.set_process(false)
	game.active = false; game.session.eligible = false
	game.session.record_directory = output+"/records"
	game.session.benchmark_path = output+"/benchmark.json"
	game.workshop.store.directory = output+"/library"
	game.effects.haptic_hardware_enabled = false
	game.effects.muted = true; game.voice.set_muted(true)
	game.hud.feedback.persist = false; game.hud.feedback.muted = true
	check(not game.preferences_enabled,"Automated Main keeps personal preferences isolated")
	game.camera_settings.reset() # Existing default Connected, exactly as seed selection.
	game.set_graphics_quality(2)
	game.display_settings.frame_generation = false
	game.display_settings.display_mode = "windowed"
	game.display_settings.apply_viewport(root)
	game.workshop._clear_markers()
	game.hud.hide_menu(); game.hud.root.hide()
	game.speed_periphery.hide(); game.vectors.hide()
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,0.0,false)
	game.weather_effects.reset()
	probe.sim = game.sim; probe.camera = game.camera
	for pixels in [Vector2i(1920,1080),Vector2i(3840,2160)]:
		game.display_settings.apply_display(root,pixels)
		game.display_settings.apply_viewport(root)
		for frame in 3: await tree.process_frame
		for plan in report.selection.views:
			var current = probe.evaluate(plan)
			if not check(current.issues.is_empty(),"Native final camera retains full geometric/canopy predicate: "+plan.label): continue
			game.sim.reset_pose_history(); game.skier.reset_animation(game.sim)
			game.skier.pose(game.sim,1.0); game.skier.show()
			game.previous_position = game.sim.position
			game.presentation_camera = game.camera
			var model = game.workshop.navigation_state
			model.clear_points()
			check(model.add_point(field,plan.anchor).error.is_empty(),"Place one real supported personal landmark")
			var before = {"ticks":game.sim.ticks,"elapsed":game.session.elapsed,"velocity":game.sim.velocity,"position":game.sim.position}
			for shown in [false,true]:
				model.set_shown(shown)
				await capture(plan,current,pixels,shown)
			check(before=={"ticks":game.sim.ticks,"elapsed":game.session.elapsed,"velocity":game.sim.velocity,"position":game.sim.position},"Native pair holds solver/session state")
	check(report.captures.size()==report.selection.views.size()*4,"All selected views have hidden/shown pairs at both resolutions")
	finish()

func capture(plan: Dictionary, current: Dictionary, pixels: Vector2i, shown: bool) -> void:
	game.world.assets.foliage_sight.initialized = false
	for frame in 60: update_foliage(1.0/60.0)
	check(is_equal_approx(game.world.assets.foliage_sight.parameters.x,1.0),"Normal canopy aid settled without tree removal or setting changes")
	game.display_settings.reset_history()
	for frame in 30:
		update_foliage(1.0/60.0)
		# Keep a matched static flow phase. No brightness/opacity/depth override.
		tree.call_group("race_beam_vfx","update_effect",0.0,false,false)
		game.weather_effects.update_weather(game.weather.state,game.camera,game.sim.position,field,1.0/60.0,false,true,0.0,game.graphics.weather_quality)
		await tree.process_frame
	await RenderingServer.frame_post_draw
	check(root.get_camera_3d()==game.camera,"Production chase owns native capture")
	var label = "%s_%dp_%s" % [plan.label,pixels.y,"shown" if shown else "hidden"]
	var image = root.get_texture().get_image()
	check(image.get_size()==pixels,"Native output size: "+label)
	check(image.save_png(output+"/"+label+".png")==OK,"Saved "+label)
	report.captures.append({"label":label,"shown":shown,"plan":plan,"probe":current,
		"camera":probe.camera_data(),"foliage_aid":game.world.assets.foliage_sight.parameters,
		"pixels":image.get_size(),"display":game.display_settings.report(root,image.get_size()),
		"weather":game.weather.snapshot(),"quality":game.graphics.label(),"style":PersonalBeams.style(),
		"image_sha256":FileAccess.get_sha256(output+"/"+label+".png"),"visual_acceptance":"requires parent comparison of actual pixels"})
	print("NAVIGATION_LANDMARK_CAPTURE ",label)

func update_foliage(dt: float) -> void:
	game.world.assets.update_foliage_sight(game.camera,game.skier.global_position,dt,true,
		game.camera_settings.shared.forest_visibility,game.camera_settings.shared.forest_visibility_strength)

func finish() -> void:
	# Each missing role/control is one failure, including selection-only and load errors.
	for failure in report.coverage_failures: check(false,failure)
	if report.captures.is_empty() and report.visual_acceptance=="pending parent pixel inspection":
		report.visual_acceptance = "not_attempted_no_native_captures"
	for path in report.sources:
		check(FileAccess.get_sha256("res://"+path)==report.sources[path],"Source unchanged: "+path)
	for path in personal_files:
		var after = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		check(after==personal_files[path],"Personal file unchanged: "+path)
	preload("res://tests/test_report.gd").write(output+"/report.json",JSON.stringify(Probe.json_safe(report),"\t"))
	if game!=null:
		if game.effects!=null: game.effects.stop_audio()
		game.free()
	tree.quit(0 if report.failures.is_empty() else 2)
