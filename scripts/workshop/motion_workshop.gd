extends CanvasLayer
signal closed
const Project = preload("res://scripts/workshop/motion_project.gd")
const Stage = preload("res://scripts/workshop/motion_stage.gd")
const Timeline = preload("res://scripts/workshop/motion_timeline.gd")
const Exporter = preload("res://scripts/workshop/motion_export.gd")
const ThemeStyle = preload("res://scripts/ui/alpine_theme.gd")
var project = Project.new()
var exporter = Exporter.new()
var stage
var timelines: Array = []
var root_panel = PanelContainer.new()
var variant_id = ""
var selected: Array = ["Hips"]
var playing = false
var speed = 1.0
var looping = true
var smooth = true
var time = 0.0
var range_start = 0.0
var range_end = 1.0
var busy = false:
	set(value):
		busy = value
		if is_instance_valid(busy_shield): busy_shield.visible = value
var busy_shield: PanelContainer
var busy_label: Label
var autosave_age = 0.0
var autosave_revision = -1
var project_name: LineEdit
var variants: OptionButton
var clip_list: ItemList
var bone_list: ItemList
var regions: ItemList
var notes: ItemList
var note_text: TextEdit
var note_priority: OptionButton
var note_status: OptionButton
var note_id = ""
var clock_label: Label
var message_label: Label
var diagnostics_label: Label
var bone_label: Label
var slider: HSlider
var start_spin: SpinBox
var end_spin: SpinBox
var note_start: SpinBox
var note_end: SpinBox
var rotation_spins: Array = []
var translation_spins: Array = []
var fixture_controls: Dictionary = {}
var view_choice: OptionButton
var ortho_toggle: CheckBox
var region_name: LineEdit
var region_start: SpinBox
var region_end: SpinBox
var region_muted: CheckBox
var save_dialog: FileDialog
var open_dialog: FileDialog
var export_dialog: FileDialog
var syncing = false
var pose_before: Dictionary = {}
var pending_pose: Dictionary = {}
var pending_bones: Array = []
var copied_pose: Dictionary = {}
var last_export = ""
var standalone = false
var persistence_enabled = true

