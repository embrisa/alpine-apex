extends RefCounted
## Fixed-step race timing, independent of Nodes and presentation.
const Replay = preload("res://scripts/racing/run_replay.gd")
const Records = preload("res://scripts/racing/competitive_record.gd")
const Recovery = preload("res://scripts/core/crash_recovery.gd")
var attempt_id: int = 0
var recovering: bool = false
var recovery_paused: bool = false
var recovery_count: int = 0
var elapsed: float = 0.0
var finish_z: float = 1450.0
var free_radius: float = 0.0
var finished: bool = false
var personal_best: float = -1.0
var history: Array = []
var practice_reason = ""
var eligible: bool = true
var race = null
var record_directory: String = "user://race_records_v6"
var benchmark_path: String = "user://benchmark_v1.json"
var previous_elapsed: float = 0.0
var previous_best: float = -1.0
var new_best: bool = false
var split_times: Array = [-1.0,-1.0,-1.0]
var best_splits: Array = [-1.0,-1.0,-1.0]
var reference_splits: Array = [-1.0,-1.0,-1.0]
var ghost_runs: Array = []
var ghost_cache = preload("res://scripts/racing/ghost_replay_cache.gd").new()
var ghost_selection = Records.default_selection()
var reference_ghosts: Array = []
var selection_notice = ""
var attempt_run_id = ""
var pending_result: Dictionary = {}
var recording = null
var split_origin = Vector2(0,25)
var split_axis = Vector2(0,1)
var split_length: float = 1425.0
var latest_split: int = -1
var save_error: String = ""
var record_warning: String = ""
var replay_warning: String = ""
var course_id: String = laboratory_identity()

static func laboratory_identity() -> String:
	return "laboratory-v%d-physics-v%d-recovery%d-default" % [preload("res://scripts/world/test_slope.gd").GENERATOR_VERSION,preload("res://scripts/core/ski_simulation.gd").MODEL_VERSION,Recovery.RULES_VERSION]

func reset() -> void:
	attempt_id += 1
	recovering = false
	recovery_paused = false
	recovery_count = 0
	elapsed = 0.0
	previous_elapsed = 0.0
	finished = false
	eligible = true
	practice_reason = ""
	previous_best = personal_best
	new_best = false
	split_times = [-1.0,-1.0,-1.0]
	reference_splits = best_splits.duplicate()
	_freeze_ghosts()
	attempt_run_id = Records.run_id()
	pending_result.clear()
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
	if finished or recovering:
		return false
	previous_elapsed = elapsed
	# The completed onset tick consumes time and real splits exactly once. A
	# crashed solver endpoint cannot finish; subsequent crash ticks have no sweep.
	var hit = -1.0 if sim!=null and sim.crashed else finish_fraction(before,after)
	var used = hit if hit>=0.0 else 1.0
	_update_splits(dt,before,after,used)
	elapsed += dt*used
	if not eligible: recording = null
	if recording and sim and intent:
		recording.record(dt,elapsed,sim,intent,hit)
	if hit >= 0.0:
		finished = true
		if eligible:
			pending_result = {"id":attempt_run_id,"time":elapsed,"splits":split_times.duplicate(),"date":int(Time.get_unix_time_from_system()),"peak_kmh":sim.peak_speed*3.6 if sim else 0.0}
			history.push_front(Records.clean_result(pending_result))
			if history.size()>20: history.resize(20)
			if personal_best<0 or elapsed<personal_best:
				new_best = true; personal_best = elapsed; best_splits = split_times.duplicate()
			# Main captures the exact final production pose before committing.
			if recording==null or recording.overflow: finalize_capture()
		return true
	return false

func begin_crash(sim) -> bool:
	if finished or recovering: return false
	recovering = true
	recovery_paused = false
	if not eligible: recording = null
	if recording: recording.begin_crash(elapsed,sim)
	return true

func step_crash(dt: float) -> void:
	if not recovering or recovery_paused or finished: return
	previous_elapsed = elapsed
	elapsed += dt
	if not eligible: recording = null
	if recording: recording.record_crash(dt,elapsed)

