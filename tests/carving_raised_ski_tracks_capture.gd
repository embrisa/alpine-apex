extends SceneTree
## Bounded ordinary-input chronology; no session stepping, record or preference writes.
const DT = 1.0/120.0
const Replay = preload("res://scripts/racing/run_replay.gd")
const Lab = preload("res://scripts/world/test_slope.gd")
const Response = preload("res://scripts/presentation/snow_response.gd")
const ROOT = "res://artifacts/orchestration_20260912/carving"
var game
var field
var observer: Camera3D
var output = ROOT+"/capture_after"
var reference_root = ""
var quality_names: Array = ["low","balanced","high"]
var cases: Array = ["left","right","reversal","jump"]
var failures: Array = []
var rows: Array = []
var timing = false
var every_frame = false
var eligibility_reference = false
var fixture_report: Dictionary = {}

class EligibilityReference extends "res://scripts/presentation/snow_response.gd":
	func resolve_track_contact(_sim, _ski, _surface) -> void:
		pass # Matched control: original support/load eligibility, all other code identical.

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Native rendering required for the carving chronology"); quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = resource_path(arg.trim_prefix("--output="))
		if arg.begins_with("--reference-root="): reference_root = resource_path(arg.trim_prefix("--reference-root="))
		if arg.begins_with("--qualities="): quality_names = Array(arg.trim_prefix("--qualities=").split(","))
		if arg.begins_with("--cases="): cases = Array(arg.trim_prefix("--cases=").split(","))
		timing = timing or arg=="--timing"
		every_frame = every_frame or arg=="--every-frame"
		eligibility_reference = eligibility_reference or arg=="--eligibility-reference"
	for quality in quality_names:
		if not quality in ["low","balanced","high"]: failures.append("Unknown quality: "+quality)
	for scenario in cases:
		if not scenario in ["left","right","reversal","jump"]: failures.append("Unknown scenario: "+scenario)
	if DirAccess.dir_exists_absolute(output) or not failures.is_empty():
		printerr("Choose a fresh output directory. ",failures); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources = source_hashes()
	set_meta("test_lab_fixture",true)
	game = load("res://main.tscn").instantiate()
	if not reference_root.is_empty():
		if not prepare_reference(): game.free(); quit(2); return
		game.set_script(load(output+"/main_reference.gd"))
	# Private fixture data, installed before meshes, scenery or collision adapters
	# are built. Both modes use identical original snow/4 m heights and no placed
	# tree/rock obstacles. Never bypass a collision query or change the solver.
	set_meta("mountain_to_load", {"definition":null,"field":isolated_lab()})
	game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_speed_lab(130)
	game.summit_ready = false; game.active = true; game.session.eligible = false
	game.effects.muted = true; game.effects.haptic_hardware_enabled = false
	game.effects.stop_audio(); game.hud.hide(); game.hud.hide_menu()
	if eligibility_reference:
		game.effects.responses = [EligibilityReference.new(),EligibilityReference.new()]
	field = game.field
	if not field.obstacles.is_empty() or not field.obstacle_grid.is_empty() or game.world.surface!=field or game.world.ski_surface.terrain!=field:
		failures.append("Fixture terrain/render/collision ownership mismatch")
		printerr(failures[-1])
		game.queue_free(); await process_frame; quit(2); return
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,0.0,false)
	game.display_settings.display_mode = "windowed"
	game.display_settings.upscaler = "native"
	game.display_settings.render_scale = 1.0
	game.display_settings.frame_generation = false
	game.display_settings.fps_limit = 120 if timing else 60
	game.display_settings.apply_display(root,Vector2i(1920,1080))
	game.display_settings.apply_viewport(root)
	root.content_scale_size = Vector2i(1920,1080)
	observer = Camera3D.new(); observer.fov = 58; observer.far = 15000
	game.add_child(observer); observer.make_current()
	for quality in quality_names:
		game.set_graphics_quality(["low","balanced","high"].find(quality))
		game.world.environment.sdfgi_enabled = false
		# Selecting a quality resets reconstruction preferences. Reapply the
		# declared capture settings after that selection, in both matched modes.
		game.display_settings.upscaler = "native"
		game.display_settings.render_scale = 1.0
		game.display_settings.frame_generation = false
		game.display_settings.apply_viewport(root)
		for scenario in cases:
			if timing:
				await ride(quality,scenario,true)
				for repetition in 3: await ride(quality,scenario,false,repetition)
			else: await ride(quality,scenario)
	var stable_sources = source_hashes()==sources
	if not stable_sources: failures.append("Sources changed during capture; matched comparison invalid")
	var renderer_report: Dictionary = game.display_settings.report(root,root.get_texture().get_image().get_size())
	var display_identity = renderer_report.duplicate(true)
	# Counts depend on setup frames and are evidence, not display identity.
	# Keep the full report alongside the stable comparison fields.
	for key in ["dxgi_present_count","rendered_present_calls","generated_frames","upscale_dispatches"]:
		display_identity.fidelityfx.erase(key)
	var report = {"scope":"Five seconds per ordinary-input scenario, 120 Hz solver and final 60 Hz production pose. No session stepping or PB/preference writes.",
		"fixture":fixture_report,"continuity_contract":1,
		"reference_root":reference_root,"eligibility_reference":eligibility_reference,"timing":timing,"render_acceptance":"pending chronological inspection","human_acceptance":"pending",
		"model":game.sim.MODEL_VERSION,"engine":Engine.get_version_info(),"device":RenderingServer.get_video_adapter_name(),
		"sources":sources,"stable_sources":stable_sources,"unranked":not game.session.eligible,
		"display":display_identity,"renderer_report":renderer_report,"cases":rows,"failures":failures}
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CARVING_RAISED_SKI_TRACKS ",output," failures=",failures)
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func isolated_lab():
	var lab = Lab.new()
	var original_heights = lab.heights.duplicate()
	var original_count: int = lab.obstacles.size()
	lab.obstacles.clear()
	lab.obstacle_grid.clear()
	fixture_report = {"name":"original-lab-without-placed-obstacles","seed":lab.seed_value,
		"removed_placements":original_count,"placements":lab.obstacles.size(),
		"height_sha256":bytes_sha256(lab.heights.to_byte_array()),
		"height_bytes_unchanged":original_heights==lab.heights,
		"collision_policy":"Original terrain, material, bounds and obstacle sweep code; fixture placements omitted before world construction",
		"start_xz":[0,600],"speed_kmh":130,"seconds_per_case":5}
	assert(original_heights==lab.heights and lab.obstacles.is_empty() and lab.obstacle_grid.is_empty())
	return lab

