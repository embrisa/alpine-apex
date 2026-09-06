extends CanvasLayer
signal start_requested(timed: bool)
signal restart_requested
signal resume_requested
signal lab_speed_requested(kmh: float)
signal tuning_changed
signal defaults_requested
signal workbench_closed
signal quit_requested
signal weather_preset_requested(id: String)
signal weather_auto_requested(enabled: bool)
signal weather_quality_requested(quality: int)
signal time_of_day_requested(id: String)
signal time_cycle_requested(enabled: bool)
signal graphics_quality_requested(level: int)
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
const INK = Color("102832")
const WHITE = Color("eef4f1")
const MUTED = Color("9eb4bf")
const LIME = Color("c2e76b")
var root = Control.new()
var menu: PanelContainer
var menu_title: Label
var menu_description: Label
var menu_specs: Label
var menu_location: Label
var mountain_name: String = ""
var mountain_seed_value: int = -1
var conditions: Label
var footer_controls: Label
const SKI_CONTROLS = "A D / ← → STEER   W TUCK   S BRAKE   SPACE HOP   R RESTART   C CAMERA   G GHOST   F2 TUNE   F3 TELEMETRY   F4 RACES   F6 HISTORY   ESC PAUSE"
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
var edge_bar: SlimBar
var telemetry_timer: float = 0.0
var menu_mode: String = "title"
var normal_font: SystemFont
var mono_font: SystemFont
var hud_controls: Array = []
var toast_label: Label
var toast_time: float = 0.0
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
	var value: float = 0.0:
		set(v):
			value = v
			queue_redraw()
	var max_value: float = 100.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(1,1,1,0.20))
		draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*clampf(value/max_value,0,1),size.y)),Color("c2e76b"))

func _ready() -> void:
	normal_font = SystemFont.new()
	normal_font.font_names = PackedStringArray(["Avenir Next", "Inter", "DejaVu Sans"])
	mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono"])
	var theme = Theme.new()
	theme.default_font = normal_font
	theme.default_font_size = 16
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_readability_gradients()
	_build_header()
	_build_instruments()
	_build_menu()
	_build_weather()
	_build_debug()
	competition.build(self)
	toast_label = _label("",20,LIME)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-280,137)
	toast_label.size = Vector2(560,36)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast_label)
	show_menu("title")

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

func _style(bg: Color, border: Color = Color(0.55,0.69,0.73,0.2), padding: int = 28) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(padding)
	style.set_corner_radius_all(3)
	return style

func _panel(parent: Control = root) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(Color(0.035,0.095,0.13,0.94)))
	parent.add_child(panel)
	return panel

func _button(text_value: String, main_button: bool = false) -> Button:
	var button = Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 50
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",17)
	button.add_theme_color_override("font_color",INK if main_button else WHITE)
	button.add_theme_color_override("font_hover_color",INK if main_button else WHITE)
	button.add_theme_color_override("font_focus_color",INK if main_button else WHITE)
	button.add_theme_color_override("font_pressed_color",INK)
	button.add_theme_stylebox_override("normal",_style(LIME if main_button else Color(0.2,0.3,0.35,0.4),Color.TRANSPARENT,14))
	button.add_theme_stylebox_override("hover",_style(Color("d8f291") if main_button else Color(0.25,0.38,0.44,0.9),LIME,14))
	button.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,LIME,14))
	button.add_theme_stylebox_override("pressed",_style(Color("d3ed93"),WHITE,14))
	return button

