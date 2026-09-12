extends RefCounted
## Session-owned validated payload references. Consumers must only read replays.
## Hash the current compressed bytes before lookup; timestamps are not proof.
const Replay = preload("res://scripts/racing/run_replay.gd")
const MAX_ENTRIES = 10
const MAX_BYTES = MAX_ENTRIES*Replay.MAX_BYTES
var _scope = ""
var _identity: Dictionary = {}
var _entries: Dictionary = {}
var _bytes = 0
var lookups = 0
var hits = 0
var decodes = 0
var compressed_bytes_read = 0

func clear() -> void:
	_entries.clear(); _bytes = 0
	_scope = ""; _identity.clear()

func prepare(scope: String, identity: Dictionary, runs: Array) -> void:
	if scope!=_scope or not Replay.compatible(_identity,identity):
		clear()
		_scope = scope; _identity = identity.duplicate(true)
	prune(runs)

func prune(runs: Array) -> void:
	# Called before selection decoding and after archive publication. Release
	# evicted/changed entries before allocating their replacements. No file I/O.
	if runs.size()>MAX_ENTRIES:
		clear(); return
	var retained: Dictionary = {}
	for row in runs:
		if row is Dictionary and row.get("id") is String:
			retained[row.id] = descriptor(row)
	for id in _entries.keys():
		if not retained.has(id) or retained[id]!=_entries[id].descriptor: discard(id)

func discard(id: String) -> void:
	if not _entries.has(id): return
	_bytes -= int(_entries[id].descriptor.bytes)
	_entries.erase(id)

func lookup(row: Dictionary, compressed_sha256: String):
	lookups += 1
	var entry: Dictionary = _entries.get(row.id,{})
	if entry.is_empty(): return null
	if entry.descriptor!=descriptor(row) or entry.compressed_sha256!=compressed_sha256:
		discard(row.id); return null
	hits += 1
	return entry.replay

func store_validated(row: Dictionary, compressed_sha256: String, replay) -> void:
	# Only CompetitiveRecord's successful full decoder calls this. Do not cache
	# caller-supplied in-memory recordings, serialized envelopes or failed loads.
	discard(row.id)
	var size = int(row.bytes)
	if replay==null or size<32 or size>Replay.MAX_BYTES or _entries.size()>=MAX_ENTRIES or _bytes+size>MAX_BYTES: return
	_entries[row.id] = {"descriptor":descriptor(row),"compressed_sha256":compressed_sha256,"replay":replay}
	_bytes += size

func stats() -> Dictionary:
	return {"entries":_entries.size(),"payload_bytes":_bytes,"ids":_entries.keys(),"lookups":lookups,"hits":hits,"decodes":decodes,"compressed_bytes_read":compressed_bytes_read}

static func descriptor(row: Dictionary) -> Dictionary:
	# Rank/date/splits do not change the immutable recording. Duration does.
	return {"sha256":row.get("sha256",""),"bytes":row.get("bytes",0),"time":row.get("time",-1.0)}
