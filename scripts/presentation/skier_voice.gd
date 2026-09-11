extends Node
## Bounded presentation voice pool. One reaction plus one ducked breath player.
const Library = preload("res://scripts/presentation/voice_library.gd")
const Events = preload("res://scripts/presentation/voice_events.gd")
const VoiceEnvironment = preload("res://scripts/presentation/voice_environment.gd")
const SETTINGS_PATH = "user://skier_voice_v1.cfg"
const RIDING_EVENTS = ["big_air","air_huge","land_big","landing_bad","impact_small","impact","injured","speed_high","speed_extreme","nearmiss","terrain_steep","terrain_cliff","terrain_tight","terrain_open","start","misc"]
const ALIASES = {"air_big":"big_air","save":"landing_bad","impact_hard":"impact","crash_start":"crash","finish_normal":"finish","pb":"personal_best","record":"race_record"}
const AUDITIONS = [
	["big_air","Big air"],["air_huge","Huge air"],["land_big","Major clean landing"],
	["landing_bad","Saved landing"],["impact_small","Compression"],["impact","Hard impact"],
	["crash","Crash onset"],["crash_after","After crash"],["breathing","Heavy breathing"],
	["injured","Low reserve"],["speed_high","High speed"],["speed_extreme","Extreme speed"],
	["nearmiss","Near miss"],["terrain_steep","Steep terrain"],["terrain_cliff","Drop ahead"],
	["terrain_tight","Tight terrain"],["terrain_open","Open terrain"],["start","Race start"],
	["misc","Rare self-talk"],["finish","Race finish"],["finish_good","Good finish"],
	["finish_bad","Bad finish"],["personal_best","Personal best"],
	["air_small","Small air (preview only)"],["land_clean","Ordinary clean landing (preview only)"],
	["race_record","Shared record (preview only)"],["win","Race win (preview only)"]
]
const RIDING_GAP_SECONDS = 60.0
const PRIORITY = {"big_air":50,"air_huge":51,"land_big":50,"landing_bad":70,"impact_small":65,"impact":75,"nearmiss":60,"injured":40,"terrain_steep":30,"terrain_cliff":33,"terrain_tight":32,"terrain_open":30,"speed_high":20,"speed_extreme":21,"start":10,"misc":10,"crash":100,"crash_after":90,"finish":105,"finish_good":105,"finish_bad":105,"personal_best":110}
const COOLDOWN = {"crash":2.0,"crash_after":2.0,"finish":2.0,"finish_good":2.0,"finish_bad":2.0,"personal_best":2.0,"speed":180.0,"start":180.0,"misc":180.0,"terrain_steep":180.0,"terrain_cliff":180.0,"terrain_tight":180.0,"terrain_open":180.0}
signal cue_started(id: String, event: String)
var events = Events.new()
var environment = VoiceEnvironment.new()
var clip_bank: Array = Library.CLIPS
var pools: Dictionary = {}
var race_progress: float = -1.0
var last_speech: float = 0.0
var crash_pending: bool = false
var crash_elapsed: float = 0.0
var crash_settled: float = 0.0
var allow_gameplay: bool = true
var enabled: bool = true
var breathing_enabled: bool = true
var volume: float = 0.75
var persist: bool = false
var muted: bool = false
var playback_enabled: bool = false
var player: AudioStreamPlayer
var breath_player: AudioStreamPlayer
var clock_seconds: float = 0.0
var speaking_until: float = 0.0
var next_reaction: float = 0.0
var next_riding_reaction: float = 0.0
var breath_until: float = 0.0
var breath_gain: float = 0.0
var breath_wanted: bool = false
var breath_preview: bool = false
var audition_active: bool = false
var current_priority: int = 0
var current_event: String = ""
var last_played: Dictionary = {}
var last_variant: Dictionary = {}
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	playback_enabled = DisplayServer.get_name() != "headless"
	rng.randomize() # Private presentation RNG; never changes physics randomness.
	player = AudioStreamPlayer.new()
	player.name = "SkierReaction"
	add_child(player)
	breath_player = AudioStreamPlayer.new()
	breath_player.name = "SkierBreathing"
	add_child(breath_player)
	# The bank is preloaded, with no disk IO or stream creation on a ski tick.
	rebuild_pools()

