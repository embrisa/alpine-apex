extends "res://tests/ghost_playtest.gd"
## Targeted actual-solver diagnostics; separate from race chronology/performance.
## One Main/resources load. No codec pose/contact mutation or solver tuning edits.
const Field = preload("res://scripts/presentation/ghost_field.gd")
const Tracks = preload("res://scripts/presentation/snow_tracks.gd")
const MaterialKind = preload("res://scripts/core/terrain_material.gd")
const Equipment = preload("res://scripts/presentation/skier_equipment.gd")
const STAGE_Y = 1000.0
const STAGE_LAYER = 2
var focused_cases: Array = []
var palette_rows: Array = []
var focused_captures: Array = []
var stage: Node3D
var geometry: Node3D
var observer: Camera3D
var local_history
var field_ghosts
var caption: Label
var labels: Array = []
var source_identity: Dictionary = {}
var reusable_replay
var readback_us = 0

class DiagnosticSurface extends RefCounted:
	var kind = "flat"
	var gradient = 0.0
	func sample(x: float, z: float) -> Dictionary:
		var drop = 2.5 if kind=="one_ski" and x>0.0 and z>=8.0 and z<22.0 else 0.0
		return {"height":1000.0-gradient*z-drop,"normal":Vector3(0,1,gradient).normalized()}
	func contact_normal(x: float,z: float) -> Vector3: return sample(x,z).normal
	func snow_depth_at(_x: float,_z: float) -> float: return .20
	func rock_fraction_at(_x: float,z: float) -> float: return float(kind=="rock_strip" and z>=6.0 and z<16.0)
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""
	func bounds() -> Rect2: return Rect2(-70,-10,140,110)

func _initialize() -> void:
	output = "res://artifacts/ghost/focused-native"
	call_deferred("run")

func run() -> void:
	set_meta("test_lab_fixture",true)
	profiling = "--profile" in OS.get_cmdline_user_args()
	review_only = "--review-only" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
			if not output.begins_with("res://"): output = "res://"+output
	if DisplayServer.get_name()=="headless":
		push_error("Ghost native harness requires a rendered engine; run ghost_archive_suite headlessly.")
		quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	for arg in OS.get_cmdline_user_args():
		if arg in ["--autoplay","--capture-menu"]:
			check(false,"Main's independent runner cannot share this fixture: "+arg)
	if not failures.is_empty(): await _finish(); return
	fixture_store = "user://ghost_native_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	root.size = PIXELS
	game = load("res://main.tscn").instantiate()
	# _ready can yield while constructing effects/session. Automation must already
	# be set when it first decides whether to read personal appearance/preferences.
	game.automated = true
	game.physics_modified = true # Any UI-triggered retry remains ineligible too.
	game.active = false
	game.benchmark_input = _input_for.bind(0)
	game.set_physics_process(false); game.set_process(false)
	root.add_child(game); current_scene = game
	var startup_deadline = Time.get_ticks_msec()+STARTUP_TIMEOUT_MS
	while not game.initialized or (game.loading and game.loading.busy):
		if Time.get_ticks_msec()>startup_deadline:
			check(false,"Main initialization/loading exceeded 600 seconds")
			await _finish(); return
		await process_frame
	check(game.session!=null and game.effects!=null and game.ghost!=null,"Main initialized effects, session and bound ghost field before fixture access")
	if not failures.is_empty(): await _finish(); return
	game.active = false
	game.set_physics_process(false); game.set_process(false)
	game.benchmark_no_captures = true
	game.preferences_enabled = false
	game.hud.feedback.persist = false
	game.voice.persist = false; game.effects.wind.persist = false; game.effects.sfx.persist = false
	game.effects.haptic_hardware_enabled = false
	game.effects.muted = true
	game.session.record_directory = fixture_store.path_join("records")
	game.session.benchmark_path = fixture_store.path_join("benchmark.json")
	game.session.mark_practice("Isolated ghost native startup")
	check(game.field.GENERATOR_ID=="laboratory" and game.field.seed_value==849205174,"Native fixture uses the requested laboratory without scene reload")
	if not failures.is_empty(): await _finish(); return
	game.start_run(true)
	game.session.mark_practice("Isolated ghost native fixture")
	if not _check_isolation("startup"): await _finish(); return
	check(game.ghost.powder_surface==game.effects.powder_surface and game.ghost.track_stack.player==game.effects.snow_tracks,"Ghost field retains bound powder receiver and player history")
	if not failures.is_empty(): await _finish(); return
	# Keep the requested quality/reconstruction settings, but measure rendered
	# frames only. The output image, not the window request, proves actual 4K.
	game.display_settings.frame_generation = false
	if not await _set_output(PIXELS,"startup"): await _finish(); return
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	if not check(not profiling,"Focused capture is not a performance profile"): await _finish(); return
	source_identity = _focused_sources()
	_setup_stage()
	for spec in [
		{"name":"hard_left","kind":"flat","gradient":.30,"speed":25.0,"seconds":3.5,"direction":-1.0},
		{"name":"hard_right","kind":"flat","gradient":.30,"speed":25.0,"seconds":3.5,"direction":1.0},
		{"name":"flight_180_switch","kind":"flat","gradient":0.0,"speed":18.0,"seconds":4.0,"direction":0.0},
		{"name":"one_ski_drop","kind":"one_ski","gradient":0.0,"speed":12.0,"seconds":3.0,"direction":0.0},
		{"name":"rock_strip","kind":"rock_strip","gradient":0.0,"speed":12.0,"seconds":3.0,"direction":0.0},
		{"name":"accepted_jump","kind":"flat","gradient":0.0,"speed":18.0,"seconds":3.0,"direction":0.0}]:
		await _focused_case(spec)
	# Independent palette evidence still runs if a physical coverage assertion fails.
	if reusable_replay!=null: await _palette_lineup()
	check(_focused_sources()==source_identity,"Source identity stable during focused capture")
	_check_isolation("focused finish")
	await _finish()

