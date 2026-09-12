extends RefCounted
## Existing Records tab/navigation; emits session intents, never saves records.
const Session = preload("res://scripts/core/run_session.gd")
var hud
var mode: OptionButton
var summary: Label
var empty: Label
var rows: VBoxContainer
var choices: Dictionary = {}
var swatches: Dictionary = {}
var ids: Array = []
var selected: Array = []

func build(owner, parent: Control) -> void:
	hud = owner
	parent.add_child(hud._label("Race against your fastest recorded runs",20,hud.WHITE))
	summary = hud._label("",16,hud.MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(summary)
	mode = OptionButton.new()
	mode.name = "GhostSelectionMode"
	mode.add_item("Automatic fastest 10")
	mode.add_item("Choose a manual subset")
	mode.item_selected.connect(_mode_changed)
	parent.add_child(mode)
	empty = hud._label("Finish an eligible race to record a ghost. Old time-only results cannot supply a recording.",16,hud.MUTED)
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(empty)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation",12)
	parent.add_child(rows)

func refresh(session) -> void:
	selected = session.ghost_selection.ids.duplicate()
	var automatic: bool = session.ghost_selection.mode=="automatic"
	mode.select(0 if automatic else 1)
	var next_ids: Array = []
	for row in session.ghost_runs: next_ids.append(row.id)
	if next_ids!=ids:
		for child in rows.get_children():
			rows.remove_child(child); child.queue_free()
		choices.clear(); swatches.clear(); ids = next_ids
		for id in ids:
			var line = HBoxContainer.new()
			line.add_theme_constant_override("separation",12)
			rows.add_child(line)
			var swatch = ColorRect.new()
			swatch.custom_minimum_size = Vector2(18,32)
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_child(swatch); swatches[id] = swatch
			var choice = CheckBox.new()
			choice.name = "Ghost_"+id
			choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			choice.toggled.connect(func(value): _toggle(id,value))
			line.add_child(choice); choices[id] = choice
	for i in session.ghost_runs.size():
		var row = session.ghost_runs[i]
		var date = Time.get_datetime_string_from_unix_time(row.date).replace("T"," ").left(16)+" UTC"
		choices[row.id].text = "#%d · %s · %s\nRun %s" % [i+1,Session.format_time(row.time),date,row.id.left(8)]
		choices[row.id].set_pressed_no_signal(automatic or selected.has(row.id))
		choices[row.id].disabled = automatic
		swatches[row.id].color = hud.ghost_colors.get(row.id,Color.WHITE)
	var count = ids.size() if automatic else selected.size()
	summary.text = "%d / 10 selected for next attempt · %d in this attempt.\nChanges apply on next start/retry. G hides or shows the current ghosts immediately. PB deltas always compare with your best at the start." % [count,session.reference_ghosts.size()]
	if not session.selection_notice.is_empty(): summary.text += "\n"+session.selection_notice
	empty.visible = ids.is_empty()
	mode.disabled = session.course_id.begins_with("free-ski-")

func _mode_changed(index: int) -> void:
	# Switching from Automatic begins with its selected available set. A saved
	# empty manual set stays empty until the player explicitly changes it.
	if index==1: selected = ids.duplicate()
	hud.ghost_selection_requested.emit("automatic" if index==0 else "manual",selected)

func _toggle(id: String, value: bool) -> void:
	if value and not selected.has(id): selected.append(id)
	if not value: selected.erase(id)
	hud.ghost_selection_requested.emit("manual",selected.duplicate())
