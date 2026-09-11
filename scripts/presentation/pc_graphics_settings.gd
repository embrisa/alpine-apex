extends RefCounted
## Display preferences never enter mountain recipes, physics or ranked identity.
const Store = preload("res://scripts/ui/preference_store.gd")
const Profile = preload("res://scripts/presentation/graphics_quality.gd")
const Presets = preload("res://scripts/presentation/graphics_presets.gd")
const Output = preload("res://scripts/presentation/display_settings.gd")
const PATH = "user://graphics_v2.cfg"
const GRAPHICS_KEYS = ["quality","upscaler","frame_generation","render_scale","terrain_gi","sharpness","msaa","anisotropic","overrides","custom"]
const KEYS = GRAPHICS_KEYS + Output.KEYS
const UPSCALERS = ["auto", "fsr4", "fsr3", "fsr2", "native"]
var display = Output.new()
var quality: int = 7
var upscaler: String = "auto"
var frame_generation: bool = false
var render_scale: float = .75
var terrain_gi: bool = false
var sharpness: float = .35
var msaa: int = 1
var anisotropic: int = 2
var overrides: Dictionary = {}
var custom = false
var display_mode: String:
	get: return display.display_mode
	set(value): display.display_mode = value
var fps_limit: int:
	get: return display.fps_limit
	set(value): display.fps_limit = value
var resolution: Vector2i:
	get: return display.resolution
	set(value): display.resolution = value
var monitor: int:
	get: return display.monitor
	set(value): display.monitor = value
var vsync: int:
	get: return display.vsync
	set(value): display.vsync = value

func snapshot() -> Dictionary:
	var result = display.snapshot()
	for key in GRAPHICS_KEYS: result[key] = get(key)
	return result.duplicate(true)

func restore(values: Dictionary) -> void:
	display.restore(values)
	for key in GRAPHICS_KEYS:
		if values.has(key) and typeof(values[key])==typeof(get(key)): set(key,values[key])
	quality = clampi(quality,1,10)
	if upscaler not in UPSCALERS: upscaler = "auto"
	if not is_finite(render_scale): render_scale = .75
	render_scale = clampf(render_scale,2.0/3.0,1.0)
	if not is_finite(sharpness): sharpness = .35
	sharpness = clampf(sharpness,0.0,1.0)
	msaa = clampi(msaa,0,3)
	anisotropic = clampi(anisotropic,0,4)
	overrides = Presets.sanitize(overrides)

func profile() -> Resource:
	var result = Profile.numbered(quality,overrides)
	result.terrain_gi = terrain_gi
	return result

func select_preset(id: int) -> void:
	quality = clampi(id,1,10)
	overrides.clear()
	custom = false
	upscaler = "auto"
	render_scale = .75
	terrain_gi = false
	sharpness = .35
	msaa = 1
	anisotropic = 2

func set_graphics_value(key: String, value: Variant) -> void:
	if Presets.CONTROLS.has(key) and key!="terrain_gi":
		overrides.merge(Presets.sanitize({key:value}),true)
	elif key in GRAPHICS_KEYS and key not in ["quality","overrides","custom"]:
		restore({key:value})
	else: return
	if key!="frame_generation": custom = true

func reset_group(group: String) -> void:
	for key in overrides.keys():
		if Presets.CONTROLS[key][1]==group: overrides.erase(key)
	if group=="Lighting & shadows": terrain_gi = false
	custom = not overrides.is_empty() or terrain_gi or upscaler!="auto" or render_scale!=.75 or sharpness!=.35 or msaa!=1 or anisotropic!=2

func load_preferences(path: String = PATH) -> void:
	restore(Store.read_values(path,2))
	display.load_preferences(Output.PATH if path==PATH else path+".display")

func save_preferences(path: String = PATH) -> Error:
	var values = {}
	for key in GRAPHICS_KEYS: values[key] = get(key)
	var error = Store.write_values(path,2,values)
	if error!=OK: return error
	return display.save_preferences(Output.PATH if path==PATH else path+".display")

func apply_arguments(args: PackedStringArray) -> void:
	for arg in args:
		var value = arg.get_slice("=",1)
		if arg.begins_with("--graphics-quality="):
			var tier = ["low","balanced","high"].find(value)
			if tier>=0: select_preset([1,4,7][tier])
			elif value.is_valid_int(): select_preset(int(value))
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
	viewport.msaa_3d = Viewport.MSAA_DISABLED if temporal else msaa
	viewport.use_taa = false
	viewport.fsr_sharpness = sharpness
	viewport.anisotropic_filtering_level = anisotropic
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
	display.apply(window,requested_pixels,frame_generation and has_native_fsr())

func report(viewport: Viewport, output_pixels: Vector2i) -> Dictionary:
	var scale_value = viewport.scaling_3d_scale
	return {"preferences":snapshot(),"output_pixels":[output_pixels.x,output_pixels.y],
		"internal_pixels_from_viewport_scale":[roundi(output_pixels.x*scale_value),roundi(output_pixels.y*scale_value)],
		"viewport_scale":scale_value,"msaa":viewport.msaa_3d,"fps_limit":Engine.max_fps,"fidelityfx":fsr_status()}
