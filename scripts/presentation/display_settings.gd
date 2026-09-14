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
# Actual state belongs only to this transaction, never to KEYS or the store.
var _pending_window: Dictionary = {}
var _rollback_window: Dictionary = {}

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
	if display_mode=="fullscreen": return result
	var screen = DisplayServer.screen_get_size(monitor if monitor>=0 else window.current_screen)
	for pixels in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3440,1440),Vector2i(3840,2160),screen]:
		if pixels.x<=screen.x and pixels.y<=screen.y and pixels not in result: result.append(pixels)
	return result

func begin_preview(values: Dictionary, now_ms: int, window: Window = null) -> void:
	if pending.is_empty():
		pending = snapshot()
		# Revert followed by another preview before apply still has the original
		# actual window available; do not capture the unconfirmed geometry.
		_pending_window = _rollback_window.duplicate(true) if not _rollback_window.is_empty() else capture_window(window)
		_rollback_window.clear()
	else:
		# Replacing an active preview must keep the first recovery target.
		restore(pending)
	restore(values)
	deadline_ms = now_ms+15000

static func capture_window(window: Window) -> Dictionary:
	if window==null: return {}
	return {"screen":window.current_screen,"position":window.position,"size":window.size,
		"mode":window.mode,"borderless":window.borderless}

func keep() -> void:
	pending.clear()
	_pending_window.clear()
	deadline_ms = 0

func revert() -> void:
	if pending.is_empty(): return
	var previous = pending.duplicate(true)
	_rollback_window = _pending_window.duplicate(true)
	keep()
	restore(previous)

func expired(now_ms: int) -> bool:
	return not pending.is_empty() and now_ms>=deadline_ms

func load_preferences(path: String = PATH) -> void:
	restore(Store.read_values(path,1))

func save_preferences(path: String = PATH) -> Error:
	return Store.write_values(path,1,pending if not pending.is_empty() else snapshot())

func window_plan(screen_pixels: Vector2i, screen_position: Vector2i, requested_pixels: Vector2i = Vector2i.ZERO, exact_output: bool = false) -> Dictionary:
	# Fullscreen preferences always use native display pixels. Explicit fixture
	# and benchmark output requests retain priority over ordinary preferences.
	var explicit_pixels = requested_pixels!=Vector2i.ZERO
	var pixels = requested_pixels if explicit_pixels else (screen_pixels if display_mode=="fullscreen" else resolution)
	if pixels==Vector2i.ZERO:
		pixels = Vector2i(mini(1920,int(screen_pixels.x*.8)),mini(1080,int(screen_pixels.y*.8)))
	var fullscreen = display_mode=="fullscreen" and pixels==screen_pixels and not exact_output
	return {"size":pixels,"position":screen_position+(screen_pixels-pixels)/2,
		"mode":Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED,
		"borderless":display_mode=="fullscreen" or explicit_pixels or pixels==screen_pixels}

func apply(window: Window, requested_pixels: Vector2i = Vector2i.ZERO, exact_output: bool = false) -> void:
	Engine.max_fps = fps_limit
	var native_window = DisplayServer.get_name()!="headless" and window.get_window_id()!=DisplayServer.INVALID_WINDOW_ID
	if native_window: DisplayServer.window_set_vsync_mode(vsync,window.get_window_id())
	if not _rollback_window.is_empty():
		# Consume once and return: normal preference application would recenter
		# the restored window or lose an automatically selected prior screen.
		var actual = _rollback_window.duplicate(true)
		_rollback_window.clear()
		_apply_window_state(window,actual)
		return
	if not native_window: return
	var screen = monitor if monitor>=0 else window.current_screen
	var plan = window_plan(DisplayServer.screen_get_size(screen),DisplayServer.screen_get_position(screen),requested_pixels,exact_output)
	plan.screen = screen
	_apply_window_state(window,plan)

static func _apply_window_state(window: Window, state: Dictionary) -> void:
	# Startup applies saved display state before world initialization. Reapplying
	# the same state must not briefly leave fullscreen during the loading handoff.
	if window.current_screen==state.screen and window.mode==state.mode:
		if state.mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]:
			window.borderless = state.borderless
			return
		if window.position==state.position and window.size==state.size and window.borderless==state.borderless: return
	# Godot Windows infers fullscreen from a borderless native-sized rectangle.
	# Drop the borderless flag before restoring Windowed so a native-sized
	# pre-fullscreen rectangle cannot immediately re-enter fullscreen.
	if window.mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]: window.borderless = false
	window.mode = Window.MODE_WINDOWED
	window.current_screen = state.screen
	window.borderless = state.borderless
	if state.mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]:
		# Preserve a real previous window rectangle instead of first resizing
		# the window to native pixels, which prevents a later fullscreen exit.
		window.mode = state.mode
	else:
		window.size = state.size
		window.position = state.position
		if state.mode!=Window.MODE_WINDOWED: window.mode = state.mode
