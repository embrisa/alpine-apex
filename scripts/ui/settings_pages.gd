extends RefCounted
const Presets = preload("res://scripts/presentation/graphics_presets.gd")
const Shell = preload("res://scripts/ui/screen_shell.gd")
var hud
var output_draft: Dictionary = {}
var output_dirty = false
var output_controls: Dictionary = {}
var graphics_controls: Dictionary = {}
var custom_label: Label
var display_status: Label
var display_apply: Button
var recovery: ConfirmationDialog
var apply_timer: Timer
var changes: Dictionary = {}
var groups: Dictionary = {}

func build(owner_hud) -> void:
	hud = owner_hud
	hud.weather_panel = hud._panel()
	hud.weather_panel.name = "SettingsWindow"
	var shell = hud._window(hud.weather_panel)
	shell.add_child(hud._label("Settings",30,hud.WHITE))
	hud.settings_tabs = hud._tabs(shell)
	var pages = {}
	for caption in ["Display","Graphics","Camera","Controls","Audio","Interface & HUD","Weather","Rider"]:
		pages[caption] = hud._tab(hud.settings_tabs,caption)
	_display(pages.Display)
	_graphics(pages.Graphics)
	hud._build_camera_settings(pages.Camera)
	_controls(pages.Controls)
	_audio(pages.Audio)
	_interface(pages["Interface & HUD"])
	_weather(pages.Weather)
	hud.appearance_column = pages.Rider
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation",16)
	shell.add_child(actions)
	var close = hud._button("Back")
	close.custom_minimum_size.x = 180
	close.pressed.connect(hud.close_weather)
	actions.add_child(close)
	var space = Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(space)
	actions.add_child(display_apply)
	hud.settings_tabs.tab_changed.connect(func(index): display_apply.visible = index==0)
	hud.weather_panel.hide()
	apply_timer = Timer.new()
	apply_timer.one_shot = true
	apply_timer.wait_time = .20
	hud.add_child(apply_timer)
	apply_timer.timeout.connect(flush_changes)

func _display(col: Control) -> void:
	_output_option(col,"display_mode","Window mode",["Fullscreen","Windowed"],["fullscreen","windowed"])
	_output_option(col,"resolution","Windowed resolution",["Automatic window size"],[Vector2i.ZERO])
	hud._display_option(col,"fps_limit",["120 FPS","90 FPS","60 FPS","144 FPS","165 FPS","240 FPS","Uncapped"],[120,90,60,144,165,240,0])
	var advanced = Shell.group(col,"Monitor & synchronization",hud)
	var names = ["Current monitor"]
	var values = [-1]
	for i in DisplayServer.get_screen_count():
		names.append("Monitor %d · %d Hz" % [i+1,roundi(DisplayServer.screen_get_refresh_rate(i))]); values.append(i)
	_output_option(advanced,"monitor","Monitor",names,values)
	_output_option(advanced,"vsync","Synchronization",["Off","On","Adaptive","Mailbox"],[0,1,2,3])
	display_status = hud._note(col,"Output changes require confirmation within 15 seconds.")
	display_apply = hud._button("Apply display changes",true)
	display_apply.custom_minimum_size.x = 275
	display_apply.pressed.connect(func(): hud.display_preview_requested.emit(output_draft.duplicate(true)))
	recovery = ConfirmationDialog.new()
	recovery.name = "DisplayRecovery"
	recovery.title = "Keep display settings?"
	recovery.ok_button_text = "Keep"
	recovery.cancel_button_text = "Revert"
	recovery.confirmed.connect(func(): hud.display_keep_requested.emit())
	recovery.canceled.connect(func(): hud.display_revert_requested.emit())
	hud.root.add_child(recovery)

func _output_option(parent: Control, key: String, caption: String, labels: Array, values: Array) -> void:
	var field = hud._settings_field(parent,caption)
	var button = OptionButton.new()
	button.custom_minimum_size.y = 44
	for label in labels: button.add_item(label)
	button.set_meta("values",values)
	button.item_selected.connect(func(index):
		output_draft[key] = button.get_meta("values")[index]
		output_dirty = true
		if key in ["display_mode","monitor"]: _sync_output_choices()
	)
	field.add_child(button)
	output_controls[key] = button

