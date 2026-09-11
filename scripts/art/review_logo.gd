extends SceneTree
## Export transparent PNGs and capture the real title, header and loading UI.
## This fixture does not generate a mountain or access personal saves.
const Art = preload("res://scripts/ui/alpine_art.gd")
const OUTPUT = "res://artifacts/logo/"
var captures: Array = []
var ice_variant: bool = "--logo-ice" in OS.get_cmdline_user_args()
var capture_prefix: String = "ice_" if ice_variant else ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for asset in ["alpine_apex", "alpine_apex_light", "alpine_apex_dark", "alpine_apex_compact", "alpine_apex_mark", "alpine_apex_ice"]:
		var source = "res://assets/images/branding/%s.svg" % asset
		var image = Image.new()
		if image.load_svg_from_string(FileAccess.get_file_as_string(source),2.0) != OK:
			push_error("Cannot rasterize logo: " + source)
			quit(1)
			return
		image.save_png(OUTPUT + asset + "_transparent.png")
	if DisplayServer.get_name() == "headless":
		quit()
		return
	root.content_scale_size = Vector2i(1440,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	Engine.max_fps = 60
	var hud = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	hud.feedback.muted = true
	hud.feedback.persist = false
	hud.feedback.reduced_motion = true
	var loading = load("res://scripts/ui/loading_overlay.gd").new()
	root.add_child(loading)
	loading.configure_feedback(hud.feedback)
	if ice_variant:
		# Preview the alternative only in this fixture; runtime preferences stay intact.
		hud.hero_logo.texture = load("res://assets/images/branding/alpine_apex_ice.svg")
		loading.overlay.get_node("AlpineApexLogo").texture = hud.hero_logo.texture
	for dimensions in [Vector2i(1280,720), Vector2i(1440,900), Vector2i(3840,2160)]:
		root.size = dimensions
		hud.menu_tabs.current_tab = 0
		await capture("title_%dx%d" % [dimensions.x, dimensions.y])
		hud.open_settings()
		await capture("header_%dx%d" % [dimensions.x, dimensions.y])
		hud.close_weather()
	for index in [0,3]:
		set_meta("alpine_loading_photo",index)
		loading.begin("Preparing your descent", "Preparing the rider, camera and interface…")
		loading.stage("Preparing terrain sections",43.0)
		for dimensions in [Vector2i(1280,720), Vector2i(3840,2160)]:
			root.size = dimensions
			await capture("loading_%d_%dx%d" % [index,dimensions.x,dimensions.y])
		loading.finish()
	var report = {"captures":captures,"logo":hud.hero_logo.texture.resource_path,
		"compact_logo":Art.COMPACT_LOGO_PATH,"device":RenderingServer.get_video_adapter_name(),
		"scope":"Native UI composition and SVG export; no gameplay or performance claim"}
	FileAccess.open(OUTPUT+capture_prefix+"review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("LOGO_REVIEW ",JSON.stringify(report))
	hud.queue_free()
	loading.queue_free()
	await process_frame
	quit()

func capture(caption: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	image.save_png(OUTPUT+capture_prefix+caption+".png")
	captures.append({"name":capture_prefix+caption,"pixels":[image.get_width(),image.get_height()]})