func _ready() -> void:
	layer = 50
	root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_panel.name = "AnimationWorkshop"
	root_panel.theme = ThemeStyle.create().duplicate()
	root_panel.theme.default_font_size = 14
	for type in ["Button","OptionButton","CheckBox","LineEdit","SpinBox"]:
		root_panel.theme.set_font_size("font_size",type,14)
	for type in ["Button","OptionButton","LineEdit"]:
		for state in ["normal","hover","pressed","focus"]:
			root_panel.theme.set_stylebox(state,type,ThemeStyle.box(Color("193442") if state in ["hover","pressed"] else Color("102532"),Color("527486"),6,Vector2(7,4)))
	for type in ["TabContainer","TabBar"]:
		for state in ["tab_selected","tab_unselected","tab_hovered"]:
			root_panel.theme.set_stylebox(state,type,ThemeStyle.box(Color("264957") if state=="tab_selected" else Color("142b37"),Color.TRANSPARENT,7,Vector2(7,4)))
	root_panel.add_theme_stylebox_override("panel",ThemeStyle.box(Color("10212e"),Color("45657b"),12,Vector2.ZERO))
	add_child(root_panel)
	var column = VBoxContainer.new(); root_panel.add_child(column)
	var header = HBoxContainer.new(); column.add_child(header)
	label(header,"ANIMATION WORKSHOP",20)
	project_name = LineEdit.new(); project_name.text = project.data.title; project_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(project_name)
	project_name.text_submitted.connect(func(value): var before = project.snapshot(); project.data.title = value; project.commit("Rename project",before))
	project_name.focus_exited.connect(func():
		if project_name.text!=project.data.title:
			var before = project.snapshot(); project.data.title = project_name.text; project.commit("Rename project",before))
	button(header,"Open",func(): if not busy: open_dialog.popup_centered_ratio(.75))
	button(header,"Save",save_project)
	button(header,"Save as",func(): if not busy: save_dialog.popup_centered_ratio(.75))
	button(header,"Export for Astra",preview_export)
	button(header,"Close",close_workshop)
	var bar = HBoxContainer.new(); column.add_child(bar)
	variants = OptionButton.new(); variants.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.add_child(variants)
	variants.item_selected.connect(func(index): choose_variant(variants.get_item_metadata(index)))
	button(bar,"Duplicate variant",duplicate_variant)
	button(bar,"Rename",rename_variant)
	button(bar,"Mark reviewed",func(): var before = project.snapshot(); project.variant(variant_id).reviewed = true; project.commit("Mark reviewed",before); message("Variant marked reviewed."))
	button(bar,"Undo",undo)
	button(bar,"Redo",redo)
	var vertical = VSplitContainer.new(); vertical.size_flags_vertical = Control.SIZE_EXPAND_FILL; vertical.split_offset = 150; column.add_child(vertical)
	var horizontal = HSplitContainer.new(); horizontal.size_flags_vertical = Control.SIZE_EXPAND_FILL; horizontal.split_offset = 215; vertical.add_child(horizontal)
	var left = VBoxContainer.new(); left.custom_minimum_size.x = 185; horizontal.add_child(left)
	var left_tabs = TabContainer.new(); left_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; left.add_child(left_tabs)
	var clips = tab(left_tabs,"Clips")
	var clip_search = LineEdit.new(); clip_search.placeholder_text = "Search 33 source clips"; clips.add_child(clip_search)
	clip_list = ItemList.new(); clip_list.custom_minimum_size.y = 200; clip_list.size_flags_vertical = Control.SIZE_EXPAND_FILL; clips.add_child(clip_list)
	clip_list.item_activated.connect(func(index): add_clip(clip_list.get_item_metadata(index)))
	button(clips,"Edit selected clip",func(): if not clip_list.get_selected_items().is_empty(): add_clip(clip_list.get_item_metadata(clip_list.get_selected_items()[0])))
	clip_search.text_changed.connect(fill_clips); fill_clips("")
	var bones = tab(left_tabs,"Bones")
	var bone_search = LineEdit.new(); bone_search.placeholder_text = "Search bones"; bones.add_child(bone_search)
	bone_list = ItemList.new(); bone_list.custom_minimum_size.y = 240; bone_list.select_mode = ItemList.SELECT_MULTI; bone_list.size_flags_vertical = Control.SIZE_EXPAND_FILL; bones.add_child(bone_list)
	bone_list.multi_selected.connect(func(_index,_value):
		selected.clear()
		for index in bone_list.get_selected_items(): selected.append(bone_list.get_item_metadata(index))
		if selected.is_empty(): selected = ["Hips"]
		sync_selection())
	bone_search.text_changed.connect(fill_bones); fill_bones("")
	var right_split = HSplitContainer.new(); right_split.split_offset = -325; horizontal.add_child(right_split)
	var viewport_column = VBoxContainer.new(); viewport_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right_split.add_child(viewport_column)
	var views = HFlowContainer.new(); viewport_column.add_child(views)
	view_choice = choice(views,["Your edit","Original","Constrained result","Side by side","Overlay"],func(value):
		stage.comparison = value
		if value=="Side by side": stage.distance = maxf(stage.distance,7.0)
		stage.update_camera(); refresh())
	for view_name in ["Front","Side","Back"]: button(views,view_name,func(): stage.set_view(view_name))
	ortho_toggle = toggle(views,"Ortho",false,func(value): stage.orthographic = value; stage.update_camera())
	toggle(views,"Bones",true,func(value): stage.skeleton_visible = value; stage.queue_redraw())
	toggle(views,"Ghosts",false,func(value): stage.ghosts_visible = value; stage.queue_redraw())
	stage = Stage.new(); stage.project = project; stage.size_flags_vertical = Control.SIZE_EXPAND_FILL; viewport_column.add_child(stage)
	stage.bone_selected.connect(func(bone,extend):
		if not extend: selected.clear()
		if not selected.has(bone): selected.append(bone)
		sync_selection())
	stage.pose_drag_started.connect(func(): seek(time); pose_before = project.snapshot(); pending_pose = {}; pending_bones = [])
	stage.pose_dragged.connect(func(pose,bones_changed): pending_pose = pose; pending_bones = bones_changed; stage.refresh(pose))
	stage.pose_drag_finished.connect(finish_pose_drag)
	stage.pose_drag_cancelled.connect(func(): pending_pose = {}; pending_bones = []; refresh())
	stage.edit_message.connect(message)
	label(viewport_column,"Controlled fitting preview · isolated clips do not reproduce gameplay blending",12)
	var inspector = TabContainer.new(); inspector.custom_minimum_size.x = 285; right_split.add_child(inspector)
	build_pose(tab(inspector,"Pose"))
	build_corrections(tab(inspector,"Edits"))
	build_notes(tab(inspector,"Notes"))
	build_fixture(tab(inspector,"Fit"))
	var lower = VBoxContainer.new(); lower.custom_minimum_size.y = 210; vertical.add_child(lower)
	var transport = HBoxContainer.new(); lower.add_child(transport)
	button(transport,"|◀",func(): seek(range_start))
	button(transport,"◀",func(): seek(time-1.0/60))
	button(transport,"Play / Pause",toggle_playback)
	button(transport,"▶",func(): seek(time+1.0/60))
	button(transport,"▶|",func(): seek(range_end))
	choice(transport,["1×","0.1×","0.25×","0.5×","2×"],func(value): speed = float(value.trim_suffix("×")))
	toggle(transport,"Loop",true,func(value): looping = value)
	clock_label = label(transport,"Frame 0 / 0 · 0.000 s",14)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_spin = spin(transport,"In",0,36000,1,0,func(value): range_start = minf(value/60,range_end-1.0/60); refresh())
	end_spin = spin(transport,"Out",1,36000,1,1,func(value): range_end = maxf(value/60,range_start+1.0/60); refresh())
	slider = HSlider.new(); slider.step = 1.0/60; lower.add_child(slider); slider.value_changed.connect(func(value): if not syncing: seek(value))
	var keybar = HFlowContainer.new(); lower.add_child(keybar)
	choice(keybar,["RX","RY","RZ","Pelvis X","Pelvis Y","Pelvis Z"],func(value):
		var selected_channel = ["RX","RY","RZ","Pelvis X","Pelvis Y","Pelvis Z"].find(value)
		if selected_channel>=3: selected = ["Hips"]; sync_selection()
		for timeline in timelines: timeline.channel = selected_channel; timeline.queue_redraw())
	button(keybar,"Insert key",insert_key)
	button(keybar,"Delete keys",func(): active_timeline().delete_keys(); refresh())
	button(keybar,"Copy keys",func(): active_timeline().copy_keys())
	button(keybar,"Paste keys",func(): active_timeline().paste_keys(); refresh())
	choice(keybar,["cubic","linear","constant"],func(value): active_timeline().interpolation(value))
	button(keybar,"Retime range",retime_dialog)
	button(keybar,"Trim to range",func(): project.trim(variant_id,range_start,range_end); choose_variant(variant_id))
	var duration_button = button(keybar,"Set duration",duration_dialog)
	duration_button.tooltip_text = "Scale all motion and keys to a new duration."
	var timeline_tabs = TabContainer.new(); timeline_tabs.name = "TimelineTabs"; timeline_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; lower.add_child(timeline_tabs)
	for graph in [false,true]:
		var timeline = Timeline.new(); timeline.name = "Curves" if graph else "Timeline"; timeline.curve_view = graph
		timeline.project = project; timeline_tabs.add_child(timeline); timelines.append(timeline)
		timeline.seek_requested.connect(seek)
		timeline.selection_changed.connect(func():
			for other in timelines: other.region_id = timeline.region_id; other.selected = timeline.selected.duplicate(); other.queue_redraw()
			sync_region())
		timeline.edited.connect(func(): refresh(); fill_regions())
	message_label = label(column,"Original assets are preserved. Projects and exports stay local.",13)
	build_dialogs()
	busy_shield = PanelContainer.new(); busy_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	busy_shield.add_theme_stylebox_override("panel",ThemeStyle.box(Color(.02,.06,.09,.90),Color("608b9a"),30,Vector2.ZERO))
	add_child(busy_shield)
	busy_label = label(busy_shield,"Preparing frames…",24); busy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; busy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	busy_shield.hide()
	exporter.progress = message
	add_clip("NAV_MED_FWD")
	if persistence_enabled and (FileAccess.file_exists(Project.RECOVERY) or FileAccess.file_exists(Project.RECOVERY+".bak")):
		var recover = ConfirmationDialog.new(); recover.title = "Recover workshop project"; recover.dialog_text = "A recovery project is available. Restore it to continue your saved work?"
		add_child(recover); recover.confirmed.connect(func(): load_project(Project.RECOVERY)); recover.popup_centered()