func _build_header() -> void:
	var brand = _label("▲  ALPINE APEX",25,WHITE)
	brand.position = Vector2(42,29)
	root.add_child(brand)
	var subtitle = _label("D O W N H I L L   /   N O   C O M P R O M I S E",10,Color("c5d8df"))
	subtitle.position = Vector2(44,65)
	root.add_child(subtitle)
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
	var footer = PanelContainer.new()
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
	edge_bar = SlimBar.new()
	edge_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	edge_bar.position = Vector2(-85,-73)
	edge_bar.size = Vector2(170,3)
	edge_bar.add_theme_font_size_override("font_size",1)
	edge_bar.add_theme_stylebox_override("background",_style(Color(1,1,1,0.2),Color.TRANSPARENT,0))
	edge_bar.add_theme_stylebox_override("fill",_style(LIME,Color.TRANSPARENT,0))
	root.add_child(edge_bar)
	hud_controls.append(edge_bar)
	var balance_label = _label("B A L A N C E",9,MUTED)
	balance_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	balance_label.position = Vector2(-85,-92)
	balance_label.size.x = 170
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(balance_label)
	hud_controls.append(balance_label)

func _build_menu() -> void:
	menu = _panel()
	menu.position = Vector2(44,145)
	menu.custom_minimum_size = Vector2(435,470)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",11)
	menu.add_child(column)
	menu_location = _label("01  /  THE TEST FACE",11,LIME,true)
	column.add_child(menu_location)
	menu_title = _label("THE FALL\nLINE.",59,WHITE)
	menu_title.add_theme_constant_override("line_spacing",-10)
	column.add_child(menu_title)
	menu_description = _label("A clean line is a fast line.\nMake every edge count.",17,MUTED)
	column.add_child(menu_description)
	menu_specs = _label("1.55 km     /     600 m VERTICAL\nONE START. ONE FINISH. YOUR LINE.",11,WHITE,true)
	menu_specs.add_theme_constant_override("line_spacing",6)
	column.add_child(menu_specs)
	primary = _button("DROP IN                         ↗",true)
	primary.pressed.connect(_primary_pressed)
	column.add_child(primary)
	secondary = _button("Free ski")
	secondary.pressed.connect(func(): start_requested.emit(false))
	var options = HBoxContainer.new()
	column.add_child(options)
	secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_child(secondary)
	weather_button = _button("Visual settings")
	weather_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weather_button.pressed.connect(func():
		menu.visible = false
		weather_panel.visible = true
		weather_preset.grab_focus()
	)
	options.add_child(weather_button)
	var mountains_button = _button("GENERATE / SAVED MOUNTAINS")
	mountains_button.custom_minimum_size.y = 40
	mountains_button.pressed.connect(func(): mountains_requested.emit())
	column.add_child(mountains_button)
	var races_button = _button("CREATE / SHARED RACES")
	races_button.custom_minimum_size.y = 40
	races_button.pressed.connect(func(): races_requested.emit())
	column.add_child(races_button)
	records_button = _button("PERSONAL BEST / RUN HISTORY")
	records_button.custom_minimum_size.y = 40
	records_button.pressed.connect(func(): competition_requested.emit())
	column.add_child(records_button)
	column.add_child(_label("ENTER / ×  DROP IN     ·     R / △  RESTART",10,MUTED,true))

func _build_weather() -> void:
	weather_panel = _panel()
	weather_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	weather_panel.offset_left = -240
	weather_panel.offset_right = 240
	weather_panel.offset_top = -350
	weather_panel.offset_bottom = 350
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation",10)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	weather_panel.add_child(scroll)
	scroll.add_child(col)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_label("VISUAL SETTINGS",24,WHITE))
	col.add_child(_label("Set the mood for your descent.",14,MUTED))
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
	col.add_child(_label("GRAPHICS QUALITY",11,LIME,true))
	graphics_quality = OptionButton.new()
	for label in ["Low","Balanced","High"]:
		graphics_quality.add_item(label)
	graphics_quality.custom_minimum_size.y = 42
	graphics_quality.item_selected.connect(func(index): graphics_quality_requested.emit(index))
	col.add_child(graphics_quality)
	appearance_column = VBoxContainer.new()
	col.add_child(appearance_column)
	col.add_child(_label("V  motion effects    ·    M  mute audio",12,MUTED,true))
	var close = _button("BACK / ESC",true)
	close.pressed.connect(close_weather)
	col.add_child(close)
	weather_panel.visible = false

