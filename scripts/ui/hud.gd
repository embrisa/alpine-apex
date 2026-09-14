extends CanvasLayer
signal start_requested(timed: bool)
signal respawn_requested
signal crash_pause_requested
signal restart_requested
signal resume_requested
signal lab_speed_requested(kmh: float)
signal tuning_changed
signal vibration_changed(value: float)
signal defaults_requested
signal workbench_closed
signal quit_requested
signal weather_option_requested(key: String, value: Variant)
signal weather_preset_requested(id: String)
signal weather_auto_requested(enabled: bool)
signal weather_quality_requested(quality: int)
signal time_of_day_requested(id: String)
signal time_cycle_requested(enabled: bool)
signal graphics_quality_requested(level: int)
signal graphics_values_requested(values: Dictionary)
signal graphics_group_reset_requested(group: String)
signal display_preview_requested(values: Dictionary)
signal display_keep_requested
signal display_revert_requested
var shell_layout = preload("res://scripts/ui/screen_shell.gd").new()
var settings_pages = preload("res://scripts/ui/settings_pages.gd").new()
var widget_layout = preload("res://scripts/ui/hud_layout.gd").new()
var hud_editor
var location_box: VBoxContainer
var ui_notice: Label
var ui_notice_time = 0.0
signal display_setting_requested(key: String, value: Variant)
signal camera_setting_requested(view: String, key: String, value: Variant)
signal camera_defaults_requested(view: String)
signal camera_preset_requested(action: String, view: String, name: String, new_name: String)
signal camera_preview_requested(enabled: bool)
const CameraSettings = preload("res://scripts/presentation/camera_settings.gd")
var camera_options = preload("res://scripts/ui/camera_settings_panel.gd").new()
var display_controls: Dictionary = {}
var fidelityfx_display_settings
var fidelityfx_status_label: Label
var compact_menu = preload("res://scripts/ui/compact_menu.gd").new()
var menu_tabs: TabContainer
var settings_tabs: TabContainer
var tuning_tabs: TabContainer
var audio_toggle: CheckButton
var wind_mode: OptionButton
var wind_volume: HSlider
var wind_status: Label
var riding_audio_settings = preload("res://scripts/ui/riding_audio_settings.gd").new()
var voice_settings = preload("res://scripts/ui/voice_settings.gd").new()
signal wind_mode_requested(value: int)
signal wind_volume_requested(value: float)
var motion_toggle: CheckButton
var feedback = preload("res://scripts/ui/interface_feedback.gd").new()
signal workbench_requested
signal audio_mute_requested(enabled: bool)
signal motion_effects_requested(enabled: bool)
signal mountains_requested
signal races_requested
signal navigation_requested
var navigation_button: Button
signal competition_requested
signal ghost_visibility_requested(enabled: bool)
signal ghost_selection_requested(mode: String, ids: Array)
var ghost_colors: Dictionary = {}
const Competition = preload("res://scripts/ui/competitive_panel.gd")
var competition = Competition.new()
var records_button: Button
var split_label: Label
var ghost_enabled: bool = true
var graphics_quality: OptionButton
const Session = preload("res://scripts/core/run_session.gd")
const Art = preload("res://scripts/ui/alpine_art.gd")
const AlpineTheme = preload("res://scripts/ui/alpine_theme.gd")
const INK = Color("102832")
const WHITE = AlpineTheme.WHITE
const HUD_WHITE = Art.WHITE
const HUD_MUTED = Art.MUTED
const HUD_ACCENT = AlpineTheme.HUD_ACCENT
const MUTED = AlpineTheme.MUTED
# Kept as an alias for panels that consume the HUD's established accent contract.
const LIME = AlpineTheme.ICE
var root = Control.new()
var menu_fade: ColorRect
var menu_backgrounds: Array[Control] = []
var menu_edge_shading: Array[Control] = []
var menu_art_ready: bool = false
var hero_logo: TextureRect
var header_logo: TextureRect
var menu: PanelContainer
var menu_title: Label
var build_version_label: Label
var copy_build_button: Button
const BuildIdentity = preload("res://scripts/diagnostics/build_identity.gd")
var menu_description: Label
var menu_specs: Label
var menu_location: Label
var mountain_name: String = ""
var mountain_seed_value: int = -1
var conditions: Label
var footer: PanelContainer
var footer_controls: Label
const Prompts = preload("res://scripts/ui/controller_prompts.gd")
var input_family = "keyboard"
var primary: Button
var crash_restart: Button
var crash_clock: Label
var crash_availability: Label
var secondary: Button
var debug_panel: PanelContainer
var debug_text: Label
var tuning_panel: PanelContainer
var speed_label: Label
var timer_label: Label
var pb_label: Label
var state_label: Label
var mode_label: Label
var altitude_label: Label
var fps_label: Label
var progress: SlimBar
var speed_dial: SpeedDial
var band_label: Label
var impact_bar: SlimBar
var impact_label: Label
var telemetry_timer: float = 0.0
var last_status_category = ""
var last_split_index = -1
var menu_mode: String = "title"
var normal_font: SystemFont
var mono_font: SystemFont
var hud_controls: Array = []
var toast_label: Label
var toast_time: float = 0.0
var summit_return_label: Label
var tuning_resource
var tuning_sliders: Dictionary = {}
var tuning_readouts: Dictionary = {}
var appearance_column: VBoxContainer
var weather_panel: PanelContainer
var weather_button: Button
var weather_preset: OptionButton
var weather_options: Dictionary = {}
var weather_practice: Label
var weather_auto: CheckButton
var weather_quality: OptionButton
const WEATHER_IDS = ["clear","cloudy","snowfall","rain","snowstorm","thunderstorm"]
const TIME_IDS = ["dawn","day","dusk","night"]
var time_of_day: OptionButton
var time_cycle: CheckButton

class SpeedDialStatic:
	extends Control
	var marks = false
	func _ready() -> void:
		resized.connect(queue_redraw)
	func _draw() -> void:
		var center = size * 0.5
		var radius = size.x * 0.46
		var start = deg_to_rad(140.0)
		var sweep = deg_to_rad(260.0)
		if not marks:
			draw_arc(center,radius,start,start+sweep,80,Color(1,1,1,.25),2.0,true)
			return
		for threshold in [60,90,120,150,165,200]:
			var direction = Vector2.from_angle(start+sweep*threshold/200.0)
			draw_line(center+direction*(radius-6),center+direction*radius,Color(1,1,1,.5),1.0,true)

