extends RefCounted
## HUD-owned record view. It only reads the selected session.
const Session = preload("res://scripts/core/run_session.gd")
var panel: PanelContainer
var course: Label
var best: Label
var ghost_toggle: CheckButton
var ghost_info: Label
var splits: Label
var history: Label
var notice: Label

func build(hud) -> void:
	panel = hud._panel()
	panel.name = "RecordsWindow"
	var shell = hud._window(panel,980)
	shell.add_child(hud._label("YOUR PERSONAL BEST",28,hud.WHITE))
	var tabs = hud._tabs(shell)
	var col = hud._tab(tabs,"Overview")
	var split_page = hud._tab(tabs,"Splits")
	var history_page = hud._tab(tabs,"Run history")
	course = hud._label("",14,hud.MUTED)
	course.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(course)
	best = hud._label("",38,hud.LIME,true)
	col.add_child(best)
	ghost_toggle = CheckButton.new()
	ghost_toggle.text = "Show personal-best ghost  /  G"
	ghost_toggle.toggled.connect(func(value): hud.ghost_visibility_requested.emit(value))
	col.add_child(ghost_toggle)
	ghost_info = hud._label("",13,hud.MUTED)
	ghost_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(ghost_info)
	split_page.add_child(hud._label("CUMULATIVE SPLITS  /  FREE ROUTE CHOICE",12,hud.LIME,true))
	splits = hud._label("",13,hud.WHITE,true)
	splits.add_theme_constant_override("line_spacing",5)
	split_page.add_child(splits)
	history_page.add_child(hud._label("LAST 20 COMPLETED RUNS  /  LOCAL TIMES",12,hud.LIME,true))
	history = hud._label("",12,hud.WHITE,true)
	history.add_theme_constant_override("line_spacing",5)
	history_page.add_child(history)
	notice = hud._label("",13,hud.MUTED)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(notice)
	var close = hud._button("BACK / ESC")
	close.pressed.connect(func(): hud.close_competition())
	shell.add_child(close)
	panel.visible = false

func refresh(session, ghost_enabled: bool) -> void:
	var free_ski: bool = session.course_id.begins_with("free-ski-")
	course.text = session.race.title if session.race else ("Free ski · create a race to record times" if free_ski else "Laboratory fixture")
	best.text = Session.format_time(session.personal_best)
	ghost_toggle.set_pressed_no_signal(ghost_enabled)
	ghost_info.text = "Cyan ghost follows your best recorded line. It has no collision." if session.best_replay else "Set a new personal best to record a ghost. Older best times are retained."
	if free_ski: ghost_info.text = "Free skiing has no personal best or ghost. Create or select a race on this mountain."
	var has_attempt: bool = session.elapsed>0.0
	var reference: Array = session.reference_splits if has_attempt else session.best_splits
	splits.text = "APPROACH       THIS RUN        PB AT START      DIFFERENCE\n" if has_attempt else "APPROACH       PERSONAL BEST\n"
	for i in range(3):
		if has_attempt:
			splits.text += "%3d%%         %s    %s    %s\n" % [(i+1)*25,_time(session.split_times[i]),_time(reference[i]),Session.format_delta(session.split_delta(i))]
		else:
			splits.text += "%3d%%         %s\n" % [(i+1)*25,_time(reference[i])]
	history.text = "DATE / UTC         RUN TIME      VS BEST    TOP km/h\n"
	for row in session.history:
		var date = Time.get_datetime_string_from_unix_time(row.date).replace("T"," ").left(16) if row.date>0 else "Earlier record  "
		var delta = row.time-session.personal_best
		history.text += "%s   %s  %9s  %s\n" % [date,Session.format_time(row.time),"BEST" if absf(delta)<0.0000001 else Session.format_delta(delta),str(roundi(row.peak_kmh)) if row.peak_kmh>0 else "—"]
	if session.history.is_empty(): history.text = "Finish a ranked race to begin your history."
	notice.text = session.save_error if not session.save_error.is_empty() else session.record_warning
	if notice.text.is_empty(): notice.text = session.replay_warning
	if notice.text.is_empty(): notice.text = "R / △ instantly retries this race. Lab and automated runs do not replace your best or enter this history."

func _time(value: float) -> String:
	return Session.format_time(value) if value>=0 else "     —    "