func label(parent: Node, text: String, font_size: int = 14) -> Label:
	var node = Label.new(); node.text = text; node.add_theme_font_size_override("font_size",font_size); parent.add_child(node); return node
func button(parent: Node, text: String, action: Callable) -> Button:
	var node = Button.new(); node.text = text; node.pressed.connect(func(): if not busy: action.call()); parent.add_child(node); return node
func toggle(parent: Node, text: String, value: bool, action: Callable) -> CheckBox:
	var node = CheckBox.new(); node.text = text; node.button_pressed = value; node.toggled.connect(func(v): if not syncing and not busy: action.call(v)); parent.add_child(node); return node
func choice(parent: Node, values: Array, action: Callable) -> OptionButton:
	var node = OptionButton.new(); parent.add_child(node)
	for value in values: node.add_item(value)
	node.item_selected.connect(func(index): if not syncing and not busy: action.call(values[index])); return node
func spin(parent: Node, caption: String, minimum: float, maximum: float, step: float, value: float, action: Callable) -> SpinBox:
	var row = HBoxContainer.new(); parent.add_child(row)
	if not caption.is_empty(): label(row,caption)
	var node = SpinBox.new(); node.min_value = minimum; node.max_value = maximum; node.step = step; node.value = value; node.custom_minimum_size.x = 84; node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(node); node.get_line_edit().focus_entered.connect(func(): playing = false)
	node.value_changed.connect(func(v): if not syncing and not busy: action.call(v)); return node