class SpeedDial:
	extends Control
	var speed: float = 0.0:
		set(value):
			if speed == value: return
			speed = value
			queue_redraw()
	var tint = Color.WHITE:
		set(value):
			if tint == value: return
			tint = value
			queue_redraw()
	func _ready() -> void:
		# Keep the original background / fill / tick ordering. Canvas retains
		# static drawing commands while only the changing speed arc redraws.
		for marks in [false,true]:
			var face = SpeedDialStatic.new()
			face.marks = marks
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.show_behind_parent = not marks
			add_child(face)
			face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)
	func _draw() -> void:
		var start = deg_to_rad(140.0)
		var sweep = deg_to_rad(260.0)
		draw_arc(size*.5,size.x*.46,start,start+sweep*clampf(speed/200.0,0,1),80,tint,3.0,true)

class SlimBar:
	extends Control
	const UITheme = preload("res://scripts/ui/alpine_theme.gd")
	var background = UITheme.box(Color(1,1,1,0.25),Color.TRANSPARENT,0,Vector2(6,3))
	var fill = UITheme.box(Color("a5dced"),Color.TRANSPARENT,0,Vector2(6,3))
	var tint: Color = Color("a5dced"):
		set(v):
			if tint == v: return
			tint = v
			fill = UITheme.box(v,Color.TRANSPARENT,0,Vector2(6,3))
			queue_redraw()
	var value: float = 0.0:
		set(v):
			if value == v: return
			value = v
			queue_redraw()
	var max_value: float = 100.0
	func _draw() -> void:
		draw_style_box(background,Rect2(Vector2.ZERO,size))
		var fraction = clampf(value/maxf(max_value,0.001),0,1)
		if fraction > 0.0: draw_style_box(fill,Rect2(Vector2.ZERO,Vector2(size.x*fraction,size.y)))

func _ready() -> void:
	add_child(feedback)
	add_child(shell_layout)
	shell_layout.setup(self)
	normal_font = Art.interface_font()
	mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono"])
	root.theme = AlpineTheme.create()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_menu_backdrop()
	_build_menu_edge_shading()
	root.move_child(hero_logo,root.get_child_count()-1)
	_build_header()
	_build_instruments()
	_build_menu()
	_build_weather()
	_build_debug()
	competition.build(self)
	register_menu_background(menu)
	menu_art_ready = true
	feedback.preferences_changed.connect(_sync_menu_backdrop)
	feedback.preferences_changed.connect(func(): get_tree().call_group("alpine_action_buttons","refresh_prompt"))
	root.visibility_changed.connect(_sync_menu_backdrop)
	toast_label = _label("",20,HUD_ACCENT)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-280,137)
	toast_label.size = Vector2(560,36)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast_label)
	summit_return_label = _label("",18,HUD_WHITE)
	summit_return_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	summit_return_label.position = Vector2(-260,179)
	summit_return_label.size = Vector2(520,30)
	summit_return_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summit_return_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	summit_return_label.add_theme_constant_override("shadow_offset_y",2)
	summit_return_label.hide()
	root.add_child(summit_return_label)
	_build_widget_registry()
	hud_editor = preload("res://scripts/ui/hud_editor.gd").new()
	root.add_child(hud_editor)
	hud_editor.setup(self)
	ui_notice = _label("",18,HUD_ACCENT)
	ui_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	ui_notice.position = Vector2(-300,74)
	ui_notice.size = Vector2(600,26)
	ui_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(ui_notice)
	ui_notice.hide()
	show_menu("title")

func update_summit_return(distance_m: float, skiing: bool) -> void:
	if widget_layout.preview: return
	summit_return_label.visible = skiing and distance_m>=0.0 and distance_m<=150.0
	if summit_return_label.visible:
		summit_return_label.text = "Summit return — %d m" % ceili(distance_m)

func _label(text_value: String, size_value: int = 16, color: Color = WHITE, mono: bool = false) -> Label:
	var label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size",size_value)
	label.add_theme_color_override("font_color",color)
	label.add_theme_font_override("font",mono_font if mono else normal_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build_menu_edge_shading() -> void:
	for bottom in [false,true]:
		var gradient = Gradient.new()
		gradient.set_color(0,Color(0.02,0.07,0.11,0.0 if bottom else 0.45))
		gradient.set_color(1,Color(0.02,0.07,0.11,0.62 if bottom else 0.0))
		var texture = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2(0,0)
		texture.fill_to = Vector2(0,1)
		var rect = TextureRect.new()
		rect.texture = texture
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		if bottom:
			rect.offset_top = -225
		else:
			rect.offset_bottom = 135
		rect.visible = false
		menu_edge_shading.append(rect)
		root.add_child(rect)

func _style(bg: Color, border: Color = Color(0.55,0.69,0.73,0.2), padding: int = 28) -> StyleBox:
	return AlpineTheme.box(bg,border,padding,AlpineTheme.PANEL_CUT if padding >= 20 else AlpineTheme.CONTROL_CUT)

func _panel(parent: Control = root) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(AlpineTheme.PANEL,AlpineTheme.EDGE))
	parent.add_child(panel)
	panel.visibility_changed.connect(func():
		if panel.visible: feedback.reveal(panel)
	)
	return panel