func _setup_stage() -> void:
	game.active = false; game.hud.visible = false
	game.ghost.set_enabled(false)
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,0.0,false)
	# Keep Main's sky/resources and actual material shaders; diagnostic light is
	# controlled explicitly. Layer 2 excludes the unrelated laboratory geometry.
	game.world.environment.fog_enabled = false
	game.world.environment.volumetric_fog_enabled = false
	game.world.environment.sdfgi_enabled = false
	game.world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	game.world.environment.ambient_light_color = Color(.65,.72,.82)
	game.world.environment.ambient_light_energy = .25
	game.world.sun.rotation_degrees = Vector3(-75,-20,0)
	game.world.sun.light_energy = 1.4; game.world.sun.visible = true
	game.world.sun.shadow_enabled = true; game.world.sun.directional_shadow_max_distance = 160
	game.world.moon.visible = false
	stage = Node3D.new(); root.add_child(stage)
	observer = Camera3D.new(); observer.cull_mask = STAGE_LAYER; observer.fov = 45; observer.far = 250
	stage.add_child(observer); observer.make_current()
	local_history = Tracks.new(); local_history.lighting = game.world.cloud_lighting
	stage.add_child(local_history); local_history.apply_quality(game.graphics)
	field_ghosts = Field.new(); stage.add_child(field_ghosts)
	_set_layers(game.skier)
	var overlay = CanvasLayer.new(); stage.add_child(overlay)
	caption = Label.new(); caption.position = Vector2(35,25); caption.add_theme_font_size_override("font_size",30)
	caption.add_theme_color_override("font_outline_color",Color.BLACK); caption.add_theme_constant_override("outline_size",8)
	overlay.add_child(caption)
	for i in 11:
		var label = Label.new(); label.add_theme_font_size_override("font_size",23)
		label.add_theme_color_override("font_outline_color",Color.BLACK); label.add_theme_constant_override("outline_size",7)
		overlay.add_child(label); labels.append(label); label.visible = false

func _set_layers(node: Node) -> void:
	if node is VisualInstance3D: node.layers = STAGE_LAYER
	for child in node.get_children(): _set_layers(child)

func _stage_surface(surface) -> void:
	if geometry: geometry.free()
	geometry = Node3D.new(); stage.add_child(geometry)
	var snow: ShaderMaterial = game.world.snow_material.duplicate()
	for key in ["contact_material_enabled","use_feature_exposure","powder_patch_enabled","powder_local_surface"]: snow.set_shader_parameter(key,false)
	var rock = StandardMaterial3D.new(); rock.albedo_color = Color(.19,.21,.23); rock.roughness = .92
	# Exact analytic planar pieces, including the one-ski trench; no field samples
	# are rewritten to obtain support. Vertical walls are diagnostic geometry only.
	for xr in [[-70.0,0.0],[0.0,70.0]]:
		for zr in [[-10.0,6.0],[6.0,8.0],[8.0,16.0],[16.0,22.0],[22.0,100.0]]:
			var x: float = (xr[0]+xr[1])*.5; var z: float = (zr[0]+zr[1])*.5
			var center = surface.sample(x,z)
			var points: Array[Vector3] = []
			for p in [Vector2(xr[0],zr[0]),Vector2(xr[1],zr[0]),Vector2(xr[0],zr[1]),Vector2(xr[1],zr[1])]:
				points.append(Vector3(p.x,center.height-(p.y-z)*surface.gradient,p.y))
			_quad(points,center.normal,rock if MaterialKind.at(surface,x,z)==MaterialKind.Kind.ROCK else snow)
	if surface.kind=="one_ski":
		_quad([Vector3(0,STAGE_Y,8),Vector3(0,STAGE_Y,22),Vector3(0,STAGE_Y-2.5,8),Vector3(0,STAGE_Y-2.5,22)],Vector3.RIGHT,rock)
		for z in [8.0,22.0]: _quad([Vector3(0,STAGE_Y,z),Vector3(70,STAGE_Y,z),Vector3(0,STAGE_Y-2.5,z),Vector3(70,STAGE_Y-2.5,z)],Vector3.BACK,rock)
	_set_layers(geometry)

func _quad(points: Array[Vector3], normal: Vector3, material: Material) -> void:
	var build = SurfaceTool.new(); build.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,2,1,1,2,3]:
		build.set_normal(normal); build.set_uv(Vector2(points[index].x,points[index].z)*.2); build.add_vertex(points[index])
	var node = MeshInstance3D.new(); node.mesh = build.commit(); node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry.add_child(node)

