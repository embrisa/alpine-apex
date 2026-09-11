extends SceneTree
## UI-only 4K review keeps terrain capture and performance evidence separate.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2);return
	Engine.max_fps=30
	root.size=Vector2i(3840,2160)
	var hud=preload("res://scripts/ui/hud.gd").new();root.add_child(hud)
	var sfx=preload("res://scripts/presentation/procedural_sfx.gd").new();root.add_child(sfx)
	hud.riding_audio_settings.bind(sfx)
	hud.open_settings()
	_select_tab(hud.settings_tabs,"Audio")
	var sound_group = _expand_group(hud.settings_tabs.get_current_tab_control(),"Skiing sounds")
	var scroll: ScrollContainer=hud.settings_tabs.get_current_tab_control()
	for i in 10: await process_frame
	scroll.ensure_control_visible(sound_group)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://artifacts/sfx/capture")
	picture.save_png("res://artifacts/sfx/capture/audio_categories_4k.png")
	print("SFX_SETTINGS_CAPTURE ",picture.get_size())
	sfx.stop_audio();sfx.queue_free();hud.queue_free()
	await create_timer(.2).timeout
	quit(0)

func _select_tab(tabs: TabContainer, caption: String) -> void:
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index)==caption:
			tabs.current_tab = index
			return
	assert(false,"Missing tab: "+caption)

func _expand_group(page: Control, caption: String) -> Control:
	for button in page.find_children("*","Button",true,false):
		if button.has_meta("group_body") and button.text.ends_with(caption):
			button.button_pressed = true
			return button.get_meta("group_body")
	assert(false,"Missing settings group: "+caption)
	return null
