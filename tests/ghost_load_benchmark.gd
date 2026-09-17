extends SceneTree
## Explicit synthetic loading benchmark. Cold means empty decoded cache, not a flushed OS disk cache.
## Use FpsCritical for timing; --prepare creates an isolated fixture deliberately.
const Records = preload("res://scripts/racing/competitive_record.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const Cache = preload("res://scripts/racing/ghost_replay_cache.gd")
const Fixture = preload("res://tests/ghost_replay_fixture.gd")
const Vary = preload("res://tests/ghost_retry_cache_suite.gd")
var path = "res://artifacts/ghost_load/fixture/race.json"
var course = "ghost-load-benchmark"
var seconds = 150.0
var output = "res://artifacts/ghost_load/results.json"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--fixture="): path=arg.trim_prefix("--fixture=")
		if arg.begins_with("--course="): course=arg.trim_prefix("--course=")
		if arg.begins_with("--seconds="): seconds=arg.trim_prefix("--seconds=").to_float()
	if not is_finite(seconds) or seconds<=0 or seconds>Replay.MAX_SECONDS:
		push_error("Seconds must be positive and at most 600."); quit(1); return
	if not path.begins_with("res://artifacts/") or ".." in path or not output.begins_with("res://artifacts/") or ".." in output:
		push_error("Benchmark fixture and output must be isolated in artifacts."); quit(1); return
	var identity = Replay.key(course)
	if "--prepare" in OS.get_cmdline_user_args():
		var rows: Array = []
		for i in 10:
			var replay = Fixture.replay(seconds,identity,true,float(i))
			Vary._vary_channels(replay,i)
			rows = Records.retain(rows,{"id":Records.run_id(),"time":seconds,"date":1700000000+i,"peak_kmh":40.0,"splits":[seconds*.2,seconds*.4,seconds*.6]},replay)
		var error = Records.save(path,identity,seconds,[seconds*.2,seconds*.4,seconds*.6],[],rows,Records.default_selection())
		if not error.is_empty(): push_error(error); quit(1); return
		print("Prepared ten current-format ",seconds,"-second varied synthetic recordings at 30 Hz stress density.")
	var loaded = Records.load_record(path,identity)
	if loaded.runs.size()!=10 or not loaded.runs.all(func(row): return row.time==seconds): push_error("Missing compatible ten-run fixture; use explicit --prepare."); quit(1); return
	var report = {"fixture":path,"seconds_per_run":seconds,"samples_hz":30,"scope":"Cold decoded cache, OS file cache uncontrolled; loading latency only, no FPS claim.","native_validation":Replay.native_validation_enabled}
	var cache = Cache.new()
	var before = Performance.get_monitor(Performance.MEMORY_STATIC)
	var start = Time.get_ticks_usec()
	var cold = Records.selected(path,identity,loaded.runs,Records.default_selection(),cache)
	report.cold_ms = (Time.get_ticks_usec()-start)/1000.0
	report.cold_static_memory_delta = Performance.get_monitor(Performance.MEMORY_STATIC)-before
	report.cold_stats = cache.stats()
	start = Time.get_ticks_usec()
	var warm = Records.selected(path,identity,loaded.runs,Records.default_selection(),cache)
	report.warm_ms = (Time.get_ticks_usec()-start)/1000.0
	report.warm_stats = cache.stats()
	report.valid = cold.runs.size()==10 and warm.runs.size()==10 and cache.decodes==10 and cache.hits==10
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t",true,true));file.close()
	print("GHOST_LOAD ",JSON.stringify(report))
	quit(0 if report.valid else 1)
