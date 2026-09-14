extends Node
## Load resources off-thread; instantiate and initialize Nodes on the main thread.
const Sequence = preload("res://scripts/ui/startup_sequence.gd")
const Feedback = preload("res://scripts/ui/interface_feedback.gd")
const MAIN_SCENE = "res://main.tscn"
const Identity = preload("res://scripts/diagnostics/build_identity.gd")
const Loading = preload("res://scripts/ui/loading_overlay.gd")
const Display = preload("res://scripts/presentation/display_settings.gd")
# These are the production skier's equipment resources, otherwise loaded inside
# mesh conversion during Node construction. Retain them until the menu is ready.
const EQUIPMENT = ["ski_detailed_v1","ski_detailed_v1_left",preload("res://scripts/presentation/skier_equipment.gd").BINDING_MESH,"skier_v7_boot_right","skier_v7_boot_left","pole_detailed_v1"]
var warm_resources: Array[Resource] = []
var warm_pending: Array[String] = []
var sequence
var loading
var game
var scene_path: String = MAIN_SCENE
var requested: bool = false
var installed: bool = false
var started_usec: int = 0
var menu_ready_usec: int = 0
var display_ready_usec: int = 0
var failure: String = ""

func _ready() -> void:
	started_usec = Time.get_ticks_usec()
	var personal = DisplayServer.get_name()!="headless" and "--script" not in OS.get_cmdline_args() and "-s" not in OS.get_cmdline_args() and "--autoplay" not in OS.get_cmdline_user_args()
	# The engine starts fullscreen. Resolve an explicit saved display choice before
	# the first logo frame; this owner is small and has no world/GPU asset dependency.
	if personal or get_tree().has_meta("startup_display_preferences"):
		var display = Display.new()
		if personal: display.load_preferences()
		if get_tree().has_meta("startup_display_preferences"): display.restore(get_tree().get_meta("startup_display_preferences"))
		display.apply(get_window())
	display_ready_usec = Time.get_ticks_usec()
	Identity.begin_background()
	_request_resources()
	sequence = Sequence.new()
	var photos = Sequence.Photos.catalog()
	var photo_rng = RandomNumberGenerator.new(); photo_rng.randomize()
	sequence.photo_index = Sequence.Photos.choose(photos,photo_rng)
	if get_tree().has_meta("startup_photo_index"): sequence.photo_index = int(get_tree().get_meta("startup_photo_index"))
	if sequence.photo_index>=0 and sequence.photo_index<photos.size():
		var entry: Dictionary = photos[sequence.photo_index]
		sequence.photo_texture = load(Sequence.Photos.DIRECTORY+entry.file) as Texture2D
		sequence.photo_focus = Vector2(entry.focus[0],entry.focus[1])
		sequence.photo_credit = str(entry.credit)
	sequence.preferences = Feedback.read_preferences(personal)
	if get_tree().has_meta("startup_preferences"): sequence.preferences.merge(get_tree().get_meta("startup_preferences"),true)
	sequence.audio_allowed = personal or get_tree().get_meta("startup_audio_review",false)
	add_child(sequence)
	sequence.dismissed.connect(_dismissed)
	loading = Loading.new()
	add_child(loading)
	loading.set_startup_cover(true)
	loading.apply_preferences(sequence.preferences)
	if sequence.photo_texture: loading.use_startup_photo(sequence.photo_texture,sequence.photo_focus,sequence.photo_credit)
	loading.begin("Loading","Loading resources…")
	sequence.destination_ready = true
	get_tree().set_meta("startup_sequence",sequence)
	get_tree().set_meta("startup_loading",loading)
	if not requested: _failed("The main scene could not be requested.")

func _request_resources() -> void:
	# Readiness polling remains independent from the animation. Reload targets main.tscn.
	requested = ResourceLoader.exists(scene_path) and ResourceLoader.load_threaded_request(scene_path,"PackedScene")==OK
	if requested:
		for id in EQUIPMENT:
			var path = "res://assets/graphics/models/"+id+".glb"
			if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path,"PackedScene")==OK: warm_pending.append(path)

func _process(_delta: float) -> void:
	for path in warm_pending.duplicate():
		var warm_status = ResourceLoader.load_threaded_get_status(path)
		if warm_status==ResourceLoader.THREAD_LOAD_LOADED:
			warm_resources.append(ResourceLoader.load_threaded_get(path)); warm_pending.erase(path)
		elif warm_status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]: warm_pending.erase(path)
	if requested and not installed:
		var status = ResourceLoader.load_threaded_get_status(scene_path)
		if "--startup-stages" in OS.get_cmdline_user_args() and Engine.get_process_frames()%120==0: print("STARTUP_RESOURCE_STATUS ",status," at ",Time.get_ticks_msec())
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			requested = false; _failed("The main scene could not be loaded.")
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			installed = true
			var packed = ResourceLoader.load_threaded_get(scene_path) as PackedScene
			if not packed: _failed("The main scene is unavailable."); return
			game = packed.instantiate()
			get_tree().set_meta("startup_sequence",sequence)
			get_tree().root.add_child(game)
			get_tree().current_scene = game
	if installed and not is_instance_valid(game): queue_free(); return
	if is_instance_valid(game):
		if not game.initialized and game.loading and game.loading.sound_muted!=sequence.preferences.get("muted",false):
			game.loading.apply_preferences(sequence.preferences)
			if game.hud: game.hud.feedback.restore(sequence.preferences)
		elif game.initialized and game.hud:
			# The ready settings panel owns preferences even during the dissolve.
			sequence.apply_preferences(game.hud.feedback.snapshot())
		sequence.destination_ready = game.loading!=null and game.loading.busy or game.initialized
		sequence.menu_ready = game.initialized and not game.loading.busy
		if sequence.menu_ready and menu_ready_usec==0:
			menu_ready_usec = Time.get_ticks_usec()
			print("STARTUP_MENU_READY ",JSON.stringify({"engine_elapsed_ms":Time.get_ticks_msec(),"startup_ms":(menu_ready_usec-started_usec)/1000.0,"display_setup_ms":(display_ready_usec-started_usec)/1000.0,"reduced_motion":sequence.state.reduced_motion,"skipped":sequence.state.skipped,"resource_loading":"threaded resources; cooperative main-thread scene/GPU submission"}))
		if sequence.complete:
			if game.loading: game.loading.set_startup_cover(false)
			if sequence.menu_ready: queue_free()

func _dismissed() -> void:
	if is_instance_valid(loading): loading.set_startup_cover(false)

func _failed(message: String) -> void:
	failure = message
	loading.cancelled_startup()
	loading.title.text = "Unable to start"
	loading.stage(message)
	sequence.state.skipped = true

func _exit_tree() -> void:
	if get_tree().has_meta("startup_sequence") and get_tree().get_meta("startup_sequence")==sequence: get_tree().remove_meta("startup_sequence")
	if get_tree().has_meta("startup_loading") and get_tree().get_meta("startup_loading")==loading: get_tree().remove_meta("startup_loading")
	if not is_instance_valid(game): Identity.current() # Join the owned worker on failed-start exit.