func _window(panel: PanelContainer, _width: float = 900.0) -> VBoxContainer:
	register_menu_background(panel)
	shell_layout.frame(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",22)
	panel.add_child(column)
	return column

func _tabs(parent: Control) -> TabContainer:
	var tabs = preload("res://scripts/ui/navigation_tabs.gd").new()
	tabs.attach(parent,self)
	return tabs

func _tab(tabs: TabContainer, caption: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_page(scroll,caption)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right",20)
	margin.resized.connect(func():
		var inset = maxi(0,roundi((margin.size.x-1280.0)*.5))
		margin.add_theme_constant_override("margin_left",inset)
		margin.add_theme_constant_override("margin_right",inset+20)
	)
	margin.add_theme_constant_override("margin_bottom",20)
	scroll.add_child(margin)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",22)
	margin.add_child(column)
	return column

func _note(parent: Control, text: String) -> Label:
	var label = _label(text,14,MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(text_value: String, main_button: bool = false) -> Button:
	var button = preload("res://scripts/ui/action_button.gd").new()
	button.text = text_value.replace("↗","").strip_edges()
	button.custom_minimum_size.y = 46
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",16)
	button.configure(self,main_button)
	button.menu_back = button.text.to_lower() in ["back","cancel"]
	button.mouse_entered.connect(func():
		if not button.disabled: feedback.play("hover")
	)
	button.focus_entered.connect(func(): feedback.play("hover"))
	button.pressed.connect(func(): feedback.play())
	return button

func _build_menu_backdrop() -> void:
	menu_fade = ColorRect.new()
	menu_fade.name = "MenuWorldFade"
	menu_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_fade.color = Color(0.02,0.04,0.06,0.0)
	menu_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu_fade)
	menu_fade.hide()
	hero_logo = Art.logo(Vector2(520,245))
	hero_logo.position = Vector2(44,8)
	root.add_child(hero_logo)

func register_menu_background(view: Control) -> void:
	if view in menu_backgrounds: return
	menu_backgrounds.append(view)
	view.visibility_changed.connect(_sync_menu_backdrop)
	_sync_menu_backdrop()

func has_menu_background() -> bool:
	return menu_backgrounds.any(func(view): return is_instance_valid(view) and view.is_visible_in_tree())

func set_background_fade(alpha: float) -> void:
	menu_fade.color.a = clampf(alpha,0.0,1.0) if has_menu_background() and not feedback.reduced_motion else 0.0
	menu_fade.visible = menu_fade.color.a>0.0

func _sync_menu_backdrop() -> void:
	if not menu_art_ready: return
	var background_visible = has_menu_background()
	var compact = menu.visible and not menu.get_meta("screen_profile","").is_empty()
	var full_screen = background_visible and not compact
	hero_logo.visible = false
	header_logo.visible = full_screen
	if not background_visible or feedback.reduced_motion: set_background_fade(0.0)
	# Shared shell owns responsive menu bounds.
	mode_label.visible = not compact and not hero_logo.visible
	if camera_options.preview_active:
		header_logo.hide()
		mode_label.hide()
	for shade in menu_edge_shading: shade.visible = full_screen
	footer.visible = full_screen
	footer_controls.text = Prompts.menu(input_family)
	widget_layout.menu_visible = background_visible
	layout_widgets()

func set_input_family(family: String, device_name: String = "") -> void:
	input_family = family
	footer_controls.text = Prompts.menu(family)
	settings_pages.refresh_controls(family,device_name)
	get_tree().call_group("alpine_action_buttons","refresh_prompt")

func _build_header() -> void:
	header_logo = Art.logo(Vector2(315,60),true)
	header_logo.position = Vector2(37,24)
	root.add_child(header_logo)
	mode_label = _label("PHYSICS LAB   /   01",12,HUD_ACCENT,true)
	mode_label.position = Vector2(43,100)
	mode_label.size.x = 455
	mode_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(mode_label)
	var top_right = VBoxContainer.new()
	location_box = top_right
	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-265,32)
	top_right.size.x = 220
	root.add_child(top_right)
	conditions = _label("AIGUILLE  /  NORTH FACE",12,HUD_WHITE,true)
	conditions.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(conditions)
	altitude_label = _label("2 850 m   ·   CLEAR",12,HUD_MUTED)
	altitude_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(altitude_label)
	fps_label = _label("120 Hz PHYSICS",11,HUD_ACCENT,true)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(fps_label)
	progress = SlimBar.new()
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	progress.position = Vector2(-180,44)
	progress.size = Vector2(360,3)
	progress.add_theme_font_size_override("font_size",1)
	progress.add_theme_stylebox_override("background",_style(Color(1,1,1,0.17),Color.TRANSPARENT,0))
	progress.add_theme_stylebox_override("fill",_style(HUD_ACCENT,Color.TRANSPARENT,0))
	root.add_child(progress)
	hud_controls.append(progress)
	var course_label = _label("START                            FINISH",10,HUD_WHITE,true)
	course_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	course_label.position = Vector2(-180,56)
	root.add_child(course_label)
	hud_controls.append(course_label)
	split_label = _label("",12,HUD_ACCENT,true)
	split_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	split_label.position = Vector2(-195,78)
	split_label.size = Vector2(390,46)
	split_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(split_label)
	hud_controls.append(split_label)
	footer = PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -44
	footer.offset_bottom = 0
	footer.add_theme_stylebox_override("panel",_style(Color(0.03,0.08,0.11,0.82),Color.TRANSPARENT,10))
	root.add_child(footer)
	footer_controls = _label(Prompts.menu(input_family),11,HUD_MUTED,true)
	footer_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(footer_controls)

func _build_instruments() -> void:
	var timer_box = VBoxContainer.new()
	timer_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	timer_box.position = Vector2(44,-191)
	root.add_child(timer_box)
	hud_controls.append(timer_box)
	timer_box.add_child(_label("D E S C E N T   T I M E",11,HUD_MUTED))
	timer_label = _label("00:00.000",43,HUD_WHITE,true)
	timer_box.add_child(timer_label)
	pb_label = _label("PERSONAL BEST    —",11,HUD_ACCENT,true)
	timer_box.add_child(pb_label)
	var speed_box = VBoxContainer.new()
	speed_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_box.position = Vector2(-226,-250)
	speed_box.size.x = 180
	root.add_child(speed_box)
	hud_controls.append(speed_box)
	speed_dial = SpeedDial.new()
	speed_dial.custom_minimum_size = Vector2(180,180)
	speed_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_box.add_child(speed_dial)
	speed_label = _label("0",54,HUD_WHITE)
	speed_label.position = Vector2(0,47)
	speed_label.size = Vector2(180,70)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_dial.add_child(speed_label)
	var units = _label("km/h",12,HUD_WHITE)
	units.position = Vector2(0,112)
	units.size.x = 180
	units.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_dial.add_child(units)
	band_label = _label("MANEUVERING",10,HUD_WHITE,true)
	band_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_box.add_child(band_label)
	state_label = _label("READY",13,HUD_WHITE,true)
	state_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	state_label.position = Vector2(-250,-122)
	state_label.size = Vector2(500,28)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(state_label)
	hud_controls.append(state_label)
	impact_bar = SlimBar.new()
	impact_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	impact_bar.position = Vector2(-85,-73)
	impact_bar.size = Vector2(170,3)
	root.add_child(impact_bar)
	hud_controls.append(impact_bar)
	impact_label = _label("IMPACT RESERVE",9,HUD_MUTED)
	impact_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	impact_label.position = Vector2(-100,-92)
	impact_label.size.x = 200
	impact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(impact_label)
	hud_controls.append(impact_label)

func _build_menu() -> void:
	compact_menu.build(self)

func open_settings() -> void:
	weather_panel.show()
	menu.hide()
	settings_tabs.focus_page()

func _build_weather() -> void:
	settings_pages.build(self)

func _build_camera_settings(col: VBoxContainer) -> void:
	camera_options.build(col,self)

func sync_camera_settings(settings) -> void:
	camera_options.sync(settings)

func _build_audio_settings(col: VBoxContainer) -> void:
	col.add_child(_label("GAME AUDIO",14,LIME,true))
	audio_toggle = CheckButton.new()
	audio_toggle.text = "Mute all game audio"
	audio_toggle.toggled.connect(func(value): audio_mute_requested.emit(value))
	col.add_child(audio_toggle)
	col = shell_layout.group(col,"Wind",self)
	col.add_child(_label("Wind sound",16,WHITE))
	wind_mode = OptionButton.new()
	wind_mode.name = "WindSound"
	wind_mode.add_item("Procedural",0)
	wind_mode.add_item("Original",1)
	wind_mode.item_selected.connect(func(value): wind_mode_requested.emit(value))
	col.add_child(wind_mode)
	wind_status = _label("F7 compares wind sounds while skiing",14,MUTED)
	wind_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(wind_status)
	col.add_child(_label("Wind volume",16,WHITE))
	wind_volume = HSlider.new()
	wind_volume.name = "WindVolume"
	wind_volume.min_value = 0.0
	wind_volume.max_value = 1.0
	wind_volume.step = 0.05
	wind_volume.value = 1.0
	wind_volume.custom_minimum_size.y = 36
	wind_volume.value_changed.connect(func(value): wind_volume_requested.emit(value))
	col.add_child(wind_volume)
	riding_audio_settings.build(shell_layout.group(audio_toggle.get_parent(),"Skiing sounds",self),self)

func _build_feedback_settings(col: VBoxContainer) -> void:
	col.add_child(_label("INTERFACE SOUND & MOTION",14,LIME,true))
	col.add_child(_label("Interface sound volume",16,WHITE))
	var volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = feedback.volume
	volume.custom_minimum_size.y = 36
	volume.value_changed.connect(func(value): feedback.volume = value; feedback.save())
	volume.drag_ended.connect(func(_changed): feedback.play("ready"))
	col.add_child(volume)
	var preview_sound = _button("PREVIEW INTERFACE SOUND")
	preview_sound.pressed.connect(func(): feedback.play("ready"))
	col.add_child(preview_sound)
	var loading_wind = CheckButton.new()
	loading_wind.name = "LoadingWindAmbience"
	loading_wind.text = "Loading wind ambience"
	loading_wind.button_pressed = feedback.loading_ambience
	loading_wind.toggled.connect(func(value): feedback.loading_ambience = value; feedback.save())
	col.add_child(loading_wind)

func sync_interface(muted: bool, motion: bool) -> void:
	feedback.muted = muted
	audio_toggle.set_pressed_no_signal(muted)
	motion_toggle.set_pressed_no_signal(motion)

func sync_wind(wind) -> void:
	wind_mode.select(wind.mode)
	wind_volume.set_value_no_signal(wind.volume)
	wind_status.text = "F7 compares wind sounds while skiing" if wind.available else "Procedural wind unavailable · using Original"

func _settings_field(parent: Control, caption: String) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	column.add_child(_label(caption.to_upper(),11,LIME,true))
	parent.add_child(column)
	return column

func _display_option(parent: Control, key: String, labels: Array, values: Array) -> void:
	var names = {"display_mode":"Window mode","upscaler":"Upscaling","render_scale":"Render scale","fps_limit":"Rendered FPS limit","msaa":"Native antialiasing","anisotropic":"Anisotropic filtering"}
	var column = _settings_field(parent,names.get(key,key))
	var control = OptionButton.new()
	for label in labels: control.add_item(label)
	control.custom_minimum_size.y = 42
	control.set_meta("values",values)
	control.item_selected.connect(func(index): display_setting_requested.emit(key,values[index]))
	if key=="upscaler": control.get_popup().about_to_popup.connect(_sync_fidelityfx_choices)
	display_controls[key] = control
	column.add_child(control)

func sync_display(settings) -> void:
	fidelityfx_display_settings = settings
	for key in display_controls:
		var control = display_controls[key]
		if control is CheckButton: control.set_pressed_no_signal(settings.get(key))
		elif control is Range: control.set_value_no_signal(settings.get(key))
		else:
			var values: Array = control.get_meta("values")
			control.select(maxi(0,values.find(settings.get(key))))
	settings_pages.sync(settings)
	_sync_fidelityfx_choices()

func _sync_fidelityfx_choices() -> void:
	if fidelityfx_display_settings==null: return
	var settings = fidelityfx_display_settings
	var native_fsr: bool = settings.has_native_fsr()
	display_controls.frame_generation.disabled = not native_fsr
	display_controls.frame_generation.tooltip_text = "FSR 3 frame generation requires a supported DX12 GPU." if native_fsr else "Requires the custom DirectX 12 engine."
	for index in [1,2]: display_controls.upscaler.set_item_disabled(index,not native_fsr)
	var status: Dictionary = settings.fsr_status()
	if native_fsr and status.get("frame_generation_capabilities_queried",false):
		display_controls.frame_generation.disabled = not status.get("frame_generation_supported",false)
		if display_controls.frame_generation.disabled: display_controls.frame_generation.tooltip_text = "This GPU does not provide FSR 3 frame generation."
	if native_fsr and status.get("capabilities_queried",false):
		display_controls.upscaler.set_item_disabled(1,not status.get("fsr4_supported",false))
		display_controls.upscaler.set_item_disabled(2,not status.get("fsr3_supported",false))
	display_controls.upscaler.tooltip_text = "Auto selects the best provider reported by AMD's SDK." if native_fsr else "Auto uses FSR 2 in this engine."
	if fidelityfx_status_label:
		var active = str(status.get("active_upscaler_version",""))
		var rendering = "Native resolution" if settings.upscaler=="native" else "FSR 2" if settings.upscaler=="fsr2" or not native_fsr else "FSR "+active if active!="" else "Waiting for renderer"
		fidelityfx_status_label.text = "Active: %s · Frame generation %s" % [rendering,"on" if status.get("frame_generation_active",false) else "off"]
		if not native_fsr: fidelityfx_status_label.text += ". FSR 3/4 require the custom DirectX 12 engine."
		elif not str(status.get("error","")).is_empty(): fidelityfx_status_label.text += ". "+str(status.error)

func sync_weather(controller) -> void:
	weather_preset.select(WEATHER_IDS.find(controller.selected_preset))
	weather_auto.set_pressed_no_signal(controller.automatic)
	if fidelityfx_display_settings: weather_quality.select(fidelityfx_display_settings.profile().weather_quality)
	time_of_day.select(TIME_IDS.find(controller.daylight.label().to_lower()))
	time_cycle.set_pressed_no_signal(controller.daylight.automatic)

func close_weather() -> void:
	settings_pages.flush_changes()
	feedback.play("back")
	menu.visible = true
	weather_panel.visible = false
	compact_menu.refresh()
	weather_button.grab_focus.call_deferred()

func _primary_pressed() -> void:
	if menu_mode == "paused":
		resume_requested.emit()
	elif menu_mode=="crashed":
		if compact_menu.crash_paused: crash_pause_requested.emit()
		elif not primary.disabled: respawn_requested.emit()
	elif menu_mode=="finished":
		restart_requested.emit()
	else:
		start_requested.emit(mountain_seed_value<0)

func show_menu(kind: String, detail: String = "") -> void:
	if kind!="crashed" or menu_mode!="crashed": compact_menu.crash_paused = false
	menu_mode = kind
	menu.visible = true
	weather_panel.visible = false
	competition.panel.visible = false
	menu_tabs.current_tab = 0
	menu_description.text = detail
	menu_title.add_theme_color_override("font_color",WHITE)
	primary.disabled = false
	compact_menu.refresh()
	if not compact_menu.is_crash_actions(): primary.grab_focus()
	_sync_menu_backdrop()

func update_crash_recovery(session, unavailable: String = "", focus_paused: bool = false) -> void:
	if not session.recovering: return
	var paused: bool = session.recovery_paused or focus_paused
	if compact_menu.crash_paused!=session.recovery_paused:
		compact_menu.crash_paused = session.recovery_paused
		compact_menu.refresh()
		if session.recovery_paused: primary.grab_focus.call_deferred()
	crash_clock.text = "%s  /  %s" % [Session.format_time(session.elapsed),"PAUSED" if paused else "CLOCK RUNNING"]
	crash_availability.text = unavailable
	if compact_menu.is_crash_actions():
		primary.disabled = paused or not unavailable.is_empty()
		primary.text = "Stand Up" if unavailable.is_empty() else "Stand Up · "+unavailable
		primary.tooltip_text = unavailable
		primary.clip_text = not unavailable.is_empty()
		primary.custom_minimum_size.x = minf(400,root.size.x*.45) if not unavailable.is_empty() else 0.0
	else:
		primary.disabled = false
		primary.clip_text = false

func hide_menu() -> void:
	menu.visible = false
	weather_panel.visible = false
	competition.panel.visible = false

func open_competition(session) -> void:
	menu.visible = false
	weather_panel.visible = false
	competition.refresh(session,ghost_enabled)
	competition.panel.visible = true
	competition.ghost_toggle.grab_focus()

func close_competition() -> void:
	feedback.play()
	competition.panel.visible = false
	menu.visible = true
	menu_tabs.current_tab = 1
	records_button.grab_focus()

func show_result(session, peak_kmh: float) -> void:
	show_menu("finished",session.result_text(peak_kmh))
	if session.new_best:
		menu_title.text = "Personal best!"
		menu_title.add_theme_color_override("font_color",AlpineTheme.SUCCESS)
		feedback.emphasize(menu_title)

func _build_debug() -> void:
	debug_panel = _panel()
	var empty_panel = StyleBoxEmpty.new()
	empty_panel.set_content_margin_all(28)
	debug_panel.add_theme_stylebox_override("panel",empty_panel)
	debug_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	debug_panel.offset_left = -386
	debug_panel.offset_right = -44
	debug_panel.offset_top = 150
	debug_panel.offset_bottom = 575
	debug_panel.custom_minimum_size = Vector2(342,425)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	debug_panel.add_child(column)
	column.add_child(_label("LIVE TELEMETRY / F3",12,HUD_ACCENT,true))
	debug_text = _label("",12,HUD_WHITE,true)
	debug_text.add_theme_constant_override("line_spacing",6)
	column.add_child(debug_text)
	column.add_child(_label("GREEN velocity  ·  ORANGE fall line\nBLUE normal  ·  PURPLE gravity\nWHITE ski heading",10,HUD_MUTED))
	debug_panel.visible = false

func build_tuning(values) -> void:
	tuning_resource = values
	tuning_panel = _panel()
	tuning_panel.name = "WorkbenchWindow"
	var shell = _window(tuning_panel,900)
	shell.add_child(_label("PHYSICS WORKBENCH",28,WHITE))
	_note(shell,"Live tuning · modified physics and speed-lab runs do not set personal bests.")
	tuning_tabs = _tabs(shell)
	var handling = _tab(tuning_tabs,"Handling")
	var forces = _tab(tuning_tabs,"Forces")
	var comfort = _tab(tuning_tabs,"Feedback")
	var lab = _tab(tuning_tabs,"Speed lab")
	for setting in [
		["Gravity", "gravity_multiplier",0.4,1.6,0.05],
		["Ski friction", "ski_friction",0.005,0.10,0.001],
		["Edge grip", "edge_grip",0.3,3.0,0.1],
		["Carving response", "carving_strength",2.0,18.0,0.5],
		["Deep snow hold", "snow_edge_cutting",0.0,6.0,0.1],
		["Skid drag", "skidding_friction",0.0,1.5,0.05],
		["Air drag", "aerodynamic_drag",0.001,0.010,0.0002],
		["Steering", "steering_sensitivity",0.4,2.5,0.05],
		["Landing severity (m/s)", "landing_tolerance",5.0,16.0,0.5],
		["Vibration", "vibration_intensity",0.0,1.0,0.1]
	]:
		var row = HBoxContainer.new()
		var label = _label(setting[0],12,WHITE)
		label.custom_minimum_size.x = 138
		row.add_child(label)
		var slider = HSlider.new()
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.min_value = setting[2]
		slider.max_value = setting[3]
		slider.step = setting[4]
		slider.value = values.get(setting[1])
		tuning_sliders[setting[1]] = slider
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var readout = _label("%.4f" % values.get(setting[1]),12,LIME,true)
		tuning_readouts[setting[1]] = readout
		readout.custom_minimum_size.x = 62
		row.add_child(readout)
		slider.value_changed.connect(func(value):
			values.set(setting[1],value)
			readout.text = "%.4f" % value
			if setting[1]=="vibration_intensity": vibration_changed.emit(value)
			if setting[1] not in ["vibration_intensity"]:
				tuning_changed.emit()
		)
		row.custom_minimum_size.y = 48
		var target = comfort if setting[1] in ["vibration_intensity"] else (forces if setting[1] in ["gravity_multiplier","ski_friction","skidding_friction","aerodynamic_drag"] else handling)
		target.add_child(row)
	lab.add_child(_label("SPEED LAB  /  START AT A KNOWN VELOCITY",11,LIME,true))
	var buttons = GridContainer.new()
	buttons.columns = 4
	buttons.add_theme_constant_override("h_separation",12)
	buttons.add_theme_constant_override("v_separation",12)
	for speed in [30,60,90,120,150,165,200]:
		var button = _button(str(speed)+" km/h")
		button.add_theme_font_size_override("font_size",13)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 38
		button.pressed.connect(func(): lab_speed_requested.emit(float(speed)))
		buttons.add_child(button)
	lab.add_child(buttons)
	_note(lab,"Start a fresh, unranked attempt at a known speed. Selecting a speed closes the workbench and begins skiing.")
	var defaults = _button("Restore defaults & restart")
	defaults.custom_minimum_size.y = 35
	defaults.pressed.connect(restore_defaults)
	shell.add_child(defaults)
	var close = _button("CLOSE WORKBENCH / F2",true)
	close.pressed.connect(func(): workbench_closed.emit())
	shell.add_child(close)
	tuning_panel.visible = false

func restore_defaults() -> void:
	var original = load("res://config/ski_default.tres")
	for key in tuning_sliders:
		# Restore exact resource values, independently of a slider's step grid.
		tuning_sliders[key].set_value_no_signal(original.get(key))
		tuning_resource.set(key,original.get(key))
		tuning_readouts[key].text = "%.4f" % original.get(key)
	defaults_requested.emit()

func toast(message: String) -> void:
	if has_menu_background() and ui_notice:
		ui_notice.text = message
		ui_notice_time = 3.0
	toast_label.text = message
	toast_time = 3.0

func update_hud(sim, session, intent, device: String, frame_ms: float, tick_ms: float, dt: float, timed: bool, weather_label: String = "Clear") -> void:
	if hud_editor and hud_editor.visible: return
	ui_notice_time -= dt
	if ui_notice: ui_notice.visible = ui_notice_time>0.0
	widget_layout.timed = timed
	widget_layout.apply(root.size)
	toast_time -= dt
	toast_label.visible = toast_time > 0.0
	speed_label.text = str(roundi(sim.speed_kmh()))
	speed_dial.speed = sim.speed_kmh()
	var band = 0
	for threshold in sim.tuning.speed_thresholds:
		if sim.speed_kmh()>=threshold:
			band += 1
	band_label.text = ["MANEUVERING","ORDINARY SKIING","FAST","RACING","ELITE DOWNHILL","EXTREME RACING","EXTREME TERRAIN","EXCEPTIONAL SPEED"][mini(band,7)]
	speed_dial.tint = AlpineTheme.HUD_WARNING if band>=5 else HUD_WHITE
	band_label.modulate = speed_dial.tint
	timer_label.text = Session.format_time(session.elapsed) if timed else "FREE SKI"
	pb_label.text = "PERSONAL BEST  " + Session.format_time(session.personal_best)
	split_label.text = ""
	if timed:
		if session.latest_split>=0:
			var index: int = session.latest_split
			var delta: float = session.split_delta(index)
			split_label.text = "%d%% APPROACH  /  %s\n%s" % [(index+1)*25,Session.format_time(session.split_times[index]),"NO PREVIOUS SPLIT" if not is_finite(delta) else Session.format_delta(delta)+( " AHEAD OF PB" if delta<0 else " BEHIND PB" if delta>0 else " LEVEL WITH PB")]
			split_label.modulate = AlpineTheme.HUD_WARNING if is_finite(delta) and delta>0 else AlpineTheme.HUD_SUCCESS
		else:
			split_label.text = "%d GHOSTS %s / G" % [session.reference_ghosts.size(),"ON" if ghost_enabled else "OFF"] if not session.reference_ghosts.is_empty() else "NO GHOSTS THIS ATTEMPT"
			split_label.modulate = HUD_WHITE
	if session.latest_split!=last_split_index:
		last_split_index = session.latest_split
		if last_split_index>=0: feedback.emphasize(split_label)
	progress.value = session.progress_percent(sim.position)
	altitude_label.text = "%s m  ·  %s" % [str(roundi(sim.position.y + (1491.5 if mountain_seed_value<0 else 0.0))),weather_label.to_upper()]
	var status = "DEEP TUCK" if sim.effective_tuck > 0.8 else "CLEAN LINE"
	if not sim.grounded:
		status = "AIRBORNE  /  %.2f s" % sim.airtime
		if sim.landing_assist_strength>0.0:
			status = "LANDING HELP  /  STEER TO TAKE OVER"
	elif intent.brake > 0.1:
		status = "BRAKING"
	elif absf(rad_to_deg(sim.slip_angle)) > 12.0:
		status = "SKIDDING / MOMENTUM LOSS"
	elif maxf(absf(sim.skis[0].edge_angle),absf(sim.skis[1].edge_angle)) > 0.12:
		status = "CARVING"
	var reserve: float = sim.impacts.reserve
	var recovering: bool = reserve<1.0 and sim.grounded and sim.rock_contact==0.0 and minf(sim.impacts.since_hit,sim.impacts.since_rock)>=sim.tuning.impact_recovery_delay
	var tint = HUD_ACCENT
	impact_label.text = "IMPACT RESERVE"
	if sim.grounded and intent.jump_held:
		status = "JUMP READY  /  RELEASE TO HOP"
	elif sim.grounded and sim.time_since_landing<.15 and sim.landing_force>2.5:
		status = "LANDING  /  ABSORBING IMPACT"
	if reserve<1.0:
		tint = AlpineTheme.HUD_SUCCESS if recovering else AlpineTheme.HUD_WARNING
		if recovering:
			status = "RECOVERING  /  KEEP YOUR LINE SMOOTH"
		elif sim.impacts.since_hit<.55:
			status = sim.impacts.last_reason+"  /  IMPACT ABSORBED"
		else:
			status = "IMPACT  /  FIND A SMOOTH LINE"
		if reserve<=.30:
			tint = AlpineTheme.HUD_DANGER
			status = "LOW IMPACT RESERVE  /  FIND SMOOTH SNOW"
	if sim.grounded and sim.rock_contact>0.0:
		impact_label.text = "ROCK  /  RESERVE %d%%" % roundi(reserve*100.0)
		status = "ROCK  /  RESERVE DRAINING — FIND SNOW" if sim.rock_wear_rate>0.0 else "ROCK  /  REDUCED GRIP"
		tint = AlpineTheme.HUD_DANGER if reserve<=.30 else AlpineTheme.HUD_WARNING
	if sim.crashed:
		status = sim.crash_reason
		tint = AlpineTheme.HUD_DANGER
	impact_bar.value = reserve*100.0
	impact_bar.tint = tint
	impact_label.add_theme_color_override("font_color",tint)
	state_label.modulate = HUD_WHITE if reserve==1.0 and not sim.crashed else tint
	var category = status.get_slice("  /  ",0)
	if category!=last_status_category:
		last_status_category = category
		if reserve<=.30 or category in ["RECOVERING","JUMP READY","LANDING"]: feedback.emphasize(state_label)
	state_label.text = status
	mode_label.text = ("TIMED DESCENT" if timed else "FREE SKI") + ("  /  LAB VALUES" if not session.eligible else "  /  01")
	if not mountain_name.is_empty() and not session.race:
		mode_label.text = "FREE SKI  /  SEED %d" % mountain_seed_value
	if session.race and timed:
		mode_label.text = session.race.title.to_upper() + (" / UNRANKED" if not session.eligible else " / OPEN ROUTE")
		state_label.text = "%s  ·  FINISH %d m" % [status,sim.position.distance_to(session.race.finish)]
		if session.finished: state_label.text = "FINISH REACHED"
		menu_specs.text = "MOUNTAIN %d  /  OPEN ROUTE\nFINISH GATE  /  NO CHECKPOINTS" % session.race.mountain.seed
	elif not mountain_name.is_empty():
		menu_specs.text = "MOUNTAIN SEED: %d\nFREE SKI / CREATE YOUR OWN RACES" % mountain_seed_value
	else:
		menu_specs.text = "1.55 km     /     600 m VERTICAL\nTIMED LAB FIXTURE"
	telemetry_timer += dt
	if telemetry_timer < 0.1:
		return
	telemetry_timer = 0.0
	fps_label.text = "%d FPS  /  120 Hz PHYSICS" % Engine.get_frames_per_second()
	debug_text.text = "SPEED         %7.2f km/h\nACCEL         %+7.2f m/s²\nSLOPE         %7.2f°\nSKI HEADING   %+7.2f°\nVEL HEADING   %+7.2f°\nSLIP ANGLE    %+7.2f°\nEDGE REQUEST  %+7.2f°\nEDGES R/L     %+5.1f / %+5.1f°\nCONTACT       %s\nNORMAL LOAD   %7.2f g\nFRICTION      %7.2f m/s²\nGRAVITY       %+7.2f m/s²\nIMPACT RESERVE%7.1f %%\nIMPACT SPEED  %7.2f m/s\nAIRTIME       %7.3f s\nCPU TICK      %7.3f ms\nFRAME         %7.2f ms\n%s" % [sim.speed_kmh(),sim.acceleration,sim.slope_angle,rad_to_deg(sim.heading),rad_to_deg(atan2(sim.velocity.x,sim.velocity.z)),rad_to_deg(sim.slip_angle),rad_to_deg(sim.edge_angle),rad_to_deg(sim.skis[0].edge_angle),rad_to_deg(sim.skis[1].edge_angle),("ROCK" if sim.rock_contact>.99 else ("MIXED" if sim.rock_contact>0.0 else "SNOW")) if sim.grounded else "AIR",sim.normal_load/9.81,sim.friction_force,sim.gravity_contribution,sim.impacts.reserve*100,sim.landing_force,sim.total_airtime,tick_ms,frame_ms,device.left(30)]

	debug_text.text += "\nYAW WANT/GET  %+5.1f / %+5.1f°/s\nSKID / TRANS  %5.0f / %5.0f %%\nCOM X / Z     %+.2f / %+.2f m" % [rad_to_deg(sim.steering_requested_yaw),rad_to_deg(sim.steering_applied_yaw),sim.steering_slip_factor*100,sim.steering_transfer_factor*100,sim.body.com.x,sim.body.com.z]

func toggle_instruments() -> void:
	widget_layout.global_visible = not widget_layout.global_visible
	layout_widgets()

func layout_widgets() -> void:
	for widget in widget_layout.widgets.values(): widget.node.background_enabled = shell_layout.hud_backgrounds
	if widget_layout.widgets.is_empty() or widget_layout.preview: return
	widget_layout.safe_area = shell_layout.safe_area
	widget_layout.apply(root.size)
	if widget_layout.values.get("debug",{}).get("visible",false): debug_panel.show()

func open_hud_editor() -> void:
	settings_pages.flush_changes()
	hud_editor.open()

func _widget(id: String, caption: String, nodes: Array, dimensions: Vector2, position: Vector2, offsets: Array, enabled: bool = true, race_only: bool = false) -> void:
	var wrapper = preload("res://scripts/ui/hud_widget_frame.gd").new()
	wrapper.name = "Widget_"+id
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wrapper)
	for i in nodes.size():
		var node: Control = nodes[i]
		node.reparent(wrapper,false)
		node.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		node.position = offsets[i]+Vector2(8,6)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.style_content(node)
	widget_layout.register(id,caption,wrapper,dimensions+Vector2(16,12),position,enabled,race_only)

