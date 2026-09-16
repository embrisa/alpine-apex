extends SceneTree
## Native fixed-view comparison. No solver descent or personal record writes.
const Beams = preload("res://scripts/presentation/race_beams.gd")
const Baseline = preload("res://tests/fixtures/finish_beam_800m/race_beams.gd")
const Mountain = preload("res://tests/validation_mountain.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Race = preload("res://scripts/racing/race_definition.gd")
const Chase = preload("res://scripts/presentation/chase_camera.gd")
const CameraSettings = preload("res://scripts/presentation/camera_settings.gd")
const SAMPLE_SECONDS = 15.0
const Evidence = preload("res://tests/session_navigation_evidence.gd")
const LandmarkProbe = preload("res://tests/session_navigation_landmark_probe.gd")
const NAVIGATION_SELECTION = "res://artifacts/orchestration_20260912/navigation/landmark-preflight-parent-v4/selection.json"
const NAVIGATION_SELECTION_SHA256 = "92783bbe89933fc195141b156dc78efcc3d1fa206304091a15180968af35a9b4"
const NAVIGATION_REPORT = "res://artifacts/orchestration_20260912/navigation/landmark-preflight-parent-v4/report.json"
const NAVIGATION_REPORT_SHA256 = "853587ccd05a022898bef91ccf2e184cd13c511be91f3c0efc7784a3385fe962"
const NAVIGATION_FINISH_BASELINE = "1a85e553562969e7cb304af12f4b8ca206ea3fb86c3a37014aa87b7eb26f2264"
# Exact selection-diag-parent-v2 producer retained for the four-image follow-up.
# The separate weather-cover allowance below also names every accepted revision.
const FOLIAGE_REVIEW_SELECTION_HARNESS = "4126615a8ace84d4f916c1e95700b9e176b1380b7e34f2b305328c65b2f6b765"
# Known geometry producer and exact integrated canopy-only fixture revision.
# Weather-only may reuse these harness hashes; production hashes still must match.
const WEATHER_SELECTION_HARNESSES = [FOLIAGE_REVIEW_SELECTION_HARNESS,
	"e0d3073aa83747467ab28a4efbd8ff20672244b5bee25667a20f3015c8f2046a"]
const WEATHER_COVER = [
	{"view":"finish_2000m","level":0,"quality":"low","preset":"clear","period":"dusk"},
	{"view":"ridge","level":1,"quality":"balanced","preset":"clear","period":"night"},
	{"view":"finish_2000m","level":2,"quality":"high","preset":"snowfall","period":"day"}]
var output = "res://artifacts/taller_finish_beam"
var game
var camera: Camera3D
var review_camera: Camera3D
var race
var failures: Array[String] = []
var captures: Array = []
var measurements: Array = []
var sources: Dictionary = {}
var approaches: Dictionary = {}
var scenario: Dictionary = {}
var variant = "proposed"
var requested_pixels = Vector2i(3840,2160)
var weather_label = "clear_day"
var reduced_motion = false
var animate = true
var personal_files: Dictionary = {}
var setup_started = 0
var search_receipts: Array = []
var coverage_gaps: Array[String] = []
var race_fixtures: Dictionary = {}
var camera_settle_trace: Array = []
var diagnostics_only = false
var selection_report = ""
var five_hundred_only = false
var weather_only = false
var navigation_500m = false
var navigation_sources: Dictionary = {}
var navigation_provenance: Dictionary = {}
var weather_case: Dictionary = {}
var weather_sources: Dictionary = {}
var selection_provenance: Dictionary = {}
var foliage_sources: Dictionary = {}
var search_seconds = 30.0
var candidate_limit = 6
var search_deadline_ms = 0
var selection_started_ms = 0
var selection_elapsed_ms = 0
var search_stop_reason = "not_started"
var finish_candidates: Array = []
var selected_fixture_data: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Native rendering is required for race_beams_playtest.")
		quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg=="--diagnostics-only": diagnostics_only = true
		if arg=="--500m-only": five_hundred_only = true
		if arg=="--weather-only": weather_only = true
		if arg=="--navigation-500m": navigation_500m = true
		if arg.begins_with("--selection-report="): selection_report = arg.trim_prefix("--selection-report=")
		if arg.begins_with("--search-seconds="): search_seconds = clampf(float(arg.get_slice("=",1)),5.0,120.0)
		if arg.begins_with("--candidate-limit="): candidate_limit = clampi(int(arg.get_slice("=",1)),1,16)
	if five_hundred_only and (diagnostics_only or selection_report.is_empty() or "--distant-only" not in OS.get_cmdline_user_args()):
		printerr("--500m-only requires --distant-only and --selection-report; no replacement search or suggested-start captures.")
		quit(2); return
	if weather_only and (five_hundred_only or diagnostics_only or selection_report.is_empty()
			or "--distant-only" not in OS.get_cmdline_user_args()
			or "--full-matrix" in OS.get_cmdline_user_args() or "--timing" in OS.get_cmdline_user_args()
			or "--timings-only" in OS.get_cmdline_user_args()):
		printerr("--weather-only requires --distant-only and --selection-report, without other capture/timing routes.")
		quit(2); return
	if navigation_500m and (five_hundred_only or weather_only or diagnostics_only or not selection_report.is_empty()
			or "--distant-only" not in OS.get_cmdline_user_args() or "--full-matrix" in OS.get_cmdline_user_args()
			or "--timing" in OS.get_cmdline_user_args() or "--timings-only" in OS.get_cmdline_user_args()):
		printerr("--navigation-500m requires --distant-only alone; exactly four pinned shown/hidden images, no search.")
		quit(2); return
	if not output.begins_with("res://"): output = "res://"+output
	var resolved = ProjectSettings.globalize_path(output).simplify_path()
	var artifacts = ProjectSettings.globalize_path("res://artifacts/").simplify_path().trim_suffix("/")+"/"
	if not resolved.begins_with(artifacts) or DirAccess.dir_exists_absolute(output):
		printerr("Choose a fresh output directory inside artifacts: ",output)
		quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	setup_started = Time.get_ticks_msec()
	for path in ["scripts/presentation/race_beams.gd","assets/graphics/race_beam.gdshader",
			"assets/graphics/race_beam_base.gdshader","scripts/racing/race_workshop.gd",
			"scripts/world/alpine_world.gd","scripts/main.gd","scripts/presentation/chase_camera.gd",
			"scripts/presentation/camera_settings.gd","tests/race_beams_playtest.gd","tests/session_navigation_evidence.gd",
			"scripts/core/ski_simulation.gd","config/ski_default.tres","scripts/racing/race_definition.gd",
			"tests/fixtures/finish_beam_800m/race_beams.gd","tests/fixtures/finish_beam_800m/race_beam.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	for path in ["scripts/presentation/foliage_sight.gd","scripts/presentation/alpine_assets.gd",
			"assets/graphics/foliage_sight.gdshaderinc","assets/graphics/pc_forest_tree.gdshader",
			"assets/graphics/pc_tree_impostor.gdshader"]:
		foliage_sources[path] = FileAccess.get_sha256("res://"+path)
	if weather_only:
		for path in ["scripts/presentation/weather_controller.gd","scripts/presentation/weather_state.gd",
				"scripts/presentation/weather_effects.gd","scripts/presentation/weather_preset.gd",
				"scripts/presentation/weather_rules.gd","scripts/presentation/daylight_cycle.gd",
				"scripts/presentation/graphics_quality.gd","scripts/presentation/graphics_presets.gd",
				"scripts/presentation/pc_graphics_settings.gd","scripts/presentation/cloud_lighting.gd",
				"scripts/presentation/alpine_atmosphere.gd","config/weather/clear.tres","config/weather/snowfall.tres",
				"assets/weather_particles.gdshader","assets/weather_particle_draw.gdshader"]:
			weather_sources[path] = FileAccess.get_sha256("res://"+path)
	_snapshot_personal_files()
	var field = Mountain.load_standard()
	if field==null:
		failures.append("Current Standard cache unavailable; no cold generation attempted.")
		_write_report(); quit(2); return
	if diagnostics_only:
		await _diagnose_selection(field)
		return
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Default Mountain"),"field":field})
	game = load("res://main.tscn").instantiate()
	game.automated = true
	game.benchmark_no_captures = true
	root.add_child(game); current_scene = game
	while not game.initialized: await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.benchmark_no_captures = true
	game.workshop.set_process(false)
	game.session.record_directory = output+"/records"
	game.session.benchmark_path = output+"/benchmark.json"
	game.workshop.store.directory = output+"/library"
	game.effects.muted = true; game.voice.set_muted(true)
	game.sim.tuning.vibration_intensity = 0.0
	game.effects.reset_haptics()
	game.active = false; game.session.eligible = false
	game.camera_settings.reset()
	check(not game.preferences_enabled,"Automated scene never loads/saves personal preferences")
	check(game.field.GENERATOR_VERSION==Definition.CURRENT_VERSION and game.field.seed_value==Definition.DEFAULT_SEED,"Current default Standard terrain fixture")
	game.set_graphics_quality(2)
	game.display_settings.frame_generation = false
	if navigation_500m: game.display_settings.fps_limit = 60
	game.display_settings.apply_viewport(root)
	await set_resolution(Vector2i(3840,2160))
	race = game.workshop.suggested_race
	check(race!=null,"Default suggested race exists")
	if race==null: await finish(); return
	set_weather("clear","day")
	if "--distant-only" not in OS.get_cmdline_user_args(): await _survey_views()
	await game.play_custom_race(race)
	game.active = false; game.session.eligible = false
	check(_gate_count()==2,"Active race retains one collidable gate pair")
	_check_effect_dispatch()
	review_camera = Camera3D.new()
	review_camera.far = game.camera.far
	review_camera.fov = game.camera.fov
	game.add_child(review_camera)
	game.hud.root.hide()
	game.speed_periphery.hide(); game.vectors.hide()
	set_weather("clear","day")
	if "--distant-only" in OS.get_cmdline_user_args():
		if navigation_500m: await _navigation_500m_review()
		else: await _distant_review()
		await finish()
		return
	approaches.race_start = {"position":race.start,"heading":race.heading,"kmh":0.0,"selection":"actual suggested start and authored heading"}
	for distance_m in [500.0,2000.0]:
		var point = distant_position(distance_m,false)
		check(not point.is_empty(),"Found valid skiable approach at %d m" % int(distance_m))
		if not point.is_empty(): approaches["finish_%dm" % int(distance_m)] = point
	for distance_m in [4000.0,3000.0,2500.0]:
		var point = distant_position(distance_m,false)
		if not point.is_empty():
			approaches.farther_approach = point
			break
	var ridge = distant_position(2000.0,true)
	if ridge.is_empty(): ridge = distant_position(850.0,true)
	check(not ridge.is_empty(),"Found skiable ridge hiding base with upper shaft exposed")
	if not ridge.is_empty(): approaches.ridge = ridge
	print("BEAM_SETUP_READY milliseconds=",Time.get_ticks_msec()-setup_started)
	if "--timings-only" not in OS.get_cmdline_user_args():
		await _distance_views()
		if "--full-matrix" in OS.get_cmdline_user_args(): await _weather_matrix()
		await _close_views()
	if "--timings-only" in OS.get_cmdline_user_args() or "--timing" in OS.get_cmdline_user_args(): await _timing_views()
	await _lifecycle_checks()
	await finish()

func _diagnose_selection(field) -> void:
	# Native camera projection with the real cached support and solver state.
	# No main scene, scenery uploads, particles, audio, stores or captures.
	requested_pixels = Vector2i(1920,1080)
	root.size = requested_pixels
	Engine.max_fps = 30
	var settings = CameraSettings.new()
	var tuning = preload("res://config/ski_default.tres").duplicate(true)
	tuning.vibration_intensity = 0.0
	tuning.ground_assist_enabled = "--ground-assist" in OS.get_cmdline_user_args()
	tuning.landing_assist_enabled = "--air-assist" in OS.get_cmdline_user_args()
	game = {"field":field,"sim":Race.Simulation.new(tuning),"camera":Chase.new(),
		"camera_settings":settings,"session":{"eligible":false}}
	game.camera.settings = settings
	game.camera.near = 0.15; game.camera.far = 32000.0
	root.add_child(game.camera)
	for frame in 2: await process_frame
	race = Race.suggested(field,field.seed_value)
	if race==null:
		failures.append("Current cached mountain supplies no suggested race.")
	else:
		race_fixtures.suggested = race.to_data()
		var fixture = _lower_finish_fixture()
		if fixture.is_empty():
			coverage_gaps.append("No complete 500 m / 2 km / ridge fixture selected within this diagnostic budget; no visual acceptance.")
		else:
			race_fixtures.lower_finish = fixture.race.to_data()
			approaches = fixture.approaches
	_write_report()
	print("BEAM_DIAGNOSTIC_RESULT ",JSON.stringify({"fixture_selected":not selected_fixture_data.is_empty(),
		"stop_reason":search_stop_reason,"captures":0,"visual_acceptance":"not_attempted","output":output}))
	game.camera.queue_free()
	await process_frame
	# Always flush diagnostics, but never give an incomplete selection a zero exit.
	quit(0 if failures.is_empty() and not selected_fixture_data.is_empty() else 2)

func _survey_views() -> void:
	game.workshop.open_library(); game.workshop.show_race(race)
	camera = game.workshop.survey
	game.workshop.focus_point = race.start.lerp(race.finish,0.5)
	game.workshop.survey_height = 650.0; game.workshop._update_survey()
	scenario = {"kind":"library survey"}
	if "--timings-only" not in OS.get_cmdline_user_args(): await capture_pair("library_overhead")
	game.workshop.begin_creation()
	game.workshop.place_point(race.start); game.workshop.place_point(race.finish)
	scenario = {"kind":"authoring survey"}
	if "--timings-only" not in OS.get_cmdline_user_args(): await capture_pair("authoring_overhead")
	game.workshop.back_pressed()

func _check_effect_dispatch() -> void:
	var beam = game.workshop.markers.get_node("FinishBeam")
	var before: float = beam.visual_time
	game.active = true; game._process(0.1)
	check(beam.visual_time>before,"Normal presentation advances race beam")
	game.active = false; before = beam.visual_time; game._process(0.1)
	check(beam.visual_time==before,"Pause freezes race beam")
	game.hud.feedback.reduced_motion = true
	game.active = true; game._process(0.1)
	check(beam.visual_time==before and beam.motion_reduced,"Reduced Motion freezes race beam")
	game.hud.feedback.reduced_motion = false; game.active = false

func _distance_views() -> void:
	game.set_graphics_quality(2); set_weather("clear","day")
	for pixels in [Vector2i(1920,1080),Vector2i(3840,2160)]:
		await set_resolution(pixels)
		for label in approaches:
			riding_view(approaches[label])
			await capture_pair("%s_%dp" % [label,pixels.y])
	# Supplemental top view is explicitly separate from ordinary riding evidence.
	game.skier.hide()
	view(race.finish+Vector3(0,1100,-2600),race.finish+Vector3.UP*1000.0)
	scenario = {"kind":"supplemental full-height/fade view; explicit upward aim"}
	await capture_pair("whole_shaft_top_fade")

func _distant_review() -> void:
	var suggested = race
	race_fixtures.suggested = suggested.to_data()
	# Prove the entire bundle BEFORE spending time on any screenshots.
	var fixture = _load_selection() if not selection_report.is_empty() else _lower_finish_fixture()
	check(not fixture.is_empty(),"Complete lower fixture passes final 500 m / 2 km / ridge predicates")
	if fixture.is_empty(): return
	coverage_gaps.append("Lower-finish captures are a separate authored race; they do not establish distant visibility of the near-summit suggested finish.")
	if selection_report.is_empty():
		var start_point = {"position":race.start,"heading":race.heading,"kmh":0.0,
			"selection":"actual suggested start and authored heading","require_visible":true,"min_visible_samples":2}
		for pixels in [Vector2i(1920,1080),Vector2i(3840,2160)]:
			await set_resolution(pixels)
			riding_view(start_point)
			await capture_pair("suggested_start_%dp" % pixels.y)
	race = fixture.race
	race_fixtures.lower_finish = race.to_data()
	await game.play_custom_race(race)
	game.active = false; game.session.eligible = false
	game.hud.root.hide()
	set_weather("clear","day")
	approaches = fixture.approaches
	check(_verify_fixture(race,approaches).is_empty(),"Active race retains the complete selected camera predicates")
	if not failures.is_empty(): return
	if weather_only:
		await _selected_weather_review()
		return
	for pixels in [Vector2i(1920,1080),Vector2i(3840,2160)]:
		await set_resolution(pixels)
		for label in approaches:
			if five_hundred_only and label!="finish_500m": continue
			riding_view(approaches[label])
			await capture_pair("lower_%s_%dp" % [label,pixels.y])
	check(_gate_count()==2 and not game.session.eligible,"Authored review fixture remains one unranked race")
	# Four new images with --500m-only; the full selected bundle is still revalidated.
	if five_hundred_only:
		check(captures.size()==4,"500 m foliage follow-up saved exactly four images")
		coverage_gaps.append("Only 500 m recaptured with settled normal foliage aid; prior suggested-start, 2 km and ridge pixels remain separate evidence. Forest legibility requires fresh pixel review.")
	# Otherwise 12 captures with a diagnostic selection report, or 16 including start.

func _navigation_500m_review() -> void:
	# Exact independent upper anchor; never rewrite the accepted lower 2 km/ridge bundle.
	check(FileAccess.get_sha256(NAVIGATION_SELECTION)==NAVIGATION_SELECTION_SHA256,"Exact navigation v4 selection")
	check(FileAccess.get_sha256(NAVIGATION_REPORT)==NAVIGATION_REPORT_SHA256,"Exact parent-run navigation v4 receipt")
	if not failures.is_empty(): return
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NAVIGATION_SELECTION))
	var native: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NAVIGATION_REPORT))
	check(saved.selection.get("shared_finish_fixture",false) and saved.selection.geometry_selection_complete
		and saved.selection.failures.is_empty(),"Navigation selected a shared finish endpoint, never a navigation-only fallback")
	check(native.failures.is_empty() and native.coverage_failures.is_empty() and native.captures.size()==8
		and native.selection==saved.selection and native.sources==saved.sources,"Matching successful native navigation selection receipt")
	check(Evidence.same_engine(native.engine,Engine.get_version_info()),"Same identified native engine as navigation v4 after JSON numeric normalization")
	check(saved.height_sha256==game.field.height_checksum and saved.obstacle_sha256==game.field.obstacle_checksum
		and native.mountain_identity==Definition.from_field(game.field).identity(),"Pinned navigation terrain, obstacles and mountain identity")
	var current_inputs = Evidence.current_sources(saved.sources)
	check(current_inputs.errors.is_empty(),"Pinned current source/runtime inputs: "+str(current_inputs.errors))
	navigation_sources = current_inputs.sources
	for path in navigation_sources:
		check(FileAccess.get_sha256("res://"+path)==navigation_sources[path],"Navigation source retained: "+path)
	var plan: Dictionary = {}
	for entry in saved.selection.views:
		if entry.label=="navigation_500m_1": plan = entry.duplicate(true)
	check(not plan.is_empty() and plan.get("finish_point_error","missing").is_empty(),"Exact eligible navigation 500 m plan exists")
	if not failures.is_empty(): return
	navigation_provenance = {"selection_path":NAVIGATION_SELECTION,"selection_sha256":NAVIGATION_SELECTION_SHA256,
		"native_report_path":NAVIGATION_REPORT,"native_report_sha256":NAVIGATION_REPORT_SHA256,
		"finish_harness_baseline_sha256":NAVIGATION_FINISH_BASELINE,"current_harness_sha256":sources["tests/race_beams_playtest.gd"],
		"current_inputs":current_inputs,
		"acknowledged_change":"Explicit captured current inputs; old selection/report hashes stay immutable; current terrain, endpoints, camera and pixels revalidated",
		"plan":plan.duplicate(true),"violet_pixels":"Historical native v4 only; current amber requires fresh pixel inspection"}
	plan.position = LandmarkProbe.vec(plan.position); plan.anchor = LandmarkProbe.vec(plan.anchor)
	check(plan.kmh==60.0 and plan.distance_m==500.0 and not plan.ridge,"Retain exact 60 km/h observer and 500 m role")
	check(Race.point_error(plan.anchor,game.field).is_empty() and Race.point_error(plan.position,game.field).is_empty(),
		"Revalidate real supported finish and ordinary observer")
	var suggested = race
	race_fixtures.suggested = suggested.to_data()
	race = Race.new()
	race.title = "Upper 500 m finish visibility review"
	race.mountain = suggested.mountain.duplicate(true)
	race.start = suggested.start; race.heading = suggested.heading
	race.finish = plan.anchor
	race.finish_heading = Race.Flavor.downhill_heading(game.field,race.finish,float(plan.heading))
	var probe = LandmarkProbe.new()
	probe.field = game.field; probe.sim = game.sim; probe.camera = game.camera
	probe.style = Beams.visual_style(true)
	check(probe.prepare_tree_bounds().is_empty(),"Production seated tree bounds ready for wider amber shaft")
	if not failures.is_empty(): return
	# V4 checked point_error only, omitting the wider physical gate clearing.
	# Preserve that failed anchor, then try at most 32 nearby fixes, without moving
	# the observer or changing camera heading, terrain, props, or gate rules.
	var original_anchor: Vector3 = plan.anchor
	var attempts: Array = []
	var qualified = false
	var offsets: Array[Vector2] = [Vector2.ZERO]
	for radius in [4.0,8.0,12.0,16.0]:
		for direction in 8: offsets.append(Vector2.from_angle(TAU*direction/8.0)*radius)
	for offset in offsets:
		var p = original_anchor+Vector3(offset.x,0,offset.y)
		p.y = game.field.sample(p.x,p.z).height
		race.finish = p
		race.finish_heading = Race.Flavor.downhill_heading(game.field,p,float(plan.heading))
		var error: String = race.validate_surface(game.field)
		var candidate: Dictionary = plan.duplicate(true)
		candidate.anchor = p
		candidate.distance_m = Vector2(candidate.position.x-p.x,candidate.position.z-p.z).length()
		var geometry: Dictionary = probe.evaluate(candidate) if error.is_empty() else {}
		attempts.append({"anchor":p,"offset_m":offset,"race_error":error,"geometry_issues":geometry.get("issues",[])})
		if error.is_empty() and geometry.issues.is_empty():
			plan = candidate; qualified = true; break
	navigation_provenance.finish_clearing = {"original_anchor":original_anchor,"attempts":attempts,"candidate_limit":33,"selected":plan.anchor if qualified else null}
	check(qualified,"Actual authored race and amber exposure qualify within the bounded 16 m clearing correction")
	if not qualified: return
	navigation_provenance.plan = LandmarkProbe.json_safe(plan)
	navigation_provenance.horizontal_distance_m = Vector2(plan.position.x-plan.anchor.x,plan.position.z-plan.anchor.z).length()
	race_fixtures.navigation_upper_500m = race.to_data()
	await game.play_custom_race(race)
	game.active = false; game.session.eligible = false; game.hud.root.hide()
	game.set_graphics_quality(2); set_weather("clear","day")
	check(_gate_count()==2,"Upper fixture has one actual collidable gate pair")
	var point = {"position":plan.position,"heading":plan.heading,"kmh":plan.kmh,
		"require_visible":true,"min_visible_samples":3,"selection":"navigation v4 observer with bounded gate-clearing correction"}
	approaches = {"finish_500m":point}
	search_stop_reason = "pinned_observer_bounded_gate_clearing"
	for pixels in [Vector2i(1920,1080),Vector2i(3840,2160)]:
		await set_resolution(pixels)
		var geometry: Dictionary = probe.evaluate(plan)
		check(geometry.issues.is_empty(),"Actual viewport amber height/fade/radius terrain and tree-bound exposure: "+str(geometry.issues))
		riding_view(point)
		check(_navigation_camera_matches(LandmarkProbe.json_safe(geometry.camera)),"Reproduce current production Connected camera at the exact v4 observer without manual aim")
		if not failures.is_empty(): return
		select_variant("proposed")
		var beam = game.workshop.markers.get_node("FinishBeam")
		check(beam.applied_style==probe.style,"Capture uses unmodified production amber style")
		var state = {"ticks":game.sim.ticks,"position":game.sim.position,"velocity":game.sim.velocity,"elapsed":game.session.elapsed}
		var first = captures.size()
		for shown in [false,true]:
			beam.visible = shown
			game.display_settings.reset_history()
			await capture("navigation_finish_500m_%dp_%s" % [pixels.y,"shown" if shown else "hidden"])
			var row: Dictionary = captures[-1]
			row.shown = shown; row.style = probe.style.duplicate(true)
			row.navigation_plan = navigation_provenance.plan.duplicate(true)
			row.amber_probe = LandmarkProbe.json_safe(geometry)
			row.image_sha256 = FileAccess.get_sha256(output+"/"+row.label+".png")
			row.normal_camera_matches_navigation = _navigation_camera_matches(LandmarkProbe.json_safe(geometry.camera))
			check(row.normal_camera_matches_navigation and beam.is_visible_in_tree()==shown,"Held camera and actual shown/hidden beam: "+row.label)
		check(captures[first].foliage_aid==captures[first+1].foliage_aid
			and captures[first].camera==captures[first+1].camera and captures[first].weather==captures[first+1].weather,
			"Matched settled ordinary canopy aid, camera and weather for 500 m shown/hidden")
		check(state=={"ticks":game.sim.ticks,"position":game.sim.position,"velocity":game.sim.velocity,"elapsed":game.session.elapsed},
			"500 m pair keeps solver and session frozen")
	check(captures.size()==4 and measurements.is_empty() and _gate_count()==2 and not game.session.eligible,
		"Exactly four unranked 500 m images; no timing or additional matrix")
	if failures.is_empty():
		selected_fixture_data = {"race_code":race.share_text(),"approaches":approaches.duplicate(true),
			"roles":["500m"],"predicate":"Pinned v4 observer; both actual viewports pass current amber frustum, terrain and seated tree bounds after bounded clearing correction"}
	coverage_gaps.append("Only current amber shown/hidden at the independent upper 500 m anchor. Prior lower 2 km/ridge, start, 800 m before/after and twelve weather images remain separate historical evidence; current source drift is recorded. Amber pixels require parent inspection.")