func rebuild_pools() -> void:
	pools.clear()
	for clip in clip_bank:
		clip.stream.loop = false
		var event: String = ALIASES.get(clip.event,clip.event)
		if not pools.has(event): pools[event] = []
		pools[event].append(clip)

func observe_tick(sim, dt: float, field = null, progress: float = -1.0, environment_candidates = null) -> void:
	if not allow_gameplay: return
	race_progress = progress
	var offered: Array[String] = events.sample_candidates(sim,dt)
	# Main supplies the shared survey; standalone callers retain the existing API.
	offered.append_array(environment.sample(sim,field,dt) if environment_candidates==null else environment_candidates)
	breath_wanted = events.breathing and not sim.crashed
	if offered.is_empty() and sim.grounded and sim.impacts.reserve>=0.75 and sim.velocity.length()>=10.0 and clock_seconds-last_speech>=180.0:
		offered.append("misc")
	offer(offered)

func offer(offered: Array[String]) -> bool:
	offered.sort_custom(func(a,b): return PRIORITY.get(a,0)>PRIORITY.get(b,0))
	for event in offered:
		if event in ["big_air","air_huge"] and rng.randf()>=0.5: continue
		if request(event):
			events.mark_spoken()
			return true
	return false

func start_run() -> void:
	if rng.randf()<0.25: request("start")

func begin_crash() -> void:
	request("crash")
	crash_pending = enabled and not muted and volume>0.001
	crash_elapsed = 0.0
	crash_settled = 0.0

func observe_crash(dt: float, hip_speed: float, visible: bool) -> void:
	if not crash_pending: return
	if not visible:
		silence()
		return
	crash_elapsed += maxf(0.0,dt)
	if crash_elapsed>10.0:
		crash_pending = false
		return
	crash_settled = crash_settled+dt if hip_speed<2.0 else 0.0
	if crash_elapsed>=1.5 and crash_settled>=0.75 and clock_seconds>=speaking_until:
		crash_pending = false
		request("crash_after")

func finish_run(session) -> void:
	var event: String = Events.finish_event(session)
	if not event.is_empty(): request(event)

func request(event: String, preview: bool = false) -> bool:
	event = ALIASES.get(event,event)
	if muted or not enabled or volume <= 0.001: return false
	var priority: int = PRIORITY.get(event,0)
	if not preview:
		if priority == 0 or (event in RIDING_EVENTS and not allow_gameplay): return false
		# One shared gate prevents a jump / landing / impact chain. Crashes and
		# verified finishes can still respond immediately. No queued chatter.
		if event in RIDING_EVENTS and clock_seconds < next_riding_reaction: return false
		var gate: String = "speed" if event in ["speed_high","speed_extreme"] else event
		if clock_seconds-float(last_played.get(gate,-1000.0)) < float(COOLDOWN.get(gate,60.0)): return false
		if clock_seconds < speaking_until and priority <= current_priority: return false
		if clock_seconds < next_reaction and event in RIDING_EVENTS: return false
	var clip: Dictionary = _choose(event,preview)
	if clip.is_empty(): return false
	if preview: silence()
	audition_active = preview
	if event == "breathing":
		_start_breath(clip)
		breath_wanted = true
		breath_preview = preview
		return true
	player.stop()
	player.stream = clip.stream
	player.volume_db = linear_to_db(volume)-6.0
	if playback_enabled: player.play()
	current_event = event
	current_priority = priority
	speaking_until = clock_seconds + clip.stream.get_length()
	next_reaction = speaking_until + 2.0
	if not preview:
		last_played["speed" if event in ["speed_high","speed_extreme"] else event] = clock_seconds
		last_speech = clock_seconds
		next_riding_reaction = maxf(next_riding_reaction,clock_seconds+RIDING_GAP_SECONDS)
	cue_started.emit(clip.id,event)
	return true

