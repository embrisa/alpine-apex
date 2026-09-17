extends RefCounted
## Small atomic manifest plus immutable bounded replay blobs. Metadata loads do
## not inflate recordings; only the next attempt's selected IDs are decoded.
const VERSION = 4
const SELECTION_VERSION = 1
const Clock = preload("res://scripts/racing/record_clock.gd")
const MAX_RUNS = 10
const MAX_BYTES = 256*1024 # manifest UTF-8, before JSON parsing
const MAX_PAYLOAD_BYTES = 32*1024*1024
const MAX_AGGREGATE_BYTES = MAX_RUNS*MAX_PAYLOAD_BYTES
const Replay = preload("res://scripts/racing/run_replay.gd")

static func path_for(record_path: String) -> String:
	return record_path.get_basename()+"_competition_v4.apexrun"

static func payload_directory(record_path: String) -> String:
	return path_for(record_path).get_basename()+"_payloads"

static func default_selection() -> Dictionary:
	return {"version":SELECTION_VERSION,"mode":"automatic","ids":[],"automatic_count":MAX_RUNS}

static func run_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

static func valid_id(value: Variant, length: int = 32) -> bool:
	if not value is String or value.length()!=length: return false
	for c in value:
		if not c in "0123456789abcdef": return false
	return true

static func ordered(a: Dictionary, b: Dictionary) -> bool:
	if a.time!=b.time: return a.time<b.time
	if a.date!=b.date: return a.date<b.date
	return a.id<b.id

