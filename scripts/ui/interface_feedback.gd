extends Node
## Six prebuilt cues, three fixed voices, no queues or per-frame audio synthesis.
const PATH = "user://interface_preferences.cfg"
const SAMPLE_RATE = 22050
const POOL_SIZE = 3
const CUE_IDS = ["hover", "press", "back", "adjust", "success", "error"]
const ALIASES = {"navigation":"hover", "focus":"hover", "activate":"press", "ready":"success"}
const COOLDOWNS = {"hover":90, "press":65, "back":65, "adjust":70, "success":180, "error":180}
const GAINS_DB = {"hover":-24.0, "press":-18.0, "back":-18.0, "adjust":-23.0, "success":-18.0, "error":-18.0}
signal preferences_changed
signal cue_played(id: String, slot: int)
var volume: float = 0.55:
	set(value):
		volume = clampf(value,0.0,1.0)
		if volume <= 0.001: cancel_sounds()
		else:
			for player in players:
				player.volume_db = linear_to_db(volume) + float(player.get_meta("cue_gain_db",-18.0))
		preferences_changed.emit()
var muted: bool = false:
	set(value):
		muted = value
		if value: cancel_sounds()
		preferences_changed.emit()
var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if value: cancel_transitions()
		preferences_changed.emit()
var loading_ambience: bool = true:
	set(value):
		loading_ambience = value
		preferences_changed.emit()
var persist: bool = false
var enabled: bool = false:
	set(value):
		enabled = value
		if not value: cancel_sounds()
var pending_preferences: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var cues: Dictionary = {}
var last_cue_at: Dictionary = {}
var last_any_at: int = -1000000
var last_action_at: int = -1000000
var priority_until: int = -1
var active_reveals: Dictionary = {}

func _ready() -> void:
	persist = DisplayServer.get_name() != "headless" and "--script" not in OS.get_cmdline_args() and "-s" not in OS.get_cmdline_args() and "--autoplay" not in OS.get_cmdline_user_args()
	restore(pending_preferences if not pending_preferences.is_empty() else read_preferences(persist))
	pending_preferences.clear()
	for id in CUE_IDS:
		cues[id] = _tone(id)
	for alias in ALIASES: cues[alias] = cues[ALIASES[alias]]
	for i in POOL_SIZE:
		var player = AudioStreamPlayer.new()
		player.name = "InterfaceCue%d" % i
		add_child(player)
		players.append(player)

static func preferences_from_config(config: ConfigFile) -> Dictionary:
	return {"volume":clampf(float(config.get_value("ui","volume",0.55)),0.0,1.0),
		"muted":bool(config.get_value("ui","muted",false)),
		"reduced_motion":bool(config.get_value("ui","reduced_motion",false)),
		"loading_ambience":bool(config.get_value("ui","loading_ambience",true))}

static func read_preferences(personal: bool) -> Dictionary:
	var config = ConfigFile.new()
	if personal: config.load(PATH)
	return preferences_from_config(config)

func snapshot() -> Dictionary:
	return {"volume":volume,"muted":muted,"reduced_motion":reduced_motion,"loading_ambience":loading_ambience}

func restore(values: Dictionary) -> void:
	volume = values.get("volume",0.55)
	muted = values.get("muted",false)
	reduced_motion = values.get("reduced_motion",false)
	loading_ambience = values.get("loading_ambience",true)

func save() -> void:
	if not persist: return
	var config = ConfigFile.new()
	config.load(PATH)
	for key in snapshot(): config.set_value("ui",key,snapshot()[key])
	config.save(PATH)

func play(id: String = "press") -> bool:
	return _play_at(id,Time.get_ticks_msec())

func _play_at(id: String, now: int) -> bool:
	# The same admission/dispatch path runs silently under the headless driver.
	# Explicit timestamps allow a deterministic rapid-input regression test.
	id = str(ALIASES.get(id,id))
	if not enabled or muted or volume <= 0.001 or players.is_empty() or not cues.has(id): return false
	var soft = id == "hover" or id == "adjust"
	if soft and now < priority_until: return false
	if now-int(last_cue_at.get(id,-1000000)) < int(COOLDOWNS[id]): return false
	if (soft and now-last_any_at < 30) or (not soft and now-last_action_at < 30):
		# A new screen action must not leave the old screen's sound ringing.
		if not soft: cancel_sounds()
		return false
	last_cue_at[id] = now
	last_any_at = now
	var slot = 0 if id == "hover" else (1 if id == "adjust" else 2)
	if not soft:
		cancel_sounds()
		last_action_at = now
		priority_until = now + 100
	var player = players[slot]
	player.stop()
	player.stream = cues[id]
	player.set_meta("cue_gain_db",GAINS_DB[id])
	player.volume_db = linear_to_db(volume) + float(GAINS_DB[id])
	if DisplayServer.get_name() != "headless": player.play()
	cue_played.emit(id,slot)
	return true

