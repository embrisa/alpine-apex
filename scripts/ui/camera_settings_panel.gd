extends RefCounted
## Camera menu and preview drawer share controls and edit only local preferences.
const Settings = preload("res://scripts/presentation/camera_settings.gd")
const SpeedCurve = preload("res://scripts/ui/camera_speed_curve.gd")
var hud
var state
var view = "chase"
var controls: Dictionary = {}
var readouts: Dictionary = {}
var fields: Dictionary = {}
var groups: Dictionary = {}
var view_selector: OptionButton
var preset_selector: OptionButton
var name_input: LineEdit
var preset_target = ""
var preset_status: Label
var preview_button: Button
var preview_speed: HSlider
var curve
var curve_readout: Label
var reset_all: Button
var preview_active = false
var preview_collapsed = false
var preview_toolbar: HBoxContainer
var collapse_button: Button
var resume_button: Button
var preview_supported = false
var saved_offsets = Vector4.ZERO
var hidden_shell_controls: Array[Control] = []
var can_resume = false

func build(col: VBoxContainer, owner_hud) -> void:
	hud = owner_hud
	var selectors = HBoxContainer.new()
	col.add_child(selectors)
	view_selector = OptionButton.new()
	view_selector.name = "CameraView"
	for label in ["Third person","First person"]: view_selector.add_item(label)
	selectors.add_child(view_selector)
	view_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_selector.item_selected.connect(func(index):
		view = Settings.VIEWS[index]
		preset_target = ""
		if state: sync(state)
	)
	preset_selector = OptionButton.new()
	preset_selector.name = "CameraPreset"
	selectors.add_child(preset_selector)
	preset_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_selector.item_selected.connect(func(index):
		preset_target = preset_selector.get_item_text(index)
		name_input.text = preset_target if preset_target not in Settings.BUILT_INS else ""
		hud.camera_preset_requested.emit("apply",view,preset_target,"")
	)
	hud._note(col,"Connected stays close. Race opens the view. Stable keeps framing fixed and removes optional motion.")
	preview_button = hud._button("PREVIEW CAMERA")
	preview_button.pressed.connect(func(): hud.camera_preview_requested.emit(true))
	col.add_child(preview_button)
	var speed_group = _group(col,"Preview speed")
	preview_speed = HSlider.new()
	preview_speed.name = "PreviewSpeed"
	preview_speed.max_value = 300
	preview_speed.step = 1
	preview_speed.custom_minimum_size.y = 34
	speed_group.add_child(preview_speed)
	curve = SpeedCurve.new()
	speed_group.add_child(curve)
	curve_readout = hud._label("",14,hud.WHITE)
	curve_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speed_group.add_child(curve_readout)
	hud._note(speed_group,"Stationary framing only. Resume skiing to judge motion and speed feel.")
	preview_speed.value_changed.connect(func(_value): _sync_curve())
	var framing = _group(col,"Framing")
	for item in [["rest_fov","FoV at rest"],["fast_fov","FoV at full-effect speed"],["rest_tilt","Tilt at rest"],["fast_tilt","Tilt at full-effect speed"],["rest_distance","Distance at rest"],["fast_distance","Distance at full-effect speed"],["rest_height","Height at rest"],["fast_height","Height at full-effect speed"],["eye_height","Eye height"],["tuck_lowering","Full-strength tuck lowering"]]:
		_slider(framing,item[0],item[1])
	hud._note(framing,"FoV is vertical. Negative tilt looks down; positive looks up. With slope following, tilt is your aim on a 15° descent; flat and uphill ground lift the view. Terrain clearance takes priority.")
	var response = _group(col,"Speed response")
	for item in [["speed_start","Start changing at"],["speed_full","Full effect at"],["speed_exponent","Curve · early to delayed"],["acceleration_time","Acceleration smoothing"],["deceleration_time","Deceleration smoothing"]]: _slider(response,item[0],item[1])
	hud._note(response,"Set matching rest and fast values for fixed framing. V uses resting framing and disables motion effects.")
	var follow = _group(col,"Follow and stability")
	for item in [["vertical_smoothing","Vertical smoothing"],["boom_response","Boom response"],["heading_response","Heading response"]]: _slider(follow,item[0],item[1])
	_slider(follow,"slope_follow","Slope following")
	_slider(follow,"slope_smoothing","Slope smoothing")
	hud._note(follow,"Follow broad slope changes while filtering small bumps. 0% keeps fixed world tilt. Slope following stays active with V; jumps hold the takeoff angle.")
	var motion = _group(col,"Motion effects")
	for item in [["carve_strength","Carve pull-in"],["tuck_strength","Tuck movement"],["compression_strength","Load and landing movement"],["bank_strength","Bank into turns"],["chatter_strength","Roll chatter"],["blur_strength","Peripheral blur"],["streak_strength","Speed streaks"]]: _slider(motion,item[0],item[1])
	hud._note(motion,"0% disables an effect; 100% uses its full existing strength. Camera pitch stays steady over bumps.")
	var look = _group(col,"Look controls · both views")
	for item in [["mouse_sensitivity","Mouse sensitivity"],["stick_yaw_speed","Stick horizontal speed"],["stick_pitch_speed","Stick vertical speed"],["stick_deadzone","Stick deadzone"],["stick_exponent","Stick response curve"],["recenter_delay","Automatic recenter delay"],["recenter_time","Recenter smoothing"]]: _slider(look,item[0],item[1])
	for item in [["invert_y","Invert vertical look"],["auto_recenter","Automatically recenter while moving"]]:
		var toggle = CheckButton.new()
		toggle.text = item[1]
		toggle.name = item[0]
		look.add_child(toggle)
		controls[item[0]] = toggle
		var key: String = item[0]
		toggle.toggled.connect(func(enabled): hud.camera_setting_requested.emit("shared",key,enabled))
	var forest = _group(col,"Forest visibility · both views")
	_slider(forest,"forest_visibility_strength","Transparency strength")
	_slider(forest,"forest_visibility","Aid reach")
	hud._note(forest,"Strength reveals more through nearby canopy across the whole screen. Reach sets the affected distance. Either at 0% turns the aid off. Trunks remain visible.")
	var saved = _group(col,"Named presets")
	name_input = LineEdit.new()
	name_input.placeholder_text = "Preset name"
	name_input.max_length = 40
	name_input.custom_minimum_size.y = 38
	saved.add_child(name_input)
	var actions = GridContainer.new()
	actions.columns = 2
	saved.add_child(actions)
	for item in [["save","SAVE NEW"],["replace","REPLACE"],["rename","RENAME"],["delete","DELETE"]]:
		var button = hud._button(item[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
		var action: String = item[0]
		button.pressed.connect(func():
			var name = name_input.text.strip_edges()
			hud.camera_preset_requested.emit(action,view,preset_target if action in ["rename","delete"] else name,name if action=="rename" else "")
		)
	preset_status = hud._label("Saved presets change only when you save or replace them.",14,hud.MUTED)
	preset_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	saved.add_child(preset_status)
	var reset_view_button = hud._button("RESET CURRENT VIEW")
	reset_view_button.pressed.connect(func(): hud.camera_defaults_requested.emit(view))
	col.add_child(reset_view_button)
	reset_all = hud._button("RESET ALL CAMERA SETTINGS")
	reset_all.pressed.connect(func(): hud.camera_defaults_requested.emit("all"))
	col.add_child(reset_all)
	hud._note(col,"Working changes save automatically. Reset keeps your named presets. Look and forest preferences are shared and unaffected by presets.")
	_build_toolbar()

func _group(parent: Control, title: String, expanded: bool = false) -> VBoxContainer:
	var toggle = hud._button(title.to_upper())
	toggle.toggle_mode = true
	toggle.button_pressed = expanded
	parent.add_child(toggle)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation",12)
	parent.add_child(content)
	content.visible = expanded
	toggle.set_meta("group_body",content)
	toggle.toggled.connect(func(enabled):
		var focus = content.get_viewport().gui_get_focus_owner()
		if not enabled and focus and content.is_ancestor_of(focus): toggle.grab_focus()
		content.visible = enabled
	)
	groups[title] = {"button":toggle,"content":content}
	return content

func _slider(parent: Control, key: String, caption: String) -> void:
	var field = hud._settings_field(parent,caption)
	fields[key] = field
	var row = HBoxContainer.new()
	field.add_child(row)
	var slider = HSlider.new()
	slider.name = key
	var bounds: Vector3 = Settings.RANGES[key]
	slider.min_value = bounds.x
	slider.max_value = bounds.y
	slider.step = bounds.z
	slider.value = Settings.DEFAULTS.get(key,Settings.SHARED_DEFAULTS.get(key,0))
	slider.custom_minimum_size = Vector2(90,34)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var readout = hud._label("",15,hud.WHITE,true)
	readout.custom_minimum_size.x = 90
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	controls[key] = slider
	readouts[key] = readout
	slider.value_changed.connect(func(item):
		hud.camera_setting_requested.emit("shared" if key in Settings.SHARED_DEFAULTS else view,key,item)
	)

static func readout(key: String, item: float) -> String:
	if key.ends_with("fov"): return "%d°" % roundi(item)
	if key.ends_with("tilt"): return ("%+d°" if item>0 else "%d°") % roundi(item)
	if key in ["speed_start","speed_full"]: return "%d km/h" % roundi(item)
	if key in ["acceleration_time","deceleration_time","recenter_delay","recenter_time","slope_smoothing"]: return "%.2f s" % item
	if key.ends_with("_strength") or key in ["vertical_smoothing","slope_follow","forest_visibility"]: return "%d%%" % roundi(item)
	if key in ["stick_yaw_speed","stick_pitch_speed"]: return "%d°/s" % roundi(item)
	if key=="mouse_sensitivity": return "%.2f°/px" % item
	if key.ends_with("_response"): return "%.1f /s" % item
	if key in ["stick_deadzone","stick_exponent","speed_exponent"]: return "%.2f" % item
	return "%.2f m" % item

func sync(settings) -> void:
	state = settings
	view_selector.select(Settings.VIEWS.find(view))
	for key in controls:
		var item = state.value("shared" if key in Settings.SHARED_DEFAULTS else view,key)
		if item is bool: controls[key].set_pressed_no_signal(item)
		else:
			controls[key].set_value_no_signal(item)
			readouts[key].text = readout(key,item)
	for key in ["rest_distance","fast_distance","rest_height","fast_height","carve_strength"]:
		fields[key].visible = view=="chase"
	for key in ["eye_height","tuck_lowering"]: fields[key].visible = view=="first_person"
	preset_selector.clear()
	var names: Array = Settings.BUILT_INS.duplicate()
	var saved_names: Array = state.presets[view].keys()
	saved_names.sort()
	names.append_array(saved_names)
	names.append("Custom")
	for name in names: preset_selector.add_item(name)
	preset_selector.set_item_disabled(names.size()-1,true)
	preset_selector.select(names.find(state.selected[view]))
	if state.selected[view]!="Custom":
		preset_target = state.selected[view]
		if not name_input.has_focus(): name_input.text = preset_target if preset_target not in Settings.BUILT_INS else ""
	preset_status.text = "Selected: %s. Save or replace to keep a named copy." % state.selected[view]
	_sync_curve()

func _sync_curve() -> void:
	if not state: return
	curve.configure(state.profile(view),preview_speed.value)
	var framing: Vector4 = state.framing(view,preview_speed.value)
	curve_readout.text = "Preview %d km/h · %.0f%% of transition · %.1f° FoV\nFull effect at %d km/h" % [preview_speed.value,Settings.speed_factor(preview_speed.value,state.profile(view))*100.0,framing.x,state.profile(view).speed_full]

func _build_toolbar() -> void:
	preview_toolbar = HBoxContainer.new()
	preview_toolbar.name = "CameraPreviewToolbar"
	preview_toolbar.position = Vector2(24,20)
	hud.root.add_child(preview_toolbar)
	hud.register_menu_background(preview_toolbar)
	collapse_button = hud._button("HIDE CONTROLS")
	collapse_button.pressed.connect(func():
		preview_collapsed = not preview_collapsed
		hud.weather_panel.visible = not preview_collapsed
		collapse_button.text = "SHOW CONTROLS" if preview_collapsed else "HIDE CONTROLS"
	)
	preview_toolbar.add_child(collapse_button)
	var exit_button = hud._button("EXIT PREVIEW")
	exit_button.pressed.connect(func(): hud.camera_preview_requested.emit(false))
	preview_toolbar.add_child(exit_button)
	resume_button = hud._button("RESUME SKIING")
	resume_button.pressed.connect(func():
		hud.camera_preview_requested.emit(false)
		hud.close_weather()
		hud.resume_requested.emit()
	)
	preview_toolbar.add_child(resume_button)
	preview_toolbar.hide()

func set_preview_available(available: bool, resumable: bool) -> void:
	preview_supported = available
	can_resume = resumable
	preview_button.disabled = not available
	preview_button.tooltip_text = "" if available else "Preview needs a loaded, non-crashed rider."
	resume_button.visible = resumable

func set_preview(enabled: bool, speed: float = 0.0) -> void:
	if enabled==preview_active: return
	preview_active = enabled
	var panel: Control = hud.weather_panel
	var shell: Control = panel.get_child(0)
	if enabled:
		saved_offsets = Vector4(panel.offset_left,panel.offset_top,panel.offset_right,panel.offset_bottom)
		panel.anchor_left = 0
		panel.anchor_right = 0
		panel.offset_left = 24
		panel.offset_right = 460
		panel.offset_top = 86
		for child in shell.get_children():
			if child!=hud.settings_tabs.row and child is Control and child.visible:
				hidden_shell_controls.append(child)
				child.hide()
		hud.settings_tabs.rail.get_parent().hide()
		panel.set_meta("preview_layout",true)
		preview_speed.value = clampf(speed,0,300)
		preview_toolbar.show()
		preview_button.hide()
	else:
		panel.anchor_left = 0.5
		panel.anchor_right = 0.5
		panel.offset_left = saved_offsets.x
		panel.offset_top = saved_offsets.y
		panel.offset_right = saved_offsets.z
		panel.offset_bottom = saved_offsets.w
		for child in hidden_shell_controls: child.show()
		hidden_shell_controls.clear()
		hud.settings_tabs.rail.get_parent().show()
		panel.set_meta("preview_layout",false)
		hud.shell_layout.frame(panel)
		panel.show()
		preview_toolbar.hide()
		preview_button.show()
	preview_collapsed = false
	collapse_button.text = "HIDE CONTROLS"
	hud._sync_menu_backdrop()

func camera_tab_visible() -> bool:
	var page = hud.settings_tabs.get_current_tab_control()
	return page!=null and page.name=="Camera"
