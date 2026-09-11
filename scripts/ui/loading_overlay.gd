extends CanvasLayer
## Stage labels never pretend to measure unknown generation work.
const Estimates = preload("res://scripts/world/generation_estimates.gd")
const Art = preload("res://scripts/ui/alpine_art.gd")
const AlpineTheme = preload("res://scripts/ui/alpine_theme.gd")
const Feedback = preload("res://scripts/ui/interface_feedback.gd")
const Snow = preload("res://scripts/ui/loading_snow.gd")
const WindAudio = preload("res://scripts/presentation/wind_audio.gd")
const Content = preload("res://scripts/ui/loading_content.gd")
const TIP_SECONDS = 8.0
const TIP_FADE_SECONDS = 0.25
var tip_device: String = "keyboard"
var overlay: ColorRect
var artwork: Art
var art_caption: Label
var tip: Label
var outgoing_tip: Label
var snow: Snow
var tip_start: int = 0
var tip_step: int = 0
var tip_fade: float = TIP_FADE_SECONDS
var elapsed_second: int = -1
var title: Label
var detail: Label
var elapsed: Label
var bar: ProgressBar
var pulse: Control
var started: int = 0
var phase: float = 0.0
var busy: bool = false
var previous_focus: WeakRef
var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if value:
			tip_fade = TIP_FADE_SECONDS
			if tip: tip.modulate.a = 1.0
			if outgoing_tip: outgoing_tip.hide(); outgoing_tip.modulate.a = 0.0
			if pulse and bar: pulse.position.x = maxf(0.0,bar.size.x-pulse.size.x)*0.5
		if artwork: artwork.set_loading_mode(busy and atmosphere_enabled,value)
		if snow: snow.update_motion(phase,busy and atmosphere_enabled and not value)
var atmosphere_enabled: bool = true:
	set(value):
		atmosphere_enabled = value
		if artwork: artwork.set_loading_mode(busy and value,reduced_motion)
		if snow: snow.update_motion(phase,busy and value and not reduced_motion)
var sound_volume: float = 0.55
var sound_muted: bool = false
var loading_ambience: bool = true
var audio_enabled: bool = false # Automated runs opt in explicitly for audio review.
var ambience: AudioStreamPlayer
var audio_tween: Tween
var audio_target_db: float = -80.0
var feedback_source: WeakRef
var stage_history: Array[String] = []
var worker: Thread
var job
var cancel_button: Button
var retry_button: Button
var quit_button: Button
var worker_snapshot_active: bool = false