func _make_diagnostic_sim(spec: Dictionary, surface):
	var sim = Sim.new(preload("res://config/ski_default.tres").duplicate(true))
	sim.reset(Vector3(0,STAGE_Y,0)); sim.prime_contacts(surface)
	sim.velocity = sim.support_basis().z*spec.speed
	if spec.name=="flight_180_switch":
		# Explicit diagnostic initial condition, following arcade_air_suite.flight:
		# six metres of altitude, retained translational momentum, real air control.
		sim.reset(Vector3(0,STAGE_Y+6.0,0))
		sim.prime_contacts(surface)
		sim.velocity = Vector3(0,3,spec.speed)
		sim._begin_flight(Basis.IDENTITY,"focused diagnostic launch at +6 m")
	sim.reset_pose_history()
	return sim

func _focused_input(spec: Dictionary, tick: int, sim, control: Dictionary) -> RiderInput:
	var time = tick*DT
	var intent = RiderInput.new()
	intent.tuck = .2
	if spec.name.begins_with("hard_"):
		intent.steer = spec.direction*.85 if time>=.5 and time<1.7 else 0.0
	if spec.name=="accepted_jump":
		intent.jump_held = time>=.20 and time<.55; intent.jump = tick==66
		intent.grab = not sim.grounded and time<1.0
	if spec.name=="flight_180_switch":
		var omega: float = absf(sim.air_control.angular_velocity.y)
		var stopping: float = omega*omega/(2.0*sim.tuning.air_rotation_braking)
		if absf(sim.air_control.integrated_yaw)+stopping>=PI-.02: control.released = true
		intent.air_yaw = 1.0 if not sim.grounded and not control.released else 0.0
		intent.grab = not sim.grounded and time>=.18 and time<.55
	return intent

func _focused_case(spec: Dictionary) -> void:
	print("GHOST_FOCUSED_STAGE ",spec.name)
	var surface = DiagnosticSurface.new(); surface.kind = spec.kind; surface.gradient = spec.gradient
	_stage_surface(surface); local_history.reset()
	field_ghosts.clear()
	field_ghosts.bind(game.skier.assets,local_history,surface,game.graphics,game.skier)
	var sim = _make_diagnostic_sim(spec,surface)
	var control = {"released":false}
	var visual = game.skier; visual.visible = true; visual.body_pivot.visible = true
	visual.reset_animation(sim); visual.pose(sim,1.0)
	var replay = Replay.new(); var identity = Replay.key("focused-"+spec.name)
	replay.begin(sim,identity); replay.capture_presentation(0.0,Pose.capture(visual,sim,surface))
	var result = {"spec":spec,"initial_state":_physical(sim,surface),"initialization":"Explicit +6 m flight and (0,3,18) m/s" if spec.name=="flight_180_switch" else "Supported analytic start; initial tangential speed only", "physics_hz":120,"record_hz":120.0/Replay.SAMPLE_EVERY,"trace":[],"playback":[],"shots":[],"events":{},"counts":{"hard":0,"one_ski":0,"air":0,"rock":0,"switch_ground":0,"jump":0,"grab":0,"landings":0},"max_yaw":0.0,"source_grip_m":0.0,"source_boot_m":0.0,"ghost_grip_m":0.0,"ghost_boot_m":0.0,"endpoint_position_m":0.0,"endpoint_basis":0.0,"endpoint_comparisons":0,"source_interpolations":0,"ghost_interpolations":0,"track_rejections":0,"track_reentries":0,"one_ski_break_frames":0,"air_break_frames":0,"rock_break_frames":0,"contact_fidelity":true,"max_reentry_length_m":0.0,"no_false_tracks":true,"crash":""}
	var endpoints: Dictionary = {0:_world_pose(visual)}
	result.producer_cpu_us = 0; result.playback_cpu_us = 0; result.decode_ms = 0.0
	var previous_grounded: bool = sim.grounded
	var ticks = roundi(spec.seconds/DT)
	for tick in range(1,ticks+1):
		var cpu_started = Time.get_ticks_usec()
		var intent = _focused_input(spec,tick,sim,control)
		sim.step(DT,intent,surface)
		var before = Replay.snapshot(tick*DT,sim)
		visual.step_animation(DT,sim,intent,surface); visual.pose(sim,1.0)
		var completed = Pose.capture(visual,sim,surface)
		replay.record(DT,tick*DT,sim,intent,1.0 if tick==ticks or sim.crashed else -1.0)
		if replay.wants_presentation_sample():
			replay.capture_presentation(tick*DT,completed); endpoints[tick] = _world_pose(visual)
		var state = _physical(sim,surface)
		state.tick = tick; state.time = tick*DT; state.input = {"steer":intent.steer,"jump":intent.jump,"held":intent.jump_held,"yaw":intent.air_yaw,"grab":intent.grab}
		state.phase = visual.animation.full_motion.phase; state.grip_amount = visual.animation.full_motion.grip_amount
		state.recorded_contacts = []
		for i in 2:
			var index: int = 1-i if sim.facing_backward else i
			var physical = state.skis[index]
			var supported: bool = sim.grounded and not sim.crashed and physical.grounded and physical.load_n>1.0
			var recorded_support: bool = completed[Pose.CONTACT_START+i*Pose.CONTACT_WIDTH]>.5
			var recorded_track: bool = completed[Pose.CONTACT_START+i*Pose.CONTACT_WIDTH+1]>.5
			var must_break: bool = not sim.grounded or physical.rock_query==MaterialKind.Kind.ROCK or (not supported and physical.clearance>.5)
			result.contact_fidelity = result.contact_fidelity and recorded_support==supported and (not must_break or not recorded_track)
			state.recorded_contacts.append({"physical_index":index,"supported":recorded_support,"track":recorded_track,"must_break_from_actual_physics":must_break})
		_count_states(result,state,sim,previous_grounded)
		previous_grounded = sim.grounded
		if tick%2==0:
			# Production player interpolation, with its current/previous tick states.
			visual.pose(sim,.5)
			state.player_interpolated_attachments = _attachments(visual)
			result.source_grip_m = maxf(result.source_grip_m,state.player_interpolated_attachments.grip_m)
			result.source_boot_m = maxf(result.source_boot_m,state.player_interpolated_attachments.boot_m)
			result.source_interpolations += 1; visual.pose(sim,1.0)
		state.presentation_preserved_solver = before==Replay.snapshot(tick*DT,sim)
		result.trace.append(state)
		result.producer_cpu_us += Time.get_ticks_usec()-cpu_started
		if tick%4==0:
			var event = _shot_event(spec,state,result)
			if not event.is_empty():
				result.events[event] = tick
				_camera_at(visual.global_position)
				await _focused_capture(spec.name+"_player_"+event,"Completed production player; "+spec.name+" / "+event,state)
				result.shots.append({"tick":tick,"event":event})
				if event in ["hard_hold","rotation_180","one_ski_hold","both_on_rock","accepted_air"] and not result.events.has("interpolated"):
					result.events.interpolated = tick
					visual.pose(sim,.5); _camera_at(visual.global_position)
					var between = {"time":(tick-.5)*DT,"player_tick_fraction":.5,"attachments":_attachments(visual),"completed_physics_tick":tick,"event":event}
					await _focused_capture(spec.name+"_player_interpolated","Actual interpolated player; "+spec.name+" / "+event,between)
					result.shots.append({"tick":tick,"event":"interpolated","time":between.time})
					visual.pose(sim,1.0)
		if tick%16==0: await process_frame
		if sim.crashed:
			result.crash = sim.crash_reason; break
	check(result.crash.is_empty(),spec.name+": real solver completes bounded diagnostic without crash")
	check(result.trace.all(func(row): return row.presentation_preserved_solver),spec.name+": all presentation reads preserve completed solver snapshots")
	var envelope = replay.to_data()
	var decode_started = Time.get_ticks_usec()
	var restored = Replay.decode(envelope,identity,replay.duration)
	result.decode_ms = (Time.get_ticks_usec()-decode_started)/1000.0
	check(restored!=null,spec.name+": actual completed recording passes normal codec validation")
	if restored!=null:
		if reusable_replay==null: reusable_replay = restored
		await _play_recording(spec,surface,restored,endpoints,result)
	_validate_case(spec,result)
	focused_cases.append(result)
	_write_focus_report() # Preserve bounded cases even if a later case hits a real blocker.

