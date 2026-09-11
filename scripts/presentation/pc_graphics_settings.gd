extends RefCounted
## Display preferences never enter mountain recipes, physics or ranked identity.
const PATH = "user://graphics_v1.cfg"
const KEYS = ["quality", "display_mode", "upscaler", "frame_generation", "render_scale", "fps_limit", "terrain_gi"]
const UPSCALERS = ["auto", "fsr4", "fsr3", "fsr2", "native"]
var quality: int = 2
var display_mode: String = "fullscreen"
var upscaler: String = "auto"
var frame_generation: bool = false
var render_scale: float = 0.75
var fps_limit: int = 120
var terrain_gi: bool = false

func snapshot() -> Dictionary:
	var result = {}
	for key in KEYS: result[key] = get(key)
	return result

func restore(values: Dictionary) -> void:
	for key in KEYS:
		if values.has(key) and typeof(values[key])==typeof(get(key)): set(key,values[key])
	quality = clampi(quality,0,2)
	if display_mode not in ["fullscreen","windowed"]: display_mode = "fullscreen"
	if upscaler not in UPSCALERS: upscaler = "auto"
	if not is_finite(render_scale): render_scale = .75
	render_scale = clampf(render_scale,2.0/3.0,1.0)
	if fps_limit not in [0,90,120,144]: fps_limit = 120

func load_preferences(path: String = PATH) -> void:
	var config = ConfigFile.new()
	if config.load(path)!=OK: return
	var values = {}
	for key in KEYS: values[key] = config.get_value("graphics",key,get(key))
	restore(values)

func save_preferences(path: String = PATH) -> Error:
	var config = ConfigFile.new()
	for key in KEYS: config.set_value("graphics",key,get(key))
	return config.save(path)

func apply_arguments(args: PackedStringArray) -> void:
	for arg in args:
		var value = arg.get_slice("=",1)
		if arg.begins_with("--graphics-quality="):
			var level = ["low","balanced","high"].find(value)
			if level>=0: quality = level
		elif arg.begins_with("--display-mode=") and value in ["fullscreen","windowed"]: display_mode = value
		elif arg.begins_with("--upscaler=") and value in UPSCALERS: upscaler = value
		elif arg.begins_with("--frame-generation=") and value in ["on","off"]: frame_generation = value=="on"
		elif arg.begins_with("--render-scale=") and value.is_valid_float(): render_scale = float(value)
		elif arg.begins_with("--fps-limit=") and value.is_valid_int(): fps_limit = int(value)
		elif arg.begins_with("--terrain-gi=") and value in ["on","off"]: terrain_gi = value=="on"
	restore(snapshot())

func apply_viewport(viewport: Viewport) -> void:
	if DisplayServer.get_name()=="headless": return
	var temporal = upscaler!="native" or (frame_generation and has_native_fsr())
	# The custom engine replaces this temporal pass with the selected SDK provider.
	# Stock Godot retains its actual FSR2 implementation and reports that fallback.
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if temporal else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale if upscaler!="native" else 1.0
	viewport.msaa_3d = Viewport.MSAA_DISABLED if temporal else Viewport.MSAA_2X
	viewport.use_taa = false
	viewport.fsr_sharpness = 0.35
	if has_native_fsr(): Engine.get_singleton("AlpineFidelityFX").set_options(upscaler,frame_generation)
	Engine.max_fps = fps_limit

static func has_native_fsr() -> bool:
	return Engine.has_singleton("AlpineFidelityFX") and RenderingServer.get_current_rendering_driver_name()=="d3d12"

func fsr_status() -> Dictionary:
	if has_native_fsr(): return Engine.get_singleton("AlpineFidelityFX").get_status()
	return {"engine_integration":false,"active_upscaler_version":"2.2" if upscaler!="native" else "",
		"frame_generation_active":false,"frame_generation_supported":false,"upscale_dispatches":0,"generated_frames":0,
		"error":"FSR 3/4 and frame generation require the custom DirectX 12 engine."}

func reset_history() -> void:
	if has_native_fsr(): Engine.get_singleton("AlpineFidelityFX").reset_history()

func apply_display(window: Window, requested_pixels: Vector2i = Vector2i.ZERO) -> void:
	if DisplayServer.get_name()=="headless": return
	var screen_pixels = DisplayServer.screen_get_size(window.current_screen)
	window.mode = Window.MODE_WINDOWED
	# A screen-sized decorated window is enlarged by Windows to include its
	# frame. Borderless exact-size benchmark windows avoid the old +16/+16 bug.
	window.borderless = display_mode=="fullscreen" or requested_pixels!=Vector2i.ZERO
	# Godot's Windows multiwindow fullscreen expands the native swapchain past
	# the reported screen size. FSR generation requires an exact HUD/output
	# match. A screen-sized borderless window keeps both resources identical.
	var exact_fullscreen = frame_generation and has_native_fsr() and (requested_pixels==screen_pixels or (requested_pixels==Vector2i.ZERO and display_mode=="fullscreen"))
	if exact_fullscreen:
		window.borderless = true
		window.size = screen_pixels
		window.position = DisplayServer.screen_get_position(window.current_screen)
		return
	if requested_pixels!=Vector2i.ZERO:
		window.size = requested_pixels
		window.position = DisplayServer.screen_get_position(window.current_screen)+(screen_pixels-requested_pixels)/2
		if requested_pixels==screen_pixels: window.mode = Window.MODE_FULLSCREEN
	elif display_mode=="fullscreen":
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.size = Vector2i(mini(1920,int(screen_pixels.x*.8)),mini(1080,int(screen_pixels.y*.8)))
		window.position = DisplayServer.screen_get_position(window.current_screen)+(screen_pixels-window.size)/2

func report(viewport: Viewport, output_pixels: Vector2i) -> Dictionary:
	var scale_value = viewport.scaling_3d_scale
	return {"preferences":snapshot(),"output_pixels":[output_pixels.x,output_pixels.y],
		"internal_pixels_from_viewport_scale":[roundi(output_pixels.x*scale_value),roundi(output_pixels.y*scale_value)],
		"viewport_scale":scale_value,"msaa":viewport.msaa_3d,"fps_limit":Engine.max_fps,"fidelityfx":fsr_status()}
