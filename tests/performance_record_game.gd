extends "res://scripts/main.gd"
## Manual diagnostic launch. Gameplay/solver remain inherited production code.
const Recorder = preload("res://tests/performance_recorder.gd")
const RecordingPrompts = preload("res://scripts/ui/controller_prompts.gd")
var recorder = Recorder.new()
var record_directory = "res://artifacts/player_recordings/current"
var record_ready = false
var record_status: Label
var record_help: Label
var attempt = 0
var last_saved = ""
var metadata: Dictionary = {}

func _ready() -> void:
	await super._ready()
	if not initialized: return
	physics_modified = true # All restarts and custom races remain unranked.
	preferences_enabled = false
	camera_settings.load_preferences()
	camera.settings = camera_settings
	display_settings.apply_display(get_window(),benchmark_resolution)
	display_settings.apply_viewport(get_viewport())
	weather.set_preset("clear"); weather.set_time_of_day("day")
	record_ready = true
	get_window().title = "Alpine Apex | Record a run"
	var layer = CanvasLayer.new(); layer.layer = 25; add_child(layer)
	var panel = PanelContainer.new(); panel.position = Vector2(20,112); layer.add_child(panel)
	var style = StyleBoxFlat.new(); style.bg_color = Color(.025,.045,.065,.88)
	style.set_content_margin_all(12); style.set_corner_radius_all(6); panel.add_theme_stylebox_override("panel",style)
	var box = VBoxContainer.new(); panel.add_child(box)
	record_status = Label.new(); record_status.add_theme_font_size_override("font_size",18); box.add_child(record_status)
	record_help = Label.new(); box.add_child(record_help)
	navigation.device_changed.connect(_refresh_record_help)
	_refresh_record_help()
	var buttons = HBoxContainer.new(); box.add_child(buttons)
	var retry = Button.new(); retry.text = "Restart recording"; retry.pressed.connect(func(): restart()); buttons.add_child(retry)
	var save = Button.new(); save.text = "Save clip"; save.pressed.connect(func(): save_clip("manual")); buttons.add_child(save)
	start_run(false)
	hud.toast("Choose a face, then drop in to start recording.")
	print("RECORDING_READY output=",record_directory)
	_capture_record_ready.call_deferred()

func _refresh_record_help() -> void:
	var family: String = navigation.family
	var retry = RecordingPrompts.button(JOY_BUTTON_Y,family)+" / R" if family!="keyboard" else "R"
	var save = "D-pad Right / F8" if family!="keyboard" else "F8"
	record_help.text = retry+" restart recording  ·  "+save+" save clip\nNormal riding controls · Saves stay here when you retry"

func restart(preserve_return: bool = false) -> void:
	recorder = Recorder.new()
	super.restart(preserve_return)
	session.eligible = false; session.recording = null
	if record_ready: record_status.text = "Ready · Choose a face, then drop in"

func drop_from_summit() -> void:
	var was_ready = summit_ready
	super.drop_from_summit()
	if not record_ready or not was_ready or summit_ready: return
	attempt += 1
	last_saved = ""
	metadata = {"camera":camera_settings.snapshot(),"camera_effects_enabled":camera.effects_enabled,
		"weather":weather.selected_preset,"graphics":display_settings.snapshot(),"hud":hud.widget_layout.snapshot()}
	recorder.begin(field,sim,metadata)
	print("RECORDING_STARTED attempt=",attempt," heading=",sim.heading)

func _physics_process(dt: float) -> void:
	var before = sim.ticks if sim else -1
	super._physics_process(dt)
	if not record_ready or not recorder.recording or sim.ticks==before: return
	recorder.observe(sim,intent,[camera.close_view,camera.look_yaw,camera.look_pitch,camera.look_idle])
	if sim.crashed: save_clip("crash")
	elif session.finished: save_clip("base")
	elif not recorder.failure.is_empty(): save_clip("limit")
	elif sim.ticks%120==0: record_status.text = "Recording · "+Session.format_time(sim.ticks/120.0)

func _resolve_zone_exit(dt: float, before: Vector3, after: Vector3) -> bool:
	if not recorder.recording: return super._resolve_zone_exit(dt,before,after)
	var fraction = mountain_zone.swept_exit_fraction(before,after)
	if fraction<0.0: return false
	# Save the actual boundary tick before the normal summit-return transition.
	session.elapsed += dt*fraction; session.finished = not sim.crashed; active = false
	return true

