extends SceneTree
## Headless interface cost probe (task 084514): times focus moves between
## action buttons, settings open/close, interface volume slider steps and the
## records panel refresh on the flat laboratory pad. Output:
## artifacts/interface_cost/<label>.json. Option: --cost-label=NAME.
var label = "probe"
var game

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cost-label="): label = arg.get_slice("=",1)
	set_meta("test_map_fixture","flat-pad")
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	for i in 3: await process_frame
	var hud = game.hud
	game.active = false
	hud.show_menu("paused")
	for i in 3: await process_frame
	var result = {"label":label,"platform":OS.get_name(),"engine":Engine.get_version_info().string}
	# Focus moves between the two primary action buttons re-key their badges.
	var started = Time.get_ticks_usec()
	for i in 200:
		(hud.primary if i%2==0 else hud.crash_restart).grab_focus()
		hud.primary.refresh_prompt(); hud.crash_restart.refresh_prompt()
	result["focus_move_us"] = (Time.get_ticks_usec()-started)/200.0
	started = Time.get_ticks_usec()
	for i in 20:
		hud.open_settings()
		await process_frame
		hud.close_weather()
		await process_frame
	result["settings_open_close_ms"] = (Time.get_ticks_usec()-started)/20000.0
	hud.open_settings()
	await process_frame
	var slider: HSlider = null
	for candidate in hud.weather_panel.find_children("*","HSlider",true,false):
		if candidate.step==0.05 and candidate.max_value==1.0 and candidate.get_parent() is VBoxContainer:
			var index = candidate.get_index()
			if index>0 and candidate.get_parent().get_child(index-1) is Label and candidate.get_parent().get_child(index-1).text=="Interface sound volume": slider = candidate
	if slider:
		var original = slider.value
		started = Time.get_ticks_usec()
		for i in 40: slider.value = float(i%20)*.05
		result["volume_step_us"] = (Time.get_ticks_usec()-started)/40.0
		slider.value = original
	var scale_slider = hud.weather_panel.find_child("UIScale",true,false)
	if scale_slider==null:
		for candidate in hud.weather_panel.find_children("*","HSlider",true,false):
			if candidate.min_value==.85 and candidate.max_value==1.4: scale_slider = candidate
	if scale_slider:
		var original_scale = scale_slider.value
		started = Time.get_ticks_usec()
		for i in 20: scale_slider.value = .9+float(i%5)*.05
		scale_slider.value = original_scale
		result["ui_scale_step_us"] = (Time.get_ticks_usec()-started)/21.0
	hud.close_weather()
	await process_frame
	var session = game.session
	var saved_history = session.history
	session.history = []
	for i in 20: session.history.append({"time":95.0+i,"splits":[24.0,48.0,72.0],"date":1780000000+i*3600,"peak_kmh":110.0+i})
	started = Time.get_ticks_usec()
	for i in 20: hud.competition.refresh(session,true)
	result["records_refresh_us"] = (Time.get_ticks_usec()-started)/20.0
	session.history = saved_history
	started = Time.get_ticks_usec()
	for i in 40: hud.compact_menu.refresh()
	result["compact_menu_refresh_us"] = (Time.get_ticks_usec()-started)/40.0
	DirAccess.make_dir_recursive_absolute("res://artifacts/interface_cost")
	var out = preload("res://tests/test_report.gd").open_write("res://artifacts/interface_cost/%s.json" % label); out.store_string(JSON.stringify(result,"\t")); out.close()
	print("INTERFACE_COST_PROBE ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0)