func _graphics(col: Control) -> void:
	col.add_child(hud._label("Graphics preset",20,hud.WHITE))
	hud.graphics_quality = OptionButton.new()
	hud.graphics_quality.custom_minimum_size.y = 50
	for id in range(1,11): hud.graphics_quality.add_item(Presets.title(id),id)
	hud.graphics_quality.item_selected.connect(func(index):
		changes.clear()
		apply_timer.stop()
		hud.graphics_quality_requested.emit(index+1)
	)
	col.add_child(hud.graphics_quality)
	custom_label = hud._note(col,"7 · High · Recommended")
	hud._note(col,"Higher presets add visual detail and cost. Ultra may run below 90 rendered FPS.")
	var reapply = hud._button("Reapply preset")
	reapply.pressed.connect(func():
		changes.clear(); apply_timer.stop()
		hud.graphics_quality_requested.emit(hud.graphics_quality.selected+1)
	)
	col.add_child(reapply)
	var rendering = Shell.group(col,"Rendering & reconstruction",hud)
	hud._display_option(rendering,"upscaler",["Auto · best supported","FSR 4.1","FSR 3.1","FSR 2","Native"],["auto","fsr4","fsr3","fsr2","native"])
	_slider(rendering,"render_scale","Internal resolution (%)",2.0/3.0,1.0,.01,100.0)
	hud.display_controls.render_scale = graphics_controls.render_scale
	_slider(rendering,"sharpness","Sharpening strength (0 Off / 1 Full)",0.0,1.0,.005)
	hud._display_option(rendering,"msaa",["MSAA off","MSAA 2×","MSAA 4×","MSAA 8×"],[0,1,2,3])
	hud._display_option(rendering,"anisotropic",["Disabled","2×","4×","8×","16×"],[0,1,2,3,4])
	var framegen = CheckButton.new()
	framegen.text = "Frame generation"
	framegen.toggled.connect(func(value): hud.display_setting_requested.emit("frame_generation",value))
	rendering.add_child(framegen)
	hud.display_controls.frame_generation = framegen
	var reset_rendering = hud._button("Reset rendering & reconstruction")
	reset_rendering.pressed.connect(func():
		flush_changes()
		hud.graphics_group_reset_requested.emit("Rendering & reconstruction")
	)
	rendering.add_child(reset_rendering)
	hud.fidelityfx_status_label = hud._note(col,"")
	var timer = Timer.new()
	timer.wait_time = 1.0; timer.autostart = true
	hud.add_child(timer)
	timer.timeout.connect(func():
		if hud.weather_panel.visible: hud._sync_fidelityfx_choices()
	)
	for key in Presets.CONTROLS:
		var spec: Array = Presets.CONTROLS[key]
		if not groups.has(spec[1]):
			groups[spec[1]] = Shell.group(col,spec[1],hud)
			var fields = preload("res://scripts/ui/settings_grid.gd").new()
			groups[spec[1]].add_child(fields)
			groups[spec[1]].set_meta("fields",fields)
		var parent: Control = groups[spec[1]].get_meta("fields")
		if spec[2] is bool:
			var control = CheckButton.new()
			control.text = spec[0]
			control.toggled.connect(func(value): queue_change(key,value))
			parent.add_child(control)
			graphics_controls[key] = control
			if key=="terrain_gi": hud.display_controls.terrain_gi = control
		elif key in ["texture_tier","backdrop_tier","weather_quality","shadow_quality"]:
			var field = hud._settings_field(parent,spec[0])
			var option = OptionButton.new()
			for label in (["Off","Low","High"] if key=="weather_quality" else ["Hard","Soft · low","Soft · medium","Soft · high","Soft · ultra","Soft · maximum"] if key=="shadow_quality" else ["Low","Balanced","High"]): option.add_item(label)
			option.item_selected.connect(func(index): queue_change(key,index))
			field.add_child(option)
			graphics_controls[key] = option
			if key=="weather_quality": hud.weather_quality = option
		else: _slider(parent,key,spec[0],spec[2],spec[3],spec[4])
	for group_name in groups:
		var reset = hud._button("Reset "+group_name.to_lower())
		groups[group_name].add_child(reset)
		reset.pressed.connect(func():
			flush_changes()
			hud.graphics_group_reset_requested.emit(group_name)
		)