func tab(parent: TabContainer, caption: String) -> VBoxContainer:
	var scroll = ScrollContainer.new(); scroll.name = caption; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; parent.add_child(scroll)
	var column = VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; column.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.add_child(column); return column

func build_pose(parent: VBoxContainer) -> void:
	bone_label = label(parent,"Hips",19)
	choice(parent,["Auto","Rotate","Move / IK"],func(value): stage.cancel_drag(); stage.tool = value; stage.queue_redraw())
	toggle(parent,"Hold feet during grounded pelvis edits",true,func(value): stage.hold_feet = value)
	toggle(parent,"World axes",false,func(value): stage.world_axes = value; stage.queue_redraw())
	toggle(parent,"Smooth local correction ±9 frames",true,func(value): smooth = value)
	label(parent,"Local rotation · degrees")
	for axis in 3: rotation_spins.append(spin(parent,["X","Y","Z"][axis],-720,720,.5,0,func(_v): pass))
	button(parent,"Apply rotation",apply_numeric_rotation)
	label(parent,"Pelvis offset · metres")
	for axis in 3: translation_spins.append(spin(parent,["X","Y","Z"][axis],-3,3,.01,0,func(_v): pass))
	button(parent,"Apply pelvis offset",apply_translation)
	var actions = HFlowContainer.new(); parent.add_child(actions)
	button(actions,"Pin / unpin",func(): stage.pin_selected(); message("Pins hold hands/feet while moving the pelvis."))
	button(actions,"Clear pins",func(): stage.pins.clear(); stage.queue_redraw())
	button(actions,"Copy pose",func(): copied_pose = stage.display_pose.duplicate(true); message("Pose copied."))
	button(actions,"Paste pose",func(): if not copied_pose.is_empty(): apply_pose(copied_pose,selected,"Paste pose"))
	button(actions,"Mirror pose",func(): apply_pose(project.mirror(stage.display_pose),Array(project.data.rig.names),"Mirror pose"))
	diagnostics_label = label(parent,"",12); diagnostics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func build_corrections(parent: VBoxContainer) -> void:
	regions = ItemList.new(); regions.custom_minimum_size.y = 150; parent.add_child(regions)
	regions.item_selected.connect(func(index):
		for timeline in timelines: timeline.region_id = regions.get_item_metadata(index); timeline.selected.clear(); timeline.queue_redraw()
		sync_region())
	region_name = LineEdit.new(); region_name.placeholder_text = "Correction name"; parent.add_child(region_name)
	region_start = spin(parent,"Start frame",0,36000,1,0,func(_v): pass)
	region_end = spin(parent,"End frame",0,36000,1,1,func(_v): pass)
	region_muted = toggle(parent,"Muted",false,func(_v): pass)
	button(parent,"Apply region settings",apply_region_settings)
	button(parent,"Reset selected correction",func():
		var before = project.snapshot(); var r = active_timeline().region()
		if not r.is_empty(): r.tracks.clear(); project.commit("Reset correction",before); refresh(); fill_regions())
	button(parent,"Delete selected correction",func():
		var before = project.snapshot(); var r = active_timeline().region()
		if not r.is_empty(): project.variant(variant_id).regions.erase(r); project.commit("Delete correction",before); refresh(); fill_regions())
	label(parent,"Drag region edges in Timeline.\nShift-click keys to select several.\nDouble-click Curves to insert a key.",12)

func build_notes(parent: VBoxContainer) -> void:
	notes = ItemList.new(); notes.custom_minimum_size.y = 100; parent.add_child(notes)
	notes.item_selected.connect(select_note)
	button(parent,"New comment at this frame",new_note)
	note_start = spin(parent,"From frame",0,36000,1,0,func(_v): pass)
	note_end = spin(parent,"To frame",0,36000,1,0,func(_v): pass)
	note_text = TextEdit.new(); note_text.placeholder_text = "Describe what feels wrong and what you want instead…"; note_text.custom_minimum_size.y = 110; note_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; parent.add_child(note_text)
	note_priority = choice(parent,["Normal","High","Low"],func(_v): pass)
	note_status = choice(parent,["Open","Resolved","Reference"],func(_v): pass)
	button(parent,"Save comment + capture frames",func(): save_note(true))
	button(parent,"Update text only",func(): save_note(false))
	button(parent,"Delete comment",delete_note)
	label(parent,"Captures preserve the current revision,\nselected bones and comparison frames.",12)