func _ready() -> void:
	layer = 100
	audio_enabled = DisplayServer.get_name() != "headless" and "--script" not in OS.get_cmdline_args() and "-s" not in OS.get_cmdline_args() and "--autoplay" not in OS.get_cmdline_user_args()
	apply_preferences(Feedback.read_preferences(audio_enabled))
	ambience = AudioStreamPlayer.new()
	ambience.name = "LoadingWind"
	add_child(ambience)
	overlay = ColorRect.new()
	overlay.color = Color("071421")
	overlay.theme = AlpineTheme.create()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.focus_mode = Control.FOCUS_ALL
	add_child(overlay)
	artwork = Art.new()
	overlay.add_child(artwork)
	snow = Snow.new()
	overlay.add_child(snow)
	var brand = Art.logo(Vector2(500,235))
	brand.position = Vector2(44,16)
	overlay.add_child(brand)
	var col = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	col.offset_left = 64
	col.offset_right = 628
	col.offset_top = -338
	col.offset_bottom = -64
	col.add_theme_constant_override("separation",16)
	overlay.add_child(col)
	col.add_child(_label("LOADING",12,Art.ICE))
	title = _label("Loading mountain",38)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	detail = _label("",17,Art.MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.y = 52
	col.add_child(detail)
	bar = ProgressBar.new()
	bar.clip_contents = true
	bar.show_percentage = false
	bar.custom_minimum_size.y = 5
	col.add_child(bar)
	pulse = Panel.new()
	pulse.add_theme_stylebox_override("panel",AlpineTheme.box(Art.ICE,Color.TRANSPARENT,0,Vector2(6,3)))
	pulse.size = Vector2(96,5)
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(pulse)
	elapsed = _label("",12,Art.MUTED)
	elapsed.custom_minimum_size.y = 18
	col.add_child(elapsed)
	var tip_stack = Control.new()
	tip_stack.custom_minimum_size.y = 42
	tip_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tip_stack)
	tip = _label(Content.tip(0,_device()),14,Art.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tip_stack.add_child(tip)
	outgoing_tip = _label("",14,Art.MUTED)
	outgoing_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outgoing_tip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tip_stack.add_child(outgoing_tip)
	outgoing_tip.hide()
	art_caption = _label("",12,Art.MUTED)
	art_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	art_caption.position = Vector2(-530,-44)
	art_caption.size = Vector2(466,24)
	art_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	overlay.add_child(art_caption)
	var actions = HBoxContainer.new()
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.offset_left = -480; actions.offset_top = -112; actions.offset_right = -64; actions.offset_bottom = -64
	overlay.add_child(actions)
	cancel_button = Button.new(); cancel_button.text = "CANCEL LOADING"; cancel_button.custom_minimum_size = Vector2(180,42)
	cancel_button.pressed.connect(cancel_job); actions.add_child(cancel_button); cancel_button.hide()
	retry_button = Button.new(); retry_button.text = "RETRY"; actions.add_child(retry_button); retry_button.hide()
	retry_button.pressed.connect(func(): get_tree().reload_current_scene())
	quit_button = Button.new(); quit_button.text = "QUIT"; actions.add_child(quit_button); quit_button.hide()
	quit_button.pressed.connect(func(): get_tree().quit())
	overlay.hide()
	set_process(false)

func _label(value: String, font_size: int, color: Color = Art.WHITE) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func begin(caption: String, message: String) -> void:
	if not busy:
		started = Time.get_ticks_msec()
		var focus = get_viewport().gui_get_focus_owner()
		previous_focus = weakref(focus) if focus else null
		stage_history.clear()
		phase = 0.0
		artwork.set_visual_time(0.0)
		tip_step = 0
		tip_fade = TIP_FADE_SECONDS
		elapsed_second = -1
		elapsed.text = ""
		outgoing_tip.hide()
		tip.modulate.a = 1.0
		# Tree metadata survives scene replacement; art never consumes simulation RNG.
		var first: int = int(Time.get_unix_time_from_system()) % Art.PHOTOS.size()
		var index: int = int(get_tree().get_meta("alpine_loading_photo",first)) + 1
		if index % Art.PHOTOS.size() == artwork.last_photo_index: index += 1
		get_tree().set_meta("alpine_loading_photo",index % Art.PHOTOS.size())
		artwork.show_photo(index)
		_update_photo_caption()
		tip_start = posmod(index,Content.COUNT)
		tip_device = _device()
		tip.text = Content.tip(tip_start,tip_device)
	busy = true
	artwork.set_loading_mode(atmosphere_enabled,reduced_motion)
	_sync_audio()
	title.text = caption
	stage(message)
	overlay.show()
	overlay.grab_focus()
	set_process(true)
	_process(0.0)

func stage(message: String, percent: float = -1.0) -> void:
	detail.text = message
	if stage_history.is_empty() or stage_history.back() != message: stage_history.append(message)
	bar.value = maxf(0.0,percent)
	pulse.visible = percent < 0.0

func finish() -> void:
	if not busy: return
	busy = false
	if job and not job.is_cancelled() and not job.snapshot().finished: job.complete()
	cancel_button.hide(); retry_button.hide(); quit_button.hide()
	job = null
	overlay.hide()
	artwork.release_photo()
	snow.update_motion(phase,false)
	outgoing_tip.hide()
	_fade_out_audio()
	set_process(false)
	if previous_focus:
		var focus = previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()
	previous_focus = null

func draw_frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func run_data(work: Callable, context = null):
	if context: attach_job(context)
	worker_snapshot_active = job!=null
	worker = Thread.new()
	if worker.start(work) != OK:
		worker = null
		var fallback = work.call()
		worker_snapshot_active = false
		return fallback
	while worker.is_alive(): await get_tree().process_frame
	var result = worker.wait_to_finish()
	worker = null
	worker_snapshot_active = false
	return result

func _exit_tree() -> void:
	_stop_audio()
	if job: job.cancel()
	if worker and worker.is_started(): worker.wait_to_finish()

func _process(dt: float) -> void:
	if not busy: return
	var visual_delta = clampf(dt,0.0,0.05)
	if not reduced_motion: phase += visual_delta
	if artwork.advance_loading(visual_delta):
		artwork.show_photo(artwork.next_photo())
		_update_photo_caption()
	snow.update_motion(phase,atmosphere_enabled and not reduced_motion)
	pulse.position.x = maxf(0.0,bar.size.x-pulse.size.x)*(0.5 if reduced_motion else (sin(phase*2.8)*0.5+0.5))
	_update_wait_feedback((Time.get_ticks_msec()-started)/1000.0,visual_delta)
	if job:
		var snapshot: Dictionary = job.snapshot()
		Estimates.reconcile(job,snapshot)
		cancel_button.disabled = snapshot.cancelled
		if not str(snapshot.error).is_empty():
			detail.text = str(snapshot.error)
			pulse.hide()
		elif snapshot.cancelled: detail.text = "Cancelling loading… Waiting for the current work to stop."
		elif worker_snapshot_active:
			detail.text = snapshot.stage.replace("_"," ").capitalize()
			if snapshot.total>0:
				bar.value = clampf(100.0*snapshot.completed/snapshot.total,0,100); pulse.hide()
			else: pulse.show()
		if not snapshot.cancelled and str(snapshot.error).is_empty() and not snapshot.finished:
			elapsed.text = "%d s elapsed · estimated %d–%d s remaining" % [snapshot.elapsed_s,maxi(0,floori(snapshot.estimate_range_s.x)),maxi(0,ceili(snapshot.estimate_range_s.y))]
		else: elapsed.text = "%d s elapsed" % snapshot.elapsed_s

func _device() -> String:
	return str(get_tree().get_meta("interface_device","keyboard"))

func _update_photo_caption() -> void:
	# A photo index supports review without inventing locations or image subjects.
	art_caption.text = "Photo %02d / %02d" % [artwork.photo_index+1,Art.PHOTOS.size()]

func _update_wait_feedback(wait_seconds: float, visual_delta: float) -> void:
	var second = int(maxf(wait_seconds,0.0))
	if second != elapsed_second:
		elapsed_second = second
		elapsed.text = "%d s elapsed" % second if second >= 8 else ""
	var step = int(maxf(wait_seconds,0.0)/TIP_SECONDS)
	var device = _device()
	if device != tip_device:
		# A device handoff fixes the visible binding immediately, without cycling tips.
		tip_device = device
		tip_step = step
		tip.text = Content.tip(tip_start+step,tip_device)
		tip_fade = TIP_FADE_SECONDS
	elif step != tip_step:
		tip_step = step
		outgoing_tip.text = tip.text
		tip.text = Content.tip(tip_start+step,tip_device)
		tip_fade = 0.0
	tip_fade = TIP_FADE_SECONDS if reduced_motion else minf(TIP_FADE_SECONDS,tip_fade+visual_delta)
	var blend = smoothstep(0.0,TIP_FADE_SECONDS,tip_fade)
	tip.modulate.a = blend
	outgoing_tip.modulate.a = 1.0-blend
	outgoing_tip.visible = blend < 1.0

func configure_feedback(source) -> void:
	var previous = feedback_source.get_ref() if feedback_source else null
	if previous != source:
		if previous and previous.preferences_changed.is_connected(_refresh_feedback):
			previous.preferences_changed.disconnect(_refresh_feedback)
		feedback_source = weakref(source)
		source.preferences_changed.connect(_refresh_feedback)
	_refresh_feedback()

func _refresh_feedback() -> void:
	var source = feedback_source.get_ref() if feedback_source else null
	if source: apply_preferences(source.snapshot())

func apply_preferences(values: Dictionary) -> void:
	reduced_motion = values.get("reduced_motion",false)
	sound_volume = clampf(values.get("volume",0.55),0.0,1.0)
	sound_muted = values.get("muted",false)
	loading_ambience = values.get("loading_ambience",true)
	if ambience: _sync_audio()

func _sync_audio() -> void:
	if not busy or not audio_enabled or sound_muted or sound_volume <= 0.001 or not loading_ambience or DisplayServer.get_name() == "headless":
		_stop_audio()
		return
	var target = WindAudio.LOADING_VOLUME_DB + linear_to_db(sound_volume)
	if ambience.playing:
		# A new job may interrupt the previous job's fade-out without a second player.
		if not is_equal_approx(target,audio_target_db):
			_fade_audio(target,0.15 if overlay.visible else 0.8)
		return
	var stream = WindAudio.forest_loop()
	if not stream: return
	ambience.stream = stream
	ambience.volume_db = -80.0
	ambience.play()
	_fade_audio(target,0.8)

func _fade_audio(target: float, seconds: float) -> void:
	if audio_tween and audio_tween.is_valid(): audio_tween.kill()
	audio_target_db = target
	audio_tween = create_tween()
	audio_tween.tween_property(ambience,"volume_db",target,seconds)

func _fade_out_audio() -> void:
	if not ambience.playing:
		_stop_audio()
		return
	_fade_audio(-80.0,0.15)
	audio_tween.tween_callback(_stop_audio)

func _stop_audio() -> void:
	if audio_tween and audio_tween.is_valid(): audio_tween.kill()
	audio_tween = null
	if ambience:
		ambience.stop()
		ambience.stream = null

func _input(event: InputEvent) -> void:
	if busy:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: cancel_job()
		# Let the cancel/retry controls receive pointer and keyboard GUI events.
		if not (event is InputEventMouse or event is InputEventKey): get_viewport().set_input_as_handled()

func attach_job(context) -> void:
	job = context
	if cancel_button: cancel_button.show(); cancel_button.disabled = false; retry_button.hide(); quit_button.hide()

func cancel_job() -> void:
	if job: job.cancel()

func cancelled_startup() -> void:
	worker_snapshot_active = false; job = null
	begin("Mountain loading cancelled", "Choose Retry to open the mountain again.")
	cancel_button.hide(); retry_button.show(); quit_button.show(); retry_button.grab_focus()