func resume() -> void:
	if recorder.recording: recorder.invalidate("Paused mid-recording. Restart for a continuous reproducible clip.")
	super.resume()
	if record_ready and not recorder.failure.is_empty(): record_status.text = recorder.failure

func _input(event: InputEvent) -> void:
	if not record_ready: super._input(event); return
	var retry_key = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_R
	var retry_pad = event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_Y
	if retry_key or retry_pad:
		restart(); get_viewport().set_input_as_handled(); return
	var save_key = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F8
	var save_pad = event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_DPAD_RIGHT
	if save_key or save_pad:
		save_clip("manual"); get_viewport().set_input_as_handled()
	else: super._input(event)

func save_clip(reason: String) -> void:
	if recorder.data.is_empty() or recorder.data.commands.is_empty():
		record_status.text = "Drop in and ski a little before saving."; return
	if not recorder.recording and recorder.data.has("result") and not last_saved.is_empty(): return
	active = false
	var configuration_changed: bool = metadata.camera!=camera_settings.snapshot() or metadata.graphics!=display_settings.snapshot() or metadata.weather!=weather.selected_preset
	if configuration_changed: recorder.invalidate("Settings changed during the clip. Restart to record a fixed scenario.")
	var accepted = recorder.finish(sim,session.finished,reason)
	recorder.data.recorded_utc = Time.get_datetime_string_from_system(true)+"Z"
	recorder.data.engine = Engine.get_version_info()
	recorder.data.engine_sha256 = FileAccess.get_sha256(OS.get_executable_path())
	recorder.data.mountain = current_mountain.to_reference()
	recorder.data.configuration_changed = configuration_changed
	var name = "attempt_%03d.json" % attempt
	var destination = record_directory+"/"+name
	var handle = FileAccess.open(destination,FileAccess.WRITE)
	if handle==null: record_status.text = "Save failed. Keep this window open and tell Codex."; return
	handle.store_string(JSON.stringify(Recorder.Inputs.storage(recorder.data),"",true,true)); handle.close()
	last_saved = destination
	var result = {"file":destination,"accepted":accepted,"scope":recorder.data.scope,"seconds":sim.ticks/120.0,"reason":reason,"error":recorder.failure}
	FileAccess.open(record_directory+"/latest.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("RECORDING_SAVED ",JSON.stringify(result))
	record_status.text = ("Saved · " if accepted else "Saved with capture issue · ")+Session.format_time(sim.ticks/120.0)+" · "+name
	hud.show_menu("paused","Recording saved. Restart for another attempt, or close the game.")

func _capture_record_ready() -> void:
	for i in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(record_directory+"/ready.png")
	if "--record-smoke-test" in OS.get_cmdline_user_args(): _record_smoke_test.call_deferred()

func _record_smoke_test() -> void:
	var failures: Array[String] = []
	for i in 12: await get_tree().physics_frame
	drop_from_summit()
	Input.action_press("tuck",.7)
	while sim.ticks<240: await get_tree().physics_frame
	Input.action_release("tuck")
	var stop = InputEventKey.new(); stop.physical_keycode = KEY_F8; stop.pressed = true
	_input(stop)
	var first = last_saved
	if not FileAccess.file_exists(first) or recorder.data.scope!="scenario" or not recorder.failure.is_empty(): failures.append("First manual clip was not saved")
	var retry = InputEventJoypadButton.new(); retry.button_index = JOY_BUTTON_Y; retry.pressed = true
	_input(retry)
	if not recorder.data.is_empty() or not summit_ready or session.eligible: failures.append("Triangle did not restart an isolated recording")
	for i in 12: await get_tree().physics_frame
	drop_from_summit()
	Input.action_press("tuck",.6)
	while sim.ticks<120: await get_tree().physics_frame
	Input.action_release("tuck")
	var save = InputEventJoypadButton.new(); save.button_index = JOY_BUTTON_DPAD_RIGHT; save.pressed = true
	_input(save)
	if last_saved==first or not FileAccess.file_exists(first) or not FileAccess.file_exists(last_saved): failures.append("Saved attempt was overwritten")
	if preferences_enabled or session.eligible or automated: failures.append("Manual input or personal-data isolation changed")
	var report = {"failures":failures,"first_clip":first,"second_clip":last_saved,"manual_input":not automated,"unranked":not session.eligible,"preferences_enabled":preferences_enabled}
	FileAccess.open(record_directory+"/smoke.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RECORDING_SMOKE ",JSON.stringify(report))
	effects.stop_audio(); get_tree().quit(0 if failures.is_empty() else 1)
