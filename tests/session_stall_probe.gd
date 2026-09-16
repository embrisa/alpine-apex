extends SceneTree
## Headless stall probe for the finish save, crash placement and retry roster
## paths (task 084511). Requires the Standard mountain (ALPINE_FULL_MOUNTAIN=1).
## Options after `--`: --stall-label=NAME --stall-ticks=N (default 18000 = 150 s).
## Output: artifacts/session_stall/<label>.json. Uses a private user:// record
## directory that it removes afterwards; no player records are touched.
const Replay = preload("res://scripts/racing/run_replay.gd")
const Records = preload("res://scripts/racing/competitive_record.gd")
const Recovery = preload("res://scripts/core/crash_recovery.gd")
const Pose = preload("res://scripts/presentation/ghost_pose.gd")
const Cache = preload("res://scripts/racing/ghost_replay_cache.gd")
const Session = preload("res://scripts/core/run_session.gd")
var label = "probe"
var ticks_wanted = 18000

func _initialize() -> void: call_deferred("run")

static func usec() -> int: return Time.get_ticks_usec()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stall-label="): label = arg.get_slice("=",1)
		if arg.begins_with("--stall-ticks="): ticks_wanted = int(arg.get_slice("=",1))
	var field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: printerr("Standard mountain unavailable"); quit(2); return
	var tuning = preload("res://config/ski_default.tres").duplicate(true)
	var sim = SkiSimulation.new(tuning)
	var heading: float = field.spawn_heading()
	sim.reset(field.launch_point(heading),heading)
	sim.prime_contacts(field)
	var intent = RiderInput.new(); intent.tuck = 1.0
	var started = usec()
	var identity = Replay.key("stall-probe-course")
	var key_ms = (usec()-started)/1000.0
	var replay = Replay.new(); replay.begin(sim,identity)
	var recovery = Recovery.new()
	var session = Session.new()
	var pose = PackedFloat32Array(); pose.resize(Pose.WIDTH)
	for i in Pose.TRANSFORMS: pose[i*7+6] = 1.0
	for i in 2:
		pose[Pose.CONTACT_START+i*Pose.CONTACT_WIDTH+2] = .3
		pose[Pose.CONTACT_START+i*Pose.CONTACT_WIDTH+3] = .3
	pose[Pose.WIDTH-1] = tuning.ski_length
	if not Pose.validate(pose): printerr("Synthetic pose invalid"); quit(2); return
	var crash_rows: Array = []
	var crash_at = [600,2400,6000,12000,17000]
	var t = 0.0
	var ticks = 0
	replay.capture_presentation(0.0,pose)
	for tick in ticks_wanted:
		sim.step(Replay.DT,intent,field)
		t += Replay.DT; ticks += 1
		# The last tick completes the capture exactly like a finish-line crossing.
		replay.record(Replay.DT,t,sim,intent,1.0 if ticks==ticks_wanted else -1.0)
		if replay.wants_presentation_sample(): replay.capture_presentation(t,pose)
		recovery.observe_support(sim)
		if ticks in crash_at or sim.crashed:
			recovery.invalidate(); recovery.capture(sim,1,field.get_instance_id())
			var crash_started = usec()
			var placement = recovery.resolve(field,field,session,null,false)
			crash_rows.append({"tick":ticks,"ms":(usec()-crash_started)/1000.0,"candidates":recovery.candidates_checked,"height_queries":recovery.height_queries,"obstacle_queries":recovery.obstacle_queries,"support_primes":recovery.support_primes,"error":placement.get("error",""),"speed_kmh":sim.speed_kmh(),"crashed":sim.crashed})
		if sim.crashed: break
	# Finish path components, then the real transaction.
	started = usec(); var bytes: PackedByteArray = replay.to_bytes(); var to_bytes_ms = (usec()-started)/1000.0
	started = usec(); var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); var digest = hash.finish().hex_encode(); var sha_ms = (usec()-started)/1000.0
	started = usec(); var compressed = bytes.compress(FileAccess.COMPRESSION_ZSTD); var zstd_ms = (usec()-started)/1000.0
	var directory = "user://session_stall_probe_%d" % OS.get_process_id()
	var record_path = directory.path_join("stall.json")
	var splits = [replay.duration*.25,replay.duration*.5,replay.duration*.75]
	var runs: Array = [_row(replay,splits)]
	started = usec(); var error = Records.save(record_path,identity,replay.duration,splits,[],runs,Records.default_selection()); var save_one_ms = (usec()-started)/1000.0
	for i in 9: runs.append(_row(replay,splits))
	started = usec(); var error_ten = Records.save(record_path,identity,replay.duration,splits,[],runs,Records.default_selection()); var save_ten_ms = (usec()-started)/1000.0
	# Retry path: the roster reload that _freeze_ghosts performs each attempt.
	var loaded = Records.load_record(record_path,identity)
	var cache = Cache.new()
	started = usec(); var cold = Records.selected(record_path,identity,loaded.runs,loaded.selection,cache); var retry_cold_ms = (usec()-started)/1000.0
	started = usec(); var warm = Records.selected(record_path,identity,loaded.runs,loaded.selection,cache); var retry_warm_ms = (usec()-started)/1000.0
	var data = {"label":label,"platform":OS.get_name(),"engine":Engine.get_version_info().string,"ticks":ticks,"duration_s":replay.duration,"samples":replay.samples.size(),"presentation":replay.presentation.size(),"crashed":sim.crashed,
		"finish":{"key_ms":key_ms,"to_bytes_ms":to_bytes_ms,"sha256_ms":sha_ms,"zstd_ms":zstd_ms,"payload_bytes":bytes.size(),"compressed_bytes":compressed.size(),"sha256":digest,"save_one_run_ms":save_one_ms,"save_ten_runs_ms":save_ten_ms,"errors":[error,error_ten]},
		"retry":{"cold_ms":retry_cold_ms,"warm_ms":retry_warm_ms,"ghosts":cold.runs.size(),"warm_ghosts":warm.runs.size(),"cache":cache.stats()},
		"crash":crash_rows}
	for name in DirAccess.get_files_at(directory.path_join("ghosts")): DirAccess.remove_absolute(directory.path_join("ghosts").path_join(name))
	DirAccess.remove_absolute(directory.path_join("ghosts")); DirAccess.remove_absolute(record_path); DirAccess.remove_absolute(directory)
	DirAccess.make_dir_recursive_absolute("res://artifacts/session_stall")
	var out = FileAccess.open("res://artifacts/session_stall/%s.json" % label,FileAccess.WRITE); out.store_string(JSON.stringify(data,"\t")); out.close()
	print("SESSION_STALL_PROBE ",JSON.stringify(data))
	quit(0)

static func _row(replay, splits: Array) -> Dictionary:
	return {"id":Records.run_id(),"time":replay.duration,"splits":splits,"date":int(Time.get_unix_time_from_system()),"peak_kmh":120.0,"replay":replay}
