extends Node
## Session owner for diagnostic capture and read-only evidence playback.
const Policy = preload("res://scripts/diagnostics/case_policy.gd")
const Simulation = preload("res://scripts/diagnostics/case_simulation.gd")
const Surface = preload("res://scripts/diagnostics/case_surface.gd")
const Recorder = preload("res://scripts/diagnostics/case_recorder.gd")
const Store = preload("res://scripts/diagnostics/case_store.gd")
const Pose = preload("res://scripts/diagnostics/case_pose.gd")
const CasePanel = preload("res://scripts/ui/test_case_panel.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Response = preload("res://scripts/presentation/snow_response.gd")
var game
var directory = Store.DIRECTORY
var ui = CasePanel.new()
var policy = Policy.new()
var recorder
var recording_mode = false
var reviewing = false
var case_data
var case_path = ""
var return_menu = "title"
var original_sim
var original_surface
var original_preferences = false
var original_modified = false
var original_weather: Dictionary = {}
var review_weather: Dictionary = {}
var review_preferences = false
var review_appearance: Dictionary = {}
var filtered_surface
var playhead = 0.0
var playing = false
var rate = 1.0
var looping = true
var in_tick = 0
var out_tick = 1
var view_camera: Camera3D
var free_camera = false
var camera_active = false
var yaw = 0.0
var pitch = -.2
var distance = 8.0
var orbit_center = Vector3.ZERO
var last_frame: Dictionary = {}
var tick_rows: Array = []
var frame_times: Array = []
var current_frame_index = 0
var all_events: Array = []
var responses: Array = [Response.new(),Response.new()]
var track_history
var last_track_time = -1.0
var file_dialog: FileDialog
var finishing = false
var pending_events: Array = []

func setup(value) -> void:
	game = value; ui.build(self,game.hud.root)
	var entry: Button = game.hud._button("Test Cases")
	game.hud.weather_button.get_parent().add_child(entry)
	entry.pressed.connect(open_library)
	view_camera = Camera3D.new(); view_camera.far = 12000; view_camera.near = .05; add_child(view_camera)
	if get_tree().has_meta("test_case_open"):
		var path: String = get_tree().get_meta("test_case_open"); get_tree().remove_meta("test_case_open")
		open_case.call_deferred(path)

func open_library() -> void:
	if recorder and recorder.running:
		open_controls(); return
	if reviewing: _end_review()
	if not recording_mode: return_menu = game.hud.menu_mode if game.hud.menu_mode in ["title","paused","crashed","finished"] else "paused"
	game.active = false; game.hud.hide_menu(); game.effects.stop_audio(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var entries: Array = []
	DirAccess.make_dir_recursive_absolute(directory)
	var names = DirAccess.get_files_at(directory); names.reverse()
	for name_value in names:
		if not name_value.ends_with(".apexcase"): continue
		var path = directory+"/"+name_value
		var data = Store.open_case(path)
		entries.append({"path":path,"title":data.metadata.get("title",name_value)+(" · unavailable: "+data.error if not data.error.is_empty() else " · %.2f s"%((data.metadata.end_tick-data.metadata.start_tick)/120.0))})
	ui.library(entries)

func setup_recording() -> void:
	if game.current_mountain==null: ui.status.text = "Choose a mountain before recording."; return
	ui.controls(true)

func start_recording() -> void:
	# Only explicitly queued setup commands survive the summit reset. A new take
	# never inherits a consumed one-shot command from an earlier take.
	var launch_commands: Array = policy.pending.duplicate(true) if ui.mode=="recording setup" else []
	if reviewing: _end_review()
	if not recording_mode:
		original_sim = game.sim; original_surface = game.world.ski_surface
		original_preferences = game.preferences_enabled; original_modified = game.physics_modified
		original_weather = game.weather.snapshot()
		game.sim = Simulation.new(game.sim.tuning.duplicate(true)); game.sim.policy = policy; game.sim.impacts.policy = policy
		filtered_surface = Surface.new(game.field,original_surface,policy); game.world.ski_surface = filtered_surface
		recording_mode = true; game.preferences_enabled = false; game.physics_modified = true
	game.crash_collision.set_diagnostic_filter(policy.values.trees,policy.values.rocks)
	ui.panel.hide(); ui.toolbar.show(); game.start_run(false)
	policy.pending = launch_commands
	game.session.eligible = false; game.session.recording = null
	game.hud.toast("TEST RECORDING · Choose a face and drop in. F9 controls · F10 save.")

func begin_take() -> void:
	if not recording_mode: return
	recorder = Recorder.new(); recorder.begin(game)
	pending_events.clear()

func queue_controls(set_once: bool, resume_after: bool = false) -> void:
	var values = ui.control_values()
	var error = Policy.settings_error(values)
	if not error.is_empty(): ui.status.text = error; return
	if ui.mode=="recording setup":
		policy.values = values.duplicate()
		if set_once: policy.queue_speed(values.speed_kmh); ui.status.text = "Speed will be applied at the first skiing tick."
		if resume_after: start_recording()
		return
	policy.queue_settings(values)
	if set_once: policy.queue_speed(values.speed_kmh)
	ui.status.text = "Queued for the next recording tick."
	if resume_after:
		ui.panel.hide()
		if game.sim.crashed:
			game.session.recovery_paused = false; game.skier.ragdoll.set_frozen(false)
		else: game.resume()

func open_controls() -> void:
	if not recording_mode: setup_recording(); return
	game.active = false
	if game.sim.crashed:
		game.session.recovery_paused = true; game.skier.ragdoll.set_frozen(true)
	game.hud.hide_menu(); game.effects.stop_audio(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.controls(false)

func record_input_reset() -> void:
	if recorder and recorder.running: policy.pending.append({"kind":"reset_input","value":true})

func before_tick() -> void:
	if not recording_mode or recorder==null or not recorder.running: return
	var points: Array = []
	var needs_overlap = false
	for command in policy.pending:
		if command.kind=="settings" and ((command.value.trees and not policy.values.trees) or (command.value.rocks and not policy.values.rocks)): needs_overlap = true
	if needs_overlap: points.append(game.sim.position)
	for ski in game.skier.skis if needs_overlap else []:
		points.append(ski.global_position-Vector3.UP*.8)
		points.append(ski.global_position+ski.global_basis.z*game.sim.tuning.ski_length*.5-Vector3.UP*.8)
		points.append(ski.global_position-ski.global_basis.z*game.sim.tuning.ski_length*.5-Vector3.UP*.8)
	if needs_overlap and game.skier.ragdoll.running:
		for body in game.skier.ragdoll.bodies.values(): points.append(body.global_position-Vector3.UP*.8)
	pending_events = policy.before_tick(game.sim,filtered_surface,recorder.tick+1,points)
	game.crash_collision.set_diagnostic_filter(policy.values.trees,policy.values.rocks)
	if not policy.error.is_empty(): game.hud.toast(policy.error)

func observe_tick(skiing: bool) -> void:
	if not recording_mode or recorder==null or not recorder.running: return
	recorder.observe_tick(game.sim,game.intent,skiing,pending_events); pending_events = []
	if not recorder.running: save_recording.call_deferred("size_limit" if recorder.data.error=="size_limit" else "duration_limit",true)

func crash_tick() -> void:
	if not recording_mode or game.session.recovery_paused or not game.application_focused: return
	before_tick(); observe_tick(false)
	if recorder and game.skier.ragdoll.elapsed>=15.0: save_recording.call_deferred("crash_aftermath",true)

func observe_frame(dt: float, fraction: float) -> void:
	if recorder and recorder.running and game.application_focused and not ui.panel.visible and (game.active or (game.sim.crashed and not game.session.recovery_paused)):
		recorder.observe_frame(game,dt,fraction)
		if not recorder.running: save_recording.call_deferred("size_limit",true)
	if recording_mode:
		game.hud.mode_label.text = "TEST RECORDING"
		ui.record_status.text = "Actual %.1f km/h · %s\nImmortal %s · Trees %s · Rocks %s"%[game.sim.speed_kmh(),"Target %.0f km/h"%policy.values.speed_kmh if policy.values.hold_speed else "Natural speed",on_off(policy.values.immortal),on_off(policy.values.trees),on_off(policy.values.rocks)]

func save_recording(reason: String, review_after: bool = false) -> bool:
	if finishing: return true
	if recorder==null or recorder.tick==0: return true
	finishing = true
	recorder.finish(reason)
	var path = Store.fresh_path(directory)
	var error = recorder.data.save(path)
	finishing = false
	if not error.is_empty():
		game.active = false; open_controls(); ui.status.text = error; return false
	case_path = path; recorder = null
	game.hud.toast("Recording saved")
	if review_after: open_case.call_deferred(path)
	return true

func restart_recording() -> void:
	if not save_recording("restart"): return
	policy.pending.clear(); ui.panel.hide(); game.restart()

func before_transition(reason: String) -> bool:
	if not recording_mode: return true
	if not save_recording(reason): return false
	if reason in ["mountain","quit"]:
		game.sim = original_sim; game.world.ski_surface = original_surface
		game.preferences_enabled = original_preferences; game.physics_modified = original_modified
		game.weather.restore(original_weather); game.crash_collision.set_diagnostic_filter(true,true)
		recording_mode = false; policy = Policy.new(); ui.toolbar.hide()
	policy.pending.clear()
	return true

func leave_mode() -> void:
	if not save_recording("exit"): return
	if reviewing: _end_review()
	ui.panel.hide(); ui.toolbar.hide(); camera_active = false
	if recording_mode:
		game.sim = original_sim; game.world.ski_surface = original_surface
		game.preferences_enabled = original_preferences; game.physics_modified = original_modified
		game.weather.restore(original_weather); game.crash_collision.set_diagnostic_filter(true,true)
		recording_mode = false; policy = Policy.new()
		game.start_run(false)
	game.active = false; game.hud.show_menu("title")

func back() -> void:
	if camera_active:
		camera_active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; ui.panel.show(); return
	if reviewing:
		if ui.mode=="save clip": ui.review()
		else: open_library()
	elif ui.mode=="test controls":
		ui.panel.hide()
		if game.sim.crashed: game.session.recovery_paused = false; game.skier.ragdoll.set_frozen(false)
		else: game.resume()
	elif ui.mode=="recording setup": open_library()
	elif recording_mode: leave_mode()
	else: ui.panel.hide(); game.hud.show_menu(return_menu)

func choose_file() -> void:
	if file_dialog==null:
		file_dialog = FileDialog.new(); file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = PackedStringArray(["*.apexcase ; Alpine Apex test case"]); game.hud.root.add_child(file_dialog)
		file_dialog.file_selected.connect(open_case)
	file_dialog.popup_centered_ratio(.75)

func open_case(path: String) -> void:
	if not save_recording("review"): return
	var data = Store.open_case(path)
	if not data.error.is_empty(): ui.status.text = data.error; return
	if not Pose.compatible(data.metadata.rig,game.skier): ui.status.text = "This case requires a different skier rig or asset."; return
	var reference = data.metadata.identity.get("mountain")
	var error = Definition.reference_error(reference)
	if not error.is_empty(): ui.status.text = error; return
	if game.current_mountain==null or not Store.same_data(reference,game.current_mountain.to_reference()):
		var decoded = Definition.decode(JSON.stringify({"format":"alpine-apex-mountain","schema":2,"name":"Recorded mountain","mountain":reference}))
		if not decoded.error.is_empty(): ui.status.text = decoded.error; return
		ui.status.text = "Reconstructing the recorded mountain…"; await get_tree().process_frame
		var restored = decoded.mountain.reconstruct()
		if not restored.error.is_empty(): ui.status.text = restored.error; return
		if recording_mode: leave_mode()
		get_tree().set_meta("test_case_open",path)
		game.load_mountain(decoded.mountain,restored.field); return
	if reviewing: _end_review()
	case_data = data; case_path = path
	tick_rows = data.rows("ticks")
	if tick_rows.size()!=int(data.metadata.duration_ticks)+1: ui.status.text = "Incomplete tick coverage."; return
	for i in tick_rows.size():
		if tick_rows[i].tick!=i or tick_rows[i].input.size()!=(9 if i>0 and i<=data.metadata.input_ticks else 0): ui.status.text = "Invalid input coverage."; return
	frame_times.clear(); all_events.clear()
	for chunk_index in data.chunks.size():
		if data.chunks[chunk_index].kind=="frames":
			for frame in data._rows(chunk_index): frame_times.append(frame.t)
	for row in tick_rows: all_events.append_array(row.events)
	if not data.error.is_empty() or frame_times.is_empty(): ui.status.text = data.error if not data.error.is_empty() else "This case has no rendered frames."; return
	review_weather = game.weather.snapshot(); review_preferences = game.preferences_enabled; game.preferences_enabled = false
	review_appearance = game.skier.appearance.values.duplicate(true)
	var appearance = tick_rows[0].get("presentation",{}).get("appearance",{})
	for id in game.skier.appearance.DEFAULTS:
		for property in game.skier.appearance.DEFAULTS[id]:
			var value = appearance.get(id,{}).get(property)
			if typeof(value)==typeof(game.skier.appearance.DEFAULTS[id][property]): game.skier.appearance.change(id,property,value,false)
	game.active = false; game.skier.ragdoll.stop(); game._invalidate_crash_recovery()
	game.hud.hide_menu(); game.effects.reset(); game.effects.stop_audio(); game._reset_screen_effects(); game._clear_storm_effects()
	game.weather_effects.reset(); game.vectors.hide(); game.skier.set_process_unhandled_input(false)
	game.voice.silence(); game.hud.debug_panel.hide(); game.hud.toast_label.hide()
	reviewing = true; playing = false; free_camera = false; camera_active = false
	in_tick = int(data.metadata.start_tick); out_tick = int(data.metadata.end_tick)
	track_history = preload("res://scripts/presentation/snow_tracks.gd").new(); track_history.lighting = game.world.assets.lighting; add_child(track_history)
	ui.toolbar.hide(); ui.review(); seek(in_tick/120.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _end_review() -> void:
	reviewing = false; playing = false; camera_active = false
	game.skier.set_process_unhandled_input(true)
	if track_history:
		game.world.assets.lighting.materials.erase(track_history.material); track_history.queue_free(); track_history = null
	game.weather.restore(review_weather); game.preferences_enabled = review_preferences
	game.skier.appearance.values = review_appearance.duplicate(true)
	for id in review_appearance: game.skier.appearance.apply(id)
	view_camera.current = false; game._restore_riding_camera(); game.effects.reset(); game.weather_effects.reset()
	game.start_run(false); game.active = false
	tick_rows.clear(); frame_times.clear(); last_frame.clear()

func seek(time: float) -> void:
	if not reviewing: return
	playhead = clampf(time,case_data.metadata.start_tick/120.0,case_data.metadata.end_tick/120.0)
	game.effects.reset(); game.weather_effects.reset(); game._reset_screen_effects(); game._clear_storm_effects()
	if Engine.has_singleton("AlpineFidelityFX"): Engine.get_singleton("AlpineFidelityFX").reset_history()
	_rebuild_tracks(playhead)
	show_frame(playhead)

func _rebuild_tracks(time: float) -> void:
	if not track_history: return
	track_history.reset(); last_track_time = -1
	for frame in case_data.rows("frames",maxf(0,time-30),time): _tracks(frame)

func _tracks(frame: Dictionary) -> void:
	if not track_history or frame.t<=last_track_time: return
	last_track_time = frame.t
	var contacts: PackedFloat32Array = frame.get("contacts",PackedFloat32Array())
	if contacts.size()!=21 or frame.crashed:
		track_history.foot_history.fill(Vector3.INF); return
	var count: int = case_data.metadata.rig.names.size()
	for i in 2:
		var response = responses[i]; var offset = i*10
		response.supported = contacts[offset]>.5; response.snow_contact = contacts[offset+1]>.5; response.track_contact = response.snow_contact
		response.width_m = contacts[offset+2]; response.contact_width_m = contacts[offset+3]; response.depth_m = contacts[offset+4]; response.track_depth_m = response.depth_m
		response.slip = contacts[offset+5]; response.crystal_density = contacts[offset+6]
		response.throw_world = Vector3(contacts[offset+7],contacts[offset+8],contacts[offset+9])
		var equipment = Pose.GhostPose.transform_at(frame.pose,count+2+i)
		response.contact_position = equipment.origin; response.contact_forward = equipment.basis.z
	track_history.update_presentation(game.field,Pose.GhostPose.transform_at(frame.pose,0).origin,true,responses,contacts[-1])

func show_frame(time: float, selected_frame: Dictionary = {}) -> void:
	var frame: Dictionary = case_data.frame_at(time) if selected_frame.is_empty() else selected_frame
	if frame.is_empty(): return
	current_frame_index = maxi(0,frame_times.bsearch(frame.t,false)-1)
	Pose.apply(game.skier,frame.pose); last_frame = frame
	if not free_camera: Pose.camera_apply(view_camera,frame.camera)
	view_camera.make_current(); game.presentation_camera = view_camera
	# Snapshot restore does not advance the weather clock and never saves preferences.
	game.weather.restore(frame.weather)
	game.world.update_weather(game.weather.state,0,false)
	_tracks(frame)
	var state: Dictionary = tick_rows[clampi(roundi(playhead*120),0,tick_rows.size()-1)].state
	game.hud.mode_label.text = "TEST CASE REVIEW"
	game.hud.speed_label.text = str(roundi(state.velocity.length()*3.6)); game.hud.speed_dial.speed = state.velocity.length()*3.6; game.hud.speed_dial.queue_redraw()
	game.hud.state_label.text = state.crash_reason if state.crashed else "RECORDED AIRBORNE" if not state.grounded else "RECORDED SKIING"
	game.hud.band_label.text = "RECORDED SPEED"; game.hud.impact_bar.value = state.reserve*100
	game.hud.altitude_label.text = "%d m · RECORDED"%roundi(state.position.y)
	game.hud.fps_label.text = "%d FPS · POSE PLAYBACK"%Engine.get_frames_per_second()
	if ui.timeline: ui.timeline.set_value_no_signal(roundi(playhead*120))
	if ui.mode=="review":
		var values = Policy.at_tick(case_data.metadata.initial_settings,all_events,roundi(playhead*120))
		ui.clock.text = "Original %08.3f s · tick %d · captured frame %.3f s · In %.3f / Out %.3f · %.3f s"%[playhead,roundi(playhead*120),frame.t,in_tick/120.0,out_tick/120.0,(out_tick-in_tick)/120.0]
		var nearby: Array = []
		for event in all_events:
			if event.kind!="reset_input" and absf(event.tick/120.0-playhead)<2: nearby.append("%.3f s %s"%[event.tick/120.0,"controls" if event.kind=="settings" else "set speed"])
		ui.status.text = "%s camera · Immortal %s · Trees %s · Rocks %s%s%s"%["Free" if free_camera else "Recorded",on_off(values.immortal),on_off(values.trees),on_off(values.rocks)," · Hold %.0f km/h"%values.speed_kmh if values.hold_speed else ""," · Changes: "+", ".join(nearby) if not nearby.is_empty() else ""]

func update_review(dt: float) -> void:
	if not game.application_focused: return
	if playing:
		var next = playhead+dt*rate
		if next>out_tick/120.0:
			if looping: seek(in_tick/120.0); return
			next = out_tick/120.0; playing = false
		playhead = next; show_frame(playhead)
	if camera_active: _move_camera(dt)
	elif ui.mode=="review" and not game.navigation.top_popup():
		var id: int = game.navigation.device
		if id>=0 and id in Input.get_connected_joypads():
			var scrub = Input.get_joy_axis(id,JOY_AXIS_TRIGGER_RIGHT)-Input.get_joy_axis(id,JOY_AXIS_TRIGGER_LEFT)
			if absf(scrub)>.2: seek(playhead+scrub*dt*20)
	game.world.assets.update_foliage_sight(view_camera,game.skier.global_position,dt,true,game.camera_settings.shared.forest_visibility,game.camera_settings.shared.forest_visibility_strength)

func step_frame(direction: int) -> void:
	playing = false
	var index = clampi(current_frame_index+direction,0,frame_times.size()-1)
	var frame: Dictionary = case_data.frame_by_index(index)
	if frame.is_empty(): return
	seek(frame.t)
	if absf(playhead-frame.t)<1e-9:
		show_frame(playhead,frame); current_frame_index = index

func mark_in() -> void:
	in_tick = clampi(roundi(playhead*120),int(case_data.metadata.start_tick),out_tick-1); show_frame(playhead)
func mark_out() -> void:
	out_tick = clampi(roundi(playhead*120),in_tick+1,int(case_data.metadata.end_tick)); show_frame(playhead)

func save_selection() -> void:
	var title = ui.title_edit.text.strip_edges()
	if title.is_empty(): ui.status.text = "Name this bug clip."; return
	var clipped = case_data.trim(in_tick,out_tick,title,ui.what_edit.text,ui.expected_edit.text)
	var error: String = clipped.error
	var path = Store.fresh_path(directory)
	if error.is_empty(): error = clipped.save(path)
	if not error.is_empty(): ui.status.text = error; return
	DisplayServer.clipboard_set(ProjectSettings.globalize_path(path))
	ui.review(); ui.status.text = "Saved clip · path copied · "+ProjectSettings.globalize_path(path)
	case_path = path

func copy_path() -> void: DisplayServer.clipboard_set(ProjectSettings.globalize_path(case_path))
func open_folder() -> void: OS.shell_open(ProjectSettings.globalize_path(case_path.get_base_dir()))

func toggle_camera() -> void:
	free_camera = not free_camera
	if free_camera: focus_skier(); show_frame(playhead)
	else: camera_active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; show_frame(playhead)

func focus_skier() -> void:
	if last_frame.is_empty(): return
	free_camera = true
	var pose = Pose.GhostPose.transform_at(last_frame.pose,2)
	var skeleton = Pose.GhostPose.transform_at(last_frame.pose,1)
	orbit_center = skeleton*pose.origin
	yaw = view_camera.rotation.y; pitch = -.2; distance = 8
	_orbit()

func capture_camera() -> void:
	if not free_camera: toggle_camera()
	camera_active = true; ui.panel.hide(); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _orbit() -> void:
	view_camera.rotation = Vector3(pitch,yaw,0)
	view_camera.global_position = orbit_center+view_camera.global_basis.z*distance

func _move_camera(dt: float) -> void:
	var move = Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var id: int = game.navigation.device
	if id>=0 and id in Input.get_connected_joypads():
		var stick = Vector2(Input.get_joy_axis(id,JOY_AXIS_RIGHT_X),Input.get_joy_axis(id,JOY_AXIS_RIGHT_Y))
		if stick.length()>.2: yaw -= stick.x*dt*2; pitch = clampf(pitch-stick.y*dt*2,-1.5,1.5)
		var translation = Vector2(Input.get_joy_axis(id,JOY_AXIS_LEFT_X),Input.get_joy_axis(id,JOY_AXIS_LEFT_Y))
		if translation.length()>.2: move += Vector3(translation.x,0,translation.y)
		move.y += Input.get_joy_axis(id,JOY_AXIS_TRIGGER_RIGHT)-Input.get_joy_axis(id,JOY_AXIS_TRIGGER_LEFT)
	view_camera.rotation = Vector3(pitch,yaw,0)
	view_camera.global_position += view_camera.global_basis*move*dt*15
	orbit_center = view_camera.global_position-view_camera.global_basis.z*distance

func route(event: InputEvent) -> bool:
	if recording_mode and not reviewing:
		if event.is_action_pressed("tuning") or event.is_action_pressed("race_library") or event.is_action_pressed("run_records"):
			open_controls(); return true
		if event is InputEventKey and event.pressed and not event.echo and not ui.panel.visible:
			if event.physical_keycode==KEY_F10: save_recording("manual",true); return true
			if event.physical_keycode==KEY_F9: open_controls(); return true
		if event.is_action_pressed("pause_run") and not ui.panel.visible: open_controls(); return true
	if not reviewing: return false
	if game.navigation.top_popup(): return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F9:
		ui.panel.visible = not ui.panel.visible; return true
	if ui.mode=="review" and not camera_active and event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
		seek(playhead+(-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1)); return true
	if not ui.panel.visible and not camera_active and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_run") or (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B,JOY_BUTTON_START])):
		ui.panel.show(); return true
	if camera_active:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_run") or (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B,JOY_BUTTON_START]): back(); return true
		if event is InputEventMouseMotion:
			yaw -= event.relative.x*.004; pitch = clampf(pitch-event.relative.y*.004,-1.5,1.5)
		return true
	if not free_camera or ui.mode!="review": return false
	if event is InputEventMouse and ui.panel.get_global_rect().has_point(event.position): return false
	if event is InputEventMouseMotion:
		if event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
			yaw -= event.relative.x*.004; pitch = clampf(pitch-event.relative.y*.004,-1.5,1.5); _orbit(); return true
		if event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:
			orbit_center += (-view_camera.global_basis.x*event.relative.x+view_camera.global_basis.y*event.relative.y)*distance*.002; _orbit(); return true
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		distance = clampf(distance*(.85 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.18),.5,300); _orbit(); return true
	return false

static func on_off(value: bool) -> String: return "on" if value else "off"