func cancel_sounds() -> void:
	for player in players:
		player.stop()
		player.stream = null

func reveal(control: Control) -> void:
	# Opening another panel supersedes the previous presentation immediately.
	cancel_transitions()
	cancel_reveal(control)
	if not is_instance_valid(control): return
	if reduced_motion or not control.is_visible_in_tree(): return
	# Only opacity changes: focus, hit testing and buttons stay live throughout.
	control.modulate.a = 0.0
	var tween = control.create_tween()
	var key = control.get_instance_id()
	active_reveals[key] = weakref(control)
	var on_hidden = _control_hidden.bind(key)
	if not control.visibility_changed.is_connected(on_hidden): control.visibility_changed.connect(on_hidden)
	var on_exit = _cancel_reveal_id.bind(key)
	if not control.tree_exiting.is_connected(on_exit): control.tree_exiting.connect(on_exit)
	control.set_meta("ui_tween",tween)
	tween.tween_property(control,"modulate:a",1.0,0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_complete_reveal.bind(key))

func cancel_reveal(control: Control) -> void:
	if not is_instance_valid(control): return
	if control.has_meta("ui_tween"):
		var old: Tween = control.get_meta("ui_tween")
		if old and old.is_valid(): old.kill()
		control.remove_meta("ui_tween")
	control.modulate.a = 1.0
	active_reveals.erase(control.get_instance_id())

func cancel_transitions() -> void:
	for key in active_reveals.keys():
		var control = active_reveals[key].get_ref()
		if is_instance_valid(control): cancel_reveal(control)
	active_reveals.clear()

func _complete_reveal(key: int) -> void:
	var ref = active_reveals.get(key)
	var control = ref.get_ref() if ref else null
	if is_instance_valid(control):
		control.modulate.a = 1.0
		control.remove_meta("ui_tween")
	active_reveals.erase(key)

func _control_hidden(key: int) -> void:
	var ref = active_reveals.get(key)
	var control = ref.get_ref() if ref else null
	if is_instance_valid(control) and not control.is_visible_in_tree(): cancel_reveal(control)

func _cancel_reveal_id(key: int) -> void:
	var ref = active_reveals.get(key)
	var control = ref.get_ref() if ref else null
	if is_instance_valid(control): cancel_reveal(control)

func _tone(id: String) -> AudioStreamWAV:
	# Related sine/soft harmonic timbre; direction and rhythm communicate intent.
	# Each note: onset seconds, frequency Hz, duration seconds, relative amplitude.
	id = str(ALIASES.get(id,id))
	var notes: Array = []
	match id:
		"hover": notes = [[0.0,880.0,0.045,0.75]]
		"adjust": notes = [[0.0,660.0,0.035,0.7],[0.025,880.0,0.035,0.4]]
		"press": notes = [[0.0,440.0,0.075,0.75],[0.035,660.0,0.075,0.65]]
		"back": notes = [[0.0,660.0,0.065,0.65],[0.035,440.0,0.075,0.75]]
		"success": notes = [[0.0,440.0,0.1,0.65],[0.065,550.0,0.1,0.6],[0.13,660.0,0.12,0.7]]
		"error": notes = [[0.0,220.0,0.085,0.8],[0.105,196.0,0.1,0.75]]
		_: return null
	var duration = 0.0
	for note in notes: duration = maxf(duration,float(note[0])+float(note[2]))
	var count = ceili(duration*SAMPLE_RATE)+1
	var data = PackedByteArray()
	data.resize(count*2)
	for i in count:
		var t = float(i)/SAMPLE_RATE
		var wave = 0.0
		for note in notes:
			var local_time = t-float(note[0])
			var length_s = float(note[2])
			if local_time < 0.0 or local_time >= length_s: continue
			var envelope = smoothstep(0.0,0.004,local_time)*pow(1.0-local_time/length_s,2.0)
			var angle = TAU*float(note[1])*local_time
			wave += (sin(angle)+0.12*sin(2.0*angle))*envelope*float(note[3])*0.48
		data.encode_s16(i*2,roundi(clampf(wave,-0.95,0.95)*32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream

func _exit_tree() -> void:
	cancel_transitions()
	cancel_sounds()
