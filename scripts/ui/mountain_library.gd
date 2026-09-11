extends Node
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
var updating_settings: bool = false
var tabs: TabContainer
var all_buttons: Array[Button] = []
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
	shell.add_child(hud._label("FIND YOUR NEXT MOUNTAIN.",28,hud.WHITE))
	var row = HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",24)
	shell.add_child(row)
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 445
	left.add_theme_constant_override("separation",10)
	row.add_child(left)
	tabs = hud._tabs(left)
	var col = hud._tab(tabs,"Create")
	col.add_theme_constant_override("separation",10)
	var saved_page = hud._tab(tabs,"Saved")
	var share = hud._tab(tabs,"Share")
	hud._note(col,"One seed. A mountain of decisions.")
	col.add_child(hud._label("MOUNTAIN SEED",11,hud.LIME,true))
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "849205174"
	seed_input.max_length = 48
	seed_input.custom_minimum_size.y = 38
	seed_input.text_submitted.connect(func(_value): generate_seed())
	col.add_child(seed_input)
	_build_generation_controls(col)
	seed_input.text_changed.connect(func(_value): _refresh_estimate())
	var generate_row = HBoxContainer.new()
	col.add_child(generate_row)
	_button(generate_row,"GENERATE SEED",generate_seed)
	_button(generate_row,"↻ RANDOM MOUNTAIN",generate_random,true)
	_button(col,"DEFAULT MOUNTAIN  ·  ALL FACES",generate_default)
	hud._note(saved_page,"Select a saved mountain to reconstruct its preview.")
	list = ItemList.new()
	list.custom_minimum_size.y = 200
	list.item_selected.connect(load_selected)
	saved_page.add_child(list)
	hud._note(share,"A seed on its own uses Standard richness. Export the mountain file to share all custom settings and reproduce this mountain.")
	_button(share,"COPY SEED",copy_seed,false,true)
	_button(share,"EXPORT MOUNTAIN FILE",export_file,false,true)
	_button(share,"IMPORT MOUNTAIN FILE",func(): import_dialog.popup_centered_ratio(.72))
	status = hud._label("",14,hud.LIME)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 38
	shell.add_child(status)
	var back_row = HBoxContainer.new()
	back_row.add_theme_constant_override("separation",12)
	shell.add_child(back_row)
	_button(back_row,"BACK / ESC",close)
	_button(back_row,"FREE SKI CURRENT MOUNTAIN",func(): close(); game.start_run(false))
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",10)
	row.add_child(right)
	right.add_child(hud._label("READ THE TERRAIN. CHOOSE YOUR LINE.",14,hud.WHITE))
	preview = preload("res://scripts/ui/mountain_preview.gd").new()
	preview.font = hud.normal_font
	preview.custom_minimum_size = Vector2(400,180)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(preview)
	hud._note(right,"SNOW · AMBER: STEEP · DARK: ROCK · GREEN: TREES")
	right.add_child(hud._label("MOUNTAIN NAME",11,hud.LIME,true))
	name_input = LineEdit.new()
	name_input.placeholder_text = "Name this mountain"
	name_input.max_length = 60
	name_input.custom_minimum_size.y = 40
	name_input.text_changed.connect(func(value):
		if draft: draft.title = value.strip_edges()
	)
	right.add_child(name_input)
	summary = hud._label("Generate or select a mountain to see its details.",12,hud.MUTED,true)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(summary)
	var ski_row = HBoxContainer.new()
	ski_row.add_theme_constant_override("separation",12)
	right.add_child(ski_row)
	_button(ski_row,"SKI THIS MOUNTAIN  ↗",ski_selected,true,true)
	_button(ski_row,"SAVE LOCALLY",save_draft,false,true)
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
	button.custom_minimum_size.y = 38
	button.add_theme_font_size_override("font_size",12)
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
	tabs.get_tab_bar().grab_focus()

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
	summary.text = "Mountain Seed: %d / v%d\n%.2f × %.2f km · %.0f m VERTICAL\n%s" % [field.seed_value,field.GENERATOR_VERSION,field.bounds().size.x/1000,field.bounds().size.y/1000,vertical,"Six alpine faces · Summit start · Descend any side" if field.is_summit_mountain() else "Ridges · Bowls · Cliffs & snow takeoffs"]
	if "population" in field:
		summary.text += "\n%s richness · Trees: %d / %d requested\nMinerals: %d / %d requested" % [Settings.PRESETS[Settings.preset_index(field.generation_settings)],field.population.trees,field.population.requested_trees,field.population.minerals,field.population.requested_minerals]
		if field.population.tree_saturated or field.population.mineral_saturated: summary.text += "\nPlacement reached the available space."
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
	for i in tabs.get_tab_count(): tabs.set_tab_disabled(i,busy)

func refresh_saved() -> void:
	saved = store.load_all()
	list.clear()
	for mountain in saved: list.add_item("%s  ·  %d / v%d" % [mountain.title,mountain.seed_value,mountain.generator_version])
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
	parent.add_child(game.hud._label("MOUNTAIN RICHNESS",11,game.hud.LIME,true))
	preset_control = OptionButton.new()
	preset_control.tooltip_text = "Richness sets requested populations. Terrain, spacing and protected openings can limit the achieved counts."
	for i in Settings.PRESETS.size(): preset_control.add_item(Settings.PRESETS[i]+("  ·  %.1f×" % Settings.MULTIPLIERS[i] if i<4 else ""))
	preset_control.select(1); preset_control.item_selected.connect(_preset_changed); parent.add_child(preset_control)
	advanced_toggle = CheckButton.new(); advanced_toggle.text = "Advanced generation controls"; parent.add_child(advanced_toggle)
	advanced_panel = VBoxContainer.new(); parent.add_child(advanced_panel); advanced_panel.hide()
	advanced_toggle.toggled.connect(func(on): advanced_panel.visible = on)
	var labels = ["Tree population","Mineral density","Snow-feature density","Landform complexity","Tree spacing"]
	for i in Settings.KEYS.size():
		var key: String = Settings.KEYS[i]; var row = HBoxContainer.new(); advanced_panel.add_child(row)
		var label = game.hud._label(labels[i],13); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
		var spin = SpinBox.new(); spin.min_value = .5; spin.max_value = 2 if key=="tree_spacing" else 5; spin.step = .01; spin.value = 1; spin.suffix = "×"
		spin.custom_minimum_size.x = 100; settings_controls[key] = spin; row.add_child(spin)
		spin.value_changed.connect(func(_value):
			if updating_settings: return
			preset_control.select(Settings.preset_index(generation_settings()))
			_refresh_estimate())
	game.hud._note(advanced_panel,"Spacing keeps trunks apart and preserves drop areas and woodland openings. Richness changes the mountain independently of graphics quality.")
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
	estimates_label.text = Estimates.label(Estimates.estimate(parsed.seed,generation_settings()))
