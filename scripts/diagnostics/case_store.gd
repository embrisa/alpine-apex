extends RefCounted
## Indexed, bounded, lossless Variant channels. Object decoding is never enabled.
const VERSION = 1
const INPUT_VERSION = 1
const MAGIC = "APEXCASE"
const DIRECTORY = "user://test_cases_v1"
const MAX_RAW = 256*1024*1024
const MAX_CHUNK = 1024*1024
const MAX_HEADER = 1024*1024
const MAX_TICKS = 72000
const Policy = preload("res://scripts/diagnostics/case_policy.gd")
var metadata: Dictionary = {}
var chunks: Array = []
var buffers = {"ticks":[],"frames":[]}
var raw_bytes = 0
var error = ""
var path = ""
var body_offset = 0
var cache: Dictionary = {}
var weather_types: Dictionary = {}

static func hash_bytes(bytes: PackedByteArray) -> String:
	var context = HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()

func append(kind: String, row: Dictionary) -> bool:
	if not error.is_empty(): return false
	var bytes = var_to_bytes(row).size()
	if raw_bytes+bytes+64>MAX_RAW: error = "size_limit"; return false
	raw_bytes += bytes+8
	buffers[kind].append(row)
	if buffers[kind].size()>=64: _flush(kind)
	return error.is_empty()

func _flush(kind: String) -> void:
	if buffers[kind].is_empty(): return
	var rows: Array = buffers[kind]
	var raw = var_to_bytes(rows)
	if raw.size()>MAX_CHUNK: error = "Capture chunk exceeds the format limit."; return
	var bytes = raw.compress(FileAccess.COMPRESSION_ZSTD)
	chunks.append({"kind":kind,"first":rows[0].t,"last":rows[-1].t,"count":rows.size(),"raw":raw.size(),"length":bytes.size(),"hash":hash_bytes(raw),"compressed_hash":hash_bytes(bytes),"bytes":bytes})
	buffers[kind] = []

func save(destination: String) -> String:
	if FileAccess.file_exists(destination): return "That case already exists. Choose a new name."
	for kind in buffers: _flush(kind)
	if not error.is_empty() and error!="size_limit": return error
	var index: Array = []; var offset = 0; var total = 0
	for chunk in chunks:
		var entry: Dictionary = chunk.duplicate(); entry.erase("bytes"); entry.offset = offset
		index.append(entry); offset += chunk.length; total += chunk.raw
	var header = {"version":VERSION,"metadata":metadata,"index":index,"raw_bytes":total}
	var bytes = JSON.stringify(header,"",true,true).to_utf8_buffer()
	if bytes.size()>MAX_HEADER or total>MAX_RAW: return "Case exceeds the format limit."
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir())!=OK: return "Cannot create the case folder."
	var temporary = destination+".tmp-"+str(Time.get_ticks_usec())
	var file = FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return "Cannot write the case. Keep this recording open and retry."
	file.store_buffer(MAGIC.to_ascii_buffer()); file.store_32(bytes.size()); file.store_buffer(bytes)
	for chunk in chunks:
		var payload: PackedByteArray = chunk.get("bytes",PackedByteArray())
		if payload.is_empty():
			var source = FileAccess.open(path,FileAccess.READ)
			if source==null: file.close(); DirAccess.remove_absolute(temporary); return "Source case is unavailable."
			source.seek(body_offset+int(chunk.offset)); payload = source.get_buffer(int(chunk.length))
		file.store_buffer(payload)
	file.flush(); var write_error = file.get_error(); file.close()
	if write_error!=OK or DirAccess.rename_absolute(temporary,destination)!=OK:
		DirAccess.remove_absolute(temporary); return "Could not publish the case; previous files are preserved."
	return ""

static func open_case(source: String):
	var result = load("res://scripts/diagnostics/case_store.gd").new()
	result.path = source
	result.error = result._open()
	return result