func build_fixture(parent: VBoxContainer) -> void:
	label(parent,"Controlled fitting preview",17)
	fixture_controls.context = choice(parent,["grounded","airborne","safety","mute"],func(value): set_fixture("context",value))
	fixture_controls.slope = spin(parent,"Slope °",0,45,1,0,func(value): set_fixture("slope",value))
	fixture_controls.stance = spin(parent,"Stance m",.25,.8,.01,.44,func(value): set_fixture("stance",value))
	fixture_controls.tuck = spin(parent,"Tuck",0,1,.05,0,func(value): set_fixture("tuck",value))
	fixture_controls.grab = spin(parent,"Grab weight",0,1,.05,1,func(value): set_fixture("grab",value))
	var note = label(parent,"Orange bones identify fitting changes. The unrestricted preview lets you show a pose beyond the current game limits.\n\nThese controls affect this studio fixture only.",13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func set_fixture(key: String, value: Variant) -> void:
	var before = project.snapshot(); project.data.preview[key] = value; project.commit("Preview "+key,before); refresh()

func fill_clips(filter: String) -> void:
	clip_list.clear(); var names: Array = Project.LIBRARY.data.clips.keys(); names.sort()
	for name_value in names:
		if not filter.is_empty() and not filter.to_lower() in name_value.to_lower(): continue
		clip_list.add_item(name_value.trim_prefix("NAV_").capitalize()); clip_list.set_item_metadata(clip_list.item_count-1,name_value)
		clip_list.set_item_tooltip(clip_list.item_count-1,name_value)
func fill_bones(filter: String) -> void:
	bone_list.clear()
	for bone in project.data.rig.names:
		if not filter.is_empty() and not filter.to_lower() in bone.to_lower(): continue
		var depth = 0; var parent: int = project.data.rig.parents[project.data.rig.names.find(bone)]
		while parent>=0: depth += 1; parent = project.data.rig.parents[parent]
		bone_list.add_item("  ".repeat(depth)+bone); bone_list.set_item_metadata(bone_list.item_count-1,bone)
		if bone in selected: bone_list.select(bone_list.item_count-1,false)
func add_clip(source: String) -> void:
	if busy: return
	choose_variant(project.add_variant(source))
func duplicate_variant() -> void:
	text_dialog("Duplicate variant",project.variant(variant_id).name+" copy",func(value): choose_variant(project.duplicate_variant(variant_id,value)))
func rename_variant() -> void:
	text_dialog("Rename variant",project.variant(variant_id).name,func(value): var before = project.snapshot(); project.variant(variant_id).name = value; project.commit("Rename variant",before); fill_variants())
func fill_variants() -> void:
	variants.clear()
	for item in project.data.variants:
		variants.add_item(item.name); variants.set_item_metadata(variants.item_count-1,item.id)
		if item.id==variant_id: variants.select(variants.item_count-1)
func choose_variant(id: String) -> void:
	if id.is_empty(): return
	variant_id = id; playing = false; time = 0; range_start = 0; range_end = project.variant(id).duration
	stage.variant_id = id; stage.pins.clear()
	for timeline in timelines: timeline.variant_id = id; timeline.region_id = ""; timeline.selected.clear()
	fill_variants(); fill_regions(); fill_notes(); refresh(); sync_selection(); new_note()
func fill_regions() -> void:
	regions.clear()
	for r in project.variant(variant_id).get("regions",[]):
		regions.add_item(("○ " if r.muted else "● ")+r.name); regions.set_item_metadata(regions.item_count-1,r.id)
		if r.id==active_timeline().region_id: regions.select(regions.item_count-1)
	sync_region()
func sync_region() -> void:
	if timelines.is_empty(): return
	var r = active_timeline().region(); syncing = true
	region_name.text = r.get("name",""); region_start.value = r.get("start",0)*60; region_end.value = r.get("end",0)*60; region_muted.button_pressed = r.get("muted",false)
	syncing = false
func active_timeline():
	for timeline in timelines:
		if timeline.is_visible_in_tree(): return timeline
	return timelines[0]

func refresh() -> void:
	if variant_id.is_empty() or stage==null: return
	stage.project = project; stage.time = time; stage.selected = selected; stage.refresh()
	syncing = true
	view_choice.select(["Your edit","Original","Constrained result","Side by side","Overlay"].find(stage.comparison))
	ortho_toggle.button_pressed = stage.orthographic
	var duration: float = project.variant(variant_id).duration
	slider.max_value = duration; slider.value = time
	start_spin.max_value = roundi(duration*60); end_spin.max_value = roundi(duration*60)
	start_spin.value = range_start*60; end_spin.value = range_end*60
	clock_label.text = "Frame %d / %d · %.3f s"%[roundi(time*60),roundi(duration*60),time]
	for timeline in timelines: timeline.project = project; timeline.cursor = time; timeline.bone = selected[-1]; timeline.queue_redraw()
	if stage.diagnostics.get("changes",{}).has(selected[-1]):
		var d: Dictionary = stage.diagnostics.changes[selected[-1]]
		diagnostics_label.text = "Fitting changes this bone by\n%.1f cm · %.1f°\nPose evaluation %.2f ms"%[d.position_m*100,rad_to_deg(d.rotation_rad),stage.frame_cost_us/1000.0]
	for key in fixture_controls:
		if key=="context": fixture_controls[key].select(["grounded","airborne","safety","mute"].find(project.data.preview[key]))
		else: fixture_controls[key].set_value_no_signal(project.data.preview[key])
	if not stage.display_pose.is_empty():
		var index: int = project.data.rig.names.find(selected[-1]); var angles = Basis(stage.display_pose.q[index]).get_euler(EULER_ORDER_YXZ)
		for axis in 3:
			if not rotation_spins[axis].get_line_edit().has_focus(): rotation_spins[axis].set_value_no_signal(rad_to_deg(angles[axis]))
	syncing = false
func sync_selection() -> void:
	bone_label.text = ", ".join(selected)
	stage.selected = selected.duplicate()
	for i in bone_list.item_count:
		if bone_list.get_item_metadata(i) in selected: bone_list.select(i,false)
		else: bone_list.deselect(i)
	if not stage.display_pose.is_empty():
		var index: int = project.data.rig.names.find(selected[-1]); var angles = Basis(stage.display_pose.q[index]).get_euler(EULER_ORDER_YXZ)
		for axis in 3: rotation_spins[axis].set_value_no_signal(rad_to_deg(angles[axis]))
	refresh()
func seek(at: float) -> void:
	if busy: return
	playing = false; time = clampf(roundf(at*60)/60,0,project.variant(variant_id).duration); refresh()
func toggle_playback() -> void:
	if playing: seek(time)
	else: playing = true
func _process(dt: float) -> void:
	if busy or variant_id.is_empty(): return
	if playing:
		if time<range_start: time = range_start
		time += dt*speed
		if time>range_end:
			if looping and range_end>range_start: time = range_start+fposmod(time-range_start,range_end-range_start)
			else: time = range_end; playing = false
		refresh()
	autosave_age += dt
	if persistence_enabled and autosave_age>30:
		autosave_age = 0
		if autosave_revision!=project.revision:
			project.data.camera = stage.camera_data()
			if project.save_to(Project.RECOVERY,true)==OK: autosave_revision = project.revision
			else: message(project.error)

func apply_pose(pose: Dictionary, bones: Array, title: String) -> void:
	var before = project.snapshot()
	var id = project.correct_pose(variant_id,time,pose,bones,smooth)
	project.commit(title,before)
	for timeline in timelines: timeline.region_id = id
	fill_regions(); refresh()
func finish_pose_drag() -> void:
	if pending_pose.is_empty(): return
	apply_pose(pending_pose,pending_bones,"Mouse pose correction"); pending_pose = {}; pending_bones = []
func apply_numeric_rotation() -> void:
	var pose = stage.display_pose.duplicate(true)
	var q = Basis.from_euler(Vector3(deg_to_rad(rotation_spins[0].value),deg_to_rad(rotation_spins[1].value),deg_to_rad(rotation_spins[2].value)),EULER_ORDER_YXZ).get_rotation_quaternion()
	for bone in selected: pose.q[project.data.rig.names.find(bone)] = q
	apply_pose(pose,selected,"Set local rotation")
func apply_translation() -> void:
	var before = stage.display_pose.duplicate(true)
	var pose = before.duplicate(true); pose.root += Vector3(translation_spins[0].value,translation_spins[1].value,translation_spins[2].value)
	var bones: Array = ["Hips"]
	bones.append_array(stage.fit_pins(pose,stage.endpoint_pins(before),before))
	apply_pose(pose,bones,"Move pelvis")
func apply_region_settings() -> void:
	var r = active_timeline().region()
	if r.is_empty() or region_end.value<=region_start.value: return
	var before = project.snapshot()
	r.name = region_name.text; r.muted = region_muted.button_pressed
	project.resize_region(r,region_start.value/60,region_end.value/60,project.variant(variant_id).duration)
	project.commit("Edit correction region",before); fill_regions(); refresh()
func insert_key() -> void:
	var timeline = active_timeline()
	var before = project.snapshot()
	if timeline.region().is_empty():
		var id = project.correct_pose(variant_id,time,stage.display_pose,selected,false)
		for other in timelines: other.region_id = id
	timeline.insert_key(time,project.curve(timeline.keys(),time)); project.commit("Insert key",before); fill_regions(); refresh()
func undo() -> void:
	playing = false; project.history.undo(); after_history()
func redo() -> void:
	playing = false; project.history.redo(); after_history()
func after_history() -> void:
	if project.variant(variant_id).is_empty():
		if project.data.variants.is_empty(): variant_id = project.add_variant("NAV_MED_FWD")
		else: variant_id = project.data.variants[0].id
	stage.variant_id = variant_id
	for timeline in timelines:
		timeline.variant_id = variant_id
		if timeline.region().is_empty():
			var remaining: Array = project.variant(variant_id).regions
			timeline.region_id = remaining[-1].id if not remaining.is_empty() else ""
			timeline.selected.clear()
	time = minf(time,project.variant(variant_id).duration); range_end = project.variant(variant_id).duration
	fill_variants(); fill_regions(); fill_notes(); refresh()

func text_dialog(title: String, initial: String, action: Callable) -> void:
	var dialog = ConfirmationDialog.new(); dialog.title = title
	var input = LineEdit.new(); input.text = initial; input.custom_minimum_size.x = 360; dialog.add_child(input); add_child(dialog)
	dialog.confirmed.connect(func(): if not input.text.strip_edges().is_empty(): action.call(input.text); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(440,130)); input.grab_focus()
func duration_dialog() -> void:
	text_dialog("New duration in seconds",str(project.variant(variant_id).duration),func(value):
		if value.is_valid_float() and float(value)>=1.0/60 and float(value)<=600:
			project.retime(variant_id,0,project.variant(variant_id).duration,0,roundf(float(value)*60)/60); choose_variant(variant_id))
func retime_dialog() -> void:
	text_dialog("Range: new start frame, new end frame","%d, %d"%[roundi(range_start*60),roundi(range_end*60)],func(value):
		var parts = value.split(",")
		if parts.size()==2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float():
			project.retime(variant_id,range_start,range_end,float(parts[0])/60,float(parts[1])/60); choose_variant(variant_id))

func build_dialogs() -> void:
	DirAccess.make_dir_recursive_absolute(Project.ROOT_DIR)
	save_dialog = file_dialog("Save workshop project",FileDialog.FILE_MODE_SAVE_FILE,"*.apexmotion ; Animation Workshop project")
	save_dialog.current_file = "skier-review.apexmotion"; save_dialog.file_selected.connect(func(path): save_at(path))
	open_dialog = file_dialog("Open workshop project",FileDialog.FILE_MODE_OPEN_FILE,"*.apexmotion ; Animation Workshop project")
	open_dialog.file_selected.connect(load_project)
	export_dialog = file_dialog("Export for Astra",FileDialog.FILE_MODE_SAVE_FILE,"*.zip ; Astra review package")
	export_dialog.current_file = "animation-review.zip"; export_dialog.file_selected.connect(export_at)
func file_dialog(title: String, mode: FileDialog.FileMode, filter: String) -> FileDialog:
	var dialog = FileDialog.new(); dialog.title = title; dialog.file_mode = mode; dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = ProjectSettings.globalize_path(Project.ROOT_DIR); dialog.add_filter(filter); add_child(dialog); return dialog
func save_project() -> void:
	if project.path.is_empty() or project.path==Project.RECOVERY: save_dialog.popup_centered_ratio(.75)
	else: save_at(project.path)
func save_at(path: String) -> void:
	project.data.camera = stage.camera_data()
	if project.save_to(path)==OK: message("Saved "+ProjectSettings.globalize_path(path))
	else: message(project.error)
func load_project(path: String) -> void:
	if busy: return
	var loaded = Project.new()
	if not loaded.load_from(path): message(loaded.error); loaded.dispose(); return
	project.save_to(Project.RECOVERY+".previous",true)
	project.dispose()
	project = loaded; stage.project = project
	project_name.text = project.data.title
	if project.data.variants.is_empty(): add_clip("NAV_MED_FWD")
	else: choose_variant(project.data.variants[0].id)
	if project.data.has("camera"): stage.restore_camera(project.data.camera); refresh()
	message("Opened saved project. Embedded source motion retained."+(" Source assets differ; fitting uses the current game." if project.identity_changed() else ""))
func close_workshop() -> void:
	if busy: message("Wait for capture/export to finish before closing."); return
	playing = false
	project.data.camera = stage.camera_data()
	if persistence_enabled and project.save_to(Project.RECOVERY,true)!=OK: message(project.error); return
	closed.emit(); queue_free()
func message(text: String) -> void:
	if is_instance_valid(message_label): message_label.text = text
	if is_instance_valid(busy_label): busy_label.text = text

func new_note() -> void:
	note_id = ""; note_text.text = ""; note_start.value = roundi(time*60); note_end.value = roundi(time*60); note_priority.select(0); note_status.select(0)
func fill_notes() -> void:
	notes.clear()
	for note in project.data.comments:
		if note.variant!=variant_id: continue
		notes.add_item("%d · %s"%[roundi(note.start*60),note.text.left(40).replace("\n"," ")]); notes.set_item_metadata(notes.item_count-1,note.id)
func select_note(index: int) -> void:
	note_id = notes.get_item_metadata(index)
	for note in project.data.comments:
		if note.id!=note_id: continue
		note_text.text = note.text; note_start.value = roundi(note.start*60); note_end.value = roundi(note.end*60)
		note_priority.select(["Normal","High","Low"].find(note.priority)); note_status.select(["Open","Resolved","Reference"].find(note.status))
		selected = note.bones.duplicate(); if selected.is_empty(): selected = ["Hips"]
		seek(note.start); sync_selection()
func save_note(capture_frames: bool) -> void:
	if busy or note_text.text.strip_edges().is_empty(): return
	var before = project.snapshot(); var note: Dictionary = {}
	for entry in project.data.comments:
		if entry.id==note_id: note = entry
	if note.is_empty():
		note = {"id":Project.uid(),"variant":variant_id}; capture_frames = true
		project.data.comments.append(note); note_id = note.id
	note.text = note_text.text; note.priority = note_priority.get_item_text(note_priority.selected); note.status = note_status.get_item_text(note_status.selected)
	if capture_frames:
		playing = false; busy = true; message("Capturing comment evidence…")
		note.start = clampf(note_start.value/60,0,project.variant(variant_id).duration); note.end = clampf(note_end.value/60,note.start,project.variant(variant_id).duration); note.bones = selected.duplicate()
		note.evidence = await exporter.capture_evidence(stage,note.start,note.end,note.bones)
		busy = false
	project.commit("Save comment",before); fill_notes(); refresh(); message("Comment saved with frozen evidence.")
func delete_note() -> void:
	var before = project.snapshot()
	project.data.comments = project.data.comments.filter(func(note): return note.id!=note_id)
	project.commit("Delete comment",before); new_note(); fill_notes()
func preview_export() -> void:
	if exporter.reviewed_variants(project).is_empty(): message("Edit, comment on, or mark a variant reviewed first."); return
	var dialog = ConfirmationDialog.new(); dialog.title = "Export preview"; dialog.dialog_text = exporter.preview(project); dialog.ok_button_text = "Choose ZIP location"
	add_child(dialog); dialog.confirmed.connect(func(): export_dialog.popup_centered_ratio(.75); dialog.queue_free()); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(650,350))