func _build_widget_registry() -> void:
	_widget("speed","Speed",[speed_dial.get_parent()],Vector2(180,210),Vector2(1,1),[Vector2.ZERO])
	_widget("time","Time & personal best",[timer_label.get_parent()],Vector2(310,105),Vector2(0,1),[Vector2.ZERO],true,true)
	_widget("progress","Course progress",[progress,hud_controls[1]],Vector2(360,32),Vector2(.5,0),[Vector2.ZERO,Vector2(0,12)],true,true)
	_widget("split","Split & delta",[split_label],Vector2(420,52),Vector2(.5,.13),[Vector2.ZERO],true,true)
	_widget("state","Riding state",[state_label],Vector2(600,34),Vector2(.5,.70),[Vector2.ZERO])
	_widget("reserve","Impact reserve",[impact_label,impact_bar],Vector2(200,34),Vector2(.5,1),[Vector2.ZERO,Vector2(15,24)])
	fps_label.reparent(root)
	_widget("location","Location & weather",[location_box],Vector2(280,55),Vector2(1,0),[Vector2.ZERO])
	_widget("performance","Performance",[fps_label],Vector2(270,22),Vector2(1,.14),[Vector2.ZERO])
	_widget("run","Run context",[mode_label],Vector2(250,26),Vector2(0,0),[Vector2.ZERO])
	_widget("debug","Debug telemetry",[debug_panel],Vector2(342,480),Vector2(1,.4),[Vector2.ZERO],false)
	_widget("notice","Gameplay notice",[toast_label],Vector2(460,40),Vector2(.5,.26),[Vector2.ZERO])
	_widget("summit","Summit return",[summit_return_label],Vector2(460,32),Vector2(.5,.38),[Vector2.ZERO])
	# Composite wrappers keep every label/bar with its instrument.
	speed_dial.get_parent().size = Vector2(180,210)
	progress.size = Vector2(360,3)
	impact_bar.size = Vector2(170,3)
	impact_label.size = Vector2(200,20)
	state_label.size = Vector2(600,34)
	split_label.size = Vector2(420,52)
	fps_label.size = Vector2(270,22)
	mode_label.size = Vector2(250,26)
	location_box.size = Vector2(280,55)
	debug_panel.size = Vector2(342,480)
	toast_label.size = Vector2(460,40)
	summit_return_label.size = Vector2(460,32)
	hud_controls.clear()
	for id in widget_layout.widgets: hud_controls.append(widget_layout.widgets[id].node)
	widget_layout.widgets.notice["transient"] = toast_label
	widget_layout.widgets.summit["transient"] = summit_return_label
	if feedback.persist: widget_layout.load_preferences()

