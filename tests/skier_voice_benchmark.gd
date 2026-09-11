extends "res://tests/alpine_v12_playtest.gd"
## Identical v12 pilot/render fixture; toggles only completed-tick voice observation.
var voice_tick_us: Array[float] = []
var survey_us: Array[float] = []
var observer_enabled: bool = true
var max_obstacles: int = 0
var max_heights: int = 0
var limited_updates: int = 0

func descent() -> void:
	observer_enabled = not "--voice-observer=off" in OS.get_cmdline_user_args()
	game.voice.playback_enabled = false # Benchmark DSP/device output independently in native audition.
	game.voice.set_gameplay_active(true)
	physics_frame.connect(_observe_voice)
	await super.descent()
	physics_frame.disconnect(_observe_voice)
	var path = OUTPUT+"/native_%d_%s.json" % [side,weather]
	if FileAccess.file_exists(path):
		var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		result.voice_observer = {"enabled":observer_enabled,"tick_us":timing(voice_tick_us),"survey_update_us":timing(survey_us),"max_obstacle_candidates":max_obstacles,"max_height_samples":max_heights,"limited_updates":limited_updates}
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
		print("VOICE_BENCHMARK ",JSON.stringify(result.voice_observer))

func _observe_voice() -> void:
	if not recording or not observer_enabled: return
	var count: int = game.voice.environment.update_count
	var begin = Time.get_ticks_usec()
	game.voice.observe_tick(game.sim,1.0/120.0,field,-1.0)
	voice_tick_us.append(Time.get_ticks_usec()-begin)
	if game.voice.environment.update_count!=count:
		survey_us.append(game.voice.environment.last_update_us)
		max_obstacles = maxi(max_obstacles,game.voice.environment.obstacle_checks)
		max_heights = maxi(max_heights,game.voice.environment.height_samples)
		if game.voice.environment.limited: limited_updates += 1
