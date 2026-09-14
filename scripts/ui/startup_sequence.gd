extends CanvasLayer
## Once per process, independent of game/session ownership. No minimum display time.
const State = preload("res://scripts/ui/startup_state.gd")
const Feedback = preload("res://scripts/ui/interface_feedback.gd")
const LOGO = preload("res://assets/images/branding/alpine_apex_ice.svg")
const ATMOSPHERE_PATH = "res://assets/images/branding/startup_atmosphere.gdshader"
const CUE_PATH = "res://assets/audio/interface/startup_ice.wav"
const Photos = preload("res://scripts/ui/startup_photos.gd")
var state = State.new()
var panel: ColorRect
var logo: TextureRect
var art
var hint: Label
var player: AudioStreamPlayer
var audio_started: bool = false
var audio_dispatches: int = 0
var audio_allowed: bool = false
var preferences: Dictionary = {}
var destination_ready: bool = false
var menu_ready: bool = false
var complete: bool = false
var optional_effects: bool = true
var cue_path: String = CUE_PATH
var photo: TextureRect
var photo_index: int = -1
var photo_texture: Texture2D
var photo_focus: Vector2 = Vector2(.5,.46)
var photo_credit: String = ""
var weather
var last_frame_usec: int = 0
signal dismissed

func _ready() -> void:
	layer = 110
	panel = ColorRect.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.color = Color("071421")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if optional_effects and ResourceLoader.exists(ATMOSPHERE_PATH):
		var shader = load(ATMOSPHERE_PATH) as Shader
		if shader:
			var material = ShaderMaterial.new(); material.shader = shader; panel.material = material
	add_child(panel)
	if photo_texture:
		photo = Photos.background(photo_texture,photo_focus)
		panel.add_child(photo)
	art = preload("res://scripts/ui/startup_art.gd").new(); panel.add_child(art)
	art.ridges_enabled = photo==null
	if optional_effects:
		weather = preload("res://scripts/ui/startup_weather.gd").new()
		panel.add_child(weather)
	logo = TextureRect.new(); logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if optional_effects and ResourceLoader.exists("res://assets/images/branding/startup_ice_light.gdshader"):
		var light_shader = load("res://assets/images/branding/startup_ice_light.gdshader") as Shader
		if light_shader:
			var light_material = ShaderMaterial.new(); light_material.shader = light_shader; logo.material = light_material
	panel.add_child(logo)
	hint = Label.new(); hint.text = "PRESS ANY BUTTON TO CONTINUE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",11)
	hint.add_theme_color_override("font_color",Color("97b4c2"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hint)
	panel.resized.connect(_layout); _layout()
	player = AudioStreamPlayer.new(); player.name = "AlpineStartupSting"; player.bus = "Master"; add_child(player)
	get_window().focus_exited.connect(_silence)
	apply_preferences(preferences)
	_paint()
	last_frame_usec = Time.get_ticks_usec()

func _layout() -> void:
	var width_value = minf(panel.size.x*.61,panel.size.y*1.36)
	logo.size = Vector2(width_value,width_value*640.0/1440.0)
	logo.position = (panel.size-logo.size)*.5-Vector2(0,panel.size.y*.045)
	logo.pivot_offset = logo.size*.5
	hint.position = Vector2(0,panel.size.y*.90); hint.size = Vector2(panel.size.x,24)

func apply_preferences(values: Dictionary) -> void:
	preferences = values.duplicate()
	state.reduced_motion = values.get("reduced_motion",false)
	if player:
		player.volume_db = linear_to_db(maxf(.0001,float(values.get("volume",.55))))-9.0
		if values.get("muted",false) or not values.get("loading_ambience",true) or float(values.get("volume",.55))<=.001: _silence()
	if panel: _paint()

func _process(_delta: float) -> void:
	# Godot clamps frame delta during a long main-thread resource submission. The
	# opening follows elapsed wall time so such a stall cannot prolong its reveal.
	var now = Time.get_ticks_usec()
	advance_visual(maxf(0.0,(now-last_frame_usec)/1000000.0))
	last_frame_usec = now

func advance_visual(delta: float) -> void:
	if complete: return
	state.advance(delta,destination_ready,menu_ready)
	_paint()
	if not audio_started:
		audio_started = true # Missing/muted audio is consumed, never replayed late.
		if audio_allowed and not preferences.get("muted",false) and preferences.get("loading_ambience",true) and float(preferences.get("volume",.55))>.001 and not cue_path.is_empty() and ResourceLoader.exists(cue_path):
			player.stream = load(cue_path) as AudioStream
			if player.stream:
				player.play(); audio_dispatches += 1
	if state.fading and player.playing:
		player.volume_db = linear_to_db(maxf(.0001,float(preferences.get("volume",.55))*state.opacity()))-9.0
	if state.finished:
		complete = true; panel.hide(); _silence(); set_process(false); dismissed.emit()

func _paint() -> void:
	panel.modulate.a = state.opacity()
	# The brand is visible on the first frame; a single soft exposure reveal adds weight.
	logo.modulate = Color(1,1,1,lerpf(.62,1.0,smoothstep(0.0,.65,state.elapsed)))
	logo.scale = Vector2.ONE*(1.0 if state.reduced_motion else lerpf(1.018,1.0,smoothstep(0.0,1.5,state.motion_time())))
	if logo.material:
		logo.material.set_shader_parameter("reveal_time",state.motion_time())
		logo.material.set_shader_parameter("reduced_motion",state.reduced_motion)
	if panel.material:
		panel.material.set_shader_parameter("reveal_time",state.motion_time())
		panel.material.set_shader_parameter("reduced_motion",state.reduced_motion)
	if photo and photo.material:
		photo.material.set_shader_parameter("reveal_time",state.motion_time())
		photo.material.set_shader_parameter("reduced_motion",state.reduced_motion)
	art.update_visual(state.motion_time(),state.reduced_motion)
	if weather: weather.update_visual(state.elapsed,not state.reduced_motion)
	hint.modulate.a = smoothstep(State.LEGIBLE_SECONDS,State.LEGIBLE_SECONDS+.25,state.elapsed)
	# When ready, the menu owns input immediately, even during the short visual dissolve.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if menu_ready else Control.MOUSE_FILTER_STOP

func _input(event: InputEvent) -> void:
	if complete or menu_ready: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		preferences.muted = not preferences.get("muted",false); apply_preferences(preferences)
	state.skip(event)
	get_viewport().set_input_as_handled()

func _silence() -> void:
	if player: player.stop()

func _exit_tree() -> void: _silence()
