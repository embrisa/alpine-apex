extends SceneTree
const Records = preload("res://scripts/racing/competitive_record.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const Ghost = preload("res://scripts/presentation/personal_best_ghost.gd")
const Palette = preload("res://scripts/presentation/ghost_palette.gd")
const Fixture = preload("res://tests/ghost_replay_fixture.gd")
var checks = 0
var failures: Array = []
var metrics: Dictionary = {}
var directory = ""
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func _track_break_checks() -> void:
	var ghost = Ghost.new()
	ghost.snow_tracks = Ghost.Tracks.new()
	ghost.add_child(ghost.snow_tracks)
	var companion = Ghost.Tracks.new()
	ghost.add_child(companion)
	ghost.snow_tracks.foot_history.fill(Vector3.ZERO)
	ghost.snow_tracks.live_active.fill(true)
	ghost.snow_tracks.written = 3; ghost.snow_tracks.cursor = 3
	companion.foot_history.fill(Vector3.ONE)
	companion.live_active.fill(true)
	ghost.break_tracks()
	check(ghost.snow_tracks.foot_history.all(func(p): return not p.is_finite()) and not ghost.snow_tracks.live_active.any(func(value): return value),"Crash/skip break clears both typed live trail anchors")
	check(ghost.snow_tracks.written==3 and ghost.snow_tracks.cursor==3 and companion.live_active.all(func(value): return value) and companion.foot_history.all(func(p): return p==Vector3.ONE),"Breaking one ghost preserves its retained history and the other trail")
	ghost.break_tracks()
	check(ghost.snow_tracks.written==3 and ghost.snow_tracks.cursor==3,"Repeated inactive ghost updates keep retained history intact")
	ghost.free()

func run() -> void:
	_track_break_checks()
	directory = "user://ghost_archive_fixture_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var path = directory.path_join("race.json")
	var identity = Replay.key("ghost-archive-fixture")
	var runs: Array = []
	var history: Array = []
	var selection = Records.default_selection()
	var best = INF
	var first_id = ""
	for i in 25:
		# Old first run remains among the fastest after leaving last-20 history.
		var seconds: float = 1.0 if i==0 else 2.0+float((i*7)%13)/10.0
		var replay = Fixture.replay(seconds,identity,false,float(i))
		var row = {"id":Records.run_id(),"time":seconds,"date":1700000000+i,"peak_kmh":40.0,"splits":[-1.0,-1.0,-1.0]}
		if i==0: first_id = row.id
		history.push_front(Records.clean_result(row)); history.resize(mini(history.size(),20))
		best = minf(best,seconds)
		runs = Records.retain(runs,row,replay)
		check(Records.save(path,identity,best,row.splits,history,runs,selection).is_empty(),"Atomic eligible completion %d" % i)
	var loaded = Records.load_record(path,identity)
	check(loaded.history.size()==20 and loaded.runs.size()==10 and loaded.runs[0].id==first_id,"Top ten independently retains old fast runs after 25 recent results")
	check(loaded.runs.all(func(row): return not row.has("replay")),"Metadata load does not decode payloads")
	for i in range(1,loaded.runs.size()): check(not Records.ordered(loaded.runs[i],loaded.runs[i-1]),"Exact-time/date/ID rank ordering %d" % i)
	var active = Records.selected(path,identity,loaded.runs,selection)
	check(active.runs.size()==10,"Automatic defaults to all ten compatible recordings")
	var ids: Array = []
	for row in loaded.runs: ids.append(row.id)
	for count in range(1,11):
		selection = Records.default_selection(); selection.automatic_count = count
		check(Records.save(path,identity,best,[-1.0,-1.0,-1.0],history,loaded.runs,selection).is_empty(),"Save automatic fastest %d" % count)
		var restored = Records.load_record(path,identity)
		var chosen = Records.selected(path,identity,restored.runs,restored.selection).runs
		check(restored.selection==selection and chosen.map(func(row): return row.id)==ids.slice(0,count),"Automatic fastest %d survives reload and preserves rank" % count)
		check(Records.selected(path,identity,restored.runs.slice(0,2),restored.selection).runs.size()==mini(count,2),"Automatic %d handles fewer available recordings" % count)
	var obsolete_selection = {"mode":"manual","ids":[ids[0]]}
	check(Records.normalize_selection(obsolete_selection)==Records.default_selection(),"Obsolete selection metadata is reset, never migrated")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(Records.path_for(path)))
	manifest.selection = obsolete_selection
	preload("res://tests/test_report.gd").write(Records.path_for(path),JSON.stringify(manifest))
	var reset = Records.load_record(path,identity)
	check(reset.selection==Records.default_selection() and not reset.warning.is_empty() and reset.best==loaded.best and reset.history==loaded.history and reset.runs==loaded.runs,"Obsolete selection resets with notice while valid PB, history and payload references survive")
	for invalid_count in [NAN,INF,1.5,"3",null]:
		var invalid_selection = Records.default_selection(); invalid_selection.automatic_count = invalid_count
		check(Records.normalize_selection(invalid_selection)==Records.default_selection(),"Malformed automatic count resets to the current default")
	for limit in [-8,0,11,999]:
		var bounded = Records.default_selection(); bounded.automatic_count = limit
		check(Records.normalize_selection(bounded).automatic_count==clampi(limit,1,10),"Automatic count is bounded: %d" % limit)
	for count in [0,1,5,10]:
		selection = {"version":Records.SELECTION_VERSION,"automatic_count":10,"mode":"manual","ids":ids.slice(0,count)}
		check(Records.save(path,identity,best,[-1.0,-1.0,-1.0],history,loaded.runs,selection).is_empty(),"Save manual subset %d" % count)
		var restored = Records.load_record(path,identity)
		check(restored.selection==selection and Records.selected(path,identity,restored.runs,restored.selection).runs.size()==count,"Manual %d survives reload including empty" % count)
	var duplicate = loaded.runs[0].duplicate()
	var same = Records.retain(loaded.runs,duplicate,active.runs[0].replay)
	check(same.size()==10 and same[0].id==duplicate.id,"Duplicate stable run ID is never inserted twice")
	var tied = duplicate.duplicate(); tied.id = Records.run_id(); tied.date += 1
	var tied_runs = Records.retain(loaded.runs,tied,active.runs[0].replay)
	check(tied_runs.size()==10 and tied_runs[1].id==tied.id,"Distinct equal-time runs coexist in stable order")
	var manual_evicted = {"version":Records.SELECTION_VERSION,"automatic_count":10,"mode":"manual","ids":[loaded.runs[-1].id]}
	check(not Records.prune_selection(manual_evicted,tied_runs).is_empty() and manual_evicted.ids.is_empty(),"Eviction removes manual ID with explanation and no replacement")
	check(Records.load_record(directory.path_join("other.json"),Replay.key("other-race")).runs.is_empty(),"Separate race has independent archive and selection")
	var good = active.runs[0].replay
	check(Replay.decode(JSON.parse_string(JSON.stringify(good.to_data())),identity,good.duration)!=null,"Binary replay envelope round trips JSON numeric normalization")
	for invalid in ["version","physics","length","nan","quaternion","held","contact","times"]:
		var bad = Fixture.replay(1.0,identity)
		var expected = identity.duplicate()
		match invalid:
			"physics": expected.physics = -1
			"nan": bad.samples[0][1] = NAN
			"quaternion": bad.presentation[0][6] = 0
			"held": bad.inputs[8] = .25
			"contact": bad.presentation[0][Replay.Pose.CONTACT_START] = .5
			"times": bad.sample_times[1] = 0
		var data = bad.to_data()
		if invalid=="version": data.version = 5
		if invalid=="length": data.payload = "AAAA"
		check(Replay.decode(data,expected,1.0)==null,"Reject malformed replay "+invalid)
	var pending = Fixture.replay(1.0,identity)
	pending.complete = false
	check(Records.retain([],duplicate,pending).is_empty(),"Incomplete recording never becomes a retained run")
	var missing = loaded.runs[3]
	DirAccess.remove_absolute(Records.payload_directory(path).path_join(missing.sha256+".replay"))
	var survivors = Records.selected(path,identity,loaded.runs,Records.default_selection())
	check(survivors.unavailable.has(missing.id) and survivors.runs.size()<10 and not survivors.runs.is_empty(),"One missing payload does not block remaining valid ghosts")
	var limited = Records.default_selection(); limited.automatic_count = 4
	var filled = Records.selected(path,identity,loaded.runs,limited)
	check(filled.runs.size()==4 and filled.runs[-1].id==loaded.runs[4].id,"Automatic count fills from the next compatible recording after a missing payload")
	var before = FileAccess.get_sha256(Records.path_for(path))
	preload("res://tests/test_report.gd").write(directory.path_join("blocked"),"fixture")
	var error = Records.save(directory.path_join("blocked/race.json"),identity,best,[-1.0,-1.0,-1.0],history,loaded.runs,selection)
	check(not error.is_empty() and FileAccess.get_sha256(Records.path_for(path))==before,"Failed write leaves the committed manifest intact")
	for player in [Color.WHITE,Color.BLACK,Color("22c6de"),Color("c34741")]:
		var colors = Palette.assignment(loaded.runs,player)
		var unique: Array = []
		for color in colors.values():
			check(not unique.has(color),"Ten distinct swatches against "+player.to_html()); unique.append(color)
		check(colors==Palette.assignment(loaded.runs,player),"Palette stable for unchanged runs/appearance")
	if "--max-duration" in OS.get_cmdline_user_args(): _maximum_archive(identity)
	var report = {"checks":checks,"failures":failures,"metrics":metrics,"isolated_store":directory,"rendered_acceptance":"not performed by this suite"}
	DirAccess.make_dir_recursive_absolute("res://artifacts/ghost")
	preload("res://tests/test_report.gd").write("res://artifacts/ghost/archive_results.json",JSON.stringify(report,"\t"))
	print("GHOST_ARCHIVE_RESULTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _maximum_archive(identity: Dictionary) -> void:
	# Explicit storage-duration coverage, not a 600-second driving scenario.
	var path = directory.path_join("maximum.json")
	var rows: Array = []
	var encoded_bytes = 0
	var started = Time.get_ticks_usec()
	for i in 10:
		var recording = Fixture.replay(600.0,identity,true,float(i))
		var row = {"id":Records.run_id(),"time":600.0,"date":1700000000+i,"peak_kmh":50.0,"splits":[150.0,300.0,450.0]}
		rows = Records.retain(rows,row,recording)
		check(Records.save(path,identity,600.0,row.splits,[],rows,Records.default_selection()).is_empty(),"Maximum-duration payload %d saves" % i)
		encoded_bytes += rows[-1].bytes
	metrics.maximum_encode_ms = (Time.get_ticks_usec()-started)/1000.0
	metrics.maximum_uncompressed_bytes = encoded_bytes
	metrics.maximum_disk_bytes = 0
	for name_value in DirAccess.get_files_at(Records.payload_directory(path)):
		metrics.maximum_disk_bytes += FileAccess.open(Records.payload_directory(path).path_join(name_value),FileAccess.READ).get_length()
	var memory_before = Performance.get_monitor(Performance.MEMORY_STATIC)
	started = Time.get_ticks_usec()
	var loaded = Records.load_record(path,identity)
	metrics.maximum_metadata_load_ms = (Time.get_ticks_usec()-started)/1000.0
	started = Time.get_ticks_usec()
	var selected = Records.selected(path,identity,loaded.runs,Records.default_selection())
	metrics.maximum_selected_load_ms = (Time.get_ticks_usec()-started)/1000.0
	metrics.maximum_decoded_static_memory_delta = Performance.get_monitor(Performance.MEMORY_STATIC)-memory_before
	check(selected.runs.size()==10 and encoded_bytes<=Records.MAX_AGGREGATE_BYTES,"Ten full supported-duration recordings fit documented aggregate and decode")