func ride(quality: String, scenario: String, warmup: bool = false, repetition: int = 0) -> void:
	var p = Vector3(0,0,600)
	p.y = field.sample(p.x,p.z).height
	var normal: Vector3 = field.contact_normal(p.x,p.z)
	game.sim.reset(p,atan2(normal.x,normal.z))
	game.sim.prime_contacts(game.world.ski_surface)
	game.sim.velocity = game.sim.support_basis().z*130.0/3.6
	game.sim.reset_pose_history()
	game.effects.reset(); game.skier.reset_animation(game.sim)
	game.skier.snow_burial_enabled = game.effects.powder_surface!=null and game.effects.powder_surface.is_active()
	game.skier.pose(game.sim,1.0)
	place_observer()
	for frame in 30: await process_frame
	var label = "%s_%s_%d"%[quality,scenario,repetition]
	var folder = output+"/"+label
	if not warmup: DirAccess.make_dir_recursive_absolute(folder)
	var telemetry = FileAccess.open(folder+"/frames.jsonl",FileAccess.WRITE) if not warmup else null
	var costs: Array[float] = []
	var gaps = [0,0]
	var continued = [0,0]
	var airborne = 0
	var airborne_after_jump = 0
	var jump_events = 0
	var invalid_air_frames: Array = []
	var invalid_candidate_frames: Array = []
	var required_continuity_samples = 0
	var invalid_continuity_frames: Array = []
	var probe_responses = [Response.new(),Response.new()]
	var candidates = {"entry_hold":0,"reversed_hold":0,"release":0}
	var low_load_grounded = 0
	var immutable = true
	var samples = 0
	var digest = HashingContext.new(); digest.start(HashingContext.HASH_SHA256)
	for frame in 300:
		var controls = RiderInput.new()
		var seconds = frame/60.0
		var phase = "release" if seconds>=4.0 else ("reversed_hold" if scenario=="reversal" and seconds>=2.3 else "entry_hold")
		if seconds>=.5 and seconds<4.0 and scenario!="jump":
			controls.steer = -.85 if scenario=="left" else .85
			if scenario=="reversal" and seconds>=2.3: controls.steer = -.85
		for tick in 2:
			# Request the ordinary jump on the first supported frame after 1.5 s;
			# natural roller airtime must not consume a fixed-frame jump request.
			controls.jump = scenario=="jump" and frame>=90 and jump_events==0 and game.sim.grounded and tick==0
			game.sim.step(DT,controls,game.world.ski_surface)
			if game.sim.jump_executed: jump_events += 1
			game.skier.step_animation(DT,game.sim,controls,field)
			digest.update(physics_bytes((frame*2+tick+1)*DT))
		game.skier.pose(game.sim,1.0)
		place_observer()
		var before = physics_bytes((frame+1)/60.0)
		var previous_cursor: int = game.effects.snow_tracks.cursor
		var start = Time.get_ticks_usec()
		game.effects.update_effects(game.sim,field,game.sim.position,1.0/60.0,true,game.weather.state,null,observer,false,false,game.skier.skis)
		costs.append(float(Time.get_ticks_usec()-start))
		immutable = immutable and before==physics_bytes((frame+1)/60.0)
		if not game.sim.grounded:
			airborne += 1
			if jump_events>0: airborne_after_jump += 1
			var track_state = game.effects.snow_tracks
			var gpu_live = false
			if reference_root.is_empty():
				var live_bytes: PackedFloat32Array = track_state.live_gpu_strokes()
				gpu_live = live_bytes[5]!=0.0 or live_bytes[13]!=0.0
			if track_state.live_active[0] or track_state.live_active[1] or gpu_live or track_state.cursor!=previous_cursor or track_state.foot_history[0].is_finite() or track_state.foot_history[1].is_finite():
				invalid_air_frames.append(frame)
		var contacts: Array = []
		for i in 2:
			var ski = game.sim.skis[i]
			var visual = game.skier.skis[1-i if game.sim.facing_backward else i]
			var response = game.effects.responses[i]
			var tracks = game.effects.snow_tracks
			var sample_value: Dictionary = field.sample(visual.global_position.x,visual.global_position.z)
			var response_report: Dictionary = response.report()
			# Read-only shadow evaluation in BOTH modes proves that the ordinary
			# scenario exercises the actual near-surface low-load exception. It
			# never supplies the rendered response or writes physical ski state.
			var probe = probe_responses[i]
			probe.sample(game.sim,ski,field)
			probe.contact_position = visual.global_position
			probe.contact_forward = visual.global_basis.z.normalized()
			probe.resolve_track_contact(game.sim,ski,field)
			if game.sim.grounded and not game.sim.crashed and ski.grounded and ski.load_n<=1.0 and absf(controls.steer)>0.0:
				low_load_grounded += 1
			if probe.cosmetic_track and seconds>=.5 and scenario!="jump":
				candidates[phase] += 1
				if reference_root.is_empty() and (tracks.live_active[i]==eligibility_reference or (not eligibility_reference and response.track_depth_m<=0.0)):
					invalid_candidate_frames.append([frame,i])
			# Independent regression windows from the native v2 review, not from
			# this resolver's eligibility result. A new cutoff cannot make these
			# ordinary grounded snow intervals pass by rejecting every candidate.
			var continuity_required: bool = continuous_snow_window(scenario,frame) and game.sim.grounded and ski.grounded and ski.material_kind==0
			if continuity_required:
				required_continuity_samples += 1
				if not eligibility_reference and reference_root.is_empty() and not tracks.live_active[i]:
					invalid_continuity_frames.append([frame,i,response_report.get("track_reason",""),response_report.get("track_rejection",{})])
			if game.sim.grounded and not tracks.live_active[i]: gaps[i] += 1
			if response_report.get("cosmetic_track",false): continued[i] += 1
			contacts.append({"ski":i,"grounded":ski.grounded,"load_n":ski.load_n,"material":ski.material_kind,
				"clearance_m":ski.clearance_m,"normal_speed_ms":ski.normal_speed_ms,"edge_angle":ski.edge_angle,"grip_n":ski.grip_n,
				"physical_position":pack(ski.position),"rendered_position":pack(visual.global_position),
				"rendered_forward":pack(visual.global_basis.z),"rendered_height_above_surface_m":visual.global_position.y-sample_value.height,
				"response":response_report,"candidate_response":probe.report(),"continuity_required":continuity_required,"live":tracks.live_active[i],"history_anchor":pack(tracks.foot_history[i]),
				"live_tail":pack(tracks.live_transforms[i]*Vector3(0,0,-.5)),"live_tip":pack(tracks.live_transforms[i]*Vector3(0,0,.5))})
		if telemetry:
			telemetry.store_line(JSON.stringify({"frame":frame,"seconds":seconds,"steer":controls.steer,"grounded":game.sim.grounded,
				"phase":phase,"jump_events":jump_events,
				"crashed":game.sim.crashed,"switch":game.sim.facing_backward,"physics_sha256":before.hex_encode().sha256_text(),
				"track_count":game.effects.snow_tracks.written,"track_cursor":game.effects.snow_tracks.cursor,"contacts":contacts}))
		await process_frame
		if not timing and not warmup and (every_frame or frame%2==0 or frame==299):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(folder+"/%04d.jpg"%frame,.93)
		samples += 1
		if game.sim.crashed:
			failures.append(label+": unexpected crash: "+game.sim.crash_reason)
			break
		immutable = immutable and before==physics_bytes((frame+1)/60.0)
	if telemetry: telemetry.close()
	if not immutable: failures.append(label+": presentation changed completed physics/replay bytes")
	if scenario=="jump" and (jump_events!=1 or airborne_after_jump==0): failures.append(label+": deliberate jump did not execute once and produce airborne coverage")
	if not invalid_air_frames.is_empty(): failures.append(label+": airborne live/GPU/history suppression failed: "+str(invalid_air_frames))
	if not invalid_candidate_frames.is_empty(): failures.append(label+": expected control/candidate track behavior failed: "+str(invalid_candidate_frames))
	if not invalid_continuity_frames.is_empty(): failures.append(label+": required grounded snow continuity failed: "+str(invalid_continuity_frames))
	if scenario!="jump":
		if required_continuity_samples==0: failures.append(label+": required grounded continuity windows NOT EXERCISED")
		if low_load_grounded==0 or candidates.entry_hold==0: failures.append(label+": original grounded low-load carving gap NOT REPRODUCED; do not accept a vacuous pair")
		if scenario=="reversal" and candidates.reversed_hold==0: failures.append(label+": reversed hold did not exercise the near-surface exception")
	if quality=="high" and not game.effects.powder_surface.is_active(): failures.append(label+": native GPU powder unavailable")
	if warmup: return
	rows.append({"name":label,"quality":quality,"scenario":scenario,"frames":samples,"seconds":samples/60.0,"stop":"crash" if game.sim.crashed else "bounded_limit",
		"physics_sha256":digest.finish().hex_encode(),"presentation_preserves_physics":immutable,"airborne_frames":airborne,
		"deliberate_jump_events":jump_events,"airborne_frames_after_deliberate_jump":airborne_after_jump,"invalid_air_frames":invalid_air_frames,
		"low_load_physically_grounded_ski_frames_during_steering":low_load_grounded,"eligible_cosmetic_ski_frames_by_phase":candidates,"invalid_candidate_frames":invalid_candidate_frames,
		"required_continuity_samples":required_continuity_samples,"invalid_continuity_frames":invalid_continuity_frames,
		"grounded_missing_live_frames_per_ski":gaps,"cosmetic_continuation_frames_per_ski":continued,
		"reproduction":"nonzero ordinary-input near-surface candidate coverage required for each carving direction; air evaluated separately",
		"effects_submission_us":stats(costs),"budget":game.effects.snow_budget()})
	print("CARVING_CASE ",label," grounded_missing=",gaps," continued=",continued," immutable=",immutable)
	print("CARVING_COVERAGE ",label," low_load_grounded=",low_load_grounded," candidates=",candidates," jumps=",jump_events," invalid_air=",invalid_air_frames)

