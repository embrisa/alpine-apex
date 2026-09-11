extends SceneTree
## Native UI art review without terrain generation, saves or ranked sessions.
const Art = preload("res://scripts/ui/alpine_art.gd")
var hud
var loading
var failures: Array[String] = []
var captures: Array = []
var report: Dictionary = {}
var rendered: bool = false
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, caption: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",caption)
	if not value: failures.append(caption)

func settle() -> void:
	for i in 8: await process_frame
	if rendered: await create_timer(0.25).timeout

func capture(caption: String) -> void:
	await settle()
	if not rendered: return
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	image.save_png("res://artifacts/interface_art/%s.png" % caption)
	captures.append({"name":caption,"pixels":[image.get_width(),image.get_height()]})

func run() -> void:
	rendered = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute("res://artifacts/interface_art")
	root.content_scale_size = Vector2i(1440,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = Vector2i(1920,1080)
	Engine.max_fps = 120
	hud = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	hud.feedback.muted = true
	hud.feedback.persist = false
	hud.feedback.reduced_motion = true
	loading = load("res://scripts/ui/loading_overlay.gd").new()
	root.add_child(loading)
	await settle()
	if "--loading-audio-only" in OS.get_cmdline_user_args():
		check(rendered,"Audio review requires the native audio driver")
		if rendered: await review_loading_audio()
		await finish_review()
		return
	await review_menu_atmosphere()
	if "--menu-atmosphere-only" in OS.get_cmdline_user_args():
		await finish_review()
		return
	await review_loading_behavior()
	check(hud.has_menu_background() and hud.root.find_child("TitlePhotography",true,false)==null,"Title leaves the world visible without photography")
	check(not hud.hero_logo.visible and hud.header_logo.is_visible_in_tree(),"Title presents one compact header logo")
	check(hud.hud_controls.all(func(control):return not control.visible),"Skiing instruments do not overlap title artwork")
	hud.toggle_instruments()
	check(hud.hud_controls.all(func(control):return not control.visible),"The instrument shortcut cannot draw telemetry over the title artwork")
	hud.hide_menu()
	check(hud.hud_controls.all(func(control):return not control.visible),"Hidden-instrument preference survives leaving the title")
	hud.toggle_instruments()
	hud.show_menu("title")
	for dimensions in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(3840,2160)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(hud.menu.get_global_rect()),"Menu fits %s" % dimensions)
		check(hud.menu.get_global_rect().encloses(hud.primary.get_global_rect()),"Drop In fits %s" % dimensions)
		await capture("menu_%dx%d" % [dimensions.x,dimensions.y])
	_select_tab(hud.menu_tabs,"Explore")
	await capture("explore_4k")
	# Focus the visible Settings opener before testing Back restoration.
	_select_tab(hud.menu_tabs,"Tools")
	hud.weather_button.grab_focus()
	hud.open_settings()
	_select_tab(hud.settings_tabs,"Display")
	await settle()
	check(hud.has_menu_background() and not hud.hero_logo.visible,"Settings retains live background context with compact brand")
	await capture("settings_4k")
	hud.close_weather()
	await settle()
	check(hud.weather_button.has_focus(),"Settings Back restores keyboard focus")
	await review_controls()
	hud.hide_menu()
	check(not hud.has_menu_background() and not hud.menu_fade.visible,"Drop In releases the menu background fade")
	for id in ["speed","state","reserve","location","performance","run"]:
		check(hud.widget_layout.widgets[id].node.is_visible_in_tree(),"Default free-ski instrument is restored: "+id)
	for id in ["time","progress","split","debug"]:
		check(not hud.widget_layout.widgets[id].node.is_visible_in_tree(),"Race-only and opt-in instruments stay hidden during free skiing: "+id)
	hud.show_menu("paused")
	check(hud.has_menu_background() and not hud.hero_logo.visible,"Pause uses live mountain coverage with compact branding")
	hud.show_menu("title")
	await settle()
	hud.primary.grab_focus()
	var seen: Array[int] = []
	set_meta("alpine_loading_photo",0) # Deterministic captures; normal startup varies.
	for i in Art.PHOTOS.size():
		loading.reduced_motion = false
		loading.begin("Preparing your descent", "Shaping the mountain, forests and powder…")
		var index: int = loading.artwork.photo_index
		check(index not in seen,"A different photograph for loading job %d" % (i+1))
		seen.append(index)
		check(loading.artwork.texture != null,"Photograph %d loads from an imported resource" % index)
		loading.stage("Preparing the rider, camera and interface…")
		check(loading.artwork.photo_index == index and loading.pulse.visible,"Stage changes keep the photograph and honest indeterminate feedback")
		await capture("loading_%02d_4k" % index)
		loading.set_process(false)
		for seconds in [0.0,6.0,12.0,18.0]:
			loading.artwork.set_visual_time(seconds)
			loading.snow.update_motion(seconds,true)
			await capture("atmosphere_%02d_t%02d_4k" % [index,int(seconds)])
		loading.artwork.set_visual_time(0.0) # Each performance sample stays within one photo cycle.
		loading.set_process(true)
		if rendered and i in [0,2]:
			loading.atmosphere_enabled = false
			await measure_interface()
			var without: Dictionary = report.performance.duplicate(true)
			loading.atmosphere_enabled = true
			await measure_interface()
			var with_effects: Dictionary = report.performance.duplicate(true)
			var added_gpu: float = with_effects.gpu_ms.mean-without.gpu_ms.mean
			if not report.has("atmosphere_comparison"): report.atmosphere_comparison = {}
			report.atmosphere_comparison["wide" if i==0 else "framed"] = {"off":without,"on":with_effects,"added_gpu_ms":added_gpu}
			check(added_gpu < 1.0,"Loading atmosphere adds less than 1 ms GPU at native 4K for photo %d" % index)
		if i == 0:
			for percent in [0.0,0.01,50.0,100.0]:
				loading.stage("Preparing terrain sections",percent)
				await capture("progress_%s_4k" % str(percent).replace(".","_"))
				check(is_equal_approx(loading.bar.value,percent) and not loading.pulse.visible,"Determinate progress retains its actual value: %s" % percent)
			loading.stage("Preparing terrain sections")
			loading.reduced_motion = true
			loading._process(0.5)
			check(is_equal_approx(loading.pulse.position.x,(loading.bar.size.x-loading.pulse.size.x)*0.5),"Reduced motion keeps the loading pulse stationary")
			loading.stage("Ready. Finding your fall line…",100.0)
			check(not loading.pulse.visible and loading.bar.value == 100.0,"Known completion uses the real progress fill")
		loading.finish()
		check(loading.artwork.texture == null and not loading.busy,"Loading completion releases its photograph")
		check(hud.primary.has_focus(),"Loading completion restores keyboard focus")
	await review_loading_layouts()
	if rendered: await review_light_animation()
	if rendered and "--loading-audio-preview" in OS.get_cmdline_user_args(): await review_loading_audio()
	await finish_review()

