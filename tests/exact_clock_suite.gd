extends SceneTree
## Bounded storage/codec checks, no solver stepping, world build or native claims.
const Clock = preload("res://scripts/racing/record_clock.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const Records = preload("res://scripts/racing/competitive_record.gd")
const Cache = preload("res://scripts/racing/ghost_replay_cache.gd")
const Fixture = preload("res://tests/ghost_replay_fixture.gd")
const PB_HEX = "c0b9808fbc962740"
const PARSED_PB_HEX = "c1b9808fbc962740"
const SPLIT_HEX = ["7910c84bbc8f1b40","64faf578ecc12140","a3fc4ebaa3dc2440"]
var checks = 0
var failures: Array = []
var evidence: Dictionary = {}
var directory = ""

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
	return value

func from_hex(value: String) -> float:
	# Independent binary reader: constants never pass through a decimal parser.
	var stream = StreamPeerBuffer.new()
	stream.data_array = value.hex_decode()
	return stream.get_double()

func bits(value: float) -> String:
	return PackedFloat64Array([value]).to_byte_array().hex_encode()

func split_values() -> Array:
	var result: Array = []
	for value in SPLIT_HEX: result.append(from_hex(value))
	return result

func same_times(a: Array, b: Array) -> bool:
	if a.size()!=b.size(): return false
	for i in a.size():
		if not a[i] is float or bits(a[i])!=bits(b[i]): return false
	return true

func run() -> void:
	directory = "user://exact_clock_fixture_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	_codec_checks()
	var identity = Replay.key("exact-clock-counterexample")
	var replay = _crash_fixture(identity)
	_replay_checks(replay,identity)
	_archive_checks(replay,identity)
	var report = {"checks":checks,"failures":failures,"evidence":evidence,"isolated_store":directory,"engine":Engine.get_version_info(),"engine_rendering":"not exercised"}
	var output = "res://artifacts/orchestration_20260912/carving/exact_clock"
	DirAccess.make_dir_recursive_absolute(output)
	var file = preload("res://tests/test_report.gd").open_write(output.path_join("results.json"))
	file.store_string(JSON.stringify(report,"\t",true,true)); file.close()
	print("EXACT_CLOCK_RESULTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _codec_checks() -> void:
	check(Replay.VERSION==7 and Records.VERSION==4 and Records.path_for("race.json")=="race_competition_v4.apexrun","New archive/replay namespace is explicit; no decimal-schema migration")
	var known = [PB_HEX,PARSED_PB_HEX,"a3fc4ebaa3dc2440","a4fc4ebaa3dc2440","000000000000f0bf","0000000000000000","0000000000000080","0100000000000000","ffffffffffffef7f","0000000000c08240","000000000018f540"]
	for value in known:
		var encoded = Clock.encode(from_hex(value))
		var decoded = Clock.decode(JSON.parse_string(JSON.stringify(encoded)))
		check(encoded==value and decoded is float and bits(decoded)==value,"Known IEEE754 bytes survive JSON string boundary: "+value)
	# Neighbouring representable race times, including values beyond replay limit
	# that remain legal result-only records. Keep workload tiny and deterministic.
	var roundtrips = true
	for base in [PB_HEX,SPLIT_HEX[2],"0000000000c08240","000000000018f540"]:
		var bytes = base.hex_decode()
		var word = bytes.decode_u64(0)
		for offset in range(-8,9):
			bytes.encode_u64(0,word+offset)
			var source = bytes.decode_double(0)
			var restored = Clock.decode(JSON.parse_string(JSON.stringify(Clock.encode(source))))
			roundtrips = roundtrips and restored is float and bits(restored)==bits(source)
	check(roundtrips,"68 neighbouring float64 timing patterns round trip bit-for-bit")
	for invalid in [null,true,12,11.794407352889607,[],{},"",PB_HEX.to_upper(),PB_HEX+"00","g".repeat(16),"0".repeat(65536),"000000000000f07f","000000000000f0ff","010000000000f87f"]:
		check(Clock.decode(invalid)==null,"Malformed/nonfinite/decimal wire clock rejected (case %d)" % checks)
	check(Clock.decode_array([PB_HEX],2)==null and Clock.decode_array([PB_HEX,PB_HEX],3)==null and Clock.decode_array([PB_HEX,PB_HEX],2000000)==null,"Array dimensions are checked before decoding or allocation")
	check(Clock.encode(INF).is_empty() and Clock.encode(NAN).is_empty(),"Nonfinite clock cannot be encoded as a valid wire value")
	evidence.decimal_counterexample = {"source_pb_f64":PB_HEX,"historical_loaded_pb_f64":PARSED_PB_HEX,"current_decimal_parser_pb_f64":bits(JSON.parse_string("11.794407352889607")),"source_split_f64":SPLIT_HEX[2],"current_decimal_parser_split_f64":bits(JSON.parse_string("10.430936643735839"))}

func _crash_fixture(identity: Dictionary):
	var replay = Fixture.replay(from_hex(PB_HEX),identity)
	# Actual failed lifecycle's accumulated 120 Hz clocks, not rounded literals.
	var start = from_hex("152222222222f83f")
	var end = from_hex("0311111111110440")
	var times = PackedFloat64Array([0.0,start,end,replay.duration])
	var first: PackedFloat32Array = replay.samples[0].duplicate()
	var pose: PackedFloat32Array = replay.presentation[0].duplicate()
	replay.samples.clear(); replay.presentation.clear()
	for time in times:
		var frame = first.duplicate(); frame[0] = time
		replay.samples.append(frame); replay.presentation.append(pose.duplicate())
	replay.sample_times = times; replay.pose_times = times.duplicate()
	replay.crash_intervals = [[start,end]]
	for tick in range(181,301): replay.tick_kinds[tick] = 1
	return replay

func _with_header(bytes: PackedByteArray, header: Dictionary) -> PackedByteArray:
	var old_size = bytes.decode_u32(8)
	var encoded = JSON.stringify(header,"",true,true).to_utf8_buffer()
	var result = bytes.slice(0,32)
	result.encode_u32(8,encoded.size())
	result.append_array(encoded); result.append_array(bytes.slice(32+old_size))
	return result

func _header(bytes: PackedByteArray) -> Dictionary:
	return JSON.parse_string(bytes.slice(32,32+bytes.decode_u32(8)).get_string_from_utf8())

func _replay_checks(replay, identity: Dictionary) -> void:
	var bytes: PackedByteArray = replay.to_bytes()
	var decoded = Replay.from_bytes(bytes,identity,replay.duration)
	if not check(decoded!=null,"Counterexample replay with actual 120-tick crash interval decodes"): return
	check(bits(bytes.decode_double(24))==PB_HEX and bits(decoded.duration)==PB_HEX,"Loaded duration equals the stored binary seconds exactly")
	check(decoded.sample_times.to_byte_array()==replay.sample_times.to_byte_array() and decoded.pose_times.to_byte_array()==replay.pose_times.to_byte_array(),"All sample and articulated-pose timestamps preserve exact bytes")
	check(same_times(decoded.crash_intervals[0],replay.crash_intervals[0]) and decoded.tick_kinds==replay.tick_kinds,"Crash endpoints preserve bits and inactive tick mask")
	check(decoded.in_crash(replay.crash_intervals[0][0]) and decoded.presentation_at(2.0).is_empty() and not decoded.presentation_at(replay.crash_intervals[0][1]).is_empty(),"Exact endpoints retain crash hiding and recovery playback semantics")
	check(decoded.inputs.to_byte_array()==replay.inputs.to_byte_array() and decoded.samples==replay.samples and decoded.presentation==replay.presentation,"Input, physical and pose channels are unchanged")
	var envelope = JSON.parse_string(JSON.stringify(replay.to_data()))
	var restored = Replay.decode(envelope,identity,replay.duration)
	check(restored!=null and bits(restored.duration)==PB_HEX,"Serialized replay envelope also preserves exact duration")
	check(Replay.from_bytes(bytes,identity,from_hex(PARSED_PB_HEX))==null and Replay.decode(envelope,identity,from_hex(PARSED_PB_HEX))==null,"Original one-ULP parsed PB mismatch is rejected without tolerance")
	envelope.duration = PARSED_PB_HEX
	check(Replay.decode(envelope,identity,replay.duration)==null,"Envelope/binary one-ULP duration disagreement is rejected")
	envelope.duration = replay.duration
	check(Replay.decode(envelope,identity,replay.duration)==null,"Decimal envelope duration has no legacy fallback")
	var wrong_identity = identity.duplicate(); wrong_identity.physics += 1
	check(Replay.from_bytes(bytes,wrong_identity,replay.duration)==null,"Existing full replay identity validation remains required")
	for kind in ["duration_ulp","endpoint_ulp","old_version","huge_header","huge_count","truncated"]:
		var broken = bytes.duplicate()
		match kind:
			"duration_ulp": broken.encode_double(24,from_hex(PARSED_PB_HEX))
			"endpoint_ulp":
				var count = broken.decode_u32(12)
				broken.encode_double(32+broken.decode_u32(8)+(count-1)*8,from_hex(PARSED_PB_HEX))
			"old_version": broken.encode_u32(4,6)
			"huge_header": broken.encode_u32(8,16385)
			"huge_count": broken.encode_u32(12,0xffffffff)
			"truncated": broken.resize(31)
		check(Replay.from_bytes(broken,identity,replay.duration)==null,"Reject bounded binary corruption: "+kind)
	var original_header = _header(bytes)
	for kind in ["decimal","ulp_start","ulp_end","negative","past_finish","reversed","overlap","too_many","malformed","nonfinite"]:
		var header = original_header.duplicate(true)
		match kind:
			"decimal": header.crashes[0] = replay.crash_intervals[0]
			"ulp_start", "ulp_end":
				var endpoint = 0 if kind=="ulp_start" else 1
				var word = header.crashes[0][endpoint].hex_decode()
				word.encode_u64(0,word.decode_u64(0)+1)
				header.crashes[0][endpoint] = word.hex_encode()
			"negative": header.crashes[0][0] = Clock.encode(-1.0)
			"past_finish": header.crashes[0][1] = Clock.encode(12.0)
			"reversed": header.crashes[0].reverse()
			"overlap": header.crashes.append(header.crashes[0].duplicate())
			"too_many":
				header.crashes.clear()
				for i in Replay.MAX_EVENTS+1: header.crashes.append([Clock.encode(0.0),Clock.encode(0.0)])
			"malformed": header.crashes[0] = [PB_HEX]
			"nonfinite": header.crashes[0][0] = "000000000000f07f"
		check(Replay.from_bytes(_with_header(bytes,header),identity,replay.duration)==null,"Reject corrupt crash timing: "+kind)
	check(Replay.from_bytes(bytes,identity,601.0)==null and Replay.from_bytes(bytes,identity,0.0)==null,"Replay duration retains positive ten-minute bound")
	var almost_finished = Fixture.replay(replay.duration,identity)
	almost_finished.duration = from_hex(PARSED_PB_HEX)
	check(not almost_finished.has_presentation() and almost_finished.to_bytes().is_empty(),"Writer rejects a one-ULP final timestamp/duration mismatch")
	var limit_header = {"compatibility":identity,"crashes":[]}
	for i in Replay.MAX_EVENTS: limit_header.crashes.append([Clock.encode(0.0),Clock.encode(0.0)])
	check(JSON.stringify(limit_header).to_utf8_buffer().size()<=16384,"All 256 encoded crash pairs fit the unchanged 16 KiB header budget")
	evidence.replay = {"bytes":bytes.size(),"header_bytes":bytes.decode_u32(8),"duration_f64":bits(decoded.duration),"crash_wire":original_header.crashes,"inactive_ticks":decoded.tick_kinds.count(1),"sample_times_f64":decoded.sample_times.to_byte_array().hex_encode(),"pose_times_f64":decoded.pose_times.to_byte_array().hex_encode()}

func _row(seconds: float, id: String) -> Dictionary:
	return {"id":id,"time":seconds,"date":1700000000,"peak_kmh":40.0,"splits":split_values()}

func _manifest(path: String, data: Dictionary) -> void:
	var file = preload("res://tests/test_report.gd").open_write(Records.path_for(path))
	file.store_string(JSON.stringify(data,"",true,true)); file.close()

func _archive_checks(replay, identity: Dictionary) -> void:
	var path = directory.path_join("race.json")
	var row = _row(replay.duration,"11111111111111111111111111111111")
	var history = [Records.clean_result(row)]
	var runs = Records.retain([],row,replay)
	if not check(runs.size()==1 and Records.save(path,identity,replay.duration,row.splits,history,runs,Records.default_selection()).is_empty(),"Atomic archive saves counterexample clocks"): return
	var stored = JSON.parse_string(FileAccess.get_file_as_string(Records.path_for(path)))
	var loaded = Records.load_record(path,identity)
	if not check(loaded.runs.size()==1 and loaded.history.size()==1,"Metadata-only reload retains run and history"): return
	check(stored.best==PB_HEX and stored.splits==SPLIT_HEX and stored.runs[0].time==PB_HEX and stored.runs[0].splits==SPLIT_HEX and stored.history[0].time==PB_HEX and stored.history[0].splits==SPLIT_HEX,"Every on-disk PB/split/run/history timing uses lossless binary hex")
	check(loaded.best is float and bits(loaded.best)==PB_HEX and same_times(loaded.splits,row.splits) and bits(loaded.runs[0].time)==PB_HEX and same_times(loaded.runs[0].splits,row.splits) and bits(loaded.history[0].time)==PB_HEX and same_times(loaded.history[0].splits,row.splits),"All public metadata clocks remain numeric and bit-exact")
	check(runs[0].time is float and same_times(runs[0].splits,row.splits) and not runs[0].has("replay") and not loaded.runs[0].has("replay") and same_times(history[0].splits,row.splits),"Committed rows publish numeric metadata only; caller history is untouched")
	var rank_path = directory.path_join("adjacent-ranks.json")
	var neighbour = Fixture.replay(from_hex(PARSED_PB_HEX),identity)
	var close_runs = Records.retain([],row,replay)
	close_runs = Records.retain(close_runs,_row(neighbour.duration,"00000000000000000000000000000000"),neighbour)
	var close_history = [Records.clean_result(row),Records.clean_result(_row(neighbour.duration,"00000000000000000000000000000000"))]
	var ranked_ok = Records.save(rank_path,identity,replay.duration,row.splits,close_history,close_runs,loaded.selection).is_empty()
	var ranked = Records.load_record(rank_path,identity)
	check(ranked_ok and ranked.runs.size()==2 and ranked.runs[0].id==row.id and bits(ranked.runs[0].time)==PB_HEX and bits(ranked.runs[1].time)==PARSED_PB_HEX and bits(ranked.history[1].time)==PARSED_PB_HEX,"One-ULP neighbouring run/history clocks stay distinct and sort by time before ID")
	var cache = Cache.new()
	var cold = Records.selected(path,identity,loaded.runs,loaded.selection,cache)
	var warm = Records.selected(path,identity,loaded.runs,loaded.selection,cache)
	if check(cold.runs.size()==1 and warm.runs.size()==1,"Counterexample archive selects both cold and cached replay"):
		check(cache.decodes==1 and cache.hits==1 and warm.runs[0].replay==cold.runs[0].replay and bits(warm.runs[0].replay.duration)==PB_HEX,"Unchanged retry preserves exact clocks and reuses validated object with zero extra decode")
	var shifted = loaded.runs.duplicate(true); shifted[0].time = from_hex(PARSED_PB_HEX)
	var unavailable = Records.selected(path,identity,shifted,loaded.selection,cache)
	check(unavailable.runs.is_empty() and unavailable.unavailable.size()==1 and cache.hits==1 and cache.stats().entries==0,"One-ULP row change invalidates cache and fails full duration identity validation")
	var pending = Records.retain([],row,replay)
	pending[0].time = from_hex(PARSED_PB_HEX)
	check(Records.retain([],_row(from_hex(PARSED_PB_HEX),row.id),replay).is_empty() and Records.selected(path,identity,pending,loaded.selection).runs.is_empty(),"Pending/retained replay cannot bypass exact metadata-duration match")
	var before = FileAccess.get_sha256(Records.path_for(path))
	check(not Records.save(path,identity,replay.duration,row.splits,history,pending,loaded.selection).is_empty() and FileAccess.get_sha256(Records.path_for(path))==before and pending[0].has("replay"),"One-ULP pending mismatch fails atomically without publishing references")
	var committed_bytes = FileAccess.get_file_as_bytes(Records.path_for(path))
	_corrupt_archive_checks(path,identity,stored,replay.duration)
	var restored_manifest = preload("res://tests/test_report.gd").open_write(Records.path_for(path))
	restored_manifest.store_buffer(committed_bytes); restored_manifest.close()
	_transaction_checks(path,identity,loaded,replay)
	var sentinel_path = directory.path_join("sentinel.json")
	var empty: Array = []
	check(Records.save(sentinel_path,identity,-1.0,[-1.0,-1.0,-1.0],[],empty,Records.default_selection()).is_empty() and Records.load_record(sentinel_path,identity).best==-1.0,"Empty archive sentinel remains distinct from malformed wire timing")
	var long_row = _row(86400.0,row.id)
	check(Records.save(sentinel_path,identity,86400.0,long_row.splits,[long_row],empty,Records.default_selection()).is_empty() and bits(Records.load_record(sentinel_path,identity).history[0].time)==bits(86400.0),"Existing one-day result-only bound remains legal without a replay")
	for bad_best in [NAN,INF,0.0,-2.0,86400.00001]:
		check(not Records.save(sentinel_path,identity,bad_best,row.splits,[],empty,Records.default_selection()).is_empty(),"Invalid PB range/nonfinite write is rejected")
	var invalid_history = history.duplicate(true); invalid_history[0].splits[2] = INF
	var invalid_splits = row.splits.duplicate(); invalid_splits[2] = 12.0
	check(not Records.save(path,identity,replay.duration,invalid_splits,history,empty,loaded.selection).is_empty() and not Records.save(path,identity,replay.duration,row.splits,invalid_history,empty,loaded.selection).is_empty() and FileAccess.get_sha256(Records.path_for(path))==before,"Invalid split/history save cannot replace a committed valid record")
	evidence.archive = {"pb_f64":bits(loaded.best),"splits_wire":stored.splits,"run_f64":bits(loaded.runs[0].time),"history_f64":bits(loaded.history[0].time),"manifest_bytes":FileAccess.get_file_as_bytes(Records.path_for(path)).size(),"cache":cache.stats()}

func _corrupt_archive_checks(path: String, identity: Dictionary, stored: Dictionary, seconds: float) -> void:
	for kind in ["old_schema","wrong_course","decimal_best","nonfinite_best","past_bound_best","bad_split","past_finish_split","reverse_splits","decimal_history","nonfinite_history","decimal_run","past_bound_run","bad_run_splits","too_many_runs"]:
		var data = stored.duplicate(true)
		match kind:
			"old_schema": data.version = 3
			"wrong_course": data.course = "different"
			"decimal_best": data.best = seconds
			"nonfinite_best": data.best = "000000000000f07f"
			"past_bound_best": data.best = Clock.encode(86401.0)
			"bad_split": data.splits[2] = "not-a-clock"
			"past_finish_split": data.splits[2] = Clock.encode(12.0)
			"reverse_splits": data.splits.reverse()
			"decimal_history": data.history[0].time = seconds
			"nonfinite_history": data.history[0].splits[2] = "010000000000f87f"
			"decimal_run": data.runs[0].time = seconds
			"past_bound_run": data.runs[0].time = Clock.encode(86401.0)
			"bad_run_splits": data.runs[0].splits = [PB_HEX]
			"too_many_runs":
				for i in Records.MAX_RUNS: data.runs.append(data.runs[0].duplicate(true))
		_manifest(path,data)
		var result = Records.load_record(path,identity)
		var rejected = false
		if kind in ["old_schema","wrong_course"]: rejected = result.best==-1.0 and result.runs.is_empty() and result.history.is_empty()
		elif kind.ends_with("best"): rejected = result.best==-1.0 and result.history.size()==1
		elif kind in ["bad_split","past_finish_split","reverse_splits"]: rejected = bits(result.best)==PB_HEX and result.splits==[-1.0,-1.0,-1.0]
		elif kind.ends_with("history"): rejected = result.history.is_empty() and bits(result.best)==PB_HEX
		else: rejected = result.runs.is_empty() and bits(result.best)==PB_HEX and result.history.size()==1
		check(rejected,"Malformed clock rejected while independent valid metadata survives: "+kind)
	var file = preload("res://tests/test_report.gd").open_write(Records.path_for(path))
	file.store_string(" ".repeat(Records.MAX_BYTES+1)); file.close()
	check(Records.load_record(path,identity).best==-1.0,"Manifest byte limit is enforced before JSON parse")

func _transaction_checks(path: String, identity: Dictionary, loaded: Dictionary, replay) -> void:
	# Force failure AFTER a new immutable blob is written, at manifest commit.
	var fresh = Fixture.replay(replay.duration,identity,false,7.0)
	var pending = Records.retain([],_row(fresh.duration,"22222222222222222222222222222222"),fresh)
	var new_blob = Records.payload_directory(path).path_join(Records._sha256(fresh.to_bytes())+".replay")
	var old_blob = Records.payload_directory(path).path_join(loaded.runs[0].sha256+".replay")
	var manifest_hash = FileAccess.get_sha256(Records.path_for(path))
	var old_hash = FileAccess.get_sha256(old_blob)
	var blocker = Records.path_for(path)+".tmp"
	if not check(DirAccess.make_dir_recursive_absolute(blocker)==OK and not FileAccess.file_exists(new_blob),"Isolated post-blob manifest failure fixture is non-vacuous"): return
	var error = Records.save(path,identity,loaded.best,loaded.splits,loaded.history,pending,loaded.selection)
	check(not error.is_empty() and not FileAccess.file_exists(new_blob) and FileAccess.get_sha256(Records.path_for(path))==manifest_hash and FileAccess.get_sha256(old_blob)==old_hash and pending[0].has("replay"),"Failed manifest write removes only newly created blob; old manifest/blob and pending references survive")
	DirAccess.remove_absolute(blocker)