func _open() -> String:
	var file = FileAccess.open(path,FileAccess.READ)
	if file==null: return "Cannot open this case."
	if file.get_length()<12 or file.get_length()>MAX_RAW+MAX_HEADER+12 or file.get_buffer(8).get_string_from_ascii()!=MAGIC: return "Not a supported .apexcase file."
	var length = file.get_32()
	if length<2 or length>MAX_HEADER or length>file.get_length()-12: return "Invalid case header length."
	var header = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	if not header is Dictionary or header.get("version")!=VERSION or not header.get("metadata") is Dictionary or not header.get("index") is Array: return "Unsupported or malformed case format."
	metadata = header.metadata; chunks = header.index; body_offset = 12+length
	var meta_error = validate_metadata(metadata)
	if not meta_error.is_empty(): return meta_error
	if chunks.size()>20000: return "Too many case chunks."
	var offset = 0; var total = 0; var previous = {"ticks":-1.0,"frames":-1.0}
	for chunk in chunks:
		if not chunk is Dictionary: return "Invalid chunk index."
		for key in ["offset","length","raw","count","first","last"]:
			if not number(chunk.get(key)): return "Invalid chunk index number."
		for key in ["offset","length","raw","count"]:
			if chunk[key]!=floorf(chunk[key]): return "Non-integral chunk size."
		if chunk.get("kind") not in ["ticks","frames"] or not chunk.get("hash") is String or chunk.hash.length()!=64 or not chunk.get("compressed_hash") is String or chunk.compressed_hash.length()!=64: return "Invalid chunk channel."
		if chunk.offset!=offset or chunk.length<1 or chunk.raw<1 or chunk.raw>MAX_CHUNK or chunk.count<1 or chunk.count>64: return "Invalid chunk bounds."
		if chunk.first<previous[chunk.kind] or chunk.first<0 or chunk.last<chunk.first or chunk.last>600.001: return "Invalid chunk timeline."
		previous[chunk.kind] = chunk.last; offset += int(chunk.length); total += int(chunk.raw)
		if total>MAX_RAW: return "Case decompression limit exceeded."
	if offset!=file.get_length()-body_offset or total!=header.get("raw_bytes"): return "Case payload length mismatch."
	if chunks.is_empty(): return "Case has no captured data."
	return ""