func _navigation_camera_matches(expected: Dictionary) -> bool:
	if camera!=game.camera or root.get_camera_3d()!=camera: return false
	if camera.global_position.distance_to(LandmarkProbe.vec(expected.position))>.01: return false
	for axis in 3:
		if camera.global_basis[axis].distance_to(LandmarkProbe.vec(expected.basis[axis]))>.0001: return false
	return absf(camera.fov-float(expected.fov))<.001 and absf(camera.near-float(expected.near))<.0001 \
		and absf(camera.far-float(expected.far))<.01 and camera.keep_aspect==int(expected.keep_aspect) \
		and JSON.parse_string(JSON.stringify(game.camera_settings.snapshot()))==JSON.parse_string(JSON.stringify(expected.settings))

func _lower_finish_fixture() -> Dictionary:
	var original = race
	selection_started_ms = Time.get_ticks_msec()
	search_deadline_ms = selection_started_ms+int(search_seconds*1000.0)
	search_stop_reason = "candidate_exhaustion"
	var valid_finishes = 0
	for xz in _finish_positions(original.heading):
		if not _search_time_left():
			search_stop_reason = "time_budget"; break
		if valid_finishes>=candidate_limit:
			search_stop_reason = "valid_finish_budget"; break
		var point = Vector3(xz.x,game.field.sample(xz.x,xz.y).height,xz.y)
		var receipt = {"finish":_vector(point),"status":"checking"}
		finish_candidates.append(receipt)
		var snow_error: String = Race.point_error(point,game.field)
		if not snow_error.is_empty():
			receipt.status = "invalid_snow"; receipt.reason = snow_error; continue
		var candidate = Race.decode(original.share_text()).race
		candidate.title = "Finish beam lower mountain review"
		candidate.finish = point
		candidate.finish_heading = Race.Flavor.downhill_heading(game.field,point,atan2(point.x,point.z))
		var gate_error: String = candidate.validate_surface(game.field)
		if not gate_error.is_empty():
			receipt.status = "invalid_gate"; receipt.reason = gate_error; continue
		valid_finishes += 1
		print("BEAM_PREFLIGHT lower_finish=",valid_finishes," anchor=",point)
		# Every selected view must pass the SAME settled camera predicate as capture.
		var far = distant_position(2000.0,false,point,true)
		if far.is_empty():
			receipt.status = "no_2000m_extension"; continue
		var near_view = distant_position(500.0,false,point,false)
		if near_view.is_empty():
			receipt.status = "no_500m_view"; continue
		var ridge: Dictionary = {}
		# Ridge distance was not a task constraint; record the actual distance.
		# Keep lower-100 m occlusion and visible >800 m shaft requirements intact.
		for distance_m in [2000.0,1500.0,2500.0,1000.0]:
			if not _search_time_left(): break
			ridge = distant_position(distance_m,true,point,true)
			if not ridge.is_empty(): break
		if ridge.is_empty():
			receipt.status = "no_ridge_extension"; continue
		var views = {"finish_500m":near_view,"finish_2000m":far,"ridge":ridge}
		var issues = _verify_fixture(candidate,views)
		if not issues.is_empty():
			receipt.status = "final_predicate_rejected"; receipt.issues = issues; continue
		receipt.status = "complete"
		search_stop_reason = "complete"
		_freeze_selection(candidate,views)
		selection_elapsed_ms = Time.get_ticks_msec()-selection_started_ms
		return {"race":candidate,"approaches":views}
	if not _search_time_left(): search_stop_reason = "time_budget"
	selection_elapsed_ms = Time.get_ticks_msec()-selection_started_ms
	return {}