func continuous_snow_window(scenario: String, frame: int) -> bool:
	# Known continuous-snow portions of this unchanged private lab trajectory.
	# Right/reversal: buried entry, post-landing hold, and complete release.
	# Left also includes its production switch transition and shallow hold.
	# Air and rock-boundary coverage remain separate in the jump scenario.
	if scenario=="right" or scenario=="reversal":
		return (frame>=34 and frame<=51) or (frame>=120 and frame<=153) or frame>=240
	if scenario=="left": return frame>=106
	return false

func physics_bytes(time: float) -> PackedByteArray:
	var state: Array = [Replay.snapshot(time,game.sim),game.sim.position,game.sim.velocity,game.sim.grounded,game.sim.crashed]
	for ski in game.sim.skis:
		state.append([ski.position,ski.orientation,ski.load_n,ski.grip_n,ski.penetration,ski.snow_depth,ski.material_kind,ski.grounded])
	return var_to_bytes(state)

func place_observer() -> void:
	var p: Vector3 = game.sim.position
	var forward: Vector3 = game.sim.ski_forward
	var right: Vector3 = game.sim.surface_normal.cross(forward).normalized()
	observer.position = p-forward*5.4-right*2.2+Vector3.UP*3.5
	observer.look_at(p-forward*1.1+Vector3.UP*.15)
	observer.make_current()

