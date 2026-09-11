extends CanvasLayer
signal start_requested(timed: bool)
signal restart_requested
signal resume_requested
signal lab_speed_requested(kmh: float)
signal tuning_changed
signal vibration_changed(value: float)
signal defaults_requested
signal workbench_closed
signal quit_requested
signal weather_preset_requested(id: String)
signal weather_auto_requested(enabled: bool)
signal weather_quality_requested(quality: int)
signal time_of_day_requested(id: String)
signal time_cycle_requested(enabled: bool)
signal graphics_quality_requested(level: int)
signal display_setting_requested(key: String, value: Variant)
signal camera_setting_requested(key: String, value: float)
signal camera_defaults_requested
const CameraSettings = preload("res://scripts/presentation/camera_settings.gd")
var camera_setting_controls: Dictionary = {}
var camera_setting_readouts: Dictionary = {}
var camera_reset_button: Button
var display_controls: Dictionary = {}
var fidelityfx_display_settings
var fidelityfx_status_label: Label
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
signal animation_workshop_requested
signal audio_mute_requested(enabled: bool)
signal motion_effects_requested(enabled: bool)
signal mountains_requested
signal races_requested
signal competition_requested
signal ghost_visibility_requested(enabled: bool)
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
const WHITE = Art.WHITE
const MUTED = Art.MUTED
# Kept as an alias for panels that consume the HUD's established accent contract.
const LIME = Art.ICE
var root = Control.new()
var menu_fade: ColorRect
var menu_backgrounds: Array[Control] = []
var menu_art_ready: bool = false
var hero_logo: TextureRect
var header_logo: TextureRect
var menu: PanelContainer
var menu_title: Label
var menu_description: Label
var menu_specs: Label
var menu_location: Label
var mountain_name: String = ""
var mountain_seed_value: int = -1
var conditions: Label
var footer: PanelContainer
var footer_controls: Label
const SKI_CONTROLS = "A / D  STEER    W  TUCK    S  BRAKE    SPACE  HOP    MOUSE / RS  LOOK    MMB / R3  CENTER    C  VIEW    ESC  MENU"
const PAD_CONTROLS = "LS  STEER    LS FORWARD  TUCK    L2 / LT  BRAKE    HOLD R2 / RT, RELEASE TO HOP    RS  LOOK    R3  CENTER    R1  VIEW"
const MENU_CONTROLS = "TAB / ARROWS  NAVIGATE     ENTER  SELECT     ESC  BACK     F2  WORKBENCH     F4  RACES     F6  HISTORY"
var primary: Button
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
var weather_auto: CheckButton
var weather_quality: OptionButton
const WEATHER_IDS = ["clear","cloudy","snowfall","rain"]
const TIME_IDS = ["dawn","day","dusk","night"]
var time_of_day: OptionButton
var time_cycle: CheckButton

class SpeedDial:
	extends Control
	var speed: float = 0.0
	var tint = Color.WHITE
	func _draw() -> void:
		var center = size * 0.5
		var radius = size.x * 0.46
		var start = deg_to_rad(140.0)
		var sweep = deg_to_rad(260.0)
		draw_arc(center,radius,start,start+sweep,80,Color(1,1,1,0.20),2.0,true)
		draw_arc(center,radius,start,start+sweep*clampf(speed/200.0,0,1),80,tint,3.0,true)
		for threshold in [60,90,120,150,165,200]:
			var direction = Vector2.from_angle(start+sweep*threshold/200.0)
			draw_line(center+direction*(radius-6),center+direction*radius,Color(1,1,1,0.4),1.0,true)

class SlimBar:
	extends Control
	const UITheme = preload("res://scripts/ui/alpine_theme.gd")
	var background = UITheme.box(Color(1,1,1,0.20),Color.TRANSPARENT,0,Vector2(6,3))
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
	normal_font = Art.interface_font()
	mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono"])
	root.theme = AlpineTheme.create()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_menu_backdrop()
	_build_readability_gradients()
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
	root.visibility_changed.connect(_sync_menu_backdrop)
	toast_label = _label("",20,LIME)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-280,137)
	toast_label.size = Vector2(560,36)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast_label)
	summit_return_label = _label("",18,WHITE)
	summit_return_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	summit_return_label.position = Vector2(-260,179)
	summit_return_label.size = Vector2(520,30)
	summit_return_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summit_return_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	summit_return_label.add_theme_constant_override("shadow_offset_y",2)
	summit_return_label.hide()
	root.add_child(summit_return_label)
	show_menu("title")

func update_summit_return(distance_m: float, skiing: bool) -> void:
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

func _build_readability_gradients() -> void:
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
		root.add_child(rect)

