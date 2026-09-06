extends Node
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Terrain = preload("res://scripts/world/generated_mountain.gd")
const Store = preload("res://scripts/world/mountain_store.gd")
var game
var store = Store.new()
var panel: PanelContainer
var generation_worker: Thread
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
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 44
	panel.offset_right = -44
	panel.offset_top = 137
	panel.offset_bottom = -64
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",28)
	panel.add_child(row)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = 440
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation",7)
	scroll.add_child(col)
	col.add_child(hud._label("MAKE YOUR MOUNTAIN.",27,hud.WHITE))
	col.add_child(hud._label("One seed. A mountain of decisions.",15,hud.MUTED))
	col.add_child(hud._label("MOUNTAIN SEED",11,hud.LIME,true))
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "849205174"
	seed_input.max_length = 48
	seed_input.custom_minimum_size.y = 38
	seed_input.text_submitted.connect(func(_value): generate_seed())
	col.add_child(seed_input)
	var generate_row = HBoxContainer.new()
	col.add_child(generate_row)
	_button(generate_row,"GENERATE SEED",generate_seed)
	_button(generate_row,"↻ RANDOM MOUNTAIN",generate_random,true)
	_button(col,"TECHNICAL SHOWCASE  ·  SOUTH FACE",generate_showcase)
	col.add_child(hud._label("MOUNTAIN NAME",11,hud.LIME,true))
	name_input = LineEdit.new()
	name_input.placeholder_text = "Name this mountain"
	name_input.max_length = 60
	name_input.custom_minimum_size.y = 38
	name_input.text_changed.connect(func(value):
		if draft: draft.title = value.strip_edges()
	)
	col.add_child(name_input)
	summary = hud._label("",12,hud.MUTED,true)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(summary)
	var ski_row = HBoxContainer.new()
	col.add_child(ski_row)
	_button(ski_row,"SKI THIS MOUNTAIN  ↗",ski_selected,true,true)
	_button(ski_row,"SAVE LOCALLY",save_draft,false,true)
	var share_row = HBoxContainer.new()
	col.add_child(share_row)
	_button(share_row,"COPY SEED",copy_seed,false,true)
	_button(share_row,"EXPORT FILE",export_file,false,true)
	_button(share_row,"IMPORT FILE",func(): import_dialog.popup_centered_ratio(.72))
	col.add_child(hud._label("SAVED MOUNTAINS  /  SELECT TO PREVIEW",11,hud.LIME,true))
	list = ItemList.new()
	list.custom_minimum_size.y = 90
	list.item_selected.connect(load_selected)
	col.add_child(list)
	status = hud._label("",13,hud.LIME)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 38
	col.add_child(status)
	var back_row = HBoxContainer.new()
	col.add_child(back_row)
	_button(back_row,"BACK / ESC",close)
	_button(back_row,"ORIGINAL TEST FACE",func(): close(); game.start_run(true))
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",10)
	row.add_child(right)
	right.add_child(hud._label("READ THE TERRAIN. CHOOSE YOUR LINE.",14,hud.WHITE))
	preview = preload("res://scripts/ui/mountain_preview.gd").new()
	preview.font = hud.normal_font
	preview.custom_minimum_size = Vector2(480,350)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(preview)
	var legend = hud._label("SNOW  ·  AMBER: STEEP  ·  DARK: ROCK  ·  GREEN: TREES\nOptional cliffs and snow takeoffs · Open shoulders to ski around.\nCreate your own race from the pause menu after loading.",12,hud.MUTED)
	right.add_child(legend)
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
		_set_draft(Definition.from_field(game.field,game.current_mountain.title),game.field)
	elif not draft:
		seed_input.text = "849205174"
		await generate_seed()
	seed_input.grab_focus()