func export_at(path: String) -> void:
	if busy: return
	playing = false; busy = true; message("Preparing Astra export…")
	var result = await exporter.export_zip(project,path,stage)
	busy = false
	if result!=OK: message(exporter.error); return
	last_export = ProjectSettings.globalize_path(path); message("Exported "+last_export)
	var dialog = ConfirmationDialog.new(); dialog.title = "Astra package exported"; dialog.dialog_text = last_export; dialog.ok_button_text = "Open export folder"
	dialog.add_button("Copy ZIP path",false,"copy_path")
	dialog.custom_action.connect(func(action): if action=="copy_path": DisplayServer.clipboard_set(last_export))
	add_child(dialog); dialog.confirmed.connect(func():
		var folder_result = OS.shell_show_in_file_manager(last_export)
		if folder_result!=OK: message("Export saved. Could not open its folder (error %d): %s"%[folder_result,last_export.get_base_dir()])
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(620,180))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if is_instance_valid(save_dialog) and (save_dialog.visible or open_dialog.visible or export_dialog.visible): return
		if event.ctrl_pressed and event.keycode==KEY_S and not busy:
			save_project(); get_viewport().set_input_as_handled(); return
		var focused = get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit: return
		if busy: get_viewport().set_input_as_handled(); return
		if event.ctrl_pressed and event.keycode in [KEY_Z,KEY_Y] and stage.cancel_drag():
			get_viewport().set_input_as_handled(); return
		if event.ctrl_pressed and event.keycode==KEY_S: save_project()
		elif event.ctrl_pressed and event.keycode==KEY_Z: undo()
		elif event.ctrl_pressed and event.keycode==KEY_Y: redo()
		elif event.keycode==KEY_SPACE: toggle_playback()
		elif event.keycode==KEY_LEFT: seek(time-1.0/60)
		elif event.keycode==KEY_RIGHT: seek(time+1.0/60)
		elif event.keycode==KEY_ESCAPE:
			if not stage.cancel_drag(): close_workshop()
		else: return
		get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		playing = false
		if is_instance_valid(stage): stage.cancel_drag(); stage.orbit_button = 0

func _exit_tree() -> void:
	project.dispose()