func _finish_positions(heading: float) -> Array[Vector2]:
	# Measured valid gate from distant-frustum-parent; every point is revalidated.
	var measured = Vector2(2247.85302734375,1306.58215332031)
	var points: Array[Vector2] = [measured]
	for radius in [80.0,160.0,320.0]:
		for step in 12:
			points.append(measured+Vector2.from_angle(TAU*float(step)/12.0)*radius)
	for radius in [1400.0,1800.0,2200.0,2600.0,2900.0]:
		for step in 24:
			var angle = heading+TAU*float(step)/24.0
			points.append(Vector2(sin(angle),cos(angle))*radius)
	return points

func _search_time_left() -> bool:
	return search_deadline_ms==0 or Time.get_ticks_msec()<search_deadline_ms

func _verify_fixture(candidate, views: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var surface_error: String = candidate.validate_surface(game.field)
	if not surface_error.is_empty(): issues.append(surface_error); return issues
	for label in ["finish_500m","finish_2000m","ridge"]:
		if not views.has(label) or views[label].is_empty():
			issues.append(label+": missing view"); continue
		var point: Dictionary = views[label]
		# Restore the mandatory contract independently of saved/report booleans.
		point.require_visible = true; point.min_visible_samples = 3
		point.require_ridge = label=="ridge"
		point.require_extension = label!="finish_500m"
		point.min_extension_samples = 3
		var snow_error: String = Race.point_error(point.position,game.field)
		if not snow_error.is_empty(): issues.append(label+": "+snow_error); continue
		if point.kmh not in [60.0,120.0]: issues.append(label+": unsupported review speed"); continue
		var distance = Vector2(point.position.x-candidate.finish.x,point.position.z-candidate.finish.z).length()
		var expected = 500.0 if label=="finish_500m" else 2000.0 if label=="finish_2000m" else float(point.requested_horizontal_distance_m)
		if absf(distance-expected)>0.1: issues.append(label+": distance mismatch"); continue
		_place_riding_camera(point,60)
		var visibility = _shaft_visibility(candidate.finish)
		for reason in _view_issues(visibility,point): issues.append(label+": "+reason)
		point.selection_visibility = visibility
	return issues

func _freeze_selection(candidate, views: Dictionary) -> void:
	selected_fixture_data = {"race_code":candidate.share_text(),"approaches":views.duplicate(true),
		"predicate":"three in-frame terrain-clear samples; 2 km/ridge three >800 m; ridge lower 100 m hidden; full 60-frame camera settle"}

func _load_selection() -> Dictionary:
	selection_started_ms = Time.get_ticks_msec()
	var path = selection_report if selection_report.begins_with("res://") else "res://"+selection_report
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("selected_fixture",{}).is_empty():
		coverage_gaps.append("Selection report contains no complete fixture."); return {}
	if parsed.get("height_sha256","")!=game.field.height_checksum or parsed.get("obstacle_sha256","")!=game.field.obstacle_checksum:
		coverage_gaps.append("Selection report terrain identity is stale."); return {}
	selection_provenance = {"report_path":path,"report_sha256":FileAccess.get_sha256(path),
		"producer_harness_sha256":parsed.get("source_sha256",{}).get("tests/race_beams_playtest.gd",""),
		"current_harness_sha256":sources["tests/race_beams_playtest.gd"],"acknowledged_harness_only_revision":false}
	for source in sources:
		var producer_hash: String = parsed.get("source_sha256",{}).get(source,"")
		if five_hundred_only and source=="tests/race_beams_playtest.gd" and producer_hash==FOLIAGE_REVIEW_SELECTION_HARNESS:
			continue # Exact old fixture producer; all three views are revalidated below.
		if weather_only and source=="tests/race_beams_playtest.gd" and producer_hash in WEATHER_SELECTION_HARNESSES:
			selection_provenance.acknowledged_harness_only_revision = producer_hash!=sources[source]
			continue # Explicit fixture-only revision; never a production source waiver.
		if producer_hash!=sources[source]:
			coverage_gaps.append("Selection report source changed: "+source); return {}
	var decoded = Race.decode(parsed.selected_fixture.get("race_code",""))
	if not decoded.has("race"): return {}
	var views: Dictionary = parsed.selected_fixture.get("approaches",{}).duplicate(true)
	for label in views:
		var coordinates = views[label].get("position",[])
		if not coordinates is Array or coordinates.size()!=3: return {}
		views[label].position = Vector3(coordinates[0],coordinates[1],coordinates[2])
	var issues = _verify_fixture(decoded.race,views)
	if not issues.is_empty():
		coverage_gaps.append("Selection report failed current final predicates: "+str(issues)); return {}
	_freeze_selection(decoded.race,views)
	search_stop_reason = "loaded_and_revalidated"
	selection_elapsed_ms = Time.get_ticks_msec()-selection_started_ms
	return {"race":decoded.race,"approaches":views}

func _selected_weather_review() -> void:
	# Three covering cases, two resolutions, two variants. No search or full matrix.
	for entry in WEATHER_COVER:
		weather_case = entry.duplicate(true)
		game.set_graphics_quality(int(entry.level))
		set_weather(entry.preset,entry.period)
		for pixels in [Vector2i(1920,1080),Vector2i(3840,2160)]:
			await set_resolution(pixels)
			riding_view(approaches[entry.view])
			var issues = _view_issues(_shaft_visibility(race.finish),scenario)
			check(issues.is_empty(),"Selected weather view retains actual-viewport geometry: "+str(entry)+str(issues))
			if not failures.is_empty(): return
			await capture_pair("weather_%s_%s_%s_%dp" % [entry.view,entry.quality,weather_label,pixels.y])
			if not failures.is_empty(): return
	check(captures.size()==12,"Selected weather cover saved exactly twelve images")
	check(_gate_count()==2 and not game.session.eligible,"Weather cover remains the same unranked authored race")
	coverage_gaps.append("Three weather/quality combinations only; prior High clear-day and close/fade pixels remain separate evidence. Visibility requires image inspection; no exhaustive combination or performance claim.")

func _weather_render_metadata() -> Dictionary:
	var state = {}
	for key in game.weather.state.FIELDS+[
			"enabled","label","time_label","time_hour","sun_direction","moon_energy","gust","visual_time","cloud_offset"]:
		state[key] = game.weather.state.get(key)
	var particles: Array = []
	for particle in game.weather_effects.volumes+game.weather_effects.drifts:
		particles.append({"amount":particle.amount,"visible":particle.visible,"emitting":particle.emitting,
			"speed_scale":particle.speed_scale,"use_fixed_seed":particle.use_fixed_seed,"seed":particle.seed})
	return {"state":state,"graphics":game.graphics.snapshot(),"graphics_preset":game.graphics.preset_id,
		"fx_quality":game.weather_effects.quality,"particle_budget":game.weather_effects.particle_budget(),
		"particles":particles,"controller_clock":"held; no front/daylight/solver progression",
		"particle_timing":"same seeds/reset and 30 warm frames; GPU elapsed-time particle positions are not pixel-exact"}

func _check_weather_capture(label: String) -> void:
	check(game.graphics.level==int(weather_case.level) and game.graphics.label()==weather_case.quality,
		"Requested graphics tier captured "+label)
	check(game.weather.selected_preset==weather_case.preset and game.weather.state.time_label.to_lower()==weather_case.period
		and not game.weather.automatic and not game.weather.daylight.automatic,"Requested held weather/daylight captured "+label)
	check(game.weather.state.storm<0.002 and game.weather.state.thunder<0.002,"Ordinary non-storm cover "+label)
	if weather_case.preset=="snowfall":
		check(game.weather.state.enabled and game.weather.state.snow>0.002
			and game.weather_effects.quality==2 and game.weather_effects.volumes[0].visible
			and game.weather_effects.volumes[0].emitting,"High ordinary snowfall is actually enabled "+label)
	else:
		check(game.weather.state.snow<0.002 and game.weather.state.rain<0.002,"Clear cover has no precipitation "+label)

func _weather_matrix() -> void:
	for pixels in [Vector2i(1920,1080),Vector2i(3840,2160)]:
		await set_resolution(pixels)
		for level in [0,1,2]:
			game.set_graphics_quality(level)
			for setting in [["clear","day"],["clear","dusk"],["clear","night"],["snowfall","day"]]:
				set_weather(setting[0],setting[1])
				for label in ["finish_2000m","ridge"]:
					if not approaches.has(label): continue
					riding_view(approaches[label])
					await capture_pair("%s_%s_%s_%dp" % [label,game.graphics.label().to_lower(),weather_label,pixels.y])

func _close_views() -> void:
	game.set_graphics_quality(2); set_weather("clear","day")
	await set_resolution(Vector2i(3840,2160))
	game.skier.hide()
	close_view(race.start,race.heading)
	scenario = {"kind":"start close"}
	await capture("start_close")
	close_view(race.finish,race.finish_heading)
	scenario = {"kind":"finish close"}
	await capture_pair("finish_close")
	var basis = Basis(Vector3.UP,race.finish_heading)
	for offset in [-4.0,0.0,4.0]:
		var p: Vector3 = race.finish+basis*Vector3(0,0,offset)
		p.y = game.field.sample(p.x,p.z).height+1.7
		view(p,p+basis*Vector3(0,0,20))
		scenario = {"kind":"close passage","offset_m":offset}
		await capture("passage_%s" % str(offset).replace("-","minus"))
	close_view(race.finish,race.finish_heading)
	scenario = {"kind":"paused close"}
	animate = false; await capture("finish_paused")
	reduced_motion = true; scenario.kind = "reduced motion close"
	await capture("finish_reduced_motion")
	animate = true; reduced_motion = false
	if "--motion" in OS.get_cmdline_user_args():
		await set_resolution(Vector2i(1920,1080))
		for frame in 30:
			_tick_effects(1.0/30.0); await process_frame; await RenderingServer.frame_post_draw
			_save_image("motion_%03d" % frame)

func _timing_views() -> void:
	game.set_graphics_quality(2); set_weather("clear","day")
	await set_resolution(Vector2i(3840,2160))
	for label in ["near_gate","finish_2000m"]:
		if label=="near_gate":
			game.skier.hide(); close_view(race.finish,race.finish_heading)
			scenario = {"kind":"finish close"}
		elif approaches.has(label): riding_view(approaches[label])
		else: continue
		# Bounded advisory diagnostic; extensive clean matrices require opt-in.
		for repetition in 1:
			for selection in ["baseline","proposed"]:
				select_variant(selection)
				var sample = await measure()
				sample.view = label; sample.repetition = repetition+1
				measurements.append(sample)
				print("BEAM_SAMPLE ",JSON.stringify(sample))
	select_variant("proposed")

func _lifecycle_checks() -> void:
	select_variant("proposed")
	game.restart(); game.active = false; game.session.eligible = false
	check(_gate_count()==2,"Retry retains one collidable gate pair")
	check(game.workshop.markers.get_node("FinishBeam").applied_style.height_m==Beams.FINISH_HEIGHT_M,"Retry retains tall finish")
	var other = Race.decode(race.share_text()).race
	other.title = "Finish beam isolated alternate"
	await game.play_custom_race(other)
	game.active = false; game.session.eligible = false
	check(_gate_count()==2 and game.workshop.markers.get_node("FinishBeam").applied_style.height_m==Beams.FINISH_HEIGHT_M,"Race switch replaces visuals with one tall finish")
	game.start_run(false); game.active = false; game.session.eligible = false
	check(game.workshop.markers.get_child_count()==0,"Free skiing removes race visuals")
	check(_gate_count()==0,"Free skiing removes only race collision")
	check(not game.session.eligible,"All samples and lifecycle checks remain unranked")

func _gate_count() -> int:
	return game.world.ski_surface.groups.size()-game.world.flavor.props.size()

func select_variant(selection: String) -> void:
	variant = selection
	var old = game.workshop.markers.get_node_or_null("FinishBeam")
	if old:
		game.workshop.markers.remove_child(old); old.queue_free()
	var beam = Baseline.new() if selection=="baseline" else Beams.new()
	beam.name = "FinishBeam"; game.workshop.markers.add_child(beam)
	beam.build(race.finish,true,game.field)
	_reset_effect_clock()
	game.display_settings.reset_history()

func _reset_effect_clock() -> void:
	for beam in get_nodes_in_group("race_beam_vfx"):
		beam.visual_time = 0.0
		beam.material.set_shader_parameter("visual_time",0.0)
		if beam.base_material!=null: beam.base_material.set_shader_parameter("visual_time",0.0)
		beam.update_effect(0.0,false,reduced_motion)

func riding_view(point: Dictionary) -> void:
	_place_riding_camera(point,60)
	game.sim.reset_pose_history(); game.skier.reset_animation(game.sim)
	game.skier.pose(game.sim,1.0); game.skier.show()
	scenario = point.duplicate()
	scenario.kind = "stationary production Connected chase; no manual look or upward aim"
	scenario.filtered_slope_degrees = rad_to_deg(game.camera.slope_pitch)
	game.display_settings.reset_history()

func _place_riding_camera(point: Dictionary, settle_frames: int) -> void:
	var position: Vector3 = point.position
	game.sim.reset(position,point.heading); game.sim.prime_contacts(game.field)
	game.sim.velocity = game.sim.support_basis().z*float(point.kmh)/3.6
	game.camera.close_view = false; game.camera.effects_enabled = true; game.camera.reset()
	camera_settle_trace = []
	for frame in settle_frames:
		game.camera.update_camera(game.sim,game.field,position,1.0/60.0,false,true,false)
		if frame in [0,11,59]:
			camera_settle_trace.append({"frame":frame+1,"position":_vector(game.camera.global_position),
				"rotation":_vector(game.camera.global_rotation),"fov":game.camera.fov,
				"slope_degrees":rad_to_deg(game.camera.slope_pitch)})
	camera = game.camera; camera.current = true

func view(position: Vector3, target: Vector3) -> void:
	camera = review_camera
	camera.global_position = position; camera.look_at(target); camera.current = true
	game.display_settings.reset_history()

func close_view(point: Vector3, yaw: float) -> void:
	var p = point+Basis(Vector3.UP,yaw)*Vector3(12,3,-27)
	p.y = maxf(p.y,game.field.sample(p.x,p.z).height+2.0)
	view(p,point+Vector3.UP*4.0)

func set_weather(preset: String, period: String) -> void:
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.weather.set_preset(preset); game.weather.set_time_of_day(period)
	game.world.update_weather(game.weather.state,0.0,false)
	game.weather_effects.reset()
	weather_label = preset+"_"+period

func set_resolution(pixels: Vector2i) -> void:
	requested_pixels = pixels
	game.display_settings.display_mode = "windowed"
	game.display_settings.apply_display(root,pixels)
	game.display_settings.apply_viewport(root)
	for frame in 3: await process_frame

func visible_segment(origin: Vector3, target: Vector3) -> bool:
	var count = maxi(2,ceili(Vector2(origin.x-target.x,origin.z-target.z).length()/4.0))
	for i in range(1,count):
		var p = origin.lerp(target,float(i)/count)
		if game.field.sample(p.x,p.z).height>p.y: return false
	return true

func distant_position(distance_m: float, require_ridge: bool, target: Vector3 = Vector3.INF, require_extension: bool = false) -> Dictionary:
	var started = Time.get_ticks_msec()
	if not target.is_finite(): target = race.finish
	var best: Dictionary = {}
	var best_score = -1
	var rejected: Dictionary = {}
	var closest: Array = []
	var examined = 0
	var passing = 0
	# Prefer 60 km/h. Only try ordinary 120 km/h framing when 60 finds no view.
	# No custom lens/profile/tilt; each static speed is recorded explicitly.
	for kmh in [60.0,120.0]:
		for i in 144:
			if not _search_time_left(): break
			examined += 1
			var direction = Vector2.from_angle(TAU*float(i)/144.0)
			var p: Vector3 = target+Vector3(direction.x,0,direction.y)*distance_m
			p.y = game.field.sample(p.x,p.z).height
			var snow_error: String = Race.point_error(p,game.field)
			if not snow_error.is_empty():
				var reason = "invalid_snow: "+snow_error
				rejected[reason] = rejected.get(reason,0)+1
				continue
			var toward = target-p
			var candidate = {"position":p,"heading":atan2(toward.x,toward.z),"kmh":kmh,
				"selection":"valid snow plus 60-frame production Connected chase and final capture predicate; no manual look",
				"requested_horizontal_distance_m":distance_m,"require_ridge":require_ridge,
				"require_extension":require_extension,"require_visible":true,
				"min_visible_samples":3,"min_extension_samples":3}
			_place_riding_camera(candidate,60)
			var visibility = _shaft_visibility(target)
			var issues = _view_issues(visibility,candidate)
			var score: int = visibility.exposed_heights.size()+visibility.extension_heights.size()*2
			if not issues.is_empty():
				for reason in issues: rejected[reason] = rejected.get(reason,0)+1
				closest.append({"position":_vector(p),"heading":candidate.heading,"kmh":kmh,
					"issues":issues,"score":score,"visibility":visibility})
				closest.sort_custom(func(a,b): return a.score>b.score)
				if closest.size()>3: closest.resize(3)
				continue
			passing += 1
			if score>best_score:
				best_score = score
				best = candidate
				best.selection_visibility = visibility
				best.selection_camera_trace = camera_settle_trace.duplicate(true)
		if not best.is_empty() or not _search_time_left(): break
	search_receipts.append({"target":_vector(target),"distance_m":distance_m,"ridge":require_ridge,
		"require_extension":require_extension,"candidates_examined":examined,"passing":passing,
		"rejections":rejected,"closest_rejected":closest,"time_budget_exhausted":not _search_time_left(),
		"milliseconds":Time.get_ticks_msec()-started,"selected":best.duplicate(true)})
	print("BEAM_SEARCH distance=",distance_m," ridge=",require_ridge," candidates=",examined,
		" passing=",passing," rejected=",JSON.stringify(rejected))
	return best

func _shaft_visibility(target: Vector3) -> Dictionary:
	var heights: Array = []
	var extension: Array = []
	var in_frame: Array = []
	var origin = camera.global_position
	# Exclude viewport edges and faded top when selecting a useful visible shaft.
	var viewport_frame = root.get_visible_rect()
	var safe_frame = viewport_frame.grow(-viewport_frame.size.y*0.03)
	for height in range(25,1601,25):
		var point = target+Vector3.UP*float(height)
		if not _in_frame(point,safe_frame): continue
		in_frame.append(height)
		if not visible_segment(origin,point): continue
		heights.append(height)
		if height>800: extension.append(height)
	return {"in_frame_heights":in_frame,"exposed_heights":heights,"extension_heights":extension,
		"base_clear":visible_segment(origin,target+Vector3.UP*5.0),
		"hundred_m_clear":visible_segment(origin,target+Vector3.UP*100.0),
		"camera":_vector(origin),"pitch_degrees":rad_to_deg(camera.global_rotation.x),
		"fov_degrees":camera.fov,"camera_rotation":_vector(camera.global_rotation),
		"viewport_size":viewport_frame.size,
		"finish_base_elevation_degrees":rad_to_deg(atan2(target.y-origin.y,Vector2(target.x-origin.x,target.z-origin.z).length())),
		"note":"Geometric preflight only; rendered inspection still required."}

func _view_issues(visibility: Dictionary, point: Dictionary) -> Array[String]:
	# Single predicate for selection, complete-bundle validation and final capture.
	var issues: Array[String] = []
	var minimum: int = point.get("min_visible_samples",2)
	if visibility.exposed_heights.size()<minimum:
		issues.append("shaft_outside_frustum" if visibility.in_frame_heights.is_empty()
			else "insufficient_terrain_clear_samples")
	if point.get("require_ridge",false) and (visibility.base_clear or visibility.hundred_m_clear):
		issues.append("ridge_lower_100m_not_hidden")
	if point.get("require_extension",false) and visibility.extension_heights.size()<int(point.get("min_extension_samples",3)):
		issues.append("insufficient_above_800m_samples")
	return issues

func _in_frame(point: Vector3, frame: Rect2) -> bool:
	var depth = -camera.to_local(point).z
	return depth>=camera.near and depth<=camera.far and frame.has_point(camera.unproject_position(point))

func _ordinary_riding_view() -> bool:
	return camera==game.camera and scenario.has("kmh")

func _update_foliage_aid(dt: float) -> void:
	# Same actor, settings and presentation API as main._process. The solver is
	# frozen for comparison, but this ordinary chase view represents active riding.
	game.world.assets.update_foliage_sight(camera,game.skier.global_position,dt,
		_ordinary_riding_view(),game.camera_settings.shared.forest_visibility,
		game.camera_settings.shared.forest_visibility_strength)

func _tick_effects(dt: float) -> void:
	_update_foliage_aid(dt)
	call_group("race_beam_vfx","update_effect",dt,animate,reduced_motion)
	game.weather_effects.update_weather(game.weather.state,camera,camera.global_position,game.field,dt,false,animate,0.0,game.graphics.weather_quality)

func capture_pair(label: String) -> void:
	var first = captures.size()
	for selection in ["baseline","proposed"]:
		select_variant(selection)
		if weather_only:
			var particles = game.weather_effects.volumes+game.weather_effects.drifts
			for index in particles.size():
				particles[index].use_fixed_seed = true; particles[index].seed = 7100+index
			game.weather_effects.reset()
		await capture(label+"_"+selection)
	if _ordinary_riding_view():
		check(captures[first].foliage_aid==captures[first+1].foliage_aid,"Matched normal foliage aid "+label)
	if weather_only:
		check(captures[first].weather==captures[first+1].weather
			and captures[first].weather_render==captures[first+1].weather_render,"Matched weather and quality inputs "+label)

func capture(label: String) -> void:
	camera.current = true
	if _ordinary_riding_view():
		# Reset and settle the real cosmetic transition, exactly as the camera is
		# settled above. No direct shader override, changed strength or tree removal.
		game.world.assets.foliage_sight.initialized = false
		for frame in 60: _update_foliage_aid(1.0/60.0)
		check(is_equal_approx(game.world.assets.foliage_sight.parameters.x,1.0),"Normal riding canopy aid settled "+label)
	_reset_effect_clock()
	for frame in 30:
		_tick_effects(1.0/60.0); await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_camera_3d()==camera,"Expected camera owns capture "+label)
	var pixels = _save_image(label)
	check(pixels==requested_pixels,"Capture pixels match "+label)
	var metadata = _view_metadata()
	if weather_only:
		metadata.weather_case = weather_case.duplicate(true)
		metadata.weather_render = _weather_render_metadata()
		_check_weather_capture(label)
	if variant=="proposed" and scenario.get("require_visible",false):
		var visibility = _shaft_visibility(race.finish)
		var issues = _view_issues(visibility,scenario)
		check(issues.is_empty(),"Final ordinary-view predicate "+label+": "+str(issues))
		metadata.visibility_check = visibility
	metadata.label = label; metadata.pixels = [pixels.x,pixels.y]
	captures.append(metadata)
	print("BEAM_CAPTURE ",label)