func prepare_reference() -> bool:
	# Preserve original bytes and rewrite only local resource links in the
	# output bundle. Never replace production files in the shared checkout.
	var bundle = output+"/reference"
	DirAccess.make_dir_recursive_absolute(bundle)
	var names = ["snow_response.gd","snow_tracks.gd","speed_effects.gd","powder_surface.gd"]
	for name in names:
		var path = reference_root+"/scripts/presentation/"+name
		if not FileAccess.file_exists(path):
			printerr("Missing original baseline: ",path); return false
		var source = FileAccess.get_file_as_string(path)
		for dependency in names: source = source.replace("res://scripts/presentation/"+dependency,bundle+"/"+dependency)
		FileAccess.open(bundle+"/"+name,FileAccess.WRITE).store_string(source)
	var main_source = FileAccess.get_file_as_string("res://scripts/main.gd").replace("res://scripts/presentation/speed_effects.gd",bundle+"/speed_effects.gd")
	FileAccess.open(output+"/main_reference.gd",FileAccess.WRITE).store_string(main_source)
	return true

func source_hashes() -> Dictionary:
	var result = {}
	for path in ["scripts/main.gd","scripts/core/ski_simulation.gd","config/ski_default.tres","scripts/racing/run_replay.gd",
		"scripts/world/test_slope.gd","scripts/world/heightfield_surface.gd","scripts/world/prop_collision_surface.gd",
		"scripts/presentation/skier_visual.gd","scripts/presentation/skier_full_motion.gd","scripts/presentation/speed_effects.gd",
		"scripts/presentation/snow_response.gd","scripts/presentation/snow_tracks.gd","scripts/presentation/powder_surface.gd",
		"assets/graphics/ski_track.gdshader","assets/graphics/powder_surface.gdshader","assets/graphics/powder_compute.gd",
		"tests/carving_raised_ski_tracks_capture.gd"]:
		result[path] = FileAccess.get_sha256("res://"+path)
		if not reference_root.is_empty() and FileAccess.file_exists(reference_root+"/"+path):
			result["baseline/"+path] = FileAccess.get_sha256(reference_root+"/"+path)
	return result

static func bytes_sha256(bytes: PackedByteArray) -> String:
	var digest = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	return digest.finish().hex_encode()

static func pack(value: Vector3):
	return [value.x,value.y,value.z] if value.is_finite() else null

static func resource_path(value: String) -> String:
	return value if value.begins_with("res://") else "res://"+value.replace("\\","/")

static func stats(values: Array[float]) -> Dictionary:
	values.sort()
	var sum = 0.0
	for value in values: sum += value
	return {"mean":sum/maxi(1,values.size()),"p95":values[mini(values.size()-1,int(values.size()*.95))],"p99":values[mini(values.size()-1,int(values.size()*.99))]}
