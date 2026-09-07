extends Node
## Small, synthesized UI cues. No assets, loops, or per-frame audio allocation.
const PATH = "user://interface_preferences.cfg"
var volume: float = 0.55
var muted: bool = false:
	set(value):
		muted = value
		if value:
			for player in players: player.stop()
var reduced_motion: bool = false
var persist: bool = false
var enabled: bool = false
var players: Array[AudioStreamPlayer] = []
var cues: Dictionary = {}
var cursor: int = 0
var last_hover: int = 0

func _ready() -> void:
	persist = DisplayServer.get_name() != "headless" and "--script" not in OS.get_cmdline_args() and "-s" not in OS.get_cmdline_args() and "--autoplay" not in OS.get_cmdline_user_args()
	if persist:
		var config = ConfigFile.new()
		if config.load(PATH) == OK:
			volume = clampf(float(config.get_value("ui","volume",0.55)),0.0,1.0)
			muted = bool(config.get_value("ui","muted",false))
			reduced_motion = bool(config.get_value("ui","reduced_motion",false))
	for id in ["hover","press","ready","error"]:
		cues[id] = _tone(id)
	for i in 3:
		var player = AudioStreamPlayer.new()
		add_child(player)
		players.append(player)

func save() -> void:
	if not persist: return
	var config = ConfigFile.new()
	config.set_value("ui","volume",volume)
	config.set_value("ui","muted",muted)
	config.set_value("ui","reduced_motion",reduced_motion)
	config.save(PATH)

func play(id: String = "press") -> void:
	if not enabled or muted or volume <= 0.001 or DisplayServer.get_name() == "headless": return
	if id == "hover":
		var now = Time.get_ticks_msec()
		if now-last_hover < 90: return
		last_hover = now
	var player = players[cursor]
	cursor = (cursor+1)%players.size()
	player.stream = cues.get(id,cues.press)
	player.volume_db = linear_to_db(volume)-16.0 if id != "hover" else linear_to_db(volume)-24.0
	player.play()

func reveal(control: Control) -> void:
	if control.has_meta("ui_tween"):
		var old: Tween = control.get_meta("ui_tween")
		if old and old.is_valid(): old.kill()
	control.modulate.a = 1.0
	if reduced_motion or not control.is_visible_in_tree(): return
	control.modulate.a = 0.0
	var tween = control.create_tween()
	control.set_meta("ui_tween",tween)
	tween.tween_property(control,"modulate:a",1.0,0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _tone(id: String) -> AudioStreamWAV:
	var duration = 0.045 if id == "hover" else (0.24 if id == "ready" else 0.09)
	var frequency = 920.0 if id == "hover" else (660.0 if id == "ready" else (240.0 if id == "error" else 580.0))
	var count = int(duration*22050)
	var data = PackedByteArray()
	data.resize(count*2)
	for i in count:
		var t = float(i)/22050.0
		var envelope = minf(t/0.006,1.0)*pow(1.0-float(i)/count,2.0)
		var wave = sin(TAU*frequency*t)
		if id == "ready": wave = 0.5*wave+0.5*sin(TAU*frequency*1.5*t)
		data.encode_s16(i*2,int(wave*envelope*20000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream

func _exit_tree() -> void:
	for player in players:
		player.stop()
		player.stream = null
