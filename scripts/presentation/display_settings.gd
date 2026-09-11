extends RefCounted
## Output domain; never reset by a graphics preset. Unconfirmed changes aren't saved.
const Store = preload("res://scripts/ui/preference_store.gd")
const PATH = "user://display_v1.cfg"
const KEYS = ["display_mode","resolution","monitor","vsync","fps_limit"]
var display_mode = "fullscreen"
var resolution = Vector2i.ZERO
var monitor = -1
var vsync = 0
var fps_limit = 120
var pending: Dictionary = {}
var deadline_ms = 0

func snapshot() -> Dictionary:
	var values = {}
	for key in KEYS: values[key] = get(key)
	return values

func restore(values: Dictionary) -> void:
	for key in KEYS:
		if values.has(key) and typeof(values[key])==typeof(get(key)): set(key,values[key])
	if display_mode not in ["fullscreen","windowed"]: display_mode = "fullscreen"
	if fps_limit not in [0,60,90,120,144,165,240]: fps_limit = 120
	vsync = clampi(vsync,0,3)
	monitor = clampi(monitor,-1,maxi(-1,DisplayServer.get_screen_count()-1))
	if resolution!=Vector2i.ZERO and (resolution.x<640 or resolution.y<480 or resolution.x>7680 or resolution.y>4320): resolution = Vector2i.ZERO

func choices(window: Window) -> Array[Vector2i]:
	var result: Array[Vector2i] = [Vector2i.ZERO]
	var screen = DisplayServer.screen_get_size(window.current_screen)
	for pixels in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3440,1440),Vector2i(3840,2160),screen]:
		if pixels.x<=screen.x and pixels.y<=screen.y and pixels not in result: result.append(pixels)
	return result

func begin_preview(values: Dictionary, now_ms: int) -> void:
	if not pending.is_empty(): revert()
	pending = snapshot()
	restore(values)
	deadline_ms = now_ms+15000

func keep() -> void:
	pending.clear()
	deadline_ms = 0

func revert() -> void:
	var previous = pending.duplicate(true)
	keep()
	restore(previous)

func expired(now_ms: int) -> bool:
	return not pending.is_empty() and now_ms>=deadline_ms

func load_preferences(path: String = PATH) -> void:
	restore(Store.read_values(path,1))

func save_preferences(path: String = PATH) -> Error:
	return Store.write_values(path,1,pending if not pending.is_empty() else snapshot())

func apply(window: Window, requested_pixels: Vector2i = Vector2i.ZERO, exact_output: bool = false) -> void:
	Engine.max_fps = fps_limit
	if DisplayServer.get_name()=="headless": return
	if monitor>=0: window.current_screen = monitor
	DisplayServer.window_set_vsync_mode(vsync,window.get_window_id())
	var screen_pixels = DisplayServer.screen_get_size(window.current_screen)
	var pixels = requested_pixels if requested_pixels!=Vector2i.ZERO else resolution
	window.mode = Window.MODE_WINDOWED
	window.borderless = display_mode=="fullscreen" or requested_pixels!=Vector2i.ZERO
	# Custom DX12 generation requires the swapchain, UI and output to match.
	if display_mode=="fullscreen" and pixels==Vector2i.ZERO: pixels = screen_pixels
	if pixels!=Vector2i.ZERO:
		window.size = pixels
		window.position = DisplayServer.screen_get_position(window.current_screen)+(screen_pixels-pixels)/2
		if pixels==screen_pixels and not exact_output: window.mode = Window.MODE_FULLSCREEN
	else:
		window.size = Vector2i(mini(1920,int(screen_pixels.x*.8)),mini(1080,int(screen_pixels.y*.8)))
		window.position = DisplayServer.screen_get_position(window.current_screen)+(screen_pixels-window.size)/2
