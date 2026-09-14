extends RefCounted
## Focusable standard controls share the game's theme and controller keyboard.
var owner
var panel: PanelContainer
var content: VBoxContainer
var status: Label
var timeline: HSlider
var clock: Label
var title_edit: LineEdit
var what_edit: TextEdit
var expected_edit: TextEdit
var speed: SpinBox
var hold: CheckButton
var immortal: CheckButton
var trees: CheckButton
var rocks: CheckButton
var set_speed_button: Button
var files: ItemList
var file_paths: Array[String] = []
var toolbar: VBoxContainer
var record_status: Label
var mode = ""
class CaseTimeline extends HSlider:
	var events: Array = []
	func _draw() -> void:
		for event in events:
			if event.kind=="reset_input" or event.tick<min_value or event.tick>max_value: continue
			var x = 8+(size.x-16)*(event.tick-min_value)/maxf(1,max_value-min_value)
			draw_line(Vector2(x,1),Vector2(x,9),Color("efa773"),2)

func build(controller, root: Control) -> void:
	owner = controller
	panel = PanelContainer.new(); panel.name = "TestCases"; root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = .08; panel.anchor_right = .92; panel.anchor_top = .06; panel.anchor_bottom = .94
	var margin = MarginContainer.new(); margin.add_theme_constant_override("margin_left",18); margin.add_theme_constant_override("margin_right",18); margin.add_theme_constant_override("margin_top",12); margin.add_theme_constant_override("margin_bottom",12); panel.add_child(margin)
	var scroll = ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; margin.add_child(scroll)
	content = VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",8); scroll.add_child(content)
	panel.hide()
	toolbar = VBoxContainer.new(); toolbar.name = "RecordingActions"; root.add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); toolbar.position = Vector2(-590,78); toolbar.size = Vector2(570,86)
	record_status = label(toolbar,"")
	record_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	record_status.add_theme_color_override("font_color",owner.game.hud.HUD_WHITE)
	record_status.add_theme_color_override("font_shadow_color",Color(0,0,0,.5))
	record_status.add_theme_constant_override("shadow_offset_y",1)
	var controls = button(toolbar,"Test Controls",owner.open_controls)
	controls.fixed_key = KEY_F9; controls.fixed_pad = JOY_BUTTON_START; controls.refresh_prompt()
	var save = button(toolbar,"Save & review",func(): owner.save_recording("manual",true))
	save.fixed_key = KEY_F10; save.refresh_prompt()
	toolbar.hide()

func clear(page: String) -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	mode = page; timeline = null; panel.show()
	panel.anchor_top = .06 if page!="review" else .54
	panel.anchor_bottom = .94 if page!="review" else .98
	label(content,"TEST CASES  /  "+page.to_upper(),22)
	status = label(content,"")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func label(parent: Node, text_value: String, size_value: int = 16) -> Label:
	var result = Label.new(); result.text = text_value; result.add_theme_font_size_override("font_size",size_value); parent.add_child(result); return result

func row() -> HFlowContainer:
	var result = HFlowContainer.new(); result.add_theme_constant_override("h_separation",8); result.add_theme_constant_override("v_separation",6); content.add_child(result); return result

func button(parent: Node, text_value: String, action: Callable) -> Button:
	var result = owner.game.hud._button(text_value); result.custom_minimum_size.y = 38; result.pressed.connect(action); parent.add_child(result); return result

func library(entries: Array) -> void:
	clear("library")
	label(content,"Record a summit run, inspect a bug, and save a focused case.")
	var actions = row()
	var record = button(actions,"New recording",owner.setup_recording)
	record.disabled = owner.game.current_mountain==null
	button(actions,"Open .apexcase…",owner.choose_file)
	button(actions,"Back",owner.back)
	files = ItemList.new(); files.custom_minimum_size.y = 260; files.size_flags_vertical = Control.SIZE_EXPAND_FILL; content.add_child(files)
	file_paths.clear()
	for entry in entries:
		file_paths.append(entry.path)
		files.add_item(entry.title)
	files.item_activated.connect(func(index): owner.open_case(file_paths[index]))
	button(content,"Review selected",func():
		var selected = files.get_selected_items()
		if not selected.is_empty(): owner.open_case(file_paths[selected[0]]))
	if entries.is_empty(): status.text = "No cases yet. Start a new recording."
	record.grab_focus()