func finish_review() -> void:
	report.checks = checks
	report.failures = failures
	report.captures = captures
	report.rendered = rendered
	report.engine = Engine.get_version_info().string
	var suffix = "native_audio" if "--loading-audio-only" in OS.get_cmdline_user_args() else ("native" if rendered else "headless")
	if "--menu-atmosphere-only" in OS.get_cmdline_user_args(): suffix = "menu_"+suffix
	var file = FileAccess.open("res://artifacts/interface_art/review_%s.json" % suffix,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("INTERFACE_ART_RESULTS ",JSON.stringify(report))
	hud.queue_free()
	loading.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func review_menu_atmosphere() -> void:
	# Camera movement is reviewed with the real world in menu_camera_playtest.gd.
	check(hud.root.find_child("TitlePhotography",true,false)==null,"Menus never instantiate a photographic backdrop")
	var selection = Art.new()
	selection.photo_rng.seed = 271828
	var seen: Array[int] = []
	for step in Art.PHOTOS.size()*2:
		var previous = selection.photo_index
		var chosen = selection.next_photo(false)
		check(chosen!=previous,"Loading photo shuffle avoids an immediate repeat")
		if step%Art.PHOTOS.size()==0: seen.clear()
		check(chosen not in seen,"Loading exhausts all nine photographs before repeating")
		seen.append(chosen)
		selection.show_photo(chosen)
	selection.free()
	hud.feedback.reduced_motion = false
	for kind in ["title","paused","crashed","finished"]:
		hud.show_menu(kind,"Live menu review")
		check(hud.has_menu_background() and not hud.menu_fade.visible,"%s keeps its world background unobstructed" % kind)
	hud.set_background_fade(0.5)
	check(hud.menu_fade.visible and hud.menu_fade.mouse_filter==Control.MOUSE_FILTER_IGNORE,"World fade never intercepts menu input")
	check(hud.root.get_children().find(hud.menu_fade)<hud.root.get_children().find(hud.menu),"World fades draw beneath menu controls")
	hud.feedback.reduced_motion = true
	check(not hud.menu_fade.visible,"Reduced motion cancels an in-progress world fade")
	hud.hide_menu()
	check(not hud.has_menu_background() and not hud.menu_fade.visible,"Leaving menus clears world fades")
	hud.show_menu("title")
	hud.root.hide()
	check(not hud.has_menu_background(),"Hidden HUD does not activate a menu background")
	hud.root.show()
	check(hud.has_menu_background(),"Showing the HUD restores menu coverage")

func review_loading_behavior() -> void:
	var early = load("res://scripts/ui/loading_overlay.gd").new()
	root.add_child(early)
	early.begin("Initial layout","Before the first container layout")
	check(early.pulse.position.x>=0.0 and early.bar.clip_contents,"The first loading frame cannot draw its pulse outside the progress track")
	early.finish()
	early.queue_free()
	var defaults = loading.Feedback.preferences_from_config(ConfigFile.new())
	check(defaults.loading_ambience and not defaults.muted and not defaults.reduced_motion,"Absent interface preferences enable wind and full motion")
	var config = ConfigFile.new()
	config.set_value("ui","volume",0.25)
	config.set_value("ui","muted",true)
	config.set_value("ui","loading_ambience",false)
	loading.apply_preferences(loading.Feedback.preferences_from_config(config))
	check(loading.sound_muted and not loading.loading_ambience and loading.sound_volume==0.25,"Cold-start loader reads the shared preference schema")
	loading.configure_feedback(hud.feedback)
	hud.feedback.reduced_motion = false
	loading.begin("Loading behavior fixture","Unknown work")
	loading.set_process(false)
	var initial_photo: int = loading.artwork.photo_index
	var initial_started: int = loading.started
	var initial_tip: String = loading.tip.text
	loading._process(20.0)
	check(loading.artwork.visual_time <= 0.05 and loading.phase <= 0.05,"A stalled frame advances presentation by at most 50 ms")
	var before_time: float = loading.artwork.visual_time
	loading.begin("Still loading","Another stage")
	loading.set_process(false)
	check(loading.started==initial_started and loading.artwork.photo_index==initial_photo and loading.artwork.visual_time==before_time,"Repeated begin preserves job time, photo and motion")
	loading.artwork.set_visual_time(23.99)
	loading._process(0.02)
	check(loading.artwork.photo_index!=initial_photo and loading.started==initial_started and loading.tip.text==initial_tip,"A full loading drift cycle changes photos without restarting the job or tip")
	check(loading.snow.motes.size()==32 and loading.snow.visible,"Atmospheric loading uses exactly 32 visible motes")
	loading._update_wait_feedback(7.99,0.0)
	check(loading.elapsed.text.is_empty() and loading.tip.text==initial_tip,"Short waits show one stable tip and no timer")
	loading._update_wait_feedback(8.0,0.0)
	check(loading.elapsed.text=="8 s elapsed" and loading.tip.text!=initial_tip and loading.outgoing_tip.visible,"Eight seconds rotates the tip and reveals elapsed time")
	loading._update_wait_feedback(8.125,0.125)
	check(is_equal_approx(loading.tip.modulate.a,0.5) and is_equal_approx(loading.outgoing_tip.modulate.a,0.5),"Tips crossfade together over 250 ms")
	loading._update_wait_feedback(8.9,0.125)
	check(loading.elapsed.text=="8 s elapsed" and not loading.outgoing_tip.visible,"Timer updates only on whole seconds and the tip fade completes")
	var current_tip: String = loading.tip.text
	loading.stage("Known sections",43.0)
	check(loading.tip.text==current_tip and loading.bar.value==43.0 and not loading.pulse.visible,"Stage updates retain the tip and report actual progress")
	hud.feedback.reduced_motion = true
	loading._process(1.0)
	loading._update_wait_feedback(16.0,0.0)
	check(loading.reduced_motion and not loading.snow.visible and not loading.artwork.material.get_shader_parameter("animate_loading"),"Live reduced-motion preference freezes artwork and removes motes")
	check(loading.tip.modulate.a==1.0 and not loading.outgoing_tip.visible,"Reduced motion changes tips without fading")
	check(not hud.menu_fade.visible,"Menus also suppress world fades with reduced motion")
	hud.feedback.loading_ambience = false
	check(not loading.loading_ambience and not loading.ambience.playing,"The separate wind preference propagates immediately")
	hud.feedback.volume = 0.0
	check(loading.sound_volume==0.0 and loading.ambience.stream==null,"Zero interface volume releases loading audio")
	loading.finish()
	check(not loading.is_processing() and not loading.snow.visible and loading.artwork.texture==null,"Completion stops visual processing and releases the photograph")
	loading.finish()
	check(not loading.busy,"Repeated finish is harmless")
	hud.feedback.volume = 0.55
	hud.feedback.loading_ambience = true
	hud.feedback.reduced_motion = true

func review_loading_layouts() -> void:
	loading.reduced_motion = true
	loading.begin("Preparing your descent","Preparing the rider, camera and interface…")
	loading.set_process(false)
	for dimensions in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(3840,2160)]:
		root.size = dimensions
		await settle()
		loading._update_wait_feedback(0.0,0.0)
		await settle()
		var original_tip: Rect2 = loading.tip.get_global_rect()
		loading._update_wait_feedback(12.0,0.0)
		await settle()
		check(loading.tip.get_global_rect().is_equal_approx(original_tip),"Timer reveal preserves loading layout at %s" % dimensions)
		check(root.get_visible_rect().encloses(loading.title.get_global_rect()) and root.get_visible_rect().encloses(original_tip),"Loading text fits %s" % dimensions)
		await capture("loading_reduced_%dx%d" % [dimensions.x,dimensions.y])
	loading.finish()

