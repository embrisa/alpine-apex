extends RefCounted
## Select only missing evidence within the existing harness's single Main load.
const Probe = preload("res://tests/session_navigation_landmark_probe.gd")
const Navigation = preload("res://scripts/racing/session_navigation.gd")
const Beams = preload("res://scripts/presentation/session_navigation_beams.gd")
const SEED = "res://artifacts/orchestration_20260912/navigation/landmark-preflight-parent-v4/report.json"
const SEED_SHA = "853587ccd05a022898bef91ccf2e184cd13c511be91f3c0efc7784a3385fe962"
const Evidence = preload("res://tests/session_navigation_evidence.gd")
var seed: Dictionary = {}
var plan: Dictionary = {}
var probe = Probe.new()
var owner
var game
var private_files: Dictionary = {}
var personal_inventory: Dictionary = {}
var loading_estimate_before = ""
var evidence = {"seed":SEED,"seed_sha256":SEED_SHA,"count_fixtures":[],"reduced_motion":[],
	"scope":"Selected missing evidence only; selected native UI checks and no repeated v4 landmark matrix. No visual acceptance from geometry or timing."}

func prepare(parent) -> bool:
	owner = parent
	if FileAccess.get_sha256(SEED)!=SEED_SHA:
		owner.audit.check(false,"Exact pixel-reviewed v4 seed report required"); return false
	seed = JSON.parse_string(FileAccess.get_file_as_string(SEED))
	var current = Evidence.current_sources(seed.sources)
	evidence.current_inputs = current
	owner.audit.check(not current.note.is_empty() and current.errors.is_empty(),"Follow-up requires captured current source/runtime inputs: "+str(current.errors))
	owner.sources.merge(current.sources,true)
	owner.sources["tests/session_navigation_evidence.gd"] = FileAccess.get_sha256("res://tests/session_navigation_evidence.gd")
	owner.audit.check(Evidence.same_engine(seed.engine,Engine.get_version_info()),"Same engine identity after JSON numeric normalization")
	for path in ["tests/session_navigation_followup.gd","scripts/core/run_session.gd","scripts/core/ski_simulation.gd",
		"config/ski_default.tres","scripts/racing/run_replay.gd","scripts/racing/competitive_record.gd",
		"scripts/presentation/skier_visual.gd","scripts/presentation/skier_animation.gd",
		"scripts/presentation/skier_pose_writer.gd","scripts/presentation/skier_animation_tuning.gd",
		"scripts/presentation/pole_push_pose.gd","scripts/presentation/ghost_pose.gd"]:
		owner.sources[path] = FileAccess.get_sha256("res://"+path)
	evidence.replay_version = preload("res://scripts/racing/run_replay.gd").VERSION
	evidence.archive_version = preload("res://scripts/racing/competitive_record.gd").VERSION
	evidence.pose_context = "Current pose pipeline; exact captured source hashes are authoritative"
	for item in seed.selection.views:
		if item.label=="navigation_500m_1":
			plan = item.duplicate(true)
			plan.position = Probe.vec(item.position); plan.anchor = Probe.vec(item.anchor)
	owner.audit.check(not plan.is_empty(),"V4 has its actual pixel-reviewed supported 500 m plan")
	for path in ["user://camera_v2.cfg","user://graphics_v2.cfg","user://display_v1.cfg","user://weather_v1.cfg","user://benchmark_v1.json"]:
		private_files[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	personal_inventory = persistent_files()
	loading_estimate_before = FileAccess.get_sha256("user://generation_measurements_v18.json")
	if not owner.audit.failures.is_empty():
		preload("res://tests/test_report.gd").write(owner.OUTPUT+"/preflight_failure.json",JSON.stringify({"failures":owner.audit.failures,"sources":owner.sources},"\t"))
	return owner.audit.failures.is_empty()

func run(parent, tasks: Array[String]) -> Dictionary:
	owner = parent; game = owner.game
	owner.audit.check(game.field.height_checksum==seed.height_sha256 and game.field.obstacle_checksum==seed.obstacle_sha256,"Follow-up uses the exact reviewed terrain/obstacles")
	if not owner.audit.failures.is_empty(): return Probe.json_safe(evidence)
	owner.audit.check(game.workshop.navigation_state.count()==0,"A new native application session starts with no personal markers")
	game.workshop.set_process(false)
	game.workshop.store.directory = owner.OUTPUT+"/library"
	game.camera_settings.reset()
	game.display_settings.display_mode = "windowed"
	game.display_settings.apply_display(owner.root,Vector2i(1920,1080))
	game.set_graphics_quality(2)
	game.display_settings.frame_generation = false
	game.display_settings.apply_viewport(owner.root)
	owner.set_weather("clear","day")
	game.workshop._clear_markers()
	game.hud.feedback.reduced_motion = false
	probe.field = game.field; probe.sim = game.sim; probe.camera = game.camera; probe.style = Beams.style()
	if "ui" in tasks:
		await ui()
	if "chronology" in tasks:
		await owner.marked_descent() # Existing corrected five-point 15 s chronology, unchanged.
		owner.audit.check(owner.chronology.get("ticks",0)==1800 and owner.chronology.get("stop","")=="15 second bound","Corrected chronology completes its 15 s bound without an early stop")
		game.automated = true
	if "counts" in tasks:
		await counts()
	if "reduced-motion" in tasks:
		await reduced_motion()
	for path in private_files:
		var after = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		owner.audit.check(after==private_files[path],"Follow-up personal file unchanged: "+path)
	var after_inventory = persistent_files()
	owner.audit.check(after_inventory==personal_inventory,"Personal settings, mountain/race libraries, replay payloads and record files remain byte-identical; no new marker files")
	evidence.loading_estimate_telemetry = {"path":"user://generation_measurements_v18.json","before":loading_estimate_before,"after":FileAccess.get_sha256("user://generation_measurements_v18.json"),"owner":"GenerationEstimates records normal loading diagnostics; excluded from personal preferences, races, replays and records"}
	evidence.personal_files_before = personal_inventory
	evidence.personal_files_after = after_inventory
	return Probe.json_safe(evidence)

func pose() -> void:
	game.active = false; game.session.eligible = false
	game.set_process(false); game.set_physics_process(false)
	game.workshop.close(); game.workshop._clear_markers()
	game.hud.hide_menu(); game.hud.root.hide()
	probe.place(plan) # Exact ordinary Connected 60 km/h observer, no search or manual aim.
	game.sim.reset_pose_history(); game.skier.reset_animation(game.sim); game.skier.pose(game.sim,1.0)
	game.previous_position = game.sim.position; game.presentation_camera = game.camera
	owner.view_description = {"anchor":owner.vector(plan.anchor),"orientation_target":owner.vector(plan.anchor),
		"camera_to_base_m":game.camera.global_position.distance_to(plan.anchor),"source":"pixel-reviewed v4 observer"}
	game.world.assets.foliage_sight.initialized = false
	for frame in 60:
		game.world.assets.update_foliage_sight(game.camera,game.skier.global_position,1.0/60.0,true,
			game.camera_settings.shared.forest_visibility,game.camera_settings.shared.forest_visibility_strength)
	game.display_settings.reset_history()

func ui() -> void:
	pose()
	owner.markers = points(false,5)
	if owner.markers.size()!=5: return
	owner.populate(5)
	game.automated = false
	game.hud.root.show()
	game.hud.show_menu("paused")
	game.navigation._select_device(-1)
	game.workshop.open_navigation()
	game.workshop.focus_point = owner.markers[2]
	game.workshop.survey_height = 340.0
	game._present_camera(0.0,game.sim.position)
	await owner.capture("map_mouse_five")
	var tool = game.workshop.navigation_panel
	tool.begin_add()
	var key = InputEventKey.new()
	key.physical_keycode = KEY_W; key.pressed = true
	game.navigation.route(key)
	var before: Vector3 = game.workshop.focus_point
	tool.update_survey(.1)
	owner.audit.check(game.workshop.focus_point!=before,"Keyboard W pans only the active navigation terrain")
	key.pressed = false; game.navigation.route(key)
	game.navigation._select_device(9001)
	tool.device_switched = false
	tool.begin_add()
	game._present_camera(0.0,game.sim.position)
	await owner.capture("map_controller_reticle")
	tool.focus_panel()
	await owner.capture("map_controller_panel")
	game.workshop.navigation_state.set_shown(false)
	await owner.capture("map_hidden_handles")
	game.workshop.navigation_state.set_shown(true)
	owner.markers = owner.Checks.supported_points(game,32)
	owner.populate(32)
	tool.begin_add()
	await owner.capture("map_limit_32")
	tool.focus_panel(); tool.back()
	game.navigation._select_device(-1)
	await race_lifecycle()
	game.automated = true
	game.hud.hide_menu()
	evidence.ui_scope = "Native keyboard pan and simulated-controller reticle/focus/prompts; full input/lifecycle assertions run once in the compact navigation suite. Physical controller acceptance is separate."

func points(near: bool, wanted: int) -> Array[Vector3]:
	# Bounded point placement at one proven observer; no observer/camera search.
	var values: Array[Vector3] = []
	var forward = Vector3(sin(plan.heading),0,cos(plan.heading))
	var side = Vector3(forward.z,0,-forward.x)
	var distances = [60.0,68.0,76.0,84.0,92.0,100.0,108.0,116.0] if near else [500.0,508.0,492.0,516.0,484.0,524.0,476.0,532.0]
	var attempts = 0
	var reasons: Dictionary = {}
	for distance in distances:
		for lateral in [0.0,-4.0,4.0,-8.0,8.0,-12.0,12.0,-16.0,16.0,-20.0,20.0]:
			attempts += 1
			var anchored = Navigation.anchor(game.field,plan.position+forward*distance+side*lateral)
			if not anchored.error.is_empty():
				reasons[anchored.error] = reasons.get(anchored.error,0)+1; continue
			var current = owner.shaft_probe(game.camera,anchored.position)
			if current.terrain_clear_in_frame_heights_m.size()<3:
				reasons["insufficient_terrain_frustum_samples"] = reasons.get("insufficient_terrain_frustum_samples",0)+1; continue
			values.append(anchored.position)
			if values.size()==wanted: break
		if values.size()==wanted: break
	evidence.count_fixtures.append({"near":near,"wanted":wanted,"selected":values,"attempts":attempts,"limit":88,"rejections":reasons,
		"camera":probe.camera_data(),"scope":"Supported points with 3 terrain/frustum samples. Tree/rock/alpha overlap still requires native reference review; no claim that all points are visible."})
	owner.audit.check(values.size()==wanted,"Bounded %s fixture has %d supported geometric points (actual pixels pending)" % ["near" if near else "far",wanted])
	return values

func counts() -> void:
	pose()
	for near in [true,false]:
		owner.markers = points(near,32)
		if owner.markers.size()!=32: continue
		var references: Dictionary = {}
		for count in [0,5,32]:
			owner.populate(count)
			await owner.capture("count_reference_%s_%d" % ["near" if near else "far",count])
			references[count] = owner.captures[-1].duplicate(true)
			owner.audit.check(game.workshop.navigation_state.count()==count and game.workshop.navigation_beams.beams.size()==count,"Functional near/far count and render ownership: %d" % count)
	owner.audit.check(owner.samples.is_empty(),"Functional count route never invokes timing")
	evidence.cost_scope = "Deferred by user: screenshot-free matched 0/5/32 near/far frame/GPU costs and variance remain unmeasured. These capped 1080p captures establish functional scope only."

func beam_state() -> Array:
	var result: Array = []
	for id in game.workshop.navigation_beams.beams:
		var beam = game.workshop.navigation_beams.beams[id]
		var strength = beam.material.get_shader_parameter("vfx_strength")
		# An unset material override uses the pinned shader's declared 1.0 default.
		if strength==null: strength = 1.0
		result.append({"id":id,"time":beam.visual_time,"reduced":beam.motion_reduced,
			"strength":strength})
	return result

func reduced_motion() -> void:
	pose()
	owner.markers = points(false,5)
	if owner.markers.size()!=5: return
	owner.populate(5)
	var model = game.workshop.navigation_state
	var retained = model.points()
	var phase = 0
	for reduced in [false,true,false]:
		game.hud.feedback.reduced_motion = reduced
		owner.call_group("race_beam_vfx","update_effect",0.0,true,reduced)
		var label = "motion_%d_%s" % [phase,"reduced" if reduced else "normal"]
		await owner.capture(label+"_start")
		var before = beam_state()
		for frame in 60: await owner.draw_frame(1.0/60.0)
		await owner.capture(label+"_end")
		var after = beam_state()
		var correct = before.size()==5 and after.size()==5
		for i in mini(before.size(),after.size()):
			correct = correct and after[i].reduced==reduced and float(after[i].strength)==(0.0 if reduced else 1.0)
			correct = correct and (is_equal_approx(after[i].time,before[i].time) if reduced else after[i].time>before[i].time)
		owner.audit.check(correct,"Five beams %s via the actual shared effect group" % ("freeze optional motion" if reduced else "advance optional motion"))
		evidence.reduced_motion.append({"label":label,"reduced":reduced,"before":before,"after":after,"render_frames_between":80,
			"scope":"Paired native beam frames plus real shader state; ambient scenery may move independently. No whole-image equality or physical-controller acceptance."})
		phase += 1
	owner.audit.check(model.points()==retained,"Reduced Motion toggle/restore retains all five IDs and positions")
	game.hud.feedback.reduced_motion = false

func persistent_files() -> Dictionary:
	var result: Dictionary = {}
	for file in DirAccess.get_files_at("user://"):
		# Normal Main loading updates its estimate telemetry, even in automated runs.
		if file=="generation_measurements_v18.json": continue
		result[file] = FileAccess.get_sha256("user://"+file)
	for directory in ["mountains_v2","races_v6","race_records_v6"]:
		collect_files("user://"+directory,result)
	result["root_directories"] = Array(DirAccess.get_directories_at("user://"))
	return result

func collect_files(directory: String, result: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(directory): return
	for file in DirAccess.get_files_at(directory):
		var path = directory.path_join(file)
		result[path] = FileAccess.get_sha256(path)
	for child in DirAccess.get_directories_at(directory): collect_files(directory.path_join(child),result)

func race_lifecycle() -> void:
	var model = game.workshop.navigation_state
	var retained = model.points()
	var race = game.workshop.suggested_race
	owner.audit.check(race!=null and race.validate_surface(game.field).is_empty(),"Actual suggested race has valid endpoints and gate seating")
	if race==null: return
	await game.play_custom_race(race)
	game.active = false
	game.session.elapsed = 12.5
	game.session.split_times[0] = 4.25
	game.session.eligible = true # Artifacts-only records and preferences disabled.
	game.sim.velocity = game.sim.support_basis().z*12.0
	game.hud.show_menu("paused")
	var before = owner.Checks.snapshot(game)
	var code: String = race.share_text()
	game.workshop.open_navigation()
	model.set_shown(false); model.set_shown(true)
	model.move_point(retained[0].id,game.field,retained[1].position)
	for tick in 60: game._physics_process(1.0/120.0)
	game.workshop.navigation_panel.focus_panel(); game.workshop.navigation_panel.back()
	owner.audit.check(owner.Checks.snapshot(game)==before and code==game.session.race.share_text(),"Native map edit preserves nonzero race time, velocity, splits, eligibility, recorder and share identity")
	model.move_point(retained[0].id,game.field,retained[0].position)
	game.resume()
	owner.audit.check(game.active and game.sim.position==before.position and game.sim.velocity==before.velocity and not game.rider_axes_armed and not game.air_controls_armed,"Native resume retains state and requires neutral gameplay inputs")
	game.active = false; game.session.eligible = false
	game.restart()
	game.active = false; game.session.eligible = false
	owner.audit.check(model.points()==retained,"Actual race retry retains all session landmarks")
	game.workshop._clear_markers()
	owner.audit.check(model.points()==retained and game.workshop.navigation_beams.beams.size()==retained.size(),"Race marker cleanup retains independent personal render ownership")
	game.returning_to_summit = true
	game._return_to_summit_midpoint(); game._return_to_summit_complete()
	game.active = false
	owner.audit.check(model.points()==retained,"Native mountain return-to-summit retains session points")
	game.start_run(false)
	game.active = false; game.session.eligible = false
	owner.audit.check(game.session.race==null and model.points()==retained,"Same-mountain free skiing retains points and removes the race")
