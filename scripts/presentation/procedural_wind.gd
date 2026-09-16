extends Node
## Presentation-only airflow and sound preferences. One stream owns each sound.
const SETTINGS_PATH = "user://wind_v1.cfg"
## This remains a manually loaded Windows configuration. Keeping it out of
## Godot's .gdextension discovery prevents macOS/Linux from reporting a missing DLL.
const EXTENSION = "res://addons/alpine_wind/alpine_wind.windows.gdextension.cfg"
const LIBRARY = "res://addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll"
enum Mode { PROCEDURAL, ORIGINAL }
var mode: int = Mode.PROCEDURAL
var volume: float = 1.0
var mix_gain: float = 1.0 # Presentation mix ducking; never stored as a preference.
var persist: bool = false
var available: bool = false
var stream = null
var player: AudioStreamPlayer
var original: AudioStreamPlayer
var playback_enabled: bool = false
var blend: float = 1.0
var airflow = Vector3.ZERO
var tuck: float = 0.0
var gust: float = 0.0
var audible: bool = false
var original_db: float = -65.0
var stopping: bool = false

func setup(original_player: AudioStreamPlayer) -> void:
	original = original_player
	playback_enabled = DisplayServer.get_name() != "headless"
	if "--wind-disable-native" not in OS.get_cmdline_user_args():
		if not ClassDB.class_exists("AlpineWindStream") and OS.has_feature("windows") and FileAccess.file_exists(LIBRARY):
			GDExtensionManager.load_extension(EXTENSION)
		available = ClassDB.class_exists("AlpineWindStream")
	player = AudioStreamPlayer.new()
	player.name = "ProceduralWind"
	add_child(player)
	if available:
		stream = ClassDB.instantiate("AlpineWindStream")
		player.stream = stream
		if playback_enabled: player.play()
	blend = 1.0 if available and mode == Mode.PROCEDURAL else 0.0

func snapshot() -> Dictionary:
	return {"mode":mode,"volume":volume}

func restore(values: Dictionary) -> void:
	var selected = values.get("mode",Mode.PROCEDURAL)
	mode = selected if selected in [Mode.PROCEDURAL,Mode.ORIGINAL] else Mode.PROCEDURAL
	var level = values.get("volume",1.0)
	volume = clampf(float(level),0.0,1.0) if typeof(level) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(level)) else 1.0

func load_preferences() -> void:
	if not persist: return
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		restore({"mode":config.get_value("wind","mode",0),"volume":config.get_value("wind","volume",1.0)})

func save_preferences() -> void:
	if not persist: return
	var config = ConfigFile.new()
	for key in snapshot(): config.set_value("wind",key,snapshot()[key])
	config.save(SETTINGS_PATH)

func label() -> String:
	if mode == Mode.PROCEDURAL and not available: return "Original · procedural wind unavailable"
	return "Procedural" if mode == Mode.PROCEDURAL else "Original"

func sample(sim, weather, enabled: bool, legacy_db: float) -> void:
	var wind = weather.wind_velocity if weather != null and weather.enabled else Vector3.ZERO
	var relative: Vector3 = wind - sim.velocity
	var support: Basis = sim.support_basis()
	var forward: Vector3 = support.z * (-1.0 if sim.facing_backward else 1.0)
	var right: Vector3 = forward.cross(support.y).normalized()
	airflow = Vector3(relative.dot(right),relative.dot(support.y),relative.dot(forward))
	tuck = sim.effective_tuck
	gust = weather.gust if weather != null and weather.enabled else 0.0
	audible = enabled and not stopping
	original_db = legacy_db

func sample_crash(ragdoll, weather, enabled: bool) -> void:
	var ambient: Vector3 = weather.wind_velocity if weather!=null and weather.enabled else Vector3.ZERO
	var relative: Vector3 = ambient-ragdoll.bodies.Hips.linear_velocity
	var head: Basis = ragdoll.bone_world("Head").basis.orthonormalized()
	airflow = Vector3(relative.dot(head.x),relative.dot(head.y),relative.dot(head.z))
	tuck = 0.0
	gust = weather.gust if weather!=null and weather.enabled else 0.0
	audible = enabled and not stopping
	original_db = lerpf(-48.0,-7.0,pow(clampf(relative.length()*3.6/200.0,0,1),.72))

func advance(dt: float) -> void:
	var target = 1.0 if mode == Mode.PROCEDURAL and available else 0.0
	blend = move_toward(blend,target,maxf(0.0,dt)/0.2)
	var legacy_gain = db_to_linear(original_db)*sqrt(1.0-blend)*volume*mix_gain if audible else 0.0
	# Original remains a comparison source. Native gain/gating are sample-smoothed.
	original.volume_linear = lerpf(original.volume_linear,legacy_gain,1.0-exp(-maxf(0.0,dt)*35.0))
	if original.volume_linear < 0.00001: original.volume_db = -80.0
	if stream: stream.set_controls(airflow,tuck,gust,sqrt(blend)*volume*mix_gain,audible)
	if playback_enabled and is_instance_valid(player): player.stream_paused = blend <= 0.0

func silence() -> void:
	audible = false
	if stream: stream.set_controls(airflow,tuck,gust,0.0,false)

func stop_audio() -> void:
	if stopping: return
	stopping = true
	silence()
	# Main's transitions call this before scene replacement; let the callback fade.
	if playback_enabled and is_inside_tree():
		# Keep playback alive across an immediate scene reload. Bind cleanup to
		# the retained player, not this controller which is about to disappear.
		var retiring = player
		retiring.reparent(get_tree().root)
		var finished = get_tree().create_timer(0.15)
		finished.timeout.connect(retiring.stop)
		finished.timeout.connect(retiring.queue_free)
		player = null
	else: _release_playback()

func _release_playback() -> void:
	if is_instance_valid(player):
		player.stop()
		player.stream = null

func _exit_tree() -> void:
	silence()
	_release_playback()

func diagnostics() -> Dictionary:
	return stream.diagnostics() if stream else {"blocks":0,"p99_512_ms":0.0}