func _style(bg: Color, border: Color = Color(0.55,0.69,0.73,0.2), padding: int = 28) -> StyleBox:
	return AlpineTheme.box(bg,border,padding,AlpineTheme.PANEL_CUT if padding >= 20 else AlpineTheme.CONTROL_CUT)

func _panel(parent: Control = root) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(Color(0.025,0.055,0.09,0.95),Color(0.55,0.72,0.83,0.25)))
	parent.add_child(panel)
	panel.visibility_changed.connect(func():
		if panel.visible: feedback.reveal(panel)
	)
	return panel

func _window(panel: PanelContainer, width: float = 900.0) -> VBoxContainer:
	register_menu_background(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -width/2.0
	panel.offset_right = width/2.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_top = 140
	panel.offset_bottom = -64
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	panel.add_child(column)
	return column

func _tabs(parent: Control) -> TabContainer:
	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.tab_changed.connect(func(_index):
		feedback.play()
		var page = tabs.get_current_tab_control()
		if page: feedback.reveal(page)
	)
	parent.add_child(tabs)
	return tabs

func _tab(tabs: TabContainer, caption: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = caption
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",16)
	scroll.add_child(column)
	return column

func _note(parent: Control, text: String) -> Label:
	var label = _label(text,14,MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(text_value: String, main_button: bool = false) -> Button:
	var button = Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 50
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",17)
	if main_button:
		button.theme_type_variation = "AlpinePrimary"
		button.text = text_value.replace("↗","").strip_edges()
		button.icon = AlpineTheme.icon("chevrons",Color.WHITE)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for state in ["icon_normal_color","icon_hover_color","icon_focus_color","icon_pressed_color"]:
			button.add_theme_color_override(state,INK)
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
	var title_screen = menu_mode == "title" and menu.visible and background_visible
	hero_logo.visible = title_screen
	header_logo.visible = not hero_logo.visible
	if not background_visible or feedback.reduced_motion: set_background_fade(0.0)
	menu.offset_top = 255 if title_screen else 145
	mode_label.visible = not hero_logo.visible
	footer.visible = background_visible
	footer_controls.text = MENU_CONTROLS if background_visible else (PAD_CONTROLS if not Input.get_connected_joypads().is_empty() else SKI_CONTROLS)
	for control in hud_controls:
		if background_visible:
			if not control.has_meta("before_menu_background"): control.set_meta("before_menu_background",control.visible)
			control.hide()
		elif control.has_meta("before_menu_background"):
			control.visible = control.get_meta("before_menu_background")
			control.remove_meta("before_menu_background")

func _build_header() -> void:
	header_logo = Art.logo(Vector2(315,60),true)
	header_logo.position = Vector2(37,24)
	root.add_child(header_logo)
	mode_label = _label("PHYSICS LAB   /   01",12,LIME,true)
	mode_label.position = Vector2(43,100)
	mode_label.size.x = 455
	mode_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(mode_label)
	var top_right = VBoxContainer.new()
	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-265,32)
	top_right.size.x = 220
	root.add_child(top_right)
	conditions = _label("AIGUILLE  /  NORTH FACE",12,WHITE,true)
	conditions.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(conditions)
	altitude_label = _label("2 850 m   ·   CLEAR",12,MUTED)
	altitude_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(altitude_label)
	fps_label = _label("120 Hz PHYSICS",11,LIME,true)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(fps_label)
	progress = SlimBar.new()
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	progress.position = Vector2(-180,44)
	progress.size = Vector2(360,3)
	progress.add_theme_font_size_override("font_size",1)
	progress.add_theme_stylebox_override("background",_style(Color(1,1,1,0.17),Color.TRANSPARENT,0))
	progress.add_theme_stylebox_override("fill",_style(LIME,Color.TRANSPARENT,0))
	root.add_child(progress)
	hud_controls.append(progress)
	var course_label = _label("START                            FINISH",10,WHITE,true)
	course_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	course_label.position = Vector2(-180,56)
	root.add_child(course_label)
	hud_controls.append(course_label)
	split_label = _label("",12,LIME,true)
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
	footer_controls = _label(SKI_CONTROLS,11,MUTED,true)
	footer_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(footer_controls)

func _build_instruments() -> void:
	var timer_box = VBoxContainer.new()
	timer_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	timer_box.position = Vector2(44,-191)
	root.add_child(timer_box)
	hud_controls.append(timer_box)
	timer_box.add_child(_label("D E S C E N T   T I M E",11,MUTED))
	timer_label = _label("00:00.000",43,WHITE,true)
	timer_box.add_child(timer_label)
	pb_label = _label("PERSONAL BEST    —",11,LIME,true)
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
	speed_label = _label("0",54,WHITE)
	speed_label.position = Vector2(0,47)
	speed_label.size = Vector2(180,70)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_dial.add_child(speed_label)
	var units = _label("km/h",12,WHITE)
	units.position = Vector2(0,112)
	units.size.x = 180
	units.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_dial.add_child(units)
	band_label = _label("MANEUVERING",10,WHITE,true)
	band_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_box.add_child(band_label)
	state_label = _label("FIND YOUR FALL LINE",13,WHITE,true)
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
	impact_label = _label("IMPACT RESERVE",9,MUTED)
	impact_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	impact_label.position = Vector2(-100,-92)
	impact_label.size.x = 200
	impact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(impact_label)
	hud_controls.append(impact_label)

func _build_menu() -> void:
	menu = _panel()
	menu.name = "DescentMenu"
	menu.add_theme_stylebox_override("panel",_style(Color(0.025,0.052,0.085,0.88),Color(0.57,0.76,0.87,0.22),24))
	menu.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	menu.offset_left = 44
	menu.offset_right = 574
	menu.offset_top = 145
	menu.offset_bottom = -64
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	menu.add_child(column)
	menu_location = _label("01  /  THE TEST FACE",11,LIME,true)
	column.add_child(menu_location)
	menu_title = _label("THE FALL\nLINE.",44,WHITE)
	menu_title.add_theme_constant_override("line_spacing",-8)
	column.add_child(menu_title)
	menu_description = _label("A clean line is a fast line.\nMake every edge count.",17,MUTED)
	menu_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(menu_description)
	menu_specs = _label("1.55 km     /     600 m VERTICAL\nONE START. ONE FINISH. YOUR LINE.",11,WHITE,true)
	column.add_child(menu_specs)
	menu_tabs = _tabs(column)
	menu_tabs.custom_minimum_size.y = 205
	var ride = _tab(menu_tabs,"Ride")
	primary = _button("DROP IN",true)
	primary.pressed.connect(_primary_pressed)
	ride.add_child(primary)
	secondary = _button("Create & share races")
	secondary.pressed.connect(func(): races_requested.emit())
	ride.add_child(secondary)
	_note(ride,"Enter to drop in · Escape to pause · R to retry")
	var explore = _tab(menu_tabs,"Explore")
	var mountains_button = _button("MOUNTAINS  /  CREATE & LIBRARY",true)
	mountains_button.pressed.connect(func(): mountains_requested.emit())
	explore.add_child(mountains_button)
	var races_button = _button("RACES  /  CREATE & SHARE")
	races_button.pressed.connect(func(): races_requested.emit())
	explore.add_child(races_button)
	records_button = _button("PERSONAL BEST & RUN HISTORY")
	records_button.pressed.connect(func(): competition_requested.emit())
	explore.add_child(records_button)
	var tools = _tab(menu_tabs,"Tools")
	weather_button = _button("SETTINGS & CONTROLS",true)
	weather_button.pressed.connect(open_settings)
	tools.add_child(weather_button)
	var workbench = _button("PHYSICS WORKBENCH  /  F2")
	workbench.pressed.connect(func(): workbench_requested.emit())
	tools.add_child(workbench)
	var animation_editor = _button("ANIMATION WORKSHOP")
	animation_editor.pressed.connect(func(): animation_workshop_requested.emit())
	tools.add_child(animation_editor)
	var quit_button = _button("QUIT GAME")
	quit_button.pressed.connect(func(): quit_requested.emit())
	tools.add_child(quit_button)

func open_settings() -> void:
	weather_panel.show()
	menu.hide()
	settings_tabs.get_tab_bar().grab_focus()

func _build_weather() -> void:
	weather_panel = _panel()
	weather_panel.name = "SettingsWindow"
	var shell = _window(weather_panel,980)
	shell.add_child(_label("MAKE IT YOUR DESCENT.",28,WHITE))
	_note(shell,"Display, mountain conditions, rider style and interface preferences.")
	settings_tabs = _tabs(shell)
	var display = _tab(settings_tabs,"Display")
	var display_grid = GridContainer.new()
	display_grid.columns = 2
	display_grid.add_theme_constant_override("h_separation",24)
	display_grid.add_theme_constant_override("v_separation",20)
	display.add_child(display_grid)
	var col = _tab(settings_tabs,"Weather")
	col.add_child(_label("CONDITIONS",11,LIME,true))
	weather_preset = OptionButton.new()
	for label in ["Clear","Cloudy","Snowfall","Rain"]:
		weather_preset.add_item(label)
	weather_preset.custom_minimum_size.y = 42
	weather_preset.item_selected.connect(func(index): weather_preset_requested.emit(WEATHER_IDS[index]))
	col.add_child(weather_preset)
	weather_auto = CheckButton.new()
	weather_auto.text = "Automatic weather"
	weather_auto.toggled.connect(func(value): weather_auto_requested.emit(value))
	col.add_child(weather_auto)
	col.add_child(_label("Conditions evolve gradually over several minutes.",12,MUTED))
	col.add_child(_label("TIME OF DAY",11,LIME,true))
	var time_row = HBoxContainer.new()
	col.add_child(time_row)
	time_of_day = OptionButton.new()
	for label in ["Dawn","Day","Dusk","Night"]:
		time_of_day.add_item(label)
	time_of_day.custom_minimum_size.y = 42
	time_of_day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_of_day.item_selected.connect(func(index): time_of_day_requested.emit(TIME_IDS[index]))
	time_row.add_child(time_of_day)
	time_cycle = CheckButton.new()
	time_cycle.text = "Cycle slowly"
	time_cycle.toggled.connect(func(value): time_cycle_requested.emit(value))
	time_row.add_child(time_cycle)
	col.add_child(_label("A full day and night takes 20 minutes of skiing.",12,MUTED))
	col.add_child(_label("EFFECTS QUALITY",11,LIME,true))
	weather_quality = OptionButton.new()
	for label in ["Off","Low","High"]:
		weather_quality.add_item(label)
	weather_quality.custom_minimum_size.y = 42
	weather_quality.item_selected.connect(func(index): weather_quality_requested.emit(index))
	col.add_child(weather_quality)
	var graphics_field = _settings_field(display_grid,"Graphics quality")
	graphics_quality = OptionButton.new()
	for label in ["Low","Balanced","High"]:
		graphics_quality.add_item(label)
	graphics_quality.custom_minimum_size.y = 42
	graphics_quality.item_selected.connect(func(index): graphics_quality_requested.emit(index))
	graphics_field.add_child(graphics_quality)
	_display_option(display_grid,"display_mode",["Fullscreen · native display","Windowed"],["fullscreen","windowed"])
	_display_option(display_grid,"upscaler",["Auto · best supported FSR","FSR 4.1 · Radeon RX 7000/9000","FSR 3.1 · supported AMD / NVIDIA / Intel","FSR 2 · engine default","Native resolution"],["auto","fsr4","fsr3","fsr2","native"])
	_display_option(display_grid,"render_scale",["75% · quality","66.7% · performance","100% · full resolution"],[.75,2.0/3.0,1.0])
	_display_option(display_grid,"fps_limit",["120 FPS limit","90 FPS limit","144 FPS limit","Uncapped"],[120,90,144,0])
	var framegen = CheckButton.new()
	framegen.text = "FSR 3 frame generation"
	framegen.toggled.connect(func(value): display_setting_requested.emit("frame_generation",value))
	_settings_field(display_grid,"Frame generation · supported GPUs").add_child(framegen)
	display_controls.frame_generation = framegen
	var gi = CheckButton.new()
	gi.text = "Terrain GI"
	gi.toggled.connect(func(value): display_setting_requested.emit("terrain_gi",value))
	_settings_field(display_grid,"Indirect lighting · higher GPU cost").add_child(gi)
	display_controls.terrain_gi = gi
	_note(display,"Recommended: High · Auto upscaling at 75% · 120 FPS. Frame generation adds display frames; input response still depends on rendered FPS.")
	fidelityfx_status_label = _label("",12,MUTED)
	fidelityfx_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	display.add_child(fidelityfx_status_label)
	var fsr_status_timer = Timer.new()
	fsr_status_timer.wait_time = 1.0
	fsr_status_timer.autostart = true
	fsr_status_timer.timeout.connect(func():
		if fidelityfx_status_label.is_visible_in_tree(): _sync_fidelityfx_choices())
	add_child(fsr_status_timer)
	appearance_column = _tab(settings_tabs,"Rider")
	_build_camera_settings(_tab(settings_tabs,"Camera"))
	voice_settings.build(_tab(settings_tabs,"Skier Voice"),self)
	_build_interface_settings(_tab(settings_tabs,"Interface"))
	var controls = _tab(settings_tabs,"Controls")
	for entry in [
		["STEER & SPEED","A / D or arrows · Left stick left / right to steer\nW / Left stick forward to tuck · S / L2 (LT) to brake\nSustained turns open your stance; return forward to tuck"],
		["HOP & RETRY","Hold Space / R2 (RT) to prepare, release to hop\nBackward skiing uses the same controls and handling\nR / △ to restart · Enter / × (A) or stick forward to drop in"],
		["AIR CONTROL","Left stick / A-D turns in the air\nCenter the stick after takeoff, then forward/back flips · No L1 needed\nL1 / LB + stick remains available for flips and fast spins\nW/S or up/down: pitch adjustment up to 50° · I/K flips · Q/E spins\nRelease to brake rotation; opposite input reverses it\nShift / west button grabs · Landing assistance is optional"],
		["CAMERA","Mouse / Right stick looks without steering, including at the summit\nMiddle mouse / R3 recenters · C / R1 changes camera\nLook returns after a short delay while moving; holds while stopped\nCamera settings: field of view, tilt, follow distance, height and vertical smoothing"],
		["TOOLS","G toggles your PB ghost · H toggles instruments\nF3 telemetry · F2 workbench · F4 races · F6 history"],
		["COMFORT","V toggles motion effects · M mutes all game audio\nVibration: brief impact pulses and faint taps on rock\nEscape / Options pauses or returns to the previous screen"]
	]:
		controls.add_child(_label(entry[0],12,LIME,true))
		_note(controls,entry[1])
	_build_audio_settings(_tab(settings_tabs,"Audio"))
	var close = _button("BACK / ESC",true)
	close.pressed.connect(close_weather)
	shell.add_child(close)
	weather_panel.visible = false

func _build_camera_settings(col: VBoxContainer) -> void:
	col.add_child(_label("BOTH VIEWS / FIELD OF VIEW",14,LIME,true))
	var lens_grid = GridContainer.new()
	lens_grid.columns = 2
	lens_grid.add_theme_constant_override("h_separation",32)
	col.add_child(lens_grid)
	_camera_slider(lens_grid,"rest_fov","At rest")
	_camera_slider(lens_grid,"fast_fov","At 200 km/h and above")
	_note(col,"Vertical field of view. Higher values show more of your surroundings. Set both values equal for a fixed FoV; motion effects off uses the resting value.")
	for group in [["DISTANCE BEHIND SKIER","distance"],["HEIGHT ABOVE SKIER","height"]]:
		col.add_child(_label("THIRD PERSON / " + group[0],14,LIME,true))
		var grid = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation",32)
		col.add_child(grid)
		_camera_slider(grid,"rest_" + group[1],"At rest")
		_camera_slider(grid,"fast_" + group[1],"At 200 km/h and above")
	_note(col,"Distance and height blend with speed. Terrain may raise the camera for clearance. Motion effects off uses the resting values.")
	col.add_child(_label("CAMERA TILT",14,LIME,true))
	var tilt_grid = GridContainer.new()
	tilt_grid.columns = 2
	tilt_grid.add_theme_constant_override("h_separation",32)
	col.add_child(tilt_grid)
	_camera_slider(tilt_grid,"chase_pitch_offset","Third person")
	_camera_slider(tilt_grid,"first_person_pitch_offset","First person")
	_note(col,"Negative looks down; positive looks up. Zero keeps the original framing. Recenter returns to your chosen tilt. Also active with motion effects off.")
	col.add_child(_label("BOTH VIEWS / VERTICAL SMOOTHING",14,LIME,true))
	_camera_slider(col,"vertical_smoothing","Off ← Vertical smoothing → Strong")
	_note(col,"Softens vertical movement over bumps in both views. Turning stays responsive. Also active with motion effects off.")
	col.add_child(_label("BOTH VIEWS / FOREST VISIBILITY",14,LIME,true))
	_camera_slider(col,"forest_visibility","Off ← Clear foliage ahead → Wider")
	_note(col,"Clears nearby foliage across most of your view while skiing, with a soft border at the edges. Trunks stay visible. Set to 0% to turn it off.")
	_note(col,"Saves automatically. Your changes apply when riding, without restarting.")
	camera_reset_button = _button("RESET CAMERA SETTINGS")
	camera_reset_button.pressed.connect(func(): camera_defaults_requested.emit())
	col.add_child(camera_reset_button)

func _camera_slider(parent: Control, key: String, caption: String) -> void:
	var field = _settings_field(parent,caption)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	field.add_child(row)
	var slider = HSlider.new()
	var bounds: Vector3 = CameraSettings.RANGES[key]
	slider.min_value = bounds.x
	slider.max_value = bounds.y
	slider.step = bounds.z
	slider.value = CameraSettings.DEFAULTS[key]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(100,42)
	slider.focus_mode = Control.FOCUS_ALL
	if key.ends_with("fov"):
		slider.tooltip_text = "Vertical field of view in degrees, shared by both riding views"
	elif key.ends_with("pitch_offset"):
		slider.tooltip_text = "Tilt in degrees from the original framing: negative looks down, positive looks up"
	elif key=="forest_visibility":
		slider.tooltip_text = "Size and reach of the central foliage opening; 0% turns it off"
	else:
		slider.tooltip_text = "Vertical stabilization in both riding views" if key == "vertical_smoothing" else ("Height above the skier, in metres; terrain clearance takes priority" if key.ends_with("height") else "Distance behind the skier, in metres")
	row.add_child(slider)
	var readout = _label(_camera_readout(key,slider.value),18,WHITE,true)
	readout.custom_minimum_size = Vector2(90,42)
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	camera_setting_controls[key] = slider
	camera_setting_readouts[key] = readout
	slider.value_changed.connect(func(value): camera_setting_requested.emit(key,value))

func _camera_readout(key: String, value: float) -> String:
	if key.ends_with("fov"): return "%d°" % roundi(value)
	if key.ends_with("pitch_offset"): return ("+%d°" if value > 0.0 else "%d°") % roundi(value)
	return "%d%%" % roundi(value) if key in ["vertical_smoothing","forest_visibility"] else "%.2f m" % value

func sync_camera_settings(settings) -> void:
	for key in camera_setting_controls:
		camera_setting_controls[key].set_value_no_signal(settings.get(key))
		camera_setting_readouts[key].text = _camera_readout(key,settings.get(key))

func _build_audio_settings(col: VBoxContainer) -> void:
	col.add_child(_label("GAME AUDIO",14,LIME,true))
	audio_toggle = CheckButton.new()
	audio_toggle.text = "Mute all game audio"
	audio_toggle.toggled.connect(func(value): audio_mute_requested.emit(value))
	col.add_child(audio_toggle)
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
	riding_audio_settings.build(col,self)

func _build_interface_settings(col: VBoxContainer) -> void:
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
	var reduced = CheckButton.new()
	reduced.text = "Reduce interface motion"
	reduced.button_pressed = feedback.reduced_motion
	reduced.toggled.connect(func(value): feedback.reduced_motion = value; feedback.save())
	col.add_child(reduced)
	motion_toggle = CheckButton.new()
	motion_toggle.text = "Skiing camera motion effects"
	motion_toggle.button_pressed = true
	motion_toggle.toggled.connect(func(value): motion_effects_requested.emit(value))
	col.add_child(motion_toggle)
	_note(col,"Interface volume also controls loading wind. Reduced motion keeps menu and loading photos and light steady, removes loading snow and skips interface fades. Below 70% impact reserve, the world gradually greys and crimson edges pulse. Reduced motion or camera motion effects off (V) keeps that warning steady.")

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
	var names = {"display_mode":"Window mode","upscaler":"Upscaling","render_scale":"Render scale","fps_limit":"Rendered FPS limit"}
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
		else:
			var values: Array = control.get_meta("values")
			control.select(maxi(0,values.find(settings.get(key))))
	display_controls.render_scale.disabled = settings.upscaler=="native"
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
	weather_quality.select(controller.quality)
	time_of_day.select(TIME_IDS.find(controller.daylight.label().to_lower()))
	time_cycle.set_pressed_no_signal(controller.daylight.automatic)

func close_weather() -> void:
	feedback.play()
	menu.visible = true
	weather_panel.visible = false
	menu_tabs.current_tab = 2
	weather_button.grab_focus()

func _primary_pressed() -> void:
	if menu_mode == "paused":
		resume_requested.emit()
	elif menu_mode in ["crashed","finished"]:
		restart_requested.emit()
	else:
		start_requested.emit(mountain_seed_value<0)

func show_menu(kind: String, detail: String = "") -> void:
	menu_mode = kind
	menu.visible = true
	weather_panel.visible = false
	competition.panel.visible = false
	weather_button.visible = true
	menu_tabs.current_tab = 0
	secondary.visible = kind == "title"
	match kind:
		"title":
			menu_title.text = "THE FALL\nLINE."
			menu_description.text = "A clean line is a fast line.\nMake every edge count."
			primary.text = "DROP IN"
		"paused":
			menu_title.text = "TAKE A\nBREATH."
			menu_description.text = "Your line is waiting.\nF2 opens the physics workbench."
			primary.text = "RESUME"
		"crashed":
			menu_title.text = "ON THE\nEDGE."
			menu_description.text = detail + "\nOne key. Another attempt."
			primary.text = "TRY AGAIN"
		"finished":
			menu_title.text = "LINE\nCOMPLETE."
			menu_description.text = detail
			primary.text = "FIND ANOTHER SECOND"
	if kind=="title" and not mountain_name.is_empty():
		menu_title.text = "YOUR\nMOUNTAIN."
		menu_description.text = "Read the terrain. Pick your descent."
		primary.text = "DROP IN"
	primary.grab_focus()
	_sync_menu_backdrop()

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
		menu_title.text = "PERSONAL\nBEST."

func _build_debug() -> void:
	debug_panel = _panel()
	debug_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	debug_panel.offset_left = -386
	debug_panel.offset_right = -44
	debug_panel.offset_top = 150
	debug_panel.offset_bottom = 575
	debug_panel.custom_minimum_size = Vector2(342,425)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	debug_panel.add_child(column)
	column.add_child(_label("LIVE TELEMETRY / F3",12,LIME,true))
	debug_text = _label("",12,WHITE,true)
	debug_text.add_theme_constant_override("line_spacing",6)
	column.add_child(debug_text)
	column.add_child(_label("GREEN velocity  ·  ORANGE fall line\nBLUE normal  ·  PURPLE gravity\nWHITE ski heading",10,MUTED))
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
	var comfort = _tab(tuning_tabs,"Camera")
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
		["Camera response", "camera_response",3.0,16.0,0.5],
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
			if setting[1] not in ["camera_response","vibration_intensity"]:
				tuning_changed.emit()
		)
		row.custom_minimum_size.y = 48
		var target = comfort if setting[1] in ["camera_response","vibration_intensity"] else (forces if setting[1] in ["gravity_multiplier","ski_friction","skidding_friction","aerodynamic_drag"] else handling)
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
	toast_label.text = message
	toast_time = 3.0

func update_hud(sim, session, intent, device: String, frame_ms: float, tick_ms: float, dt: float, timed: bool, weather_label: String = "Clear") -> void:
	toast_time -= dt
	toast_label.visible = toast_time > 0.0
	speed_label.text = str(roundi(sim.speed_kmh()))
	speed_dial.speed = sim.speed_kmh()
	var band = 0
	for threshold in sim.tuning.speed_thresholds:
		if sim.speed_kmh()>=threshold:
			band += 1
	band_label.text = ["MANEUVERING","ORDINARY SKIING","FAST","RACING","ELITE DOWNHILL","EXTREME RACING","EXTREME TERRAIN","EXCEPTIONAL SPEED"][mini(band,7)]
	speed_dial.tint = Color("efa773") if band>=5 else WHITE
	band_label.modulate = speed_dial.tint
	speed_dial.queue_redraw()
	timer_label.text = Session.format_time(session.elapsed) if timed else "FREE SKI"
	pb_label.text = "PERSONAL BEST  " + Session.format_time(session.personal_best)
	split_label.text = ""
	if timed:
		if session.latest_split>=0:
			var index: int = session.latest_split
			var delta: float = session.split_delta(index)
			split_label.text = "%d%% APPROACH  /  %s\n%s" % [(index+1)*25,Session.format_time(session.split_times[index]),"NO PREVIOUS SPLIT" if not is_finite(delta) else Session.format_delta(delta)+( " AHEAD OF PB" if delta<0 else " BEHIND PB" if delta>0 else " LEVEL WITH PB")]
			split_label.modulate = Color("ffa96b") if is_finite(delta) and delta>0 else LIME
		else:
			split_label.text = "PB GHOST %s / G" % ("ON" if ghost_enabled else "OFF") if session.reference_replay else "SET A PERSONAL BEST / FIND YOUR LINE"
			split_label.modulate = WHITE
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
	var tint = LIME
	impact_label.text = "IMPACT RESERVE"
	if sim.grounded and intent.jump_held:
		status = "JUMP READY  /  RELEASE TO HOP"
	elif sim.grounded and sim.time_since_landing<.15 and sim.landing_force>2.5:
		status = "LANDING  /  ABSORBING IMPACT"
	if reserve<1.0:
		tint = Color("85d5ca") if recovering else Color("efa773")
		if recovering:
			status = "RECOVERING  /  KEEP YOUR LINE SMOOTH"
		elif sim.impacts.since_hit<.55:
			status = sim.impacts.last_reason+"  /  IMPACT ABSORBED"
		else:
			status = "IMPACT  /  FIND A SMOOTH LINE"
		if reserve<=.30:
			tint = Color("ee8b83")
			status = "LOW IMPACT RESERVE  /  FIND SMOOTH SNOW"
	if sim.grounded and sim.rock_contact>0.0:
		impact_label.text = "ROCK  /  RESERVE %d%%" % roundi(reserve*100.0)
		status = "ROCK  /  RESERVE DRAINING — FIND SNOW" if sim.rock_wear_rate>0.0 else "ROCK  /  REDUCED GRIP"
		tint = Color("ee8b83") if reserve<=.30 else Color("efa773")
	if sim.crashed:
		status = sim.crash_reason
		tint = Color("ee8b83")
	impact_bar.value = reserve*100.0
	impact_bar.tint = tint
	impact_label.add_theme_color_override("font_color",tint)
	state_label.modulate = WHITE if reserve==1.0 and not sim.crashed else tint
	state_label.text = status
	mode_label.text = ("TIMED DESCENT" if timed else "FREE SKI") + ("  /  LAB VALUES" if not session.eligible else "  /  01")
	if not mountain_name.is_empty() and not session.race:
		mode_label.text = "FREE SKI  /  SEED %d" % mountain_seed_value
	if session.race and timed:
		mode_label.text = session.race.title.to_upper() + (" / UNRANKED" if not session.eligible else " / OPEN ROUTE")
		state_label.text = "%s  ·  FINISH %d m" % [status,sim.position.distance_to(session.race.finish)]
		if session.finished: state_label.text = "FINISH REACHED"
		menu_specs.text = "MOUNTAIN %d  /  OPEN ROUTE\n12 m FINISH RADIUS  /  NO CHECKPOINTS" % session.race.mountain.seed
	elif not mountain_name.is_empty():
		menu_specs.text = "MOUNTAIN SEED: %d\nFREE SKI / CREATE YOUR OWN RACES" % mountain_seed_value
	else:
		menu_specs.text = "1.55 km     /     600 m VERTICAL\nONE START. ONE FINISH. YOUR LINE."
	telemetry_timer += dt
	if telemetry_timer < 0.1:
		return
	telemetry_timer = 0.0
	fps_label.text = "%d FPS  /  120 Hz PHYSICS" % Engine.get_frames_per_second()
	debug_text.text = "SPEED         %7.2f km/h\nACCEL         %+7.2f m/s²\nSLOPE         %7.2f°\nSKI HEADING   %+7.2f°\nVEL HEADING   %+7.2f°\nSLIP ANGLE    %+7.2f°\nEDGE REQUEST  %+7.2f°\nEDGES R/L     %+5.1f / %+5.1f°\nCONTACT       %s\nNORMAL LOAD   %7.2f g\nFRICTION      %7.2f m/s²\nGRAVITY       %+7.2f m/s²\nIMPACT RESERVE%7.1f %%\nIMPACT SPEED  %7.2f m/s\nAIRTIME       %7.3f s\nCPU TICK      %7.3f ms\nFRAME         %7.2f ms\n%s" % [sim.speed_kmh(),sim.acceleration,sim.slope_angle,rad_to_deg(sim.heading),rad_to_deg(atan2(sim.velocity.x,sim.velocity.z)),rad_to_deg(sim.slip_angle),rad_to_deg(sim.edge_angle),rad_to_deg(sim.skis[0].edge_angle),rad_to_deg(sim.skis[1].edge_angle),("ROCK" if sim.rock_contact>.99 else ("MIXED" if sim.rock_contact>0.0 else "SNOW")) if sim.grounded else "AIR",sim.normal_load/9.81,sim.friction_force,sim.gravity_contribution,sim.impacts.reserve*100,sim.landing_force,sim.total_airtime,tick_ms,frame_ms,device.left(30)]

	debug_text.text += "\nYAW WANT/GET  %+5.1f / %+5.1f°/s\nSKID / TRANS  %5.0f / %5.0f %%\nCOM X / Z     %+.2f / %+.2f m" % [rad_to_deg(sim.steering_requested_yaw),rad_to_deg(sim.steering_applied_yaw),sim.steering_slip_factor*100,sim.steering_transfer_factor*100,sim.body.com.x,sim.body.com.z]

func toggle_instruments() -> void:
	for control in hud_controls:
		if control.has_meta("before_menu_background"):
			control.set_meta("before_menu_background",not bool(control.get_meta("before_menu_background")))
		else:
			control.visible = not control.visible

func build_skier_controls(appearance, persist: bool = true) -> void:
	appearance_column.add_child(_label("SKIER MATERIALS",11,LIME,true))
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
			appearance_column.add_child(control)
			var caption = _label("Glossy / matte" if property=="roughness" else "Metallic reflection",12,MUTED)
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
	var reset_button = _button("RESET SKIER MATERIALS")
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
	menu_specs.text = "MOUNTAIN SEED: %d\nFREE SKI / CREATE YOUR OWN RACES" % mountain_seed_value if mountain else "1.55 km     /     600 m VERTICAL\nONE START. ONE FINISH. YOUR LINE."
	if menu.visible: show_menu(menu_mode)