func _physical(sim,surface) -> Dictionary:
	var skis: Array = []
	for ski in sim.skis:
		var sampled = surface.sample(ski.position.x,ski.position.z)
		skis.append({"position":_v(ski.position),"grounded":ski.grounded,"load_n":ski.load_n,"material":ski.material_kind,"rock_query":MaterialKind.at(surface,ski.position.x,ski.position.z),"height":sampled.height,"clearance":ski.position.y-sampled.height,"edge":ski.edge_angle})
	return {"position":_v(sim.position),"velocity":_v(sim.velocity),"grounded":sim.grounded,"contacts":sim.contact_count,"facing_backward":sim.facing_backward,"heading":sim.heading,"facing_heading":sim.facing_heading,"air_yaw":sim.air_control.integrated_yaw,"angular_velocity":_v(sim.air_control.angular_velocity),"turn_rate":sim.motion.turn_rate_rad_s,"turn_acceleration":absf(sim.motion.turn_rate_rad_s)*sim.velocity.length(),"applied_yaw":sim.steering_applied_yaw,"carve":sim.carve_blend,"jump_executed":sim.jump_executed,"takeoff_reason":sim.takeoff_reason,"skis":skis}

func _count_states(result: Dictionary,state: Dictionary,sim,previous_grounded: bool) -> void:
	if state.grounded and state.carve>.5 and state.turn_acceleration>8.0: result.counts.hard += 1
	if state.contacts==1 and state.skis[0].grounded!=state.skis[1].grounded: result.counts.one_ski += 1
	if not state.grounded: result.counts.air += 1
	if state.grounded and state.facing_backward: result.counts.switch_ground += 1
	if state.jump_executed: result.counts.jump += 1
	if state.grip_amount>.3 and not state.grounded: result.counts.grab += 1
	if not previous_grounded and sim.grounded: result.counts.landings += 1
	if state.skis.any(func(ski): return ski.grounded and ski.rock_query==MaterialKind.Kind.ROCK): result.counts.rock += 1
	result.max_yaw = maxf(result.max_yaw,absf(state.air_yaw))