func review_loading_audio() -> void:
	# An isolated native audio bus records the actual fades and loop, not a mock.
	loading.configure_feedback(hud.feedback)
	loading.audio_enabled = true
	AudioServer.add_bus()
	var bus = AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,"LoadingReview")
	var recorder = AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus,recorder)
	loading.ambience.bus = "LoadingReview"
	hud.feedback.muted = false
	hud.feedback.loading_ambience = true
	hud.feedback.volume = 0.55
	var shared = load(loading.WindAudio.FOREST_01)
	var original_loop = shared.loop
	recorder.set_recording_active(true)
	loading.begin("Wind review","Loop and fade recording")
	var private_stream = weakref(loading.ambience.stream)
	check(loading.ambience.playing and loading.ambience.stream!=shared and shared.loop==original_loop,"Loading owns a private forest wind stream and leaves the shared asset unchanged")
	check(absf(shared.get_length()-139.52)<0.01 and loading.ambience.stream.loop_offset==0.25,"The full stereo forest recording uses its prepared 250 ms loop overlap")
	check(FileAccess.get_sha256("res://art_source/audio/wind/wind_forest_01.wav")=="f772b858f7f78431b04ea0151cea1dadaab2a036cbd0da12673cc8e4d1bda01e","The valuable source recording is preserved byte for byte")
	await create_timer(0.95).timeout
	check(absf(loading.ambience.volume_db-(loading.WindAudio.LOADING_VOLUME_DB+linear_to_db(0.55)))<0.1,"Forest wind reaches its calibrated quiet level scaled by Interface volume")
	var playback: float = loading.ambience.get_playback_position()
	loading.begin("Same wind review","Repeated begin")
	check(loading.ambience.stream==private_stream.get_ref() and loading.ambience.get_playback_position()>=playback,"Repeated begin retains the same wind playback")
	await create_timer(6.0).timeout
	loading.finish()
	check(not loading.busy and not loading.overlay.visible,"Audio fade-out does not hold the loading screen open")
	await create_timer(0.25).timeout
	check(not loading.ambience.playing and loading.ambience.stream==null and private_stream.get_ref()==null,"Fade-out stops playback and releases the private stream")
	recorder.set_recording_active(false)
	var recording = recorder.get_recording()
	if recording:
		recording.save_to_wav("res://artifacts/interface_art/loading_wind_review.wav")
	loading.begin("Forest loop review","Checking the prepared seam")
	await create_timer(0.85).timeout
	loading.ambience.seek(shared.get_length()-0.4)
	await create_timer(1.0).timeout
	var loop_position: float = loading.ambience.get_playback_position()
	check(loading.ambience.playing and loop_position>=0.25 and loop_position<2.0,"The forest wind wraps to the prepared loop offset without stopping")
	loading.finish()
	loading.begin("Fast new job","Wind lifecycle")
	await create_timer(0.1).timeout
	hud.feedback.volume = 0.2
	await create_timer(0.2).timeout
	check(absf(loading.ambience.volume_db-(loading.WindAudio.LOADING_VOLUME_DB+linear_to_db(0.2)))<0.1,"Volume changes during fade-in retarget the live wind")
	loading.finish()
	loading.begin("Replacement job","Interrupt fade-out")
	await create_timer(0.3).timeout
	check(loading.busy and loading.ambience.playing,"A new job cancels the old fade-out callback")
	hud.feedback.muted = true
	check(not loading.ambience.playing and loading.ambience.stream==null,"Global mute immediately stops and releases wind")
	hud.feedback.muted = false
	hud.feedback.loading_ambience = false
	check(not loading.ambience.playing,"Wind switch silences ambience independently of UI cues")
	hud.feedback.loading_ambience = true
	hud.feedback.volume = 0.0
	check(not loading.ambience.playing,"Zero interface volume stops live wind")
	loading.finish()
	loading.audio_enabled = false
	loading.ambience.bus = "Master"
	AudioServer.remove_bus(bus)
	hud.feedback.volume = 0.55
	hud.feedback.muted = true
	hud.feedback.loading_ambience = true
	var transient = load("res://scripts/ui/loading_overlay.gd").new()
	root.add_child(transient)
	transient.audio_enabled = true
	transient.begin("Teardown fixture","Wind cleanup")
	var player_ref = weakref(transient.ambience)
	transient.queue_free()
	await process_frame
	await process_frame
	check(player_ref.get_ref()==null,"Scene teardown frees the loading wind player")