func preview(event: String) -> void:
	request(event,true)

func _choose(event: String, audition: bool = false) -> Dictionary:
	var eligible: Array = []
	for clip in pools.get(event,[]):
		if audition or float(clip.get("min_race_progress",0.0))<=maxf(0.0,race_progress):
			eligible.append(clip)
	if eligible.is_empty(): return {}
	var options: Array = eligible.filter(func(c): return c.id!=last_variant.get(event,""))
	if options.is_empty(): options = eligible # A single accepted clip remains usable.
	var weight = 0.0
	for clip in options: weight += maxf(0.0,float(clip.get("weight",1.0)))
	if weight<=0.0: return {}
	var choice = rng.randf()*weight
	for clip in options:
		choice -= maxf(0.0,float(clip.get("weight",1.0)))
		if choice<=0.0:
			last_variant[event] = clip.id
			return clip
	return options.back()

func _start_breath(clip: Dictionary) -> void:
	if clip.is_empty(): return
	breath_player.stream = clip.stream
	breath_player.volume_db = -80.0
	if playback_enabled: breath_player.play()
	breath_until = clock_seconds + clip.stream.get_length()
	cue_started.emit(clip.id,"breathing")

func _process(dt: float) -> void:
	clock_seconds += maxf(0.0,dt)
	if breath_preview and clock_seconds >= breath_until:
		breath_wanted = false
		breath_preview = false
	if muted or not enabled or volume <= 0.001:
		silence()
		return
	player.volume_db = linear_to_db(volume)-6.0
	var wants: bool = breathing_enabled and breath_wanted
	# A settings audition ends after one breath clip. Skiing reasserts demand.
	if wants and clock_seconds > breath_until+0.28:
		_start_breath(_choose("breathing"))
	var target: float = volume * 0.7 if wants else 0.0
	if clock_seconds < speaking_until: target *= 0.12
	breath_gain = move_toward(breath_gain,target,dt*2.0)
	breath_player.volume_db = linear_to_db(breath_gain) if breath_gain > 0.00001 else -80.0
	if not wants and breath_gain <= 0.00001:
		breath_player.stop()
		breath_until = clock_seconds

func set_gameplay_active(value: bool) -> void:
	allow_gameplay = value
	if not value or audition_active:
		silence()
		environment.reset()

func set_muted(value: bool) -> void:
	muted = value
	if value: silence()

func silence() -> void:
	crash_pending = false
	if is_instance_valid(player): player.stop()
	if is_instance_valid(breath_player): breath_player.stop()
	breath_wanted = false
	breath_preview = false
	audition_active = false
	breath_gain = 0.0
	breath_until = clock_seconds
	speaking_until = clock_seconds
	current_event = ""
	current_priority = 0

func reset() -> void:
	silence()
	events.reset()
	environment.reset()
	race_progress = -1.0
	next_reaction = clock_seconds
	# Keep next_riding_reaction across retries / summit returns in this scene.

func snapshot() -> Dictionary:
	return {"enabled":enabled,"breathing_enabled":breathing_enabled,"volume":volume}

func restore(values: Dictionary) -> void:
	enabled = values.get("enabled",true) == true
	breathing_enabled = values.get("breathing_enabled",true) == true
	var level = values.get("volume",0.75)
	volume = clampf(float(level),0,1) if typeof(level) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(level)) else 0.75
	if not enabled or volume <= 0.001: silence()
	if not breathing_enabled: breath_wanted = false

func load_preferences() -> void:
	if not persist: return
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var values = {}
		for key in snapshot(): values[key] = config.get_value("voice",key,snapshot()[key])
		restore(values)

func save_preferences() -> void:
	if not persist: return
	var config = ConfigFile.new()
	for key in snapshot(): config.set_value("voice",key,snapshot()[key])
	config.save(SETTINGS_PATH)

func _exit_tree() -> void:
	silence()