func _shot_event(spec: Dictionary,state: Dictionary,result: Dictionary) -> String:
	var candidates: Array = []
	if state.time<=.04: candidates.append("entry")
	if spec.name.begins_with("hard_"):
		if state.carve>.5 and state.turn_acceleration>8: candidates.append("accepted_hard")
		if result.counts.hard>=36 and state.carve>.5: candidates.append("hard_hold")
		if state.time>=2.4: candidates.append("release")
	elif spec.name=="flight_180_switch":
		if state.grip_amount>.3 and not state.grounded: candidates.append("accepted_grab")
		if absf(state.air_yaw)>PI*.5: candidates.append("rotation_halfway")
		if absf(state.air_yaw)>PI-.15: candidates.append("rotation_180")
		if state.grounded and state.facing_backward: candidates.append("accepted_switch_landing")
	elif spec.name=="one_ski_drop":
		if state.contacts==1: candidates.append("one_supported_ski")
		if state.time>1.0 and state.contacts==1: candidates.append("one_ski_hold")
		if state.position[2]>24 and state.contacts==2: candidates.append("support_reentry")
	elif spec.name=="rock_strip":
		if state.skis.all(func(ski): return ski.grounded and ski.rock_query==MaterialKind.Kind.ROCK): candidates.append("both_on_rock")
		if state.position[2]>19 and state.contacts==2: candidates.append("snow_reentry")
	elif spec.name=="accepted_jump":
		if state.time>.55 and not state.grounded: candidates.append("accepted_air")
		if state.grip_amount>.3 and not state.grounded: candidates.append("accepted_grab")
		if result.counts.landings>0 and state.grounded: candidates.append("landing")
	for candidate in candidates:
		if not result.events.has(candidate): return candidate
	return ""

func _play_recording(spec: Dictionary,surface,replay,endpoints: Dictionary,result: Dictionary) -> void:
	var row = {"id":"focus-"+spec.name,"time":replay.duration,"date":1700000000,"replay":replay}
	var session = {"ghost_runs":[row],"reference_ghosts":[row],"attempt_id":field_ghosts.attempt+1}
	field_ghosts.sync_attempt(session); _set_layers(field_ghosts)
	var ghost = field_ghosts.ghosts[0]
	# Independent ribbon rendering uses this analytic surface. Local terrain GPU
	# deformation belongs to the integrated lab fixture, not this elevated stage.
	for key in ["exact_surface","contact_material_enabled","powder_patch_enabled"]: ghost.snow_tracks.material.set_shader_parameter(key,false)
	game.skier.visible = false
	var previous_live = [false,false]
	var have_live = [false,false]
	for tick in range(0,roundi(replay.duration/DT)+1):
		var cpu_started = Time.get_ticks_usec()
		var time = tick*DT
		# Render one non-endpoint beside the corresponding real player half-tick
		# view. Visit it in chronological order, preserving the real track history.
		for shot in result.shots:
			if shot.tick==tick and shot.has("time"):
				var middle = replay.presentation_at(shot.time)
				var middle_point: Vector3 = Pose.transform_at(middle.a,0).origin
				ghost.update_ghost(shot.time,middle_point+Vector3.RIGHT*18.0,true)
				var grip = _attachments(ghost.visual)
				result.ghost_grip_m = maxf(result.ghost_grip_m,grip.grip_m); result.ghost_boot_m = maxf(result.ghost_boot_m,grip.boot_m)
				_camera_at(ghost.visual.global_position)
				await _focused_capture(spec.name+"_ghost_interpolated","Actual interpolated decoded ghost; "+spec.name,{"time":shot.time,"replay_weight":middle.weight,"attachments":grip})
				cpu_started = Time.get_ticks_usec()
		var pair = replay.presentation_at(time)
		if pair.is_empty(): continue
		var point: Vector3 = Pose.transform_at(pair.a,0).origin
		ghost.update_ghost(time,point+Vector3.RIGHT*18.0,true)
		var attachments = _attachments(ghost.visual)
		result.ghost_grip_m = maxf(result.ghost_grip_m,attachments.grip_m)
		result.ghost_boot_m = maxf(result.ghost_boot_m,attachments.boot_m)
		if pair.weight>0.00001 and pair.weight<.99999: result.ghost_interpolations += 1
		if endpoints.has(tick):
			var error = _pose_error(endpoints[tick],_world_pose(ghost.visual))
			result.endpoint_position_m = maxf(result.endpoint_position_m,error.x)
			result.endpoint_basis = maxf(result.endpoint_basis,error.y)
			result.endpoint_comparisons += 1
		var contacts: Array = []
		var live_gpu: PackedFloat32Array = ghost.snow_tracks.live_gpu_strokes()
		for i in 2:
			var response = ghost.responses[i]
			var p: Vector3 = response.contact_position
			var rock: bool = MaterialKind.at(surface,p.x,p.z)==MaterialKind.Kind.ROCK
			var live: bool = ghost.snow_tracks.live_active[i]
			var rejected: bool = not response.track_contact or rock
			if rejected:
				result.track_rejections += 1
				result.no_false_tracks = result.no_false_tracks and not live and not ghost.snow_tracks.foot_history[i].is_finite()
				for word in range(i*8,i*8+8): result.no_false_tracks = result.no_false_tracks and live_gpu[word]==0.0
			if live and not previous_live[i] and have_live[i]:
				result.track_reentries += 1
				result.max_reentry_length_m = maxf(result.max_reentry_length_m,ghost.snow_tracks.live_transforms[i].basis.z.length())
			if live: have_live[i] = true
			previous_live[i] = live
			contacts.append({"supported":response.supported,"track_contact":response.track_contact,"rock_query":int(rock),"live":live,"anchor_finite":ghost.snow_tracks.foot_history[i].is_finite(),"position":_v(p),"live_gpu":Array(live_gpu.slice(i*8,i*8+8))})
		# Non-vacuous per-case agreement with the actual completed source state.
		# At intermediate frames the codec conservatively gates both endpoints;
		# compare recorded endpoints with their original physical tick only.
		if tick>0 and endpoints.has(tick) and tick<=result.trace.size():
			var original: Dictionary = result.trace[tick-1]
			if not original.grounded and contacts.all(func(c): return not c.live and not c.anchor_finite): result.air_break_frames += 1
			if original.contacts==1:
				for i in 2:
					var recorded: Dictionary = original.recorded_contacts[i]
					if recorded.must_break_from_actual_physics and not contacts[i].live and contacts[1-i].live: result.one_ski_break_frames += 1
			if original.skis.all(func(ski): return ski.grounded and ski.rock_query==MaterialKind.Kind.ROCK) and contacts.all(func(c): return not c.live and not c.anchor_finite): result.rock_break_frames += 1
		result.playback.append({"tick":tick,"time":time,"weight":pair.weight,"attachments":attachments,"contacts":contacts,"retained":ghost.snow_tracks.written})
		result.playback_cpu_us += Time.get_ticks_usec()-cpu_started
		for shot in result.shots:
			if shot.tick==tick and not shot.has("time"):
				_camera_at(ghost.visual.global_position)
				await _focused_capture(spec.name+"_ghost_"+shot.event,"Actual decoded ghost; "+spec.name+" / "+shot.event,result.playback[-1])
		if tick%2==0: await process_frame
	check(ghost.snow_tracks.written<=320,spec.name+": bounded independent ghost history")
	var retained_snow_only = true
	for stamp in ghost.snow_tracks.written:
		var start = stamp*8
		var gpu: PackedFloat32Array = ghost.snow_tracks.gpu_stamps
		for weight in [0.0,.5,1.0]:
			retained_snow_only = retained_snow_only and MaterialKind.at(surface,lerpf(gpu[start],gpu[start+2],weight),lerpf(gpu[start+1],gpu[start+3],weight))!=MaterialKind.Kind.ROCK
	check(retained_snow_only,spec.name+": retained GPU strokes do not bridge exposed rock")
	game.skier.visible = true