func build_skier_controls(appearance, persist: bool = true) -> void:
	appearance_column.add_child(_label("Rider colors",20,WHITE))
	var finishes = shell_layout.group(appearance_column,"Material finishes",self)
	for id in ["Clothing","Helmet","Lens"]:
		var row = HBoxContainer.new()
		appearance_column.add_child(row)
		var label = _label(id,14,WHITE)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var color = ColorPickerButton.new()
		color.custom_minimum_size = Vector2(90,30)
		color.color = appearance.values[id].tint
		color.edit_alpha = false
		color.color_changed.connect(func(value): appearance.change(id,"tint",value,persist))
		row.add_child(color)
		for property in ["roughness","metallic"]:
			var control = HBoxContainer.new()
			finishes.add_child(control)
			var caption = _label(id+" · "+("Glossy / matte" if property=="roughness" else "Metallic reflection"),14,MUTED)
			caption.custom_minimum_size.x = 150
			control.add_child(caption)
			var slider = HSlider.new()
			slider.min_value = .04 if property=="roughness" else 0.0
			slider.max_value = 1.0
			slider.step = .01
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.value = appearance.values[id][property]
			slider.value_changed.connect(func(value): appearance.change(id,property,value,persist))
			control.add_child(slider)
	appearance_column.move_child(finishes.get_parent(),appearance_column.get_child_count()-1)
	var reset_button = _button("Reset rider appearance")
	reset_button.pressed.connect(func():
		appearance.reset(persist)
		for child in appearance_column.get_children(): appearance_column.remove_child(child); child.queue_free()
		build_skier_controls(appearance,persist))
	appearance_column.add_child(reset_button)

func set_mountain(mountain) -> void:
	mountain_name = mountain.title if mountain else ""
	mountain_seed_value = mountain.seed_value if mountain else -1
	menu_location.text = "YOUR MOUNTAIN" if mountain else "01  /  THE TEST FACE"
	conditions.text = mountain_name.to_upper() if mountain else "AIGUILLE  /  NORTH FACE"
	conditions.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	conditions.custom_minimum_size.x = 220
	menu_specs.text = "MOUNTAIN SEED: %d\nFREE SKI / CREATE YOUR OWN RACES" % mountain_seed_value if mountain else "1.55 km     /     600 m VERTICAL\nTIMED LAB FIXTURE"
	if menu.visible: show_menu(menu_mode)

func _finish_build_identity() -> void:
	while is_inside_tree() and not BuildIdentity.poll_background():
		await get_tree().process_frame
	if not is_inside_tree(): return
	build_version_label.text = BuildIdentity.short_label()
	build_version_label.tooltip_text = BuildIdentity.current().get("warning","")
	copy_build_button.disabled = false