func _slider(parent: Control, key: String, caption: String, minimum: float, maximum: float, step: float, multiplier: float = 1.0) -> void:
	var field = hud._settings_field(parent,caption)
	var row = HBoxContainer.new()
	field.add_child(row)
	var slider = HSlider.new()
	slider.name = key
	slider.min_value = minimum; slider.max_value = maximum; slider.step = step
	slider.custom_minimum_size = Vector2(120,36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var label = hud._label("",16,hud.LIME,true)
	label.custom_minimum_size.x = 90
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)
	slider.value_changed.connect(func(value):
		label.text = str(snappedf(value*multiplier,.001 if key=="sharpness" else .01))
		queue_change(key,int(value) if Presets.CONTROLS.has(key) and Presets.CONTROLS[key][2] is int else value)
	)
	slider.set_meta("readout",label)
	slider.set_meta("multiplier",multiplier)
	slider.drag_ended.connect(func(_changed): flush_changes())
	graphics_controls[key] = slider

func queue_change(key: String, value: Variant) -> void:
	changes[key] = value
	apply_timer.start()
	hud.feedback.play("adjust")

func flush_changes() -> void:
	if changes.is_empty(): return
	var values = changes.duplicate(true)
	changes.clear()
	apply_timer.stop()
	hud.graphics_values_requested.emit(values)

func sync(settings) -> void:
	if not output_dirty: output_draft = settings.display.snapshot()
	_sync_output_choices()
	hud.graphics_quality.select(settings.quality-1)
	custom_label.text = "Custom · based on "+Presets.title(settings.quality)
	custom_label.visible = settings.custom
	var profile = settings.profile()
	for key in graphics_controls:
		var control = graphics_controls[key]
		var value = profile.get(key) if Presets.CONTROLS.has(key) else settings.get(key)
		if control is CheckButton: control.set_pressed_no_signal(value)
		elif control is OptionButton: control.select(value)
		else:
			control.set_value_no_signal(value)
			control.get_meta("readout").text = str(snappedf(value*control.get_meta("multiplier"),.001 if key=="sharpness" else .01))
	graphics_controls.render_scale.editable = settings.upscaler!="native"
	var temporal: bool = settings.upscaler!="native" or (settings.frame_generation and settings.has_native_fsr())
	graphics_controls.sharpness.editable = temporal
	hud.display_controls.msaa.disabled = temporal

func _sync_output_choices() -> void:
	var draft = preload("res://scripts/presentation/display_settings.gd").new()
	draft.restore(output_draft)
	var sizes = draft.choices(hud.get_window())
	var resolution: OptionButton = output_controls.resolution
	resolution.clear()
	for pixels in sizes:
		resolution.add_item(("Native display" if draft.display_mode=="fullscreen" else "Automatic window size") if pixels==Vector2i.ZERO else "%d × %d" % [pixels.x,pixels.y])
	resolution.set_meta("values",sizes)
	resolution.disabled = draft.display_mode=="fullscreen"
	for key in output_controls:
		var control = output_controls[key]
		control.select(maxi(0,control.get_meta("values").find(draft.get(key))))

func _weather(col: Control) -> void:
	col.add_child(hud._label("Conditions",20,hud.WHITE))
	hud.weather_preset = OptionButton.new()
	for label in ["Clear","Cloudy","Snowfall","Rain"]: hud.weather_preset.add_item(label)
	hud.weather_preset.item_selected.connect(func(index): hud.weather_preset_requested.emit(hud.WEATHER_IDS[index]))
	col.add_child(hud.weather_preset)
	hud.weather_auto = CheckButton.new()
	hud.weather_auto.text = "Automatic weather"
	hud.weather_auto.toggled.connect(func(value): hud.weather_auto_requested.emit(value))
	col.add_child(hud.weather_auto)
	col.add_child(hud._label("Time of day",20,hud.WHITE))
	hud.time_of_day = OptionButton.new()
	for label in ["Dawn","Day","Dusk","Night"]: hud.time_of_day.add_item(label)
	hud.time_of_day.item_selected.connect(func(index): hud.time_of_day_requested.emit(hud.TIME_IDS[index]))
	col.add_child(hud.time_of_day)
	var deeper = Shell.group(col,"Automatic changes",hud)
	hud.time_cycle = CheckButton.new()
	hud.time_cycle.text = "Cycle day and night"
	hud.time_cycle.toggled.connect(func(value): hud.time_cycle_requested.emit(value))
	deeper.add_child(hud.time_cycle)
	hud._note(deeper,"One full day takes 20 minutes of skiing. Menus pause the cycle.")