func _attachments(visual) -> Dictionary:
	var grips: Array = []; var boots: Array = []; var grip_max = 0.0; var boot_max = 0.0
	for side in 2:
		var prefix = "Right" if side==0 else "Left"
		var hand: int = visual.bone_ids[prefix+"Hand"]
		var foot: int = visual.bone_ids[prefix+"Foot"]
		var pose: Transform3D = visual.skeleton.get_bone_global_pose(hand)
		var rotation = pose.basis*visual.rest[hand].basis.inverse()
		var expected: Vector3 = visual.skeleton.global_transform*(pose.origin+rotation*Vector3(-.070 if side==0 else .070,0,.018))
		var pole: Vector3 = visual.poles[side].global_position
		var ankle: Vector3 = visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(foot).origin
		var socket: Vector3 = visual.skis[side].global_transform*Vector3(0,Equipment.SOLE_ABOVE_SUPPORT+visual.rest[foot].origin.y-.015,-.15)
		grip_max = maxf(grip_max,expected.distance_to(pole)); boot_max = maxf(boot_max,ankle.distance_to(socket))
		grips.append({"hand_socket":_v(expected),"pole_grip":_v(pole),"error_m":expected.distance_to(pole)})
		boots.append({"ankle":_v(ankle),"ski_socket":_v(socket),"error_m":ankle.distance_to(socket)})
	return {"grip_m":grip_max,"boot_m":boot_max,"grips":grips,"boots":boots}

func _world_pose(visual) -> Array:
	var values: Array = [visual.global_transform]
	for bone in visual.skeleton.get_bone_count(): values.append(visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(bone))
	for pair in [visual.skis,visual.poles]:
		for node in pair: values.append(node.global_transform)
	return values

func _pose_error(a: Array,b: Array) -> Vector2:
	var error = Vector2.ZERO
	for i in a.size():
		error.x = maxf(error.x,a[i].origin.distance_to(b[i].origin))
		for axis in 3: error.y = maxf(error.y,a[i].basis[axis].distance_to(b[i].basis[axis]))
	return error

func _validate_case(spec: Dictionary,result: Dictionary) -> void:
	var counts = result.counts
	check(result.source_interpolations>30 and result.ghost_interpolations>30,spec.name+": nonzero interpolated player and decoded ghost coverage")
	check(result.events.has("interpolated"),spec.name+": paired actual fractional player/ghost images captured")
	check(result.endpoint_comparisons>20 and result.endpoint_position_m<.001 and result.endpoint_basis<.002,spec.name+": decoded endpoints equal actual completed player bones/equipment")
	check(maxf(result.source_grip_m,result.ghost_grip_m)<.001 and maxf(result.source_boot_m,result.ghost_boot_m)<.001,spec.name+": actual interpolated glove/pole and ankle/ski sockets stay attached")
	check(result.no_false_tracks and result.max_reentry_length_m<2.5,spec.name+": rejected contacts clear anchors; re-entry creates local footprints only")
	check(result.contact_fidelity,spec.name+": recorded support agrees with physical ski mapping; actual air/rock/deep unsupported ski cannot emit")
	if spec.name.begins_with("hard_"):
		check(counts.hard>=24 and result.events.has("hard_hold"),spec.name+": accepted high-input loaded turn exceeds 8 m/s2 with hold coverage")
		check(result.trace.any(func(row): return row.grounded and row.applied_yaw*spec.direction<-.01),spec.name+": requested turn has corresponding accepted signed steering")
	elif spec.name=="flight_180_switch":
		check(counts.air>60 and absf(result.max_yaw-PI)<.18 and counts.switch_ground>12 and counts.landings>0,"Actual air rotation reaches 180 degrees, releases and lands switch")
		check(counts.grab>6 and result.events.has("accepted_switch_landing"),"Actual grab and switch-landing images were exercised")
	elif spec.name=="one_ski_drop":
		check(counts.one_ski>12 and result.one_ski_break_frames>3 and result.track_reentries>0,"Actual terrain drop stops only its unsupported ski trail, preserves the peer and reopens locally")
	elif spec.name=="rock_strip":
		check(counts.rock>12 and result.rock_break_frames>3 and result.events.has("snow_reentry") and result.track_reentries>=2,"Both actual skis cross exposed rock, reject trails, and return to snow")
	elif spec.name=="accepted_jump":
		check(counts.jump>0 and counts.air>12 and result.air_break_frames>3 and counts.landings>0 and result.track_reentries>=2,"Actual jump executes, loses support, breaks both tracks and lands without a bridge")