func recover(sim) -> bool:
	if not recovering or recovery_paused or finished or sim.crashed: return false
	if not eligible: recording = null
	if recording: recording.record_recovery(elapsed,sim)
	recovering = false
	recovery_count += 1
	previous_elapsed = elapsed
	return true

func cancel_recovery() -> void:
	# Abandoned world/attempt transitions cannot reuse an old recovery action.
	recovering = false
	recovery_paused = false

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
	course_id = race.record_identity() if race else laboratory_identity()
	personal_best = -1.0
	history = []
	ghost_runs.clear()
	ghost_selection = Records.default_selection()
	reference_ghosts.clear()
	selection_notice = ""
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
	ghost_cache.clear() # Explicit archive reload is metadata-only and drops old decoded references.
	var data = Records.load_record(record_path(),Replay.key(course_id))
	personal_best = data.best
	history = data.history
	best_splits = data.splits
	ghost_runs = data.runs
	ghost_selection = data.selection
	record_warning = data.warning
	save_error = ""

func save_record() -> void:
	save_error = Records.save(record_path(),Replay.key(course_id),personal_best,best_splits,history,ghost_runs,ghost_selection)
	if save_error.is_empty(): record_warning = ""
	ghost_cache.prune(ghost_runs) # Release evicted/replaced payloads without changing the active roster.

func capture_presentation(data: PackedFloat32Array) -> void:
	if recording and recording.wants_presentation_sample():
		recording.capture_presentation(elapsed,data)
	if finished: finalize_capture()

func finalize_capture() -> void:
	if pending_result.is_empty(): return
	if eligible:
		ghost_runs = Records.retain(ghost_runs,pending_result,recording)
		if recording==null or not recording.has_presentation():
			replay_warning = "Time saved without a ghost; complete presentation capture was unavailable or exceeded 10 minutes."
		var removed = Records.prune_selection(ghost_selection,ghost_runs)
		if not removed.is_empty(): selection_notice = removed
		save_record()
	pending_result.clear()
	recording = null

func _freeze_ghosts() -> void:
	# A retry owns a fresh roster but can share immutable validated replay data.
	reference_ghosts = []
	var selected = Records.selected(record_path(),Replay.key(course_id),ghost_runs,ghost_selection,ghost_cache)
	reference_ghosts = selected.runs
	if not selected.unavailable.is_empty():
		for id in selected.unavailable:
			for row in ghost_runs.duplicate():
				if row.id==id: ghost_runs.erase(row)
			ghost_selection.ids.erase(id)
		selection_notice = "Unavailable or incompatible ghosts removed: "+", ".join(selected.unavailable)+". Times remain available; choose replacements or Automatic fastest 10."

func choose_ghosts(mode: String, ids: Array) -> void:
	ghost_selection = Records.normalize_selection({"mode":mode,"ids":ids})
	selection_notice = Records.prune_selection(ghost_selection,ghost_runs)
	# Only saved next-attempt choices change. Frozen competitors and PB deltas
	# remain unchanged during this attempt, including an explicitly empty subset.
	save_record()

static func format_delta(seconds: float) -> String:
	if not is_finite(seconds): return "—"
	return "%s%.3f s" % ["−" if seconds<0 else "+",absf(seconds)]

static func format_time(seconds: float) -> String:
	if seconds < 0.0:
		return "— — : — — . — — —"
	var ms = roundi(seconds * 1000.0)
	return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]

func configure_free(mountain_id: String, basin_z: float = 1740.0, radial_radius: float = 0.0) -> void:
	ghost_cache.clear()
	free_radius = radial_radius
	race = null
	course_id = "free-ski-"+mountain_id
	personal_best = -1.0
	previous_best = -1.0
	history = []
	ghost_runs.clear()
	ghost_selection = Records.default_selection()
	reference_ghosts.clear()
	selection_notice = ""
	best_splits = [-1.0,-1.0,-1.0]
	save_error = ""
	record_warning = ""
	finish_z = basin_z
	reset()
	eligible = false