static func normalize_selection(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("version")!=SELECTION_VERSION or value.get("mode") not in ["automatic","manual"] or not value.get("ids") is Array: return default_selection()
	var count = value.get("automatic_count")
	if not Replay.number(count) or count!=floorf(count): return default_selection()
	var result = {"version":SELECTION_VERSION,"mode":value.mode,"ids":[],"automatic_count":clampi(int(count),1,MAX_RUNS)}
	if value.mode=="automatic": return result
	for id in value.ids.slice(0,MAX_RUNS):
		if valid_id(id) and not result.ids.has(id): result.ids.append(id)
	return result

static func load_record(record_path: String, identity: Dictionary) -> Dictionary:
	var result = {"best":-1.0,"history":[],"splits":[-1.0,-1.0,-1.0],"runs":[],"selection":default_selection(),"warning":""}
	var path = path_for(record_path)
	if not FileAccess.file_exists(path): return result
	var file = FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()>MAX_BYTES:
		result.warning = "The race record is unreadable or exceeds its storage limit."
		return result
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version")!=VERSION or data.get("course")!=identity.course:
		result.warning = "This race record is incompatible."
		return result
	var best = Clock.decode(data.get("best"))
	if positive(best):
		result.best = best
		var decoded_splits = Clock.decode_array(data.get("splits"),3)
		result.splits = splits(decoded_splits,best)
		if not valid_splits(decoded_splits,best): result.warning = "Invalid split timing was discarded."
	elif best==null or best!=-1.0:
		result.warning = "Invalid personal-best timing was discarded."
	if data.get("history") is Array:
		for stored in data.history.slice(0,20):
			var row = _read_result(stored)
			if not row.is_empty(): result.history.append(clean_result(row))
	result.selection = normalize_selection(data.get("selection"))
	if not data.get("selection") is Dictionary or data.selection.get("version")!=SELECTION_VERSION:
		result.warning = "Ghost selection was reset to Automatic fastest 10 because its saved settings are incompatible."
	if not data.get("runs") is Array or data.runs.size()>MAX_RUNS:
		result.warning = "Times retained; the ghost archive has an invalid entry count."
		return result
	var aggregate: int = 0
	var seen = {}
	for stored in data.runs:
		var row = _read_result(stored)
		if not valid_result(row) or not valid_id(row.get("id")) or not valid_id(row.get("sha256"),64):
			result.warning = "Times retained; an unavailable or malformed ghost was skipped."
			continue
		if not Replay.number(row.get("bytes")) or row.bytes<32 or row.bytes>MAX_PAYLOAD_BYTES or row.bytes!=floorf(row.bytes):
			result.warning = "Times retained; a ghost exceeded its storage limit."
			continue
		aggregate += int(row.bytes)
		if aggregate>MAX_AGGREGATE_BYTES:
			result.runs.clear(); result.warning = "Times retained; ghost archive exceeds its total storage limit."
			return result
		var blob = payload_directory(record_path).path_join(row.sha256+".replay")
		if seen.has(row.id) or not FileAccess.file_exists(blob):
			result.warning = "A duplicate or missing ghost was skipped."
			continue
		var raw = FileAccess.open(blob,FileAccess.READ)
		if not raw or raw.get_length()>MAX_PAYLOAD_BYTES+65536:
			result.warning = "An oversized ghost payload was skipped."
			continue
		seen[row.id] = true
		var entry = clean_result(row)
		entry.id = row.id; entry.sha256 = row.sha256; entry.bytes = int(row.bytes)
		result.runs.append(entry)
	result.runs.sort_custom(ordered)
	var missing = prune_selection(result.selection,result.runs)
	if not missing.is_empty(): result.warning = missing
	return result

static func valid_result(row: Variant) -> bool:
	return row is Dictionary and positive(row.get("time")) and Replay.number(row.get("date")) and row.date>=0 and row.date<=4102444800 and Replay.number(row.get("peak_kmh")) and row.peak_kmh>=0 and row.peak_kmh<=2000

static func clean_result(row: Dictionary) -> Dictionary:
	return {"time":float(row.time),"splits":splits(row.get("splits"),row.time),"date":int(row.date),"peak_kmh":float(row.peak_kmh)}

# Only the storage boundary sees hex clocks; callers/cache keep numeric rows.
static func _read_result(stored: Variant) -> Dictionary:
	if not stored is Dictionary: return {}
	var row = stored.duplicate()
	row.time = Clock.decode(stored.get("time"))
	row.splits = Clock.decode_array(stored.get("splits"),3)
	if not valid_result(row) or not valid_splits(row.splits,row.time): return {}
	return row

static func _store_result(row: Dictionary) -> Dictionary:
	var stored = row.duplicate()
	stored.time = Clock.encode(row.time)
	stored.splits = Clock.encode_array(row.splits)
	return stored

static func retain(runs: Array, result: Dictionary, replay) -> Array:
	var next = runs.duplicate()
	if replay==null or not replay.has_presentation() or not valid_result(result) or not valid_id(result.get("id")): return next
	if float(result.time)!=replay.duration: return next
	for row in next:
		if row.id==result.id: return next
	var entry = clean_result(result)
	entry.id = result.id
	entry.replay = replay # pending immutable payload, never serialized as JSON
	next.append(entry)
	next.sort_custom(ordered)
	if next.size()>MAX_RUNS: next.resize(MAX_RUNS)
	return next

static func prune_selection(selection: Dictionary, runs: Array) -> String:
	var ids: Array = []
	for row in runs: ids.append(row.id)
	var removed: Array = []
	for id in selection.ids.duplicate():
		if not ids.has(id):
			selection.ids.erase(id); removed.append(id.left(8))
	return "Selected ghosts removed because they are unavailable or evicted: "+", ".join(removed)+". Choose replacements or Automatic fastest 10." if not removed.is_empty() else ""

static func selected(record_path: String, identity: Dictionary, runs: Array, selection: Dictionary, cache = null) -> Dictionary:
	selection = normalize_selection(selection)
	var active: Array = []
	if runs.size()>MAX_RUNS:
		if cache: cache.clear()
		return {"runs":[],"unavailable":[]}
	var unavailable: Array = []
	var aggregate: int = 0
	var wanted: Array = []
	for row in runs:
		if selection.mode=="manual" and not selection.ids.has(row.id): continue
		wanted.append(row)
	if cache: cache.prepare(ProjectSettings.globalize_path(path_for(record_path)).simplify_path(),identity,wanted)
	# The bounded aggregate decides which rows are read at all, in roster order.
	# Stored payloads are then read, hashed and (on a cache miss) fully decoded on
	# WorkerThreadPool workers; every cache decision and all accounting stay on
	# this thread in roster order, so results equal the former sequential loop.
	var loader = PayloadLoader.new(payload_directory(record_path),identity)
	for row in wanted:
		aggregate += int(row.get("bytes",MAX_PAYLOAD_BYTES))
		if aggregate>MAX_AGGREGATE_BYTES: break
		var job = {"row":row,"replay":row.get("replay"),"compressed":PackedByteArray(),"compressed_sha256":"","decode":false,"readable":false,"decoded_bytes_valid":false}
		job.readable = job.replay==null and valid_id(row.get("sha256"),64) and Replay.number(row.get("bytes")) and row.bytes>=32 and row.bytes<=MAX_PAYLOAD_BYTES and row.bytes==floorf(row.bytes) and positive(row.get("time"))
		loader.jobs.append(job)
	loader.run(loader.read)
	for job in loader.jobs:
		if job.replay!=null or job.compressed.is_empty(): continue
		if cache:
			# Read/hash the same bounded bytes that a miss will decode. Even a corrupt
			# replacement preserving length and mtime cannot reuse a cached recording.
			cache.compressed_bytes_read += job.compressed.size()
			var reused = cache.lookup(job.row,job.compressed_sha256)
			if reused!=null:
				job.replay = reused
				continue
		job.decode = true
	loader.run(loader.decode)
	for job in loader.jobs:
		var row: Dictionary = job.row
		var replay = job.replay
		if job.decoded_bytes_valid:
			if cache: cache.decodes += 1
			if replay!=null and cache: cache.store_validated(row,job.compressed_sha256,replay)
		if replay==null or not replay.has_presentation() or replay.duration!=row.time or not Replay.compatible(replay.compatibility,identity):
			if cache: cache.discard(row.id)
			unavailable.append(row.id)
			continue
		active.append({"id":row.id,"time":row.time,"date":row.date,"replay":replay})
		if selection.mode=="automatic" and active.size()>=selection.automatic_count: break
	return {"runs":active,"unavailable":unavailable}

## Immutable-input payload work shared across worker threads. Each job is a
## distinct Dictionary written only by its own worker; the roster order, cache
## and accounting belong to the calling thread.
class PayloadLoader extends RefCounted:
	var directory: String
	var identity: Dictionary
	var jobs: Array = []
	func _init(payload_directory_value: String, identity_value: Dictionary) -> void:
		directory = payload_directory_value; identity = identity_value
	static func digest(bytes: PackedByteArray) -> String:
		var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
		return hash.finish().hex_encode()
	func run(work: Callable) -> void:
		if jobs.is_empty(): return
		if jobs.size()==1: work.call(0); return
		WorkerThreadPool.wait_for_group_task_completion(WorkerThreadPool.add_group_task(work,jobs.size(),-1,false,"Ghost payloads"))
	func read(index: int) -> void:
		var job: Dictionary = jobs[index]
		if not job.readable: return
		var row: Dictionary = job.row
		var file = FileAccess.open(directory.path_join(row.sha256+".replay"),FileAccess.READ)
		if not file or file.get_length()<1 or file.get_length()>MAX_PAYLOAD_BYTES+65536: return
		var size = file.get_length()
		var compressed = file.get_buffer(size)
		file.close()
		if compressed.size()!=size: return
		job.compressed = compressed
		job.compressed_sha256 = digest(compressed)
	func decode(index: int) -> void:
		var job: Dictionary = jobs[index]
		if not job.decode: return
		var row: Dictionary = job.row
		# Never trust a container's own claimed decompressed length. Every new byte
		# sequence must match the manifest hash AND pass the complete replay decoder.
		var bytes = job.compressed.decompress(int(row.bytes),FileAccess.COMPRESSION_ZSTD)
		if bytes.size()!=int(row.bytes) or digest(bytes)!=row.sha256: return
		job.decoded_bytes_valid = true
		job.replay = Replay.from_bytes(bytes,identity,row.time)

static func _sha256(bytes: PackedByteArray) -> String:
	var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	return hash.finish().hex_encode()

static func save(record_path: String, identity: Dictionary, best: float, best_splits: Array, history: Array, runs: Array, selection: Dictionary) -> String:
	var created: Array[String] = []
	var error = _save_transaction(record_path,identity,best,best_splits,history,runs,selection,created)
	if not error.is_empty():
		for path in created: DirAccess.remove_absolute(path)
	return error

static func _save_transaction(record_path: String, identity: Dictionary, best: float, best_splits: Array, history: Array, runs: Array, selection: Dictionary, created: Array[String]) -> String:
	if runs.size()>MAX_RUNS: return "Too many retained ghosts."
	if (best!=-1.0 and not positive(best)) or not valid_splits(best_splits,best): return "Invalid personal-best timing."
	var stored_history: Array = []
	for row in history.slice(0,20):
		if not valid_result(row) or not valid_splits(row.get("splits"),row.time): return "Invalid result history timing."
		stored_history.append(_store_result(clean_result(row)))
	var path = ProjectSettings.globalize_path(path_for(record_path))
	var directory = ProjectSettings.globalize_path(payload_directory(record_path))
	var ancestor = directory
	while not DirAccess.dir_exists_absolute(ancestor):
		if FileAccess.file_exists(ancestor): return "Could not create the records folder: a file occupies its path."
		var parent = ancestor.get_base_dir()
		if parent==ancestor or parent.is_empty(): break
		ancestor = parent
	if DirAccess.make_dir_recursive_absolute(directory)!=OK: return "Could not create the records folder."
	var old = load_record(record_path,identity)
	var manifest_runs: Array = []
	var aggregate: int = 0
	var seen = {}
	for row in runs:
		if not valid_result(row) or not valid_splits(row.get("splits"),row.time) or not valid_id(row.get("id")) or seen.has(row.id): return "Invalid timing or duplicate ghost identity."
		seen[row.id] = true
		var entry = clean_result(row); entry.id = row.id
		if row.has("replay"):
			if not Replay.compatible(row.replay.compatibility,identity) or row.replay.duration!=row.time: return "Ghost timing or identity does not match this race."
			var bytes: PackedByteArray = row.replay.to_bytes()
			if bytes.is_empty() or bytes.size()>MAX_PAYLOAD_BYTES: return "A ghost recording is unavailable or too large to save."
			var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
			entry.sha256 = hash.finish().hex_encode(); entry.bytes = bytes.size()
			var blob = directory.path_join(entry.sha256+".replay")
			if not FileAccess.file_exists(blob):
				var compressed = bytes.compress(FileAccess.COMPRESSION_ZSTD)
				if compressed.is_empty() or compressed.size()>MAX_PAYLOAD_BYTES+65536: return "Could not compress the bounded ghost recording."
				var file = FileAccess.open(blob+".tmp",FileAccess.WRITE)
				if not file: return "Could not write the ghost recording."
				file.store_buffer(compressed); file.flush()
				var error = file.get_error(); file.close()
				if error!=OK or DirAccess.rename_absolute(blob+".tmp",blob)!=OK:
					DirAccess.remove_absolute(blob+".tmp")
					return "Could not commit the ghost recording."
				created.append(blob)
		else:
			entry.sha256 = row.sha256; entry.bytes = row.bytes
		aggregate += int(entry.bytes)
		if aggregate>MAX_AGGREGATE_BYTES: return "Ghost archive exceeds its total storage limit."
		manifest_runs.append(entry)
	manifest_runs.sort_custom(ordered)
	var stored_runs: Array = []
	for entry in manifest_runs: stored_runs.append(_store_result(entry))
	var data = {"version":VERSION,"course":identity.course,"best":Clock.encode(best),"splits":Clock.encode_array(best_splits),"history":stored_history,"runs":stored_runs,"selection":normalize_selection(selection)}
	var bytes = JSON.stringify(data,"",true,true).to_utf8_buffer()
	if bytes.size()>MAX_BYTES: return "Race record metadata is too large to save."
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file: return "Could not write the race record."
	file.store_buffer(bytes); file.flush()
	var error = file.get_error(); file.close()
	if error!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK:
		DirAccess.remove_absolute(path+".tmp")
		return "Could not finish saving the race record."
	# Publish references only after both blob and manifest are committed.
	for i in runs.size():
		for entry in manifest_runs:
			if runs[i].id==entry.id: runs[i] = entry
	var retained: Array = []
	for entry in manifest_runs: retained.append(entry.sha256)
	for entry in old.runs:
		if not retained.has(entry.sha256):
			# Filenames are validated lowercase hashes within this race's directory.
			DirAccess.remove_absolute(directory.path_join(entry.sha256+".replay"))
	return ""

static func positive(value: Variant) -> bool:
	return Replay.number(value) and float(value)>0.0 and float(value)<=86400.0

static func splits(value: Variant, finish: float) -> Array:
	return value.duplicate() if valid_splits(value,finish) else [-1.0,-1.0,-1.0]

static func valid_splits(value: Variant, finish: float) -> bool:
	if not value is Array or value.size()!=3: return false
	var last = -1.0
	for time in value:
		if not Replay.number(time) or (float(time)!=-1.0 and (float(time)<last or float(time)<0 or float(time)>finish)): return false
		last = maxf(last,float(time))
	return true