func _camera_at(point: Vector3) -> void:
	observer.fov = 45
	observer.global_position = point+Vector3(3.6,2.1,5.4)
	observer.look_at(point+Vector3.UP*.8)

func _palette_lineup() -> void:
	print("GHOST_FOCUSED_STAGE palette_lineup")
	var surface = DiagnosticSurface.new(); _stage_surface(surface)
	field_ghosts.clear(); field_ghosts.bind(game.skier.assets,local_history,surface,game.graphics,game.skier)
	var lineup: Array = []
	for i in 10: lineup.append({"id":"lineup-run-%02d"%i,"time":reusable_replay.duration,"date":1700000000+i,"replay":reusable_replay})
	var session = {"ghost_runs":lineup,"reference_ghosts":lineup,"attempt_id":field_ghosts.attempt+1}
	field_ghosts.sync_attempt(session); _set_layers(field_ghosts)
	var sim = Sim.new(); sim.reset(Vector3(9,STAGE_Y,2)); sim.prime_contacts(surface)
	game.skier.reset_animation(sim); game.skier.pose(sim,1.0); game.skier.visible = true
	# Raised oblique view and 6.5 m row separation keep all ten complete skiers
	# apart in projection; a shallow chase angle would occlude the second row.
	observer.fov = 37; observer.global_position = Vector3(3,STAGE_Y+12,24); observer.look_at(Vector3(1,STAGE_Y+1,3))
	var caster = MeshInstance3D.new(); var box = BoxMesh.new(); box.size = Vector3(42,.5,26)
	caster.mesh = box; caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	caster.layers = STAGE_LAYER; stage.add_child(caster); caster.position = Vector3(0,STAGE_Y+8,2)
	var original: Color = game.skier.appearance.values.Clothing.tint
	for outfit in [{"name":"default","tint":original},{"name":"dark","tint":Color("22252b")},{"name":"light","tint":Color("edf6ff")},{"name":"cyan","tint":Color("22c6de")}]:
		game.skier.appearance.change("Clothing","tint",outfit.tint,false)
		field_ghosts.refresh_colors(lineup)
		var binding: Dictionary = field_ghosts.colors.duplicate()
		field_ghosts.refresh_colors(lineup)
		check(binding==field_ghosts.colors,outfit.name+": stable run-to-color bindings on unchanged appearance")
		var entries: Array = []
		var projected: Array[Rect2] = []
		for i in 10:
			var ghost = field_ghosts.ghosts[i]
			ghost.update_ghost(0.0,Vector3(30,STAGE_Y,0),true,false,false)
			# Translate only the completed presentation root/equipment together.
			# This is an explicitly arranged lineup, never an actual race trajectory.
			ghost.visual.global_position = Vector3((i%5-2)*2.8,STAGE_Y,6.5 if i<5 else 0.0)
			ghost.snow_tracks.visible = false
			labels[i].visible = true; labels[i].text = "#%d %s\n%s"%[i+1,ghost.run_id,ghost.color.to_html()]
			labels[i].modulate = ghost.color; labels[i].position = observer.unproject_position(ghost.visual.global_position+Vector3.UP*2.2)-Vector2(95,0)
			var rect = _screen_bounds(ghost.visual); projected.append(rect)
			entries.append({"id":ghost.run_id,"color":ghost.color.to_html(),"display_position":_v(ghost.visual.global_position),"recorded_position":_v(Pose.transform_at(reusable_replay.presentation_at(0).a,0).origin),"opacity":ghost.opacity,"projected_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
		projected.append(_screen_bounds(game.skier))
		var framed = true; var separated = true
		for i in projected.size():
			framed = framed and Rect2(Vector2.ZERO,Vector2(PIXELS)).encloses(projected[i])
			for j in range(i): separated = separated and not projected[i].intersects(projected[j])
		check(framed and separated,outfit.name+": all ten joint/equipment bounds and player are framed and separated in projection")
		labels[10].visible = true; labels[10].text = "LIVE / "+outfit.name
		labels[10].position = observer.unproject_position(game.skier.global_position+Vector3.UP*2.2)-Vector2(60,0)
		var bright_luma = -1.0
		for shadow in [false,true]:
			caster.visible = shadow
			for frame in 12: await process_frame
			var info = {"outfit":outfit.name,"shadow_caster":shadow,"arrangement":"Separated presentation-only 2x5 lineup; shared actual decoded clip is deliberate; IDs/colors remain bound","entries":entries,"light_rotation":_v(game.world.sun.rotation_degrees),"light_energy":game.world.sun.light_energy,"ambient_energy":game.world.environment.ambient_light_energy}
			var image = await _focused_capture("palette_"+outfit.name+("_shadow" if shadow else "_bright"),"Separated production-material ghost lineup / "+outfit.name+(" / real overhead shadow caster" if shadow else " / direct sunlight"),info)
			if image!=null:
				var probe: Vector2 = observer.unproject_position(Vector3(0,STAGE_Y,-3))
				var luma = _image_luma(image,probe)
				info.shadow_probe_pixel = [probe.x,probe.y]; info.shadow_probe_luma = luma
				if not shadow: bright_luma = luma
				else: check(bright_luma>0.0 and luma<bright_luma*.90,outfit.name+": real caster visibly darkens the snow probe; palette still needs pixel review")
			palette_rows.append(info)
	game.skier.appearance.change("Clothing","tint",original,false)
	field_ghosts.refresh_colors(lineup); caster.queue_free()

func _screen_bounds(visual) -> Rect2:
	var points: Array[Vector3] = []
	for i in visual.skeleton.get_bone_count(): points.append(visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(i).origin)
	for group in [visual.skis,visual.poles]:
		for node in group:
			var box: AABB = node.mesh.get_aabb()
			for x in [0.0,1.0]:
				for y in [0.0,1.0]:
					for z in [0.0,1.0]: points.append(node.global_transform*(box.position+box.size*Vector3(x,y,z)))
	var rect = Rect2(observer.unproject_position(points[0]),Vector2.ZERO)
	for point in points: rect = rect.expand(observer.unproject_position(point))
	return rect.grow(10.0)

func _image_luma(image: Image,point: Vector2) -> float:
	var value = 0.0
	for y in range(-2,3):
		for x in range(-2,3):
			var c = image.get_pixel(clampi(roundi(point.x)+x,0,image.get_width()-1),clampi(roundi(point.y)+y,0,image.get_height()-1))
			value += c.r*.2126+c.g*.7152+c.b*.0722
	return value/25.0

func _focused_capture(name: String,title: String,state: Dictionary):
	caption.text = title+"\nIsolated analytic diagnostic; no race timing/performance claim"
	var start = Time.get_ticks_usec()
	await process_frame; await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	if not _framebuffer_matches(image,name): return null
	check(image.save_png(output.path_join(name+".png"))==OK,"Saved "+name)
	readback_us += Time.get_ticks_usec()-start
	focused_captures.append({"name":name,"pixels":[image.get_width(),image.get_height()],"camera":_v(observer.global_position),"fov":observer.fov,"state":state})
	return image

static func _v(value: Vector3) -> Array: return [value.x,value.y,value.z]

func _focused_sources() -> Dictionary:
	var sources: Dictionary = {}
	for path in ["tests/ghost_focused_native.gd","tests/ghost_playtest.gd","scripts/core/ski_simulation.gd","scripts/core/ski_contact.gd","scripts/core/air_rotation.gd","config/ski_default.tres","scripts/presentation/ghost_pose.gd","scripts/presentation/personal_best_ghost.gd","scripts/presentation/ghost_field.gd","scripts/presentation/ghost_palette.gd","scripts/presentation/skier_visual.gd","scripts/presentation/skier_full_motion.gd","scripts/presentation/pole_push_pose.gd","scripts/presentation/snow_response.gd","scripts/presentation/snow_tracks.gd","scripts/racing/run_replay.gd","assets/graphics/ghost_skier.gdshader","assets/graphics/ski_track.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	for path in ["scripts/presentation/skier_pose_writer.gd","scripts/presentation/skier_equipment.gd","scripts/presentation/skier_animation.gd","scripts/presentation/skier_anatomy.gd","scripts/presentation/action_posture.gd","scripts/presentation/downhill_posture.gd","assets/graphics/models/skier_v7.glb","assets/animation/steep_ski_motion.res"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	return sources

func _write_focus_report() -> void:
	var report = {"checks":checks,"failures":failures,"scope":"One Main load; 20 seconds total actual 120 Hz physics on labelled analytic fixtures; no fabricated recording frames/contact flags. Separated lineup positions are presentation-only.","cases":focused_cases,"palette":palette_rows,"captures":focused_captures,"sources":source_identity,"engine":Engine.get_version_info().string,"display":game.display_settings.report(root,actual_pixels) if is_instance_valid(game) else {},"framebuffers":framebuffer_checks,"readback_wall_ms":readback_us/1000.0,"performance_eligible":false,"human_acceptance":"pending"}
	var file = preload("res://tests/test_report.gd").open_write(output.path_join("focused_results.json"))
	if file: file.store_string(JSON.stringify(report,"\t")); file.close()
	else: check(false,"Focused report writable")

func _finish() -> void:
	_write_focus_report()
	print("GHOST_FOCUSED_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"output":output,"cases":focused_cases.size(),"palette":palette_rows.size()}))
	if is_instance_valid(game):
		game.active = false
		if game.effects: game.effects.stop_audio()
	if is_instance_valid(field_ghosts): field_ghosts.clear()
	if is_instance_valid(stage): stage.queue_free()
	if is_instance_valid(game): game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
