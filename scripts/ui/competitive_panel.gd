extends RefCounted
## HUD-owned record view. It only reads the selected session.
const RetainedContent = preload("res://scripts/ui/retained_screen_content.gd")
const Session = preload("res://scripts/core/run_session.gd")
var panel: PanelContainer
var tabs: TabContainer
var course: Label
var best: Label
var ghost_toggle: CheckButton
var ghost_info: Label
var splits: Label
var history: Label
var notice: Label
var selector = preload("res://scripts/ui/ghost_selector.gd").new()

func build(hud) -> void:
	panel = hud._panel()
	panel.name = "RecordsWindow"
	var shell = hud._window(panel,980)
	shell.add_theme_constant_override("separation",14)
	shell.add_child(hud._label("Records",28,hud.WHITE))
	tabs = hud._tabs(shell)
	var col = hud._tab(tabs,"Overview")
	var split_page = hud._tab(tabs,"Splits")
	var history_page = hud._tab(tabs,"Run history")
	var ghost_page = hud._tab(tabs,"Ghosts")
	selector.build(hud,ghost_page)
	# Read-only pages still need a controller focus target for long records.
	for index in [1,2]:
		tabs.get_tab_control(index).get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	var columns = RetainedContent.new()
	col.add_child(columns)
	var best_column = VBoxContainer.new()
	best_column.add_theme_constant_override("separation",18)
	columns.add_child(best_column)
	var ghost_column = VBoxContainer.new()
	ghost_column.add_theme_constant_override("separation",18)
	columns.add_child(ghost_column)
	best_column.add_child(hud._label("Personal best",20,hud.WHITE))
	course = hud._label("",16,hud.MUTED)
	course.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	best_column.add_child(course)
	best = hud._label("",38,hud.LIME,true)
	best_column.add_child(best)
	ghost_toggle = CheckButton.new()
	ghost_toggle.text = "Show selected ghosts"
	ghost_toggle.toggled.connect(func(value): hud.ghost_visibility_requested.emit(value))
	ghost_column.add_child(hud._label("Ghosts",20,hud.WHITE))
	ghost_column.add_child(ghost_toggle)
	ghost_info = hud._label("",16,hud.MUTED)
	ghost_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ghost_column.add_child(ghost_info)
	split_page.add_child(hud._label("Cumulative splits",20,hud.WHITE))
	splits = hud._label("",16,hud.WHITE)
	splits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	splits.add_theme_constant_override("line_spacing",5)
	split_page.add_child(splits)
	history_page.add_child(hud._label("Last 20 completed runs",20,hud.WHITE))
	history = hud._label("",16,hud.WHITE)
	history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history.add_theme_constant_override("line_spacing",5)
	history_page.add_child(history)
	notice = hud._label("",13,hud.MUTED)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(notice)
	var close = hud._button("Back")
	close.pressed.connect(func(): hud.close_competition())
	shell.add_child(close)
	panel.visible = false

func refresh(session, ghost_enabled: bool) -> void:
	var free_ski: bool = session.course_id.begins_with("free-ski-")
	course.text = session.race.title if session.race else ("Free ski · create a race to record times" if free_ski else "Laboratory fixture")
	best.text = Session.format_time(session.personal_best)
	ghost_toggle.set_pressed_no_signal(ghost_enabled)
	ghost_toggle.disabled = free_ski
	ghost_info.text = "%d selected ghosts this attempt. Choose Automatic fastest 1–10 or a manual subset on the Ghosts tab. Changes apply next start/retry." % session.reference_ghosts.size()
	selector.refresh(session)
	if free_ski: ghost_info.text = "Free skiing has no personal best or ghost. Create or select a race on this mountain."
	var has_attempt: bool = session.elapsed>0.0
	var reference: Array = session.reference_splits if has_attempt else session.best_splits
	# Build each label's text locally and assign once; every Label.text write re-shapes.
	var splits_text = ""
	for i in range(3):
		if has_attempt:
			splits_text += "%d%% approach\nThis run: %s · Best at start: %s\nDifference: %s\n\n" % [(i+1)*25,_time(session.split_times[i]),_time(reference[i]),Session.format_delta(session.split_delta(i))]
		else:
			splits_text += "%d%% approach\nPersonal best: %s\n\n" % [(i+1)*25,_time(reference[i])]
	if free_ski: splits_text = "Choose a race to record split times."
	splits.text = splits_text
	var history_text = ""
	for row in session.history:
		var date = Time.get_datetime_string_from_unix_time(row.date).replace("T"," ").left(16)+" UTC" if row.date>0 else "Date unavailable"
		var delta = row.time-session.personal_best
		history_text += "%s\n%s · %s · Top speed %s km/h\n\n" % [date,Session.format_time(row.time),"BEST" if absf(delta)<0.0000001 else Session.format_delta(delta),str(roundi(row.peak_kmh)) if row.peak_kmh>0 else "—"]
	if session.history.is_empty(): history_text = "Finish a race eligible for records to begin your history."
	if free_ski: history_text = "Free skiing does not record timed runs. Choose or create a race."
	history.text = history_text
	notice.text = session.save_error if not session.save_error.is_empty() else session.record_warning
	if notice.text.is_empty(): notice.text = session.replay_warning
	if notice.text.is_empty(): notice.text = session.selection_notice
	if notice.text.is_empty() and not free_ski and session.race==null: notice.text = "Lab and automated runs do not replace personal bests or enter race history."
	notice.visible = not notice.text.is_empty()

func _time(value: float) -> String:
	return Session.format_time(value) if value>=0 else "—"