func controls(setup: bool) -> void:
	clear("recording setup" if setup else "test controls")
	label(content,"Changes apply when skiing resumes and are saved in the recording.")
	var speed_row = row(); label(speed_row,"Speed (km/h)")
	speed = SpinBox.new(); speed.min_value = 0; speed.max_value = 300; speed.step = 1; speed.value = owner.policy.values.speed_kmh; speed.custom_minimum_size.x = 120; speed_row.add_child(speed)
	set_speed_button = button(speed_row,"Set speed now",func(): owner.queue_controls(true))
	hold = check("Hold target speed",owner.policy.values.hold_speed)
	immortal = check("Immortality · no damage or crashes",owner.policy.values.immortal)
	trees = check("Tree collisions",owner.policy.values.trees)
	rocks = check("Rock collisions · placed rocks and formations",owner.policy.values.rocks)
	label(content,"Terrain stays solid. Trees and rocks remain visible.")
	var crashed: bool = owner.game.sim.crashed and not setup
	for control in [hold,immortal,set_speed_button]: control.disabled = crashed
	speed.editable = not crashed
	if crashed: status.text = "Crash aftermath: collision switches remain available."
	var actions = row()
	button(actions,"Start recording" if setup else "Apply & resume",func(): owner.queue_controls(false,true))
	if not setup:
		button(actions,"Save & review",func(): owner.save_recording("manual",true))
		button(actions,"Restart recording",owner.restart_recording)
	button(actions,"Back" if setup else "Exit test mode",owner.back if setup else owner.leave_mode)
	hold.grab_focus()

func check(text_value: String, value: bool) -> CheckButton:
	var result = CheckButton.new(); result.text = text_value; result.button_pressed = value; content.add_child(result); return result

func control_values() -> Dictionary:
	return {"speed_kmh":speed.value,"hold_speed":hold.button_pressed,"immortal":immortal.button_pressed,"trees":trees.button_pressed,"rocks":rocks.button_pressed}

func review() -> void:
	clear("review")
	clock = label(content,"")
	timeline = CaseTimeline.new(); timeline.events = owner.all_events; timeline.min_value = owner.case_data.metadata.start_tick; timeline.max_value = owner.case_data.metadata.end_tick; timeline.step = 1; timeline.value = owner.playhead*120; timeline.custom_minimum_size.y = 28; content.add_child(timeline)
	timeline.value_changed.connect(func(value): owner.seek(value/120.0))
	var transport = row()
	button(transport,"Play / pause",func(): owner.playing = not owner.playing)
	button(transport,"Hide controls · F9",func(): panel.hide())
	var rate = OptionButton.new()
	for text_value in ["0.1×","0.25×","0.5×","1×","2×"]: rate.add_item(text_value)
	rate.select([.1,.25,.5,1.0,2.0].find(owner.rate)); rate.item_selected.connect(func(index): owner.rate = [.1,.25,.5,1.0,2.0][index]); transport.add_child(rate)
	button(transport,"− tick",func(): owner.playing = false; owner.seek((roundi(owner.playhead*120)-1)/120.0))
	button(transport,"+ tick",func(): owner.playing = false; owner.seek((roundi(owner.playhead*120)+1)/120.0))
	button(transport,"− frame",func(): owner.step_frame(-1))
	button(transport,"+ frame",func(): owner.step_frame(1))
	var selection = row()
	button(selection,"Set In",func(): owner.mark_in())
	button(selection,"Set Out",func(): owner.mark_out())
	var loop = CheckButton.new(); loop.text = "Loop selection"; loop.button_pressed = owner.looping; loop.toggled.connect(func(value): owner.looping = value); selection.add_child(loop)
	button(selection,"Save selected clip",notes)
	var camera_row = row()
	button(camera_row,"Recorded / free camera",owner.toggle_camera)
	button(camera_row,"Focus skier",owner.focus_skier)
	button(camera_row,"Control free camera",owner.capture_camera)
	button(camera_row,"Copy path",owner.copy_path)
	button(camera_row,"Open folder",owner.open_folder)
	button(camera_row,"Library",owner.open_library)
	label(content,"Free camera: right-drag orbit · middle-drag pan · wheel zoom · WASD/QE move. Controller: triggers scrub, shoulders step 1 s. Free camera: sticks move/look, triggers rise/fall, B returns.",13)
	timeline.grab_focus()

func notes() -> void:
	owner.playing = false; clear("save clip")
	label(content,"Title")
	title_edit = LineEdit.new(); title_edit.max_length = 120; title_edit.text = owner.case_data.metadata.title; content.add_child(title_edit)
	label(content,"What went wrong (optional)")
	what_edit = TextEdit.new(); what_edit.custom_minimum_size.y = 80; what_edit.text = owner.case_data.metadata.what; content.add_child(what_edit)
	label(content,"Expected behavior (optional)")
	expected_edit = TextEdit.new(); expected_edit.custom_minimum_size.y = 80; expected_edit.text = owner.case_data.metadata.expected; content.add_child(expected_edit)
	var actions = row(); button(actions,"Save clip",owner.save_selection); button(actions,"Back to review",review)
	title_edit.grab_focus()
