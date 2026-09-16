extends SceneTree
## Bounded dense codec/storage fixtures. No riding, personal writes or visuals.
## Optional --reuse-maximum=<existing isolated maximum.json>: read-only reuse,
## never regenerates ten 600-second payloads. Requires Session integration patch.
const Records = preload("res://scripts/racing/competitive_record.gd")
const Replay = preload("res://scripts/racing/run_replay.gd")
const Cache = preload("res://scripts/racing/ghost_replay_cache.gd")
const Session = preload("res://scripts/core/run_session.gd")
const Fixture = preload("res://tests/ghost_replay_fixture.gd")
var checks = 0
var failures: Array = []
var metrics: Dictionary = {}
var directory = ""

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
	return value

func run() -> void:
	directory = "user://ghost_retry_fixture_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var maximum_path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reuse-maximum="): maximum_path = arg.trim_prefix("--reuse-maximum=")
	if "--maximum-only" not in OS.get_cmdline_user_args(): _small_archive()
	if not maximum_path.is_empty(): _maximum_reuse(maximum_path)
	elif "--maximum-only" in OS.get_cmdline_user_args(): check(false,"--maximum-only requires an existing isolated --reuse-maximum path")
	var report = {"checks":checks,"failures":failures,"metrics":metrics,"isolated_store":directory,"cold_maximum_latency":"Unresolved: prior ten x 600 s decode was 42764.478 ms. Cache only removes repeated validation of unchanged payloads.","rendered_acceptance":"not exercised"}
	DirAccess.make_dir_recursive_absolute("res://artifacts/ghost")
	var file = preload("res://tests/test_report.gd").open_write("res://artifacts/ghost/retry_cache_results.json")
	file.store_string(JSON.stringify(report,"\t",true,true)); file.close()
	print("GHOST_RETRY_CACHE_RESULTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _small_archive() -> void:
	var identity = Replay.key("ghost-retry-cache-fixture")
	var path = directory.path_join("race.json")
	var rows: Array = []
	for i in 10:
		# 15 seconds at production sample density and input width, different roots.
		var replay = Fixture.replay(15.0,identity,true,float(i))
		_vary_channels(replay,i)
		rows = Records.retain(rows,{"id":Records.run_id(),"time":15.0,"date":1700000000+i,"peak_kmh":40.0,"splits":[3.0,6.0,9.0]},replay)
	if not check(Records.save(path,identity,15.0,[3.0,6.0,9.0],[],rows,Records.default_selection()).is_empty(),"Save ten isolated dense 15-second payloads once"): return
	var session = Session.new()
	session.course_id = identity.course; session.benchmark_path = path
	session.record_directory = directory.path_join("records")
	session.load_record()
	check(session.ghost_runs.size()==10 and session.ghost_runs.all(func(row): return not row.has("replay")) and session.ghost_cache.stats().entries==0,"Session metadata load does not decode or populate cache")
	metrics.small_cold = _timed_reset(session)
	check(session.reference_ghosts.size()==10 and metrics.small_cold.decodes==10,"Cold attempt fully decodes all ten selected recordings")
	var cold = session.reference_ghosts.duplicate()
	metrics.small_cached_retry = _timed_reset(session)
	check(metrics.small_cached_retry.decodes==0 and metrics.small_cached_retry.hits==10,"Unchanged retry performs zero decodes and ten cache hits")
	check(_same_replays(cold,session.reference_ghosts),"Retry shares validated objects without copying pose/input arrays")
	check(session.ghost_cache.stats().entries==10 and session.ghost_cache.stats().payload_bytes<=Cache.MAX_BYTES,"Cache is bounded to ten and the existing aggregate payload budget")
	var best: float = session.personal_best
	var reference_splits = session.reference_splits.duplicate()
	var ids: Array = []
	for row in session.ghost_runs: ids.append(row.id)
	session.choose_ghosts("manual",ids.slice(0,3))
	check(_same_replays(cold,session.reference_ghosts),"Selection changes leave current attempt references frozen")
	metrics.small_subset_retry = _timed_reset(session)
	check(session.reference_ghosts.size()==3 and metrics.small_subset_retry.decodes==0 and metrics.small_subset_retry.hits==3 and session.ghost_cache.stats().entries==3,"Next attempt reuses chosen subset and releases deselected cache references")
	check(session.previous_best==best and session.reference_splits==reference_splits,"Cache and selection do not change PB/split references")
	session.choose_ghosts("manual",[]); session.reset()
	check(session.reference_ghosts.is_empty() and session.ghost_cache.stats().entries==0,"Explicit empty selection clears decoded cache at next attempt")
	session.choose_ghosts("automatic",[])
	metrics.small_reselected_cold = _timed_reset(session)
	check(session.reference_ghosts.size()==10 and metrics.small_reselected_cold.decodes==10,"Reselecting released payloads still requires full decoding")
	var evicted: String = session.ghost_runs[-1].id
	var frozen_ids = session.reference_ghosts.map(func(row): return row.id)
	session.ghost_runs.pop_back(); session.save_record()
	check(session.save_error.is_empty() and evicted not in session.ghost_cache.stats().ids and session.ghost_cache.stats().entries==9,"Archive publication prunes evicted cache entry immediately")
	check(session.reference_ghosts.map(func(row): return row.id)==frozen_ids,"Eviction leaves the already frozen attempt unchanged")
	metrics.small_after_eviction = _timed_reset(session)
	check(session.reference_ghosts.size()==9 and metrics.small_after_eviction.decodes==0,"Eviction does not re-decode surviving immutable recordings")
	var loaded = Records.load_record(path,identity)
	_payload_invalidation(path,identity,loaded.runs)
	_identity_and_scope(path,identity,loaded.runs)
	session.load_record()
	check(session.ghost_cache.stats().entries==0 and session.ghost_runs.all(func(row): return not row.has("replay")),"Explicit archive reload clears cache and remains metadata-only")
	session.reset()
	session.configure_free("isolated-free-ski")
	check(session.ghost_cache.stats().entries==0 and session.reference_ghosts.is_empty() and not session.eligible,"Leaving race for free ski releases cache and competitors")

static func _vary_channels(replay, variant: int) -> void:
	# Exercise changing inputs/joint rotations/contact channels instead of timing
	# only zero-filled compression. Still a codec fixture, not visual evidence.
	for tick in replay.ticks:
		var time: float = tick*Replay.DT+variant*.13
		var start: int = tick*Replay.INPUT_WIDTH
		replay.inputs[start] = .4*sin(time*.7)
		replay.inputs[start+1] = .45+.4*sin(time*.6)
		replay.inputs[start+2] = .1*maxf(0.0,sin(time*.4))
	for i in replay.presentation.size():
		var time: float = replay.pose_times[i]+variant*.13
		var pose: PackedFloat32Array = replay.presentation[i].duplicate()
		for bone in range(1,25):
			var angle = .22*sin(time*.7+bone*.31)
			var q = Quaternion(Vector3.RIGHT if bone%2 else Vector3.UP,angle)
			var start = bone*7
			pose[start+3] = q.x; pose[start+4] = q.y; pose[start+5] = q.z; pose[start+6] = q.w
		for side in 2:
			var start: int = Replay.Pose.CONTACT_START+side*Replay.Pose.CONTACT_WIDTH
			pose[start+2] = .3+.05*sin(time+side)
			pose[start+5] = .1+.1*sin(time*.8+side)
		replay.presentation[i] = pose
		replay.samples[i][6] = .45+.4*sin(time*.6)

func _payload_invalidation(path: String, identity: Dictionary, rows: Array) -> void:
	var cache = Cache.new()
	var selected = Records.selected(path,identity,rows,Records.default_selection(),cache)
	if not check(selected.runs.size()==rows.size(),"Populate invalidation fixture from validated bytes"): return
	var target: Dictionary = rows[0]
	var blob = Records.payload_directory(path).path_join(target.sha256+".replay")
	var original = FileAccess.get_file_as_bytes(blob)
	# Another valid Zstd recording of the same uncompressed size avoids invoking
	# a malformed compression stream; manifest content hashing must still reject it.
	var other_blob = Records.payload_directory(path).path_join(rows[1].sha256+".replay")
	var changed = FileAccess.get_file_as_bytes(other_blob)
	check(original!=changed and target.bytes==rows[1].bytes,"Corruption fixture changes content while preserving the decoded length")
	_write(blob,changed)
	var before = cache.stats()
	var metadata = Records.load_record(path,identity)
	check(metadata.runs.size()==rows.size() and metadata.runs.all(func(row): return not row.has("replay")) and cache.stats()==before,"Metadata-only reload defers corrupt payload validation until selection")
	var corrupted = Records.selected(path,identity,rows,Records.default_selection(),cache)
	check(target.id in corrupted.unavailable and corrupted.runs.size()==rows.size()-1,"Changed on-disk content cannot use a formerly validated cached replay")
	check(cache.stats().hits-before.hits==rows.size()-1 and target.id not in cache.stats().ids,"Only corrupted entry is dropped; survivors remain cache hits")
	_write(blob,original)
	before = cache.stats()
	selected = Records.selected(path,identity,rows,Records.default_selection(),cache)
	check(selected.runs.size()==rows.size() and cache.stats().decodes-before.decodes==1,"Restored payload must pass full decoder again")
	# Hold the previous manifest size constant as well as the payload descriptor;
	# the lookup trusts the computed content digest, never file length/timestamp.
	var digest = Records._sha256(original)
	check(cache.lookup(target,digest)!=null,"Exact validated compressed digest can be reused")
	check(cache.lookup(target,Records._sha256(changed))==null,"Different digest invalidates even when manifest/size metadata are unchanged")
	Records.selected(path,identity,rows,Records.default_selection(),cache)
	DirAccess.remove_absolute(blob)
	var missing = Records.selected(path,identity,rows,Records.default_selection(),cache)
	check(target.id in missing.unavailable and target.id not in cache.stats().ids,"Missing immutable file invalidates cached entry")
	_write(blob,original)
	Records.selected(path,identity,rows,Records.default_selection(),cache)
	var retimed = rows.duplicate(true); retimed[0].time += .25
	var retimed_result = Records.selected(path,identity,retimed,Records.default_selection(),cache)
	check(target.id in retimed_result.unavailable and retimed_result.runs.size()==rows.size()-1,"Manifest duration change cannot reuse a stale cached object")
	Records.selected(path,identity,rows,Records.default_selection(),cache)
	var resized = rows.duplicate(true); resized[0].bytes += 4
	var resized_result = Records.selected(path,identity,resized,Records.default_selection(),cache)
	check(target.id in resized_result.unavailable,"Manifest decoded-size change cannot reuse a stale cached object")
	# Swap to another existing, fully valid immutable payload under the same run
	# ID. The new manifest descriptor must be decoded, not serve the old pose.
	Records.selected(path,identity,rows,Records.default_selection(),cache)
	var replaced = rows.duplicate(true)
	replaced[0].sha256 = rows[1].sha256; replaced[0].bytes = rows[1].bytes
	before = cache.stats()
	var replacement = Records.selected(path,identity,replaced,Records.default_selection(),cache)
	check(replacement.unavailable.is_empty() and cache.stats().decodes-before.decodes==1,"Changed payload descriptor receives full validation")
	check(replacement.runs[0].replay.samples[0][1]==replacement.runs[1].replay.samples[0][1],"Same run ID now presents the newly validated payload")
	# Correct outer hash is not sufficient to admit a bad replay into the cache.
	var raw = original.decompress(int(target.bytes),FileAccess.COMPRESSION_ZSTD)
	raw[0] = 0
	var malformed = target.duplicate(); malformed.sha256 = Records._sha256(raw)
	_write(Records.payload_directory(path).path_join(malformed.sha256+".replay"),raw.compress(FileAccess.COMPRESSION_ZSTD))
	before = cache.stats()
	var malformed_result = Records.selected(path,identity,[malformed],Records.default_selection(),cache)
	check(malformed.id in malformed_result.unavailable and cache.stats().decodes-before.decodes==1 and cache.stats().entries==0,"New matching-hash bytes still require structural decoder validation")

func _identity_and_scope(path: String, identity: Dictionary, rows: Array) -> void:
	var cache = Cache.new()
	var manual = {"mode":"manual","ids":[rows[0].id]}
	Records.selected(path,identity,rows,manual,cache)
	for key in ["course","engine","physics","tuning","tick_hz"]:
		var changed = identity.duplicate()
		if key in ["physics","tick_hz"]: changed[key] += 1
		else: changed[key] += "-changed"
		var before = cache.stats()
		var rejected = Records.selected(path,changed,rows,manual,cache)
		check(rejected.runs.is_empty() and cache.stats().hits==before.hits and cache.stats().entries==0,"Identity invalidates cached payload: "+key)
		Records.selected(path,identity,rows,manual,cache)
	var before = cache.stats()
	var other = Records.selected(directory.path_join("other-race.json"),identity,rows,manual,cache)
	check(other.runs.is_empty() and cache.stats().hits==before.hits and cache.stats().entries==0,"Different storage scope cannot reuse another race archive")
	var excessive = rows.duplicate()
	while excessive.size()<=10: excessive.append(rows[0])
	check(Records.selected(path,identity,excessive,Records.default_selection(),cache).runs.is_empty() and cache.stats().entries==0,"Oversized roster is rejected without exceeding cache capacity")

func _maximum_reuse(path: String) -> void:
	# Explicitly read only the parent's existing isolated storage fixture.
	if not check(path.begins_with("user://ghost_archive_fixture_") and path.get_file()=="maximum.json" and ".." not in path,"Maximum reuse path names an existing isolated archive"): return
	if not check(FileAccess.file_exists(Records.path_for(path)),"Existing maximum manifest is available; no recreation fallback"): return
	var identity = Replay.key("ghost-archive-fixture")
	var started = Time.get_ticks_usec()
	var loaded = Records.load_record(path,identity)
	metrics.maximum_metadata_ms = (Time.get_ticks_usec()-started)/1000.0
	if not check(loaded.runs.size()==10 and loaded.runs.all(func(row): return row.time==600.0 and not row.has("replay")),"Existing maximum archive is ten full-duration metadata entries"): return
	var cache = Cache.new()
	var memory_before = Performance.get_monitor(Performance.MEMORY_STATIC)
	started = Time.get_ticks_usec()
	var cold = Records.selected(path,identity,loaded.runs,Records.default_selection(),cache)
	metrics.maximum_cold_ms = (Time.get_ticks_usec()-started)/1000.0
	metrics.maximum_cold_memory_delta = Performance.get_monitor(Performance.MEMORY_STATIC)-memory_before
	check(cold.runs.size()==10 and cache.stats().decodes==10,"Maximum cold selection validates all ten payloads")
	var before = cache.stats()
	memory_before = Performance.get_monitor(Performance.MEMORY_STATIC)
	started = Time.get_ticks_usec()
	var reused = Records.selected(path,identity,loaded.runs,Records.default_selection(),cache)
	metrics.maximum_cached_retry_ms = (Time.get_ticks_usec()-started)/1000.0
	metrics.maximum_cached_memory_delta = Performance.get_monitor(Performance.MEMORY_STATIC)-memory_before
	metrics.maximum_cache = cache.stats()
	metrics.maximum_source = path
	check(reused.runs.size()==10 and cache.stats().hits-before.hits==10 and cache.stats().decodes==before.decodes,"Maximum cached retry retains ten ghosts with zero new decodes")
	check(_same_replays(cold.runs,reused.runs),"Maximum retry shares original decoded objects without another payload allocation")
	check(cache.stats().entries==10 and cache.stats().payload_bytes<=Cache.MAX_BYTES,"Maximum cache respects entry and aggregate bounds")

func _timed_reset(session) -> Dictionary:
	var before = session.ghost_cache.stats()
	var memory_before = Performance.get_monitor(Performance.MEMORY_STATIC)
	var started = Time.get_ticks_usec()
	session.reset()
	var milliseconds = (Time.get_ticks_usec()-started)/1000.0
	var after = session.ghost_cache.stats()
	return {"ms":milliseconds,"decodes":after.decodes-before.decodes,"hits":after.hits-before.hits,"compressed_bytes_read":after.compressed_bytes_read-before.compressed_bytes_read,"memory_delta":Performance.get_monitor(Performance.MEMORY_STATIC)-memory_before,"entries":after.entries,"payload_bytes":after.payload_bytes}

static func _same_replays(a: Array, b: Array) -> bool:
	if a.size()!=b.size(): return false
	for i in a.size():
		if a[i].id!=b[i].id or a[i].replay!=b[i].replay: return false
	return true

static func _write(path: String, bytes: PackedByteArray) -> void:
	var file = preload("res://tests/test_report.gd").open_write(path)
	file.store_buffer(bytes); file.close()