func review_light_animation() -> void:
	set_meta("alpine_loading_photo",4) # Framed p9: photograph is stationary inside its frame.
	loading.reduced_motion = false
	loading.begin("Light movement review","Stationary print, animated light")
	loading.set_process(false)
	loading.snow.update_motion(0.0,false)
	var frames: Array[Image] = []
	for seconds in [0.0,12.0]:
		loading.artwork.set_visual_time(seconds)
		await settle()
		await RenderingServer.frame_post_draw
		frames.append(root.get_texture().get_image())
	var dimensions = frames[0].get_size()
	var print_region = Rect2i(Vector2i(dimensions.x*0.66,dimensions.y*0.15),Vector2i(dimensions.x*0.14,dimensions.y*0.65))
	check(frames[0].get_region(print_region).get_data()!=frames[1].get_region(print_region).get_data(),"Rays and lens flare move independently across a stationary framed photo")
	frames.clear()
	loading.reduced_motion = true
	for seconds in [0.0,12.0]:
		loading.artwork.set_visual_time(seconds)
		await settle()
		await RenderingServer.frame_post_draw
		frames.append(root.get_texture().get_image())
	check(frames[0].get_data()==frames[1].get_data(),"Reduced motion produces identical rendered pixels at different animation times")
	loading.finish()

