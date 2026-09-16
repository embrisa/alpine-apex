extends Node
const RetainedContent = preload("res://scripts/ui/retained_screen_content.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Store = preload("res://scripts/world/mountain_store.gd")
var game
var store = Store.new()
var panel: PanelContainer
const Settings = preload("res://scripts/world/generation_settings.gd")
const Job = preload("res://scripts/world/generation_job.gd")
const Estimates = preload("res://scripts/world/generation_estimates.gd")
var generation_job
var preset_control: OptionButton
var settings_controls: Dictionary = {}
var advanced_toggle: CheckButton
var advanced_panel: VBoxContainer
var estimates_label: Label
var population_label: Label
var updating_settings: bool = false
var tabs: TabContainer
var all_buttons: Array[Button] = []
var preview_column: VBoxContainer
var page_columns: Array[BoxContainer] = []
var seed_input: LineEdit
var name_input: LineEdit
var status: Label
var summary: Label
var list: ItemList
var preview
var draft = null
var draft_field = null
var saved: Array = []
var actions: Array[Button] = []
var instrument_visibility: Array = []
var return_mode: String = "title"
var busy: bool = false
var export_dialog: FileDialog
var import_dialog: FileDialog

func build(owner_game) -> void:
	game = owner_game
	var hud = game.hud
	panel = hud._panel()
	panel.name = "MountainLibrary"
	var shell = hud._window(panel,1260)
	shell.add_theme_constant_override("separation",14)
	shell.add_child(hud._label("Mountains",28,hud.WHITE))
	tabs = hud._tabs(shell)
	for caption in ["Create","Saved","Share"]:
		var page = hud._tab(tabs,caption)
		var columns = RetainedContent.new()
		page.add_child(columns)
		page_columns.append(columns)
		var controls = VBoxContainer.new()
		controls.add_theme_constant_override("separation",16)
		columns.add_child(controls)
	var col = page_columns[0].get_child(0)
	var saved_page = page_columns[1].get_child(0)
	var share = page_columns[2].get_child(0)
	col.add_child(hud._label("Mountain seed",14,hud.LIME))
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "849205174"
	seed_input.max_length = 48
	seed_input.custom_minimum_size.y = 44
	seed_input.text_submitted.connect(func(_value): generate_seed())
	col.add_child(seed_input)
	_build_generation_controls(col)
	seed_input.text_changed.connect(func(_value): _refresh_estimate())
	_button(col,"Random mountain",generate_random)
	_button(col,"Default mountain",generate_default)
	hud._note(saved_page,"Select a mountain to preview it.")
	list = ItemList.new()
	list.custom_minimum_size.y = 260
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(load_selected)
	saved_page.add_child(list)
	hud._note(share,"A seed uses Standard richness. Share a mountain file to include custom generation settings.")
	_button(share,"Copy seed",copy_seed,false,true)
	_button(share,"Export mountain file",export_file,false,true)
	_button(share,"Import mountain file",func(): import_dialog.popup_centered_ratio(.72))
	preview_column = VBoxContainer.new()
	preview_column.add_theme_constant_override("separation",12)
	page_columns[0].add_child(preview_column)
	preview = RetainedContent.TerrainPreview.new()
	preview.name = "MountainTerrainPreview"
	preview.font = hud.normal_font
	preview.custom_minimum_size = Vector2(0,400)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_column.add_child(preview)
	hud._note(preview_column,"White: snow · Amber: steep · Dark: rock · Green: trees")
	preview_column.add_child(hud._label("Mountain name",14,hud.LIME))
	name_input = LineEdit.new()
	name_input.placeholder_text = "Name this mountain"
	name_input.max_length = 60
	name_input.custom_minimum_size.y = 44
	name_input.text_changed.connect(func(value):
		if draft: draft.title = value.strip_edges()
	)
	preview_column.add_child(name_input)
	summary = hud._label("Generate or select a mountain to preview it.",14,hud.MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_column.add_child(summary)
	tabs.tab_changed.connect(func(index):
		if preview_column.get_parent()!=page_columns[index]:
			preview_column.reparent(page_columns[index])
			page_columns[index]._fit_columns()
	)
	status = hud._label("",14,hud.LIME)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible = 2
	shell.add_child(status)
	var actions_row = HFlowContainer.new()
	actions_row.name = "MountainActions"
	actions_row.add_theme_constant_override("h_separation",12)
	actions_row.add_theme_constant_override("v_separation",8)
	shell.add_child(actions_row)
	_button(actions_row,"Back",close)
	_button(actions_row,"Ski current",func(): close(); game.start_run(false))
	var generate = _button(actions_row,"GENERATE SEED",generate_seed)
	generate.visible = tabs.current_tab==0
	tabs.tab_changed.connect(func(index): generate.visible = index==0)
	_button(actions_row,"Save mountain",save_draft,false,true)
	_button(actions_row,"Ski this mountain",ski_selected,true,true)
	export_dialog = _file_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	export_dialog.file_selected.connect(func(path):
		if draft: status.text = _result(Store.write_file(path,draft),"Exported a compact mountain file. Send it to a friend.")
	)
	import_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	import_dialog.file_selected.connect(import_file)
	panel.visible = false
	_refresh_actions()

func _button(parent, caption: String, callback: Callable, primary: bool = false, needs_draft: bool = false) -> Button:
	var button = game.hud._button(caption,primary)
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size",16)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	all_buttons.append(button)
	if needs_draft: actions.append(button)
	return button

func _file_dialog(mode: FileDialog.FileMode) -> FileDialog:
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	dialog.filters = PackedStringArray(["*.apexmountain ; Alpine Apex mountain"])
	dialog.title = "Export mountain" if mode==FileDialog.FILE_MODE_SAVE_FILE else "Import mountain"
	# Built-in dialogs keep overwrite confirmation and keyboard focus visible.
	game.hud.root.add_child(dialog)
	return dialog

func open() -> void:
	if panel.visible: return
	return_mode = "paused" if game.active or game.hud.menu_mode=="racing" else game.hud.menu_mode
	game.active = false
	game.hud.hide_menu()
	game.hud.tuning_panel.hide()
	game.hud.debug_panel.hide()
	game.vectors.hide()
	instrument_visibility.clear()
	for control in game.hud.hud_controls:
		instrument_visibility.append(control.visible)
		control.visible = false
	panel.show()
	refresh_saved()
	if game.current_mountain:
		await _set_draft(Definition.from_field(game.field,game.current_mountain.title),game.field)
	elif not draft:
		seed_input.text = "849205174"
		await generate_seed()
	# Common menu navigation restores focus in the retained category.

func close() -> void:
	if busy or not panel.visible: return
	game.hud.feedback.play()
	panel.hide()
	for i in instrument_visibility.size(): game.hud.hud_controls[i].visible = instrument_visibility[i]
	instrument_visibility.clear()
	game.hud.show_menu(return_mode,game.sim.crash_reason if game.sim.crashed else game.Session.format_time(game.session.elapsed))

func generate_seed() -> void:
	if busy: return
	var parsed = Definition.parse_seed(seed_input.text)
	if not parsed.has("seed"):
		status.text = parsed.error
		return
	await _begin_work("Shaping your mountain", "Generating the summit, ridges and downhill faces…")
	var values = generation_settings()
	Estimates.configure(generation_job,parsed.seed,values)
	var field = await _background(Definition.generate.bind(parsed.seed,parsed.version,values,generation_job))
	if field==null:
		_end_work(false)
		status.text = "Generation cancelled. Your previous preview is ready." if generation_job.is_cancelled() else "That mountain could not be generated. Your preview is unchanged."
		return
	Estimates.record(field)
	game.loading.stage("Drawing the terrain preview…")
	await game.loading.draw_frame()
	var adopted = await _set_draft(Definition.from_field(field,"Default Mountain" if parsed.version==Definition.CURRENT_VERSION and parsed.seed==Definition.DEFAULT_SEED and values==Settings.preset() else ""),field)
	_end_work(adopted)
	status.text = "Ready to explore. Save it to keep it in your library." if adopted else "Preview cancelled. Your previous mountain is ready."

func generate_default() -> void:
	if busy: return
	seed_input.text = str(Definition.DEFAULT_SEED)
	_apply_settings(Settings.preset())
	await generate_seed()

func generate_random() -> void:
	if busy: return
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	seed_input.text = str(rng.randi_range(0,Definition.MAX_SEED))
	await generate_seed()

func _set_draft(mountain, field) -> bool:
	var owns_overlay = not busy
	if owns_overlay: await _begin_work("Surveying mountain","Drawing the mountain preview…")
	generation_job.begin_stage("preview")
	var image = await _background(preview.build_image.bind(field,generation_job))
	generation_job.end_stage("preview")
	if image==null or generation_job.is_cancelled():
		if owns_overlay: _end_work(false)
		return false
	draft = mountain
	draft_field = field
	if "generation_settings" in field: _apply_settings(field.generation_settings)
	seed_input.text = str(draft.seed_value) if draft.generator_version==Definition.CURRENT_VERSION else draft.seed_text()
	name_input.text = draft.title
	var vertical: float = field.spawn_point().y-field.sample(0,field.finish_z).height
	var summary_text: String = "Seed %d\n%.2f × %.2f km · %.0f m vertical\n%s" % [field.seed_value,field.bounds().size.x/1000,field.bounds().size.y/1000,vertical,"Six alpine faces · Summit start · Descend any side" if field.is_summit_mountain() else "Ridges · Bowls · Cliffs & snow takeoffs"]
	population_label.text = ""
	if "population" in field:
		population_label.text = "Trees: %d / %d requested\nMinerals: %d / %d requested" % [field.population.trees,field.population.requested_trees,field.population.minerals,field.population.requested_minerals]
		summary_text += "\n%s richness" % Settings.PRESETS[Settings.preset_index(field.generation_settings)]
		if field.population.tree_saturated or field.population.mineral_saturated: summary_text += "\nPlacement reached the available space."
	summary.text = summary_text
	preview.apply_image(field,image)
	_refresh_actions()
	if owns_overlay: _end_work(true)
	return true

func _refresh_actions() -> void:
	if preset_control: preset_control.disabled = busy
	if advanced_toggle: advanced_toggle.disabled = busy
	for control in settings_controls.values(): control.editable = not busy
	seed_input.editable = not busy
	name_input.editable = not busy
	for button in all_buttons: button.disabled = busy or (button in actions and draft==null)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_STOP
	list.focus_mode = Control.FOCUS_NONE if busy else Control.FOCUS_ALL
	for button in tabs.buttons: button.disabled = busy
	for i in tabs.get_tab_count(): tabs.set_tab_disabled(i,busy)

func refresh_saved() -> void:
	saved = store.load_all()
	list.clear()
	for mountain in saved: list.add_item("%s  ·  %d" % [mountain.title,mountain.seed_value])
	status.text = store.warning if not store.warning.is_empty() else ("No saved mountains yet. Generate one, give it a name and save it here." if saved.is_empty() else "%d saved mountains" % saved.size())

func save_draft() -> void:
	if not draft or busy: return
	draft.title = name_input.text.strip_edges()
	var error = store.save(draft)
	if error.is_empty():
		if game.current_mountain and game.current_mountain.identity()==draft.identity():
			game.current_mountain.title = draft.title
			game.hud.set_mountain(game.current_mountain)
		refresh_saved()
	status.text = _result(error,"Saved locally. Saving the same mountain updates its name.")

func load_selected(index: int) -> void:
	if busy or index<0 or index>=saved.size(): return
	await _begin_work("Opening saved mountain", "Reconstructing the terrain from its saved recipe…")
	Estimates.configure(generation_job,saved[index].seed_value,saved[index].generation_settings)
	var result = await _background(saved[index].reconstruct.bind(generation_job))
	game.loading.stage("Drawing the saved mountain preview…")
	await game.loading.draw_frame()
	if result.has("field"): await _set_draft(saved[index],result.field)
	_end_work(result.has("field"))
	status.text = _result(result.error,"Loaded from your library. Ready to ski.")

func copy_seed() -> void:
	if not draft or busy: return
	DisplayServer.clipboard_set(draft.seed_text())
	status.text = "Seed and version copied. Seed-only sharing uses Standard; export the mountain file to share custom richness."

func export_file() -> void:
	if not draft or busy: return
	draft.title = name_input.text.strip_edges()
	var error = Definition.name_error(draft.title)
	if not error.is_empty():
		status.text = error
		return
	export_dialog.current_file = "%s-%d.apexmountain" % [draft.title.validate_filename(),draft.seed_value]
	export_dialog.popup_centered_ratio(.72)

func import_file(path: String) -> void:
	if busy: return
	var parsed = Store.read_file(path)
	if not parsed.has("mountain"):
		status.text = parsed.error
		return
	await _begin_work("Importing mountain", "Checking the recipe and reconstructing its terrain…")
	Estimates.configure(generation_job,parsed.mountain.seed_value,parsed.mountain.generation_settings)
	var result = await _background(parsed.mountain.reconstruct.bind(generation_job))
	game.loading.stage("Checking the imported terrain and drawing its preview…")
	await game.loading.draw_frame()
	var error: String = result.error
	if result.has("field"):
		var adopted = await _set_draft(parsed.mountain,result.field)
		error = store.save(parsed.mountain) if adopted else "Import cancelled."
		if error.is_empty(): refresh_saved()
	_end_work(error.is_empty())
	status.text = _result(error,"Imported and saved locally. Ready to ski.")

func ski_selected() -> void:
	if not draft or busy: return
	draft.title = name_input.text.strip_edges()
	var error = Definition.name_error(draft.title)
	if not error.is_empty():
		status.text = error
		return
	game.load_mountain(draft,draft_field)

func _begin_work(caption: String, message: String) -> void:
	busy = true
	generation_job = Job.new()
	game.loading.attach_job(generation_job)
	_refresh_actions()
	status.text = message
	game.loading.configure_feedback(game.hud.feedback)
	game.loading.begin(caption,message)
	await game.loading.draw_frame()

func _end_work(success: bool) -> void:
	busy = false
	_refresh_actions()
	game.loading.finish()
	_refresh_estimate()
	game.hud.feedback.play("ready" if success else "error")

func _result(error: String, success: String) -> String:
	return success if error.is_empty() else error

func _background(work: Callable):
	return await game.loading.run_data(work,generation_job)

func _exit_tree() -> void:
	if generation_job: generation_job.cancel()

func generation_settings() -> Dictionary:
	var values: Dictionary = {}
	for key in Settings.KEYS: values[key] = roundf(settings_controls[key].value*100)/100.0
	return Settings.canonical(values)

func _build_generation_controls(parent) -> void:
	parent.add_child(game.hud._label("Mountain richness",14,game.hud.LIME))
	preset_control = OptionButton.new()
	preset_control.tooltip_text = "Richness sets requested populations. Terrain, spacing and protected openings can limit the achieved counts."
	for i in Settings.PRESETS.size(): preset_control.add_item(Settings.PRESETS[i]+("  ·  %.1f×" % Settings.MULTIPLIERS[i] if i<4 else ""))
	preset_control.select(1); preset_control.item_selected.connect(_preset_changed); parent.add_child(preset_control)
	advanced_toggle = CheckButton.new(); advanced_toggle.text = "Generation details"; parent.add_child(advanced_toggle)
	advanced_panel = VBoxContainer.new(); parent.add_child(advanced_panel); advanced_panel.hide()
	advanced_toggle.toggled.connect(func(on):
		var focus = advanced_panel.get_viewport().gui_get_focus_owner()
		if not on and focus and advanced_panel.is_ancestor_of(focus): advanced_toggle.grab_focus()
		advanced_panel.visible = on
	)
	var labels = ["Tree population","Mineral density","Snow-feature density","Landform complexity","Tree spacing"]
	for i in Settings.KEYS.size():
		var key: String = Settings.KEYS[i]; var row = HBoxContainer.new(); advanced_panel.add_child(row)
		var label = game.hud._label(labels[i],14); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
		var spin = SpinBox.new(); spin.min_value = .5; spin.max_value = 2 if key=="tree_spacing" else 5; spin.step = .01; spin.value = 1; spin.suffix = "×"
		spin.custom_minimum_size.x = 100; settings_controls[key] = spin; row.add_child(spin)
		spin.value_changed.connect(func(_value):
			if updating_settings: return
			preset_control.select(Settings.preset_index(generation_settings()))
			_refresh_estimate())
	game.hud._note(advanced_panel,"Spacing keeps trunks apart and preserves drop areas and woodland openings. Terrain space can limit populations. Richness changes the mountain independently of graphics quality.")
	population_label = game.hud._note(advanced_panel,"")
	estimates_label = game.hud._label("",12,game.hud.MUTED); estimates_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(estimates_label)
	_refresh_estimate()

func _preset_changed(index: int) -> void:
	if index<4: _apply_settings(Settings.preset(index))
	else: advanced_toggle.button_pressed = true

func _apply_settings(values: Dictionary) -> void:
	updating_settings = true
	for key in Settings.KEYS: settings_controls[key].value = values[key]
	preset_control.select(Settings.preset_index(values)); updating_settings = false
	_refresh_estimate()

func _refresh_estimate() -> void:
	if not estimates_label or busy: return
	var parsed = Definition.parse_seed(seed_input.text if not seed_input.text.is_empty() else str(Definition.DEFAULT_SEED))
	if not parsed.has("seed"): estimates_label.text = "Enter a valid seed for an estimate."; return
	var estimate = Estimates.estimate(parsed.seed,generation_settings())
	estimates_label.text = "Estimated generation %s · then %s to ski\nPeak memory %.1f–%.1f GiB" % [Estimates._range(estimate.generation_s),Estimates._range(estimate.additional_s),estimate.peak_memory_gib.x,estimate.peak_memory_gib.y]