static func same_data(a: Variant, b: Variant) -> bool:
	if number(a) and number(b): return absf(float(a)-float(b))<=1e-12
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same_data(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not same_data(a[i],b[i]): return false
		return true
	return a==b

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func validate_metadata(meta: Dictionary) -> String:
	for key in ["start_tick","end_tick","duration_ticks","input_ticks"]:
		if not number(meta.get(key)) or meta[key]!=floorf(meta[key]) or meta[key]<0 or meta[key]>MAX_TICKS: return "Invalid case tick coverage."
	if meta.start_tick>=meta.end_tick or meta.end_tick>meta.duration_ticks or meta.input_ticks>meta.duration_ticks: return "Invalid case selection."
	if meta.get("policy_version")!=Policy.VERSION: return "Unsupported diagnostic policy."
	if meta.get("input_version")!=INPUT_VERSION: return "Unsupported recorded input layout."
	if not Policy.settings_error(meta.get("initial_settings")).is_empty(): return "Invalid initial diagnostic controls."
	if not meta.get("identity") is Dictionary or not meta.get("rig") is Dictionary or not meta.rig.get("names") is Array or meta.rig.names.size()<1 or meta.rig.names.size()>256: return "Missing recording identity or rig."
	if not meta.identity.get("sources") is Dictionary or not meta.identity.get("engine_sha256") is String or not meta.identity.get("mountain") is Dictionary: return "Incomplete capture identity."
	for key in ["title","what","expected"]:
		if not meta.get(key) is String or meta[key].length()>(120 if key=="title" else 4000): return "Invalid case notes."
	if meta.title.strip_edges().is_empty(): return "Name this case."
	return ""

static func valid_state(state: Dictionary) -> bool:
	if not sane(state): return false
	for key in ["position","velocity","normal","speed_delta"]:
		if not state.get(key) is Vector3: return false
	for key in ["heading","reserve","sim_tick","load","edge","slip","rock_contact","impact_speed","prevented_damage"]:
		if not number(state.get(key)): return false
	for key in ["grounded","crashed"]:
		if not state.get(key) is bool: return false
	return state.get("crash_reason") is String and state.get("impact_reason") is String and state.get("obstacle") is Dictionary

static func sane(value: Variant, depth: int = 0) -> bool:
	if depth>12: return false
	if value is float: return is_finite(value)
	if value is Vector2 or value is Vector3: return value.is_finite()
	if value is Dictionary:
		if value.size()>512: return false
		for key in value:
			if not key is String or not sane(value[key],depth+1): return false
		return true
	if value is Array or value is PackedFloat32Array or value is PackedFloat64Array:
		if value.size()>4096: return false
		for item in value:
			if not sane(item,depth+1): return false
		return true
	return value is int or value is bool or value is String or value==null

func valid_weather(value: Dictionary) -> bool:
	const Weather = preload("res://scripts/presentation/weather_controller.gd")
	if weather_types.is_empty():
		var weather = Weather.new(); var snapshot = weather.snapshot(); weather.free()
		for key in snapshot: weather_types[key] = typeof(snapshot[key])
	if value.size()!=weather_types.size() or not sane(value): return false
	for key in weather_types:
		if not value.has(key) or typeof(value[key])!=weather_types[key]: return false
	return Weather.PRESETS.has(value.selected_preset) and Weather.PRESETS.has(value.target_preset)

func _rows(index: int) -> Array:
	var chunk: Dictionary = chunks[index]
	if cache.get("index",-1)==index: return cache.rows
	var bytes: PackedByteArray = chunk.get("bytes",PackedByteArray())
	if bytes.is_empty():
		var file = FileAccess.open(path,FileAccess.READ)
		if file==null: error = "Case disappeared while reading."; return []
		file.seek(body_offset+int(chunk.offset)); bytes = file.get_buffer(int(chunk.length))
	if hash_bytes(bytes)!=chunk.compressed_hash: error = "Case compressed chunk checksum failed."; return []
	var raw = bytes.decompress(int(chunk.raw),FileAccess.COMPRESSION_ZSTD)
	if raw.size()!=int(chunk.raw) or hash_bytes(raw)!=chunk.hash: error = "Case chunk checksum failed."; return []
	var rows = bytes_to_var(raw)
	if not rows is Array or rows.size()!=int(chunk.count): error = "Malformed case rows."; return []
	var previous = float(chunk.first)
	for row in rows:
		if not row is Dictionary or not number(row.get("t")) or row.t<previous-.000000001 or row.t>chunk.last+.000000001 or not number(row.get("tick")) or row.tick<0 or row.tick>MAX_TICKS:
			error = "Malformed case timeline."; return []
		previous = row.t
		if chunk.kind=="frames":
			if not row.get("pose") is PackedFloat32Array or row.pose.size()!=(metadata.rig.names.size()+6)*7 or not row.get("camera") is PackedFloat64Array or row.camera.size()!=13 or not row.get("weather") is Dictionary:
				error = "Malformed captured frame."; return []
			for value in row.pose:
				if not is_finite(value) or absf(value)>100000: error = "Invalid captured transform."; return []
			for value in row.camera:
				if not is_finite(value): error = "Invalid captured camera."; return []
			if not valid_weather(row.weather) or not row.get("crashed") is bool or not row.get("contacts") is PackedFloat32Array or row.contacts.size() not in [0,21] or not sane(row.contacts): error = "Invalid captured environment or contact data."; return []
			if row.camera[12]<1 or row.camera[12]>179: error = "Invalid camera field of view."; return []
			for offset in range(0,row.pose.size(),7):
				var q = Quaternion(row.pose[offset+3],row.pose[offset+4],row.pose[offset+5],row.pose[offset+6])
				if absf(q.length_squared()-1)>.01: error = "Invalid captured rotation."; return []
		else:
			if not row.get("input") is PackedFloat64Array or row.input.size() not in [0,9] or not row.get("state") is Dictionary or not row.get("events") is Array:
				error = "Malformed recorded tick."; return []
			for value in row.input:
				if not is_finite(value) or value < -1 or value>1: error = "Invalid recorded input."; return []
			if row.input.size()==9:
				for i in [3,4,7]:
					if row.input[i] not in [0.0,1.0]: error = "Invalid input flag."; return []
				if row.input[1]<0 or row.input[2]<0: error = "Invalid tuck or brake input."; return []
			if not valid_state(row.state) or row.events.size()>256 or row.tick!=floorf(row.tick) or absf(row.t-row.tick/120.0)>1e-9: error = "Invalid tick telemetry."; return []
			for event in row.events:
				if not event is Dictionary or event.get("tick")!=row.tick or event.get("kind") not in ["settings","speed","reset_input"]: error = "Invalid control event."; return []
				if event.kind=="settings" and not Policy.settings_error(event.get("value")).is_empty(): error = "Invalid recorded controls."; return []
				if event.kind=="speed" and (not number(event.get("value")) or event.value<0 or event.value>300): error = "Invalid speed event."; return []
				if event.kind=="reset_input" and event.get("value")!=true: error = "Invalid input reset."; return []
	cache = {"index":index,"rows":rows}
	return rows

func rows(kind: String, from: float = 0.0, to: float = 600.0) -> Array:
	for channel in buffers: _flush(channel)
	var result: Array = []
	for i in chunks.size():
		var chunk: Dictionary = chunks[i]
		if chunk.kind!=kind or chunk.last<from or chunk.first>to: continue
		for row in _rows(i):
			if row.t>=from and row.t<=to: result.append(row)
	return result

func frame_at(time: float) -> Dictionary:
	var chosen = -1
	for i in chunks.size():
		if chunks[i].kind=="frames" and chunks[i].first<=time+.000000001: chosen = i
	if chosen<0:
		for i in chunks.size():
			if chunks[i].kind=="frames":
				var initial = _rows(i)
				return initial[0] if not initial.is_empty() else {}
		return {}
	var rows_value = _rows(chosen)
	var result: Dictionary = {}
	for row in rows_value:
		if row.t>time+1e-9: break
		result = row
	return result

func frame_by_index(index: int) -> Dictionary:
	for channel in buffers: _flush(channel)
	for i in chunks.size():
		if chunks[i].kind!="frames": continue
		if index<int(chunks[i].count):
			var frames = _rows(i)
			return frames[index] if index>=0 and index<frames.size() else {}
		index -= int(chunks[i].count)
	return {}

func trim(start: int, end: int, title: String, what: String, expected: String):
	var result = load("res://scripts/diagnostics/case_store.gd").new()
	result.metadata = metadata.duplicate(true)
	result.metadata.source_duration_ticks = metadata.get("source_duration_ticks",metadata.duration_ticks)
	result.metadata.merge({"start_tick":start,"end_tick":end,"duration_ticks":end,"input_ticks":mini(end,int(metadata.input_ticks)),"title":title,"what":what,"expected":expected,"parent_sha256":FileAccess.get_sha256(path) if not path.is_empty() else ""},true)
	result.error = validate_metadata(result.metadata)
	if start<int(metadata.start_tick) or end>int(metadata.end_tick): result.error = "Selection must stay inside this case."
	if not result.error.is_empty(): return result
	# Keep 30 seconds of track context and every earlier control/input tick.
	for kind in ["ticks","frames"]:
		var first = maxf(0,start/120.0-30) if kind=="frames" else 0.0
		for row in rows(kind,first,end/120.0):
			if not result.append(kind,row): return result
	if not error.is_empty(): result.error = error
	return result

static func fresh_path(directory: String = DIRECTORY) -> String:
	return directory+"/case-"+Time.get_datetime_string_from_system(true).replace(":","-")+"-"+str(Time.get_ticks_usec())+".apexcase"