func close() -> void:
	if busy: return
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
	busy = true
	status.text = "Shaping the mountain, summit and downhill faces…"
	_refresh_actions()
	await get_tree().process_frame
	var field = await _background(Definition.generate.bind(parsed.seed,parsed.version))
	if field==null:
		busy = false
		_refresh_actions()
		status.text = "That mountain could not be generated. Your preview is unchanged."
		return
	_set_draft(Definition.from_field(field,"Technical Showcase" if parsed.version>=5 else ""),field)
	busy = false
	_refresh_actions()
	status.text = "Ready to explore. Save it to keep it in your library."

func generate_showcase() -> void:
	if busy: return
	seed_input.text = "Mountain Seed: 849205174 / v6"
	await generate_seed()

func generate_random() -> void:
	if busy: return
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	seed_input.text = str(rng.randi_range(0,Definition.MAX_SEED))
	await generate_seed()

func _set_draft(mountain, field) -> void:
	draft = mountain
	draft_field = field
	seed_input.text = str(draft.seed_value) if draft.generator_version==Terrain.GENERATOR_VERSION else draft.seed_text()
	name_input.text = draft.title
	var vertical: float = field.spawn_point().y-field.sample(0,field.finish_z).height
	summary.text = "Mountain Seed: %d / v%d\n%.2f × %.2f km · %.0f m VERTICAL\n%s" % [field.seed_value,field.GENERATOR_VERSION,field.bounds().size.x/1000,field.bounds().size.y/1000,vertical,"Summit start · Descend any side" if field.is_summit_mountain() else "Ridges · Bowls · Cliffs & snow takeoffs"]
	if field.GENERATOR_VERSION>=5:
		summary.text += "\nSouth face · Ridge → twin chutes → rock band → forest\nTwo snow alternatives · Cliff drops are optional"
	preview.set_terrain(field)
	_refresh_actions()

func _refresh_actions() -> void:
	seed_input.editable = not busy
	name_input.editable = not busy
	for button in actions: button.disabled = draft==null or busy

func refresh_saved() -> void:
	saved = store.load_all()
	list.clear()
	for mountain in saved: list.add_item("%s  ·  %d / v%d" % [mountain.title,mountain.seed_value,mountain.generator_version])
	status.text = store.warning

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
	busy = true
	_refresh_actions()
	status.text = "Reconstructing saved mountain…"
	await get_tree().process_frame
	var result = await _background(saved[index].reconstruct)
	if result.has("field"): _set_draft(saved[index],result.field)
	busy = false
	_refresh_actions()
	status.text = _result(result.error,"Loaded from your library. Ready to ski.")

func copy_seed() -> void:
	if not draft or busy: return
	DisplayServer.clipboard_set(draft.seed_text())
	status.text = "Seed and version copied. Paste them into Mountain Seed to reconstruct this mountain."

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
	busy = true
	_refresh_actions()
	status.text = "Checking the mountain file…"
	await get_tree().process_frame
	var result = await _background(parsed.mountain.reconstruct)
	var error: String = result.error
	if result.has("field"):
		_set_draft(parsed.mountain,result.field)
		error = store.save(parsed.mountain)
		if error.is_empty(): refresh_saved()
	busy = false
	_refresh_actions()
	status.text = _result(error,"Imported and saved locally. Ready to ski.")

func ski_selected() -> void:
	if not draft or busy: return
	draft.title = name_input.text.strip_edges()
	var error = Definition.name_error(draft.title)
	if not error.is_empty():
		status.text = error
		return
	game.load_mountain(draft,draft_field)

func _result(error: String, success: String) -> String:
	return success if error.is_empty() else error

func _background(work: Callable):
	# Generation owns its RefCounted data and RNG; no Nodes cross this thread.
	# The library stays responsive and busy until the complete recipe is ready.
	var worker = Thread.new()
	generation_worker = worker
	if worker.start(work)!=OK:
		generation_worker = null
		return work.call()
	while worker.is_alive(): await get_tree().process_frame
	var result = worker.wait_to_finish()
	generation_worker = null
	return result

func _exit_tree() -> void:
	if generation_worker and generation_worker.is_started():
		generation_worker.wait_to_finish()
		generation_worker = null
