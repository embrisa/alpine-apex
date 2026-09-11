extends RefCounted
## Optional same-process native output matrix. No monitor mode/refresh changes,
## no persistence, and restoration of the exact pre-matrix actual window.
const Output = preload("res://scripts/presentation/display_settings.gd")

static func run(suite) -> void:
	var game = suite.game
	var settings = game.display_settings
	suite.case_name = "native_display"
	var screen_pixels = DisplayServer.screen_get_size(suite.root.current_screen)
	if screen_pixels!=suite.PIXELS:
		suite.rows.append({"case":"native_display","status":"skipped","reason":"Native selected-monitor pixels are not 3840x2160; no monitor switch attempted."})
		return
	var saved: Dictionary = settings.snapshot()
	var actual: Dictionary = Output.capture_window(suite.root)
	game.active = false
	game.set_physics_process(false)
	game.hud.show_menu("paused")
	game.hud.open_settings()
	settings.monitor = -1
	settings.frame_generation = false
	settings.apply_viewport(suite.root)
	# Drive real parent UI callbacks, including its real 15-second timeout.
	for action in ["revert","keep","timeout"]:
		if not suite.alive(): break
		suite.case_name = "display_"+action
		print("INTERFACE_PERFORMANCE_BEGIN ",suite.case_name)
		var before = Output.capture_window(suite.root)
		var preferences: Dictionary = settings.display.snapshot()
		var began = Time.get_ticks_msec()
		game.preview_display({"display_mode":"windowed","resolution":Vector2i(1280,720),"monitor":-1})
		await suite.wait_seconds(.5)
		await RenderingServer.frame_post_draw
		var preview_pixels: Vector2i = suite.root.get_texture().get_image().get_size()
		if suite.take_captures: await suite.capture("recovery_"+action)
		suite.check(preview_pixels==Vector2i(1280,720) and suite.root.mode==Window.MODE_WINDOWED,"native preview applies exact client pixels")
		if action=="revert": game.revert_display()
		elif action=="keep":
			game.keep_display()
			suite.check(settings.display.pending.is_empty() and settings.resolution==Vector2i(1280,720),"Keep accepts output without persistence")
			# Restore original using another real preview + Keep transaction.
			game.preview_display(preferences)
			game.keep_display()
		else:
			while suite.alive() and not settings.display.pending.is_empty() and Time.get_ticks_msec()-began<18000:
				await suite.process_frame
			suite.check(settings.display.pending.is_empty(),"real timeout recovered without synthetic clock advancement")
		await suite.wait_seconds(.5)
		var restored = Output.capture_window(suite.root)
		suite.check(restored==before,"exact actual window restoration after "+action)
		suite.check(settings.display.snapshot()==preferences,"display preferences restored after "+action)
		suite.rows.append({"case":suite.case_name,"preview_pixels":preview_pixels,"before":before,"after":restored,
			"elapsed_ms":Time.get_ticks_msec()-began,"pending":settings.display.pending,"preferences_restored":settings.display.snapshot()==preferences,
			"ui_output_viewport":game.hud.root.get_viewport()==suite.root,"outside_measurement":true})
		suite.write_report()
	if suite.alive():
		suite.case_name = "display_native_windowed"
		game.preview_display({"display_mode":"windowed","resolution":screen_pixels,"monitor":-1})
		await suite.wait_seconds(.5)
		suite.check(suite.root.mode in [Window.MODE_WINDOWED,Window.MODE_EXCLUSIVE_FULLSCREEN] and suite.root.borderless and settings.display_mode=="windowed","native-sized Windowed uses an exact borderless client rectangle")
		await suite.verify_pixels()
		if suite.take_captures: await suite.capture("recovery_native_4k")
		game.revert_display()
	# Godot Windows infers EXCLUSIVE_FULLSCREEN from a borderless rectangle
	# equal to the screen, even without requesting exclusive mode. Verify actual
	# pixels, borderless state and working recovery rather than that classification.
	# FG affects only this process's swapchain. Skip unsupported capability;
	# failures still flow to the unconditional restoration below.
	if suite.alive():
		var support: Dictionary = settings.fsr_status()
		if not support.get("frame_generation_supported",false):
			suite.rows.append({"case":"native_fg","status":"skipped","reason":"Native provider reports frame generation unsupported","status_detail":support})
		else:
			for enabled in [false,true,false]:
				if not suite.alive(): break
				suite.case_name = "native_fg_"+("on" if enabled else "off")
				print("INTERFACE_PERFORMANCE_BEGIN ",suite.case_name)
				settings.display_mode = "fullscreen"
				settings.frame_generation = enabled
				settings.apply_viewport(suite.root)
				settings.apply_display(suite.root)
				await suite.wait_seconds(2.0)
				var begin: Dictionary = settings.fsr_status()
				await suite.wait_seconds(2.0)
				var end: Dictionary = settings.fsr_status()
				var generated = int(end.get("generated_frames",0))-int(begin.get("generated_frames",0))
				var rendered = int(end.get("rendered_present_calls",0))-int(begin.get("rendered_present_calls",0))
				suite.check(end.get("frame_generation_active",false)==enabled,"native FG active matches request")
				suite.check(rendered>0 and (generated>=rendered-3 if enabled else generated==0),"separate rendered/generated native counters advance correctly")
				suite.check(str(end.get("error","")).is_empty(),"native FG status reports no error")
				if enabled: suite.check(suite.root.mode in [Window.MODE_WINDOWED,Window.MODE_EXCLUSIVE_FULLSCREEN] and suite.root.borderless,"FG exact-output borderless swapchain")
				var pixels: Vector2i = await suite.verify_pixels()
				suite.rows.append({"case":suite.case_name,"requested":enabled,"begin":begin,"end":end,"rendered_presents":rendered,
					"generated_frames":generated,"actual_pixels":pixels,"window":Output.capture_window(suite.root),
					"monitor_delivery_proven":false,"outside_measurement":true})
				suite.write_report()
	# Unconditional cleanup on every checked failure, independent of alive().
	if not settings.display.pending.is_empty(): game.revert_display()
	settings.restore(saved)
	settings.frame_generation = false
	settings.apply_viewport(suite.root)
	Output._apply_window_state(suite.root,actual)
	game.hud.settings_pages.recovery.hide()
	game.hud.sync_display(settings)
	await suite.process_frame
	suite.check(Output.capture_window(suite.root)==actual,"native matrix final actual window restored")