func review_controls() -> void:
	# A native control gallery exposes states hidden in ordinary menu screenshots.
	hud.menu.hide()
	hud.hero_logo.hide()
	var panel = hud._panel()
	var column = hud._window(panel,1040)
	column.add_child(hud._label("ALPINE APEX / CONTROL REVIEW",24))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	column.add_child(row)
	var normal = hud._button("Normal")
	var primary = hud._button("Primary",true)
	var pressed = hud._button("Pressed")
	pressed.toggle_mode = true
	pressed.set_pressed_no_signal(true)
	var disabled = hud._button("Disabled",true)
	disabled.disabled = true
	var focused = hud._button("Keyboard focus")
	for button in [normal,primary,pressed,disabled,focused]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	var fields = HBoxContainer.new()
	fields.add_theme_constant_override("separation",16)
	column.add_child(fields)
	var edit = LineEdit.new()
	edit.text = "Mountain name / sharp edges"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(edit)
	var option = OptionButton.new()
	for value in ["High","Balanced","Low"]: option.add_item(value)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(option)
	var swatch = ColorPickerButton.new()
	swatch.color = Color("a5dced")
	swatch.custom_minimum_size = Vector2(90,30)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fields.add_child(swatch)
	var toggles = HBoxContainer.new()
	toggles.add_theme_constant_override("separation",20)
	column.add_child(toggles)
	for enabled in [false,true]:
		var toggle = CheckButton.new()
		toggle.text = "Enabled" if enabled else "Disabled"
		toggle.set_pressed_no_signal(enabled)
		toggles.add_child(toggle)
		var check_box = CheckBox.new()
		check_box.text = "Selected" if enabled else "Unselected"
		check_box.set_pressed_no_signal(enabled)
		toggles.add_child(check_box)
	var slider = HSlider.new()
	slider.value = 42
	slider.custom_minimum_size.y = 32
	column.add_child(slider)
	var text = TextEdit.new()
	text.text = "Shared race code\nAngular fields retain native text selection, scrolling and editing."
	text.custom_minimum_size.y = 90
	column.add_child(text)
	var list = ItemList.new()
	list.custom_minimum_size.y = 90
	for i in 12: list.add_item("Mountain %02d / saved locally" % (i+1))
	list.select(1)
	column.add_child(list)
	var dialog = FileDialog.new()
	dialog.title = "Import mountain / control review"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.current_dir = "res://examples/mountains"
	dialog.filters = PackedStringArray(["*.apexmountain ; Alpine Apex mountain"])
	panel.add_child(dialog)
	for dimensions in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(3840,2160)]:
		root.size = dimensions
		await settle()
		focused.grab_focus()
		check(root.get_visible_rect().encloses(panel.get_global_rect()),"Control gallery fits %s" % dimensions)
		check(panel.get_global_rect().encloses(list.get_global_rect()),"Gallery content fits %s" % dimensions)
		await capture("controls_%dx%d" % [dimensions.x,dimensions.y])
	var initial = primary.get_global_rect()
	primary.grab_focus()
	await settle()
	check(primary.has_focus() and primary.get_global_rect().is_equal_approx(initial),"Keyboard focus does not move or resize the action")
	var mouse = InputEventMouseMotion.new()
	mouse.position = primary.get_global_rect().get_center()
	root.push_input(mouse,true)
	await settle()
	check(primary.is_hovered(),"Primary action receives native hover input")
	await capture("button_hover_4k")
	var activations = [0]
	normal.pressed.connect(func(): activations[0] += 1)
	for down in [true,false]:
		var click = InputEventMouseButton.new()
		click.position = normal.get_global_rect().position+Vector2(1,1)
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		root.push_input(click,true)
	check(activations[0]==1,"A click in the clipped corner activates the native rectangular button")
	slider.grab_focus()
	var before = slider.value
	var right = InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	root.push_input(right)
	check(slider.value > before,"Styled slider retains native keyboard adjustment")
	right.pressed = false
	root.push_input(right)
	await capture("slider_focus_4k")
	edit.grab_focus()
	edit.select_all()
	await capture("text_selection_4k")
	option.show_popup()
	await capture("dropdown_4k")
	check(option.get_popup().visible,"Styled dropdown opens its native popup")
	option.get_popup().hide()
	dialog.popup_centered_ratio(0.72)
	await capture("file_dialog_4k")
	check(dialog.visible and dialog.get_ok_button().is_visible_in_tree(),"Styled file dialog retains its native action controls")
	dialog.hide()
	swatch.get_popup().popup_centered()
	await capture("color_picker_4k")
	swatch.get_popup().hide()
	panel.queue_free()
	await settle()
	hud.show_menu("title")

func measure_interface() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for i in 120: await process_frame
	var frames: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var previous = Time.get_ticks_usec()
	for i in 360:
		await process_frame
		var now = Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	report.performance = {"scope":"Standalone loading UI at 4K; no terrain or skiing workload; excludes texture loading and captures", "device":RenderingServer.get_video_adapter_name(),"frame_ms":timings(frames),"render_cpu_ms":timings(cpu),"gpu_ms":timings(gpu),"video_memory_bytes":int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),"static_memory_bytes":OS.get_static_memory_usage(),"warmup_frames":120,"sample_frames":360}

func timings(values: Array[float]) -> Dictionary:
	values.sort()
	var total: float = 0.0
	for value in values: total += value
	return {"mean":total/values.size(),"p95":values[int(values.size()*0.95)],"p99":values[int(values.size()*0.99)]}

func _select_tab(tabs: TabContainer, caption: String) -> void:
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index)==caption:
			tabs.current_tab = index
			return
	assert(false,"Missing tab: "+caption)