func _audio(col: Control) -> void:
	hud._build_audio_settings(col)
	var voice = Shell.group(col,"Skier voice",hud)
	hud.voice_settings.build(voice,hud)
	var ui = Shell.group(col,"Interface & loading sound",hud)
	hud._build_feedback_settings(ui)

func _interface(col: Control) -> void:
	for key in ["ui_scale","safe_area"]:
		var field = hud._settings_field(col,"UI scale" if key=="ui_scale" else "Safe area")
		var row = HBoxContainer.new()
		field.add_child(row)
		var slider = HSlider.new()
		slider.min_value = .85 if key=="ui_scale" else 0.0
		slider.max_value = 1.4 if key=="ui_scale" else .08
		slider.step = .05 if key=="ui_scale" else .005
		slider.value = hud.shell_layout.get(key)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 40
		row.add_child(slider)
		var readout = hud._label("%d%%" % roundi(slider.value*100),16,hud.WHITE)
		readout.custom_minimum_size.x = 64
		row.add_child(readout)
		slider.value_changed.connect(func(value): hud.shell_layout.change(key,value); readout.text = "%d%%" % roundi(value*100))
	var backgrounds = CheckButton.new()
	backgrounds.name = "HUDBackgrounds"
	backgrounds.text = "HUD backgrounds"
	backgrounds.button_pressed = hud.shell_layout.hud_backgrounds
	backgrounds.toggled.connect(func(value): hud.shell_layout.change("hud_backgrounds",value))
	hud.shell_layout.preferences_changed.connect(func(): backgrounds.set_pressed_no_signal(hud.shell_layout.hud_backgrounds))
	col.add_child(backgrounds)
	hud._note(col,"Off by default. Outlined text and gauges stay readable without panels.")
	var reduced = CheckButton.new()
	reduced.text = "Reduce interface motion"
	reduced.button_pressed = hud.feedback.reduced_motion
	reduced.toggled.connect(func(value): hud.feedback.reduced_motion = value; hud.feedback.save())
	col.add_child(reduced)
	var edit = hud._button("Edit HUD",true)
	edit.name = "EditHUD"
	edit.pressed.connect(func(): hud.open_hud_editor())
	col.add_child(edit)
	hud._note(col,"Move, resize, fade or hide individual instruments. H temporarily hides your layout while skiing.")
	var comfort = Shell.group(col,"Visual comfort",hud)
	hud.motion_toggle = CheckButton.new()
	hud.motion_toggle.text = "Skiing camera motion effects"
	hud.motion_toggle.button_pressed = true
	hud.motion_toggle.toggled.connect(func(value): hud.motion_effects_requested.emit(value))
	comfort.add_child(hud.motion_toggle)
	hud._note(comfort,"Reduced motion keeps interface transitions and impact warnings steady.")

func _controls(col: Control) -> void:
	col.add_child(hud._label("Menu controls",20,hud.WHITE))
	hud._note(col,"D-pad / left stick: navigate. South button: select. East button: back. Shoulders: categories. Select a text field to open the controller keyboard.")
	for entry in [
		["Skiing","A/D or left stick: steer. W / stick forward: tuck. S / LT / L2: brake. Hold Space / RT / R2 and release to hop."],
		["Air control","Center the stick after takeoff, then forward/back flips. L1 / LB remains optional. Left/right turns. Shift / west button grabs. I/K flips and Q/E spins on keyboard."],
		["Camera","Mouse / right stick looks. Middle mouse / R3 centers. C / R1 / RB changes view."],
		["Shortcuts & tools","Escape / Options / Menu pauses. R / north button retries while skiing. H hides the HUD; G toggles the ghost; F3 telemetry; F2 Physics Workbench; F4 races; F6 records. Terrain gate placement uses a pointer."],
		["Comfort","V toggles camera motion. M mutes audio. Vibration strength is available in Physics Workbench → Feedback."]
	]:
		var group = Shell.group(col,entry[0],hud)
		hud._note(group,entry[1])