func sync_weather(controller) -> void:
	weather_preset.select(WEATHER_IDS.find(controller.selected_preset))
	weather_auto.set_pressed_no_signal(controller.automatic)
	weather_quality.select(controller.quality)
	time_of_day.select(TIME_IDS.find(controller.daylight.label().to_lower()))
	time_cycle.set_pressed_no_signal(controller.daylight.automatic)

func close_weather() -> void:
	weather_panel.visible = false
	menu.visible = true
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
	weather_button.visible = kind in ["title","paused"]
	secondary.visible = kind == "title"
	match kind:
		"title":
			menu_title.text = "THE FALL\nLINE."
			menu_description.text = "A clean line is a fast line.\nMake every edge count."
			primary.text = "DROP IN                         ↗"
		"paused":
			menu_title.text = "TAKE A\nBREATH."
			menu_description.text = "Your line is waiting.\nF2 opens the physics workbench."
			primary.text = "RESUME                         ↗"
		"crashed":
			menu_title.text = "ON THE\nEDGE."
			menu_description.text = detail + "\nOne key. Another attempt."
			primary.text = "TRY AGAIN                      ↗"
		"finished":
			menu_title.text = "LINE\nCOMPLETE."
			menu_description.text = detail
			primary.text = "FIND ANOTHER SECOND             ↗"
	if kind=="title" and not mountain_name.is_empty():
		menu_title.text = "YOUR\nMOUNTAIN."
		menu_description.text = "Read the terrain. Pick your descent."
		primary.text = "EXPLORE MOUNTAIN               ↗"
	primary.grab_focus()

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
	competition.panel.visible = false
	menu.visible = true
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
	debug_panel.offset_bottom = 520
	debug_panel.custom_minimum_size = Vector2(342,370)
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
	tuning_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tuning_panel.offset_left = -265
	tuning_panel.offset_right = 265
	tuning_panel.offset_top = -365
	tuning_panel.offset_bottom = 365
	tuning_panel.custom_minimum_size = Vector2(530,655)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation",11)
	tuning_panel.add_child(col)
	col.add_child(_label("PHYSICS WORKBENCH",23,WHITE))
	col.add_child(_label("Live values · modified runs do not set personal bests",12,MUTED))
	for setting in [
		["Gravity", "gravity_multiplier",0.4,1.6,0.05],
		["Ski friction", "ski_friction",0.005,0.10,0.001],
		["Edge grip", "edge_grip",0.3,3.0,0.1],
		["Carving response", "carving_strength",2.0,18.0,0.5],
		["Skid drag", "skidding_friction",0.0,1.5,0.05],
		["Air drag", "aerodynamic_drag",0.001,0.010,0.0002],
		["Steering", "steering_sensitivity",0.4,2.5,0.05],
		["Landing tolerance", "landing_tolerance",5.0,16.0,0.5],
		["Camera response", "camera_response",3.0,16.0,0.5],
		["Vibration", "vibration_intensity",0.0,1.0,0.1]
	]:
		var row = HBoxContainer.new()
		var label = _label(setting[0],12,WHITE)
		label.custom_minimum_size.x = 138
		row.add_child(label)
		var slider = HSlider.new()
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
			if setting[1] not in ["camera_response","vibration_intensity"]:
				tuning_changed.emit()
		)
		col.add_child(row)
	col.add_child(_label("SPEED LAB  /  START AT A KNOWN VELOCITY",11,LIME,true))
	var buttons = HBoxContainer.new()
	for speed in [30,60,90,120,150,165,200]:
		var button = _button(str(speed))
		button.add_theme_font_size_override("font_size",13)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 38
		button.pressed.connect(func(): lab_speed_requested.emit(float(speed)))
		buttons.add_child(button)
	col.add_child(buttons)
	var defaults = _button("Restore defaults & restart")
	defaults.custom_minimum_size.y = 35
	defaults.pressed.connect(restore_defaults)
	col.add_child(defaults)
	col.add_child(_label("Keyboard: A/D steer · W tuck · S brake · Space hop\nGamepad: left stick · R2 tuck · L2 brake · × hop\n△ restart · R1 camera · Options pause · Share telemetry\nV motion effects · M mute · H instruments · F2 close",12,MUTED))
	var close = _button("CLOSE WORKBENCH / F2",true)
	close.pressed.connect(func(): workbench_closed.emit())
	col.add_child(close)
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
	edge_bar.value = sim.balance * 100.0
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
	elif intent.brake > 0.1:
		status = "BRAKING"
	elif absf(rad_to_deg(sim.slip_angle)) > 12.0:
		status = "SKIDDING / MOMENTUM LOSS"
	elif maxf(absf(sim.skis[0].edge_angle),absf(sim.skis[1].edge_angle)) > 0.12:
		status = "CARVING"
	if sim.balance<0.70 and sim.grounded:
		status = "LOSING EDGE  /  EASE THE TURN"
	state_label.modulate = Color("efa773") if sim.balance<0.70 else WHITE
	if sim.crashed:
		status = sim.crash_reason
	state_label.text = status
	mode_label.text = ("TIMED DESCENT" if timed else "FREE SKI") + ("  /  LAB VALUES" if not session.eligible else "  /  01")
	if not mountain_name.is_empty() and not session.race:
		mode_label.text = "FREE SKI  /  SEED %d" % mountain_seed_value
	if session.race and timed:
		mode_label.text = session.race.title.to_upper() + (" / UNRANKED" if not session.eligible else " / OPEN ROUTE")
		state_label.text = "%s  ·  FINISH %d m" % [status,sim.position.distance_to(session.race.finish)]
		if session.finished: state_label.text = "FINISH REACHED"
		menu_specs.text = "MOUNTAIN %d  /  OPEN ROUTE\n12 m FINISH RADIUS  /  NO CHECKPOINTS" % session.race.mountain.seed
	else:
		menu_specs.text = "1.55 km     /     600 m VERTICAL\nONE START. ONE FINISH. YOUR LINE."
	telemetry_timer += dt
	if telemetry_timer < 0.1:
		return
	telemetry_timer = 0.0
	fps_label.text = "%d FPS  /  120 Hz PHYSICS" % Engine.get_frames_per_second()
	debug_text.text = "SPEED         %7.2f km/h\nACCEL         %+7.2f m/s²\nSLOPE         %7.2f°\nSKI HEADING   %+7.2f°\nVEL HEADING   %+7.2f°\nSLIP ANGLE    %+7.2f°\nEDGE REQUEST  %+7.2f°\nEDGES R/L     %+5.1f / %+5.1f°\nCONTACT       %s\nNORMAL LOAD   %7.2f g\nFRICTION      %7.2f m/s²\nGRAVITY       %+7.2f m/s²\nBALANCE       %7.1f %%\nAIRTIME       %7.3f s\nCPU TICK      %7.3f ms\nFRAME         %7.2f ms\n%s" % [sim.speed_kmh(),sim.acceleration,sim.slope_angle,rad_to_deg(sim.heading),rad_to_deg(atan2(sim.velocity.x,sim.velocity.z)),rad_to_deg(sim.slip_angle),rad_to_deg(sim.edge_angle),rad_to_deg(sim.skis[0].edge_angle),rad_to_deg(sim.skis[1].edge_angle),"SNOW" if sim.grounded else "AIR",sim.normal_load/9.81,sim.friction_force,sim.gravity_contribution,sim.balance*100,sim.total_airtime,tick_ms,frame_ms,device.left(30)]

func toggle_instruments() -> void:
	for control in hud_controls:
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