func _save_image(label: String) -> Vector2i:
	var captured = root.get_texture().get_image()
	check(captured.save_png(output+"/"+label+".png")==OK,"Saved "+label)
	return captured.get_size()

func _view_metadata() -> Dictionary:
	var aid: Vector4 = game.world.assets.foliage_sight.parameters
	var height_m = 800.0 if variant=="baseline" else Beams.FINISH_HEIGHT_M
	var segments: Array = []
	for step in range(0,81):
		var height: float = height_m*float(step)/80.0
		var point: Vector3 = race.finish+Vector3.UP*height
		var in_front = not camera.is_position_behind(point)
		var in_frame = in_front and root.get_visible_rect().has_point(camera.unproject_position(point))
		segments.append({"height_m":height,"in_frame":in_frame,"terrain_clear":visible_segment(camera.global_position,point),
			"inside_far_clip":-camera.to_local(point).z<=camera.far})
	return {"variant":variant,"beam_height_m":height_m,"fade_start_m":600.0 if variant=="baseline" else 1600.0,
		"radius_m":6.0,"buried_m":8.0,"camera":_vector(camera.global_position),"camera_rotation":_vector(camera.global_rotation),
		"fov_degrees":camera.fov,"near_m":camera.near,"far_m":camera.far,"keep_aspect":camera.keep_aspect,
		"distance_3d_m":camera.global_position.distance_to(race.finish),
		"distance_horizontal_m":Vector2(camera.global_position.x-race.finish.x,camera.global_position.z-race.finish.z).length(),
		"scenario":scenario.duplicate(true),"weather":game.weather.snapshot(),"quality":game.graphics.label(),
		"race_identity":race.identity(),"finish_anchor":_vector(race.finish),"camera_settle_trace":camera_settle_trace.duplicate(true),
		"display":game.display_settings.report(root,requested_pixels),"camera_profile":game.camera_settings.snapshot(),
		"shaft_samples":segments,"shaft_sampling_note":"4 m terrain LOS only; excludes fog, props and pixel visibility. Inspect rendered images.",
		"foliage_aid":{"parameters":[aid.x,aid.y,aid.z,aid.w],"riding":_ordinary_riding_view(),
			"actor":_vector(game.skier.global_position),"reach_percent":game.camera_settings.shared.forest_visibility,
			"transparency_percent":game.camera_settings.shared.forest_visibility_strength},
		"animate":animate,"reduced_motion":reduced_motion}

