extends RefCounted
## Fixed-step race timing, independent of Nodes and presentation.
const Replay = preload("res://scripts/racing/run_replay.gd")
const Records = preload("res://scripts/racing/competitive_record.gd")
var elapsed: float = 0.0
var finish_z: float = 1450.0
var free_radius: float = 0.0
var finished: bool = false
var personal_best: float = -1.0
var history: Array = []
var practice_reason = ""
var eligible: bool = true
var race = null
var record_directory: String = "user://race_records_v5"
var benchmark_path: String = "user://benchmark_v1.json"
var previous_elapsed: float = 0.0
var previous_best: float = -1.0
var new_best: bool = false
var split_times: Array = [-1.0,-1.0,-1.0]
var best_splits: Array = [-1.0,-1.0,-1.0]
var reference_splits: Array = [-1.0,-1.0,-1.0]
var best_replay = null
var reference_replay = null
var recording = null
var split_origin = Vector2(0,25)
var split_axis = Vector2(0,1)
var split_length: float = 1425.0
var latest_split: int = -1
var save_error: String = ""
var record_warning: String = ""
var replay_warning: String = ""
var course_id: String = "laboratory-v%d-physics-v%d-default" % [preload("res://scripts/world/test_slope.gd").GENERATOR_VERSION, preload("res://scripts/core/ski_simulation.gd").MODEL_VERSION]

func reset() -> void:
	elapsed = 0.0
	previous_elapsed = 0.0
	finished = false
	eligible = true
	practice_reason = ""
	previous_best = personal_best
	new_best = false
	split_times = [-1.0,-1.0,-1.0]
	reference_splits = best_splits.duplicate()
	reference_replay = best_replay
	recording = null
	latest_split = -1
	replay_warning = ""
	if race:
		split_origin = Vector2(race.start.x,race.start.z)
		var delta = Vector2(race.finish.x,race.finish.z)-split_origin
		split_axis = delta.normalized()
		split_length = delta.length()
	else:
		split_origin = Vector2(0,25)
		split_axis = Vector2(0,1)
		split_length = finish_z-25.0

func mark_practice(reason: String) -> void:
	eligible = false
	recording = null
	if practice_reason.is_empty(): practice_reason = reason

func begin_capture(sim) -> void:
	if not eligible: return
	recording = Replay.new()
	recording.begin(sim,Replay.key(course_id))

func step(dt: float, before: Vector3, after: Vector3, sim = null, intent = null) -> bool:
	if finished:
		return false
	previous_elapsed = elapsed
	var hit = finish_fraction(before,after)
	var used = hit if hit>=0.0 else 1.0
	_update_splits(dt,before,after,used)
	elapsed += dt*used
	if not eligible: recording = null
	if recording and sim and intent:
		recording.record(dt,elapsed,sim,intent,hit)
	if hit >= 0.0:
		finished = true
		if eligible:
			history.push_front({"time":elapsed,"splits":split_times.duplicate(),"date":int(Time.get_unix_time_from_system()),"peak_kmh":sim.peak_speed*3.6 if sim else 0.0})
			if history.size() > 20:
				history.resize(20)
			if personal_best < 0.0 or elapsed < personal_best:
				new_best = true
				personal_best = elapsed
				best_splits = split_times.duplicate()
				best_replay = recording if recording and recording.complete and not recording.overflow else null
				if not best_replay: replay_warning = "Best time saved without a ghost; recording was unavailable or exceeded 10 minutes."
			save_record()
		return true
	return false

func _update_splits(dt: float, before: Vector3, after: Vector3, end_fraction: float) -> void:
	# Infinite, non-mandatory planes measure approach to the finish. They never
	# gate completion, constrain lateral route choice, or reward recrossing.
	var a = (Vector2(before.x,before.z)-split_origin).dot(split_axis)
	var b = (Vector2(after.x,after.z)-split_origin).dot(split_axis)
	if b<=a: return
	for i in range(3):
		var distance = split_length*float(i+1)/4.0
		var fraction = (distance-a)/(b-a)
		if split_times[i]<0.0 and a<distance and fraction>=0.0 and fraction<=end_fraction:
			split_times[i] = elapsed+dt*fraction
			latest_split = i

func split_delta(index: int) -> float:
	if index<0 or split_times[index]<0 or reference_splits[index]<0: return NAN
	return split_times[index]-reference_splits[index]

func result_text(peak_kmh: float) -> String:
	var result = "%s  /  TOP SPEED %d km/h" % [format_time(elapsed),peak_kmh]
	if not eligible: return result+"\nPractice · "+practice_reason+". Personal best unchanged." if not practice_reason.is_empty() else result+"\nUnranked run. Personal best unchanged."
	if previous_best<0.0: result += "\nFirst personal best. Your next line starts here."
	else: result += "\n%s vs your previous best." % format_delta(elapsed-previous_best)
	if not save_error.is_empty(): return result+"\nSave failed. This result is kept for this session."
	return result

func finish_fraction(before: Vector3, after: Vector3) -> float:
	if race:
		return race.finish_fraction(before,after)
	var fraction = clampf((finish_z-before.z)/maxf(after.z-before.z,0.00001),0,1)
	var crossing = before.lerp(after,fraction)
	if before.z < finish_z and after.z >= finish_z and absf(crossing.x) <= 36.0:
		return fraction
	return -1.0

func configure(definition = null) -> void:
	free_radius = 0.0
	race = definition
	finish_z = 1450.0
	course_id = race.record_identity() if race else "laboratory-v%d-physics-v%d-default" % [preload("res://scripts/world/test_slope.gd").GENERATOR_VERSION,preload("res://scripts/core/ski_simulation.gd").MODEL_VERSION]
	personal_best = -1.0
	history = []
	best_replay = null
	best_splits = [-1.0,-1.0,-1.0]
	load_record()
	reset()

func progress_percent(position: Vector3) -> float:
	if finished: return 100.0
	if free_radius>0 and race==null:
		return clampf(Vector2(position.x,position.z).length()/free_radius*100,0,100)
	if race:
		return clampf((1.0-position.distance_to(race.finish)/race.start.distance_to(race.finish))*100.0,0,100)
	return clampf((position.z-25.0)/(finish_z-25.0)*100.0,0,100)

func record_path() -> String:
	return record_directory.path_join(course_id.sha256_text()+".json") if race else benchmark_path

func load_record() -> void:
	var data = Records.load_record(record_path(),Replay.key(course_id))
	personal_best = data.best
	history = data.history
	best_splits = data.splits
	best_replay = data.replay
	record_warning = data.warning
	save_error = ""

func save_record() -> void:
	save_error = Records.save(record_path(),Replay.key(course_id),personal_best,best_splits,history,best_replay)
	if save_error.is_empty(): record_warning = ""

static func format_delta(seconds: float) -> String:
	if not is_finite(seconds): return "—"
	return "%s%.3f s" % ["−" if seconds<0 else "+",absf(seconds)]

static func format_time(seconds: float) -> String:
	if seconds < 0.0:
		return "— — : — — . — — —"
	var ms = roundi(seconds * 1000.0)
	return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]

func configure_free(mountain_id: String, basin_z: float = 1740.0, radial_radius: float = 0.0) -> void:
	free_radius = radial_radius
	race = null
	course_id = "free-ski-"+mountain_id
	personal_best = -1.0
	previous_best = -1.0
	history = []
	best_replay = null
	best_splits = [-1.0,-1.0,-1.0]
	save_error = ""
	record_warning = ""
	finish_z = basin_z
	reset()
	eligible = false
