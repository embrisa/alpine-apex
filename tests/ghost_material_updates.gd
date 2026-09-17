extends SceneTree
## Small production slopes fixture; material submission cost is NOT frame cost.
const Ghost = preload("res://scripts/presentation/personal_best_ghost.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const Pose = preload("res://scripts/presentation/ghost_pose.gd")
const InputState = preload("res://scripts/core/rider_input.gd")
const Report = preload("res://tests/test_report.gd")
var game
var ghosts: Array = []
var failures: Array[String] = []
var checks = 0
var output = "res://artifacts/ghost_material_root_20260918"
var timing = false
var samples: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr(label)

func run() -> void:
	timing = "--timing" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	check(DisplayServer.get_name()!="headless","Native renderer required")
	check(not timing or OS.get_environment("ALPINE_VALIDATION_MODE")=="FpsCritical","Timing requires FpsCritical")
	if not failures.is_empty(): quit(1); return
	set_meta("test_map_fixture","perf-slopes")
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	var deadline = Time.get_ticks_msec()+120000
	while not game.initialized or game.loading.busy:
		if Time.get_ticks_msec()>deadline: push_error("Targeted startup timed out"); quit(1); return
		await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.preferences_enabled = false; game.set_audio_muted(true); game.effects.haptic_hardware_enabled = false
	game.display_settings.display_mode = "windowed"; game.display_settings.fps_limit = 60
	game.display_settings.upscaler = "auto"; game.display_settings.frame_generation = false
	game.display_settings.apply_display(root,Vector2i(1920,1080)); game.display_settings.apply_viewport(root)
	game.weather.set_automatic(false); game.weather.set_time_cycle(false)
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.start_run(false); game.set_physics_process(false)
	check(game.field.fixture_id=="perf-slopes" and not game.session.eligible,"Explicit unranked perf-slopes fixture")
	check(game.world.wilderness==null and game.world.preparation==null,"No full mountain construction")
	if not failures.is_empty(): quit(1); return
	print("GHOST_MATERIAL_MAP ",JSON.stringify(game.field.fixture_descriptor()))
	game.hud.hide(); game.skier.reset_animation(game.sim); game.skier.pose(game.sim,1.0)
	var replay = Replay.new(); var identity = Replay.key("ghost-material-local")
	replay.begin(game.sim,identity)
	replay.capture_presentation(0.0,Pose.capture(game.skier,game.sim,game.field))
	for tick in range(1,Replay.SAMPLE_EVERY+1):
		var intent = InputState.new()
		game.sim.step(Replay.DT,intent,game.field)
		game.skier.step_animation(Replay.DT,game.sim,intent,game.field); game.skier.pose(game.sim,1.0)
		replay.record(Replay.DT,tick*Replay.DT,game.sim,intent,1.0 if tick==Replay.SAMPLE_EVERY else -1.0)
		if replay.wants_presentation_sample(): replay.capture_presentation(tick*Replay.DT,Pose.capture(game.skier,game.sim,game.field))
	replay = Replay.decode(replay.to_data(),identity,replay.duration)
	check(replay!=null,"Actual completed production pose passes replay validation")
	if not failures.is_empty(): quit(1); return
	for i in 10:
		var ghost = Ghost.new()
		ghost.source_assets = game.ghost.source_assets; ghost.player_history = game.effects.snow_tracks
		ghost.field = game.field; ghost.profile = game.ghost.profile; ghost.replay = replay
		ghost.color = [Color("24c5c5"),Color("ffc14c"),Color("d785f7")][i%3]
		root.add_child(ghost); ghosts.append(ghost)
		ghost.update_ghost(0.0,Vector3.ZERO,true,false,false)
		ghost.visible = i==0
	functional_checks()
	var camera = Camera3D.new(); root.add_child(camera); camera.make_current()
	var anchor: Vector3 = ghosts[0].visual.global_position
	camera.position = anchor+Vector3(3,2,5); camera.look_at(anchor+Vector3(0,1,0))
	game.skier.hide()
	DirAccess.make_dir_recursive_absolute(output)
	if timing:
		for i in 90: await process_frame
		for mode in ["steady","color_change"]: await measure(mode)
	else:
		for i in 3:
			ghosts[i].visible = true; ghosts[i].position.x = (i-1)*1.7
			ghosts[i].ghost_assets.tint(ghosts[i].color)
		for view in ["front","back"]:
			camera.position = anchor+Vector3(0,1.9,5.8 if view=="front" else -5.8)
			camera.look_at(anchor+Vector3(0,1,0))
			for i in 12: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp(output+"/jackets_"+view+".webp",true,.95)
		ghosts[1].hide(); ghosts[2].hide(); ghosts[0].position = Vector3.ZERO
		camera.position = anchor+Vector3(2.1,1.5,3.0); camera.look_at(anchor+Vector3(0,1,0))
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp(output+"/jacket_close.webp",true,.95)
	var material_count = 0
	for ghost in ghosts: material_count += ghost.ghost_assets.materials.size()
	Report.write(output+"/report.json",JSON.stringify({"checks":checks,"failures":failures,"map":game.field.fixture_descriptor(),"materials":material_count,"ghosts":ghosts.size(),"timing":timing,"samples":samples,"engine":Engine.get_version_info(),"device":RenderingServer.get_video_adapter_name(),"scope":"Jacket-only setter CPU microseconds per ten-ghost update against an unconditional equivalent setter, not whole-frame FPS. Capped local production slopes; no full mountain, no capture during timing."},"\t"))
	print("GHOST_MATERIAL_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"output":output}))
	for ghost in ghosts: ghost.queue_free()
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func check_materials(assets, color: Color) -> void:
	check(assets.jacket_materials.size()==1,"Exactly one private jacket material")
	for mat in assets.jacket_materials:
		check(mat.get_shader_parameter("ghost_tint")==color,"Jacket has the exact selected tint")
	for mat in assets.materials.values():
		check(not "ALPHA=" in mat.shader.code.replace(" ",""),"Solid body and equipment shaders")
		check((mat in assets.jacket_materials)==(mat.shader.resource_path=="res://assets/graphics/ghost_skier.gdshader"),"Jacket shader is isolated from other surfaces")

func functional_checks() -> void:
	for ghost in ghosts:
		var unchanged: Dictionary = {}
		for mat in ghost.ghost_assets.materials.values():
			if mat not in ghost.ghost_assets.jacket_materials: unchanged[mat] = mat.get_shader_parameter("base_color")
		for value in [ghost.color,ghost.color,Color(0.73,0.24,0.58),ghost.color]:
			ghost.ghost_assets.tint(value)
			check_materials(ghost.ghost_assets,value)
			for mat in unchanged: check(mat.get_shader_parameter("base_color")==unchanged[mat],"Non-jacket colors unchanged")
	var asset = Ghost.Assets.new(game.ghost.source_assets)
	asset.tint(Color.CYAN)
	var original = ghosts[0].ghost_assets.jacket_materials[0]
	asset.material_for(original); check_materials(asset,Color.CYAN)
	asset.dispose(); check(asset.materials.is_empty() and asset.jacket_materials.is_empty(),"Disposal clears all owned material references")
	asset.material_for(original); check_materials(asset,Color.CYAN); asset.dispose()
	var ghost = ghosts[0]
	for distance in [0.0,9.0,18.0,750.0]:
		ghost.update_ghost(0.0,ghost.visual.global_position+Vector3(0,0,distance),true,true,false)
		check(ghost.visual.visible,"Distance never hides a solid ghost")
		check_materials(ghost.ghost_assets,ghost.color)
	ghost.update_ghost(0.0,Vector3.ZERO,false,false,false)
	check(not ghost.visual.visible,"Hidden ghost clears presentation")
	ghost.update_ghost(0.0,Vector3.ZERO,true,false,false)
	check(ghost.visual.visible,"Resumed ghost restores presentation")

func unconditional_tint(assets, color: Color) -> void:
	# Equivalent new jacket-only design, without skipping unchanged values.
	assets.color = color
	for mat in assets.jacket_materials: mat.set_shader_parameter("ghost_tint",color)

func batch(candidate: bool, mode: String, count: int) -> float:
	var start = Time.get_ticks_usec()
	for i in count:
		for ghost in ghosts:
			var color: Color = ghost.color if mode=="steady" or i%2 else Color(0.73,0.24,0.58)
			if candidate: ghost.ghost_assets.tint(color)
			else: unconditional_tint(ghost.ghost_assets,color)
	return float(Time.get_ticks_usec()-start)/count

func measure(mode: String) -> void:
	var old: Array = []; var candidate: Array = []
	for repeat in 8:
		for arm in ([false,true] if repeat%2==0 else [true,false]):
			for ghost in ghosts: ghost.ghost_assets.tint(ghost.color)
			batch(arm,mode,120)
			var value = batch(arm,mode,1200)
			if arm: candidate.append(value)
			else: old.append(value)
			for ghost in ghosts: check_materials(ghost.ghost_assets,ghost.color)
			await process_frame
	old.sort(); candidate.sort()
	samples[mode] = {"unconditional_us":(old[3]+old[4])*.5,"candidate_us":(candidate[3]+candidate[4])*.5,"unconditional_batches_us":old,"candidate_batches_us":candidate}