func measure() -> Dictionary:
	var rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	# Terrain probes and metadata allocation are outside warmup and timing.
	var metadata = _view_metadata()
	_reset_effect_clock(); game.display_settings.reset_history()
	var warmup_started = Time.get_ticks_usec()
	while float(Time.get_ticks_usec()-warmup_started)/1000000.0<2.0:
		_tick_effects(1.0/60.0); await process_frame
	var frames: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var unfocused = 0
	var started = Time.get_ticks_usec()
	var previous = started
	while float(Time.get_ticks_usec()-started)/1000000.0<SAMPLE_SECONDS:
		_tick_effects(1.0/60.0); await process_frame
		var now = Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0); previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		if not root.has_focus(): unfocused += 1
	return {"frame_ms":game._timing_summary(frames),"render_cpu_ms":game._timing_summary(cpu),
		"gpu_ms":game._timing_summary(gpu),"sample_seconds":float(previous-started)/1000000.0,
		"warmup_seconds":2.0,"frame_count":frames.size(),"unfocused_frames":unfocused,
		"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"settings":metadata,"scope":"stationary rendered scene; no readback, no riding or generated FPS claim"}

func _snapshot_personal_files() -> void:
	for path in ["user://camera_v2.cfg","user://graphics_v2.cfg","user://display_v1.cfg",
			"user://weather_v1.cfg","user://benchmark_v1.json"]:
		personal_files[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

func _write_report() -> void:
	var report = {"failures":failures,"captures":captures,"measurements":measurements,"source_sha256":sources,
		"foliage_source_sha256":foliage_sources,"five_hundred_only":five_hundred_only,
		"navigation_500m":navigation_500m,"navigation_provenance":navigation_provenance,"navigation_source_sha256":navigation_sources,
		"weather_only":weather_only,"weather_cover":WEATHER_COVER if weather_only else [],
		"weather_source_sha256":weather_sources,"selection_provenance":selection_provenance,
		"engine":Engine.get_version_info().string,"runtime_path":OS.get_executable_path(),
		"device":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"args":OS.get_cmdline_user_args(),"approaches":approaches,
		"race_fixtures":race_fixtures,"search_receipts":search_receipts,"coverage_gaps":coverage_gaps,
		"run_kind":"selection_diagnostics" if diagnostics_only else "native_render_review",
		"visual_acceptance":"not_attempted" if diagnostics_only else "requires_image_inspection",
		"geometry_selection_complete":not selected_fixture_data.is_empty(),
		"selected_fixture":selected_fixture_data,"selection_report_input":selection_report,
		"finish_candidates":finish_candidates,"selection_elapsed_ms":selection_elapsed_ms,
		"search_stop_reason":search_stop_reason,"search_budget_seconds":search_seconds,"valid_finish_budget":candidate_limit,
		"farther_approach_available":approaches.has("farther_approach"),
		"scope":"stationary native comparisons; rendered review and human acceptance require inspection"}
	if game!=null:
		report.merge({"unranked":not game.session.eligible,"seed":game.field.seed_value,
			"version":game.field.GENERATOR_VERSION,"height_sha256":game.field.height_checksum,
			"obstacle_sha256":game.field.obstacle_checksum,"race":race.to_data() if race!=null else {},
			"setup_and_total_ms":Time.get_ticks_msec()-setup_started})
	preload("res://tests/test_report.gd").write(output+"/report.json",JSON.stringify(_json_safe(report),"\t"))

func _vector(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _json_safe(value: Variant) -> Variant:
	if value is Vector3: return _vector(value)
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Color: return [value.r,value.g,value.b,value.a]
	if value is Dictionary:
		var result = {}
		for key in value: result[key] = _json_safe(value[key])
		return result
	if value is Array:
		var result = []
		for item in value: result.append(_json_safe(item))
		return result
	return value

func finish() -> void:
	for path in navigation_sources:
		check(FileAccess.get_sha256("res://"+path)==navigation_sources[path],"Navigation source stayed unchanged: "+path)
	for path in sources:
		check(FileAccess.get_sha256("res://"+path)==sources[path],"Source stayed unchanged: "+path)
	for path in foliage_sources:
		check(FileAccess.get_sha256("res://"+path)==foliage_sources[path],"Foliage source stayed unchanged: "+path)
	for path in weather_sources:
		check(not weather_sources[path].is_empty() and FileAccess.get_sha256("res://"+path)==weather_sources[path],"Weather/quality source stayed unchanged: "+path)
	for path in personal_files:
		var current = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		check(current==personal_files[path],"Personal file unchanged: "+path)
	_write_report()
	print("RACE_BEAMS_RESULT ",JSON.stringify({"failures":failures,"captures":captures.size(),"measurements":measurements.size(),"output":output}))
	if game!=null:
		game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
