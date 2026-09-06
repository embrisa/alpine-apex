extends RefCounted
## One atomic compressed JSON document keeps the PB, its splits and ghost together.
const VERSION = 2
const MAX_BYTES = 32*1024*1024 # bounded 10-minute articulated pose replay
const Replay = preload("res://scripts/racing/run_replay.gd")

static func path_for(legacy_path: String) -> String:
	return legacy_path.get_basename()+"_competition_v2.apexrun"

static func load_record(legacy_path: String, identity: Dictionary) -> Dictionary:
	var path = path_for(legacy_path)
	var data = null
	var warning = ""
	if FileAccess.file_exists(path):
		var file = FileAccess.open_compressed(path,FileAccess.READ)
		if file and file.get_length()<=MAX_BYTES:
			data = JSON.parse_string(file.get_as_text())
		if not data is Dictionary or data.get("version")!=VERSION or data.get("course")!=identity.course:
			warning = "The competitive record could not be read; older times are shown if available."
			data = null
	if data==null and FileAccess.file_exists(legacy_path):
		var file = FileAccess.open(legacy_path,FileAccess.READ)
		if file and file.get_length()<65536:
			var old = JSON.parse_string(file.get_as_text())
			if old is Dictionary and old.get("version")==1 and old.get("course")==identity.course:
				data = {"best":old.get("best"),"history":[],"splits":[-1.0,-1.0,-1.0]}
				if old.get("history") is Array:
					for time in old.history.slice(0,20):
						if positive(time): data.history.append({"time":float(time),"splits":[-1.0,-1.0,-1.0],"date":0,"peak_kmh":0.0})
	var result = {"best":-1.0,"history":[],"splits":[-1.0,-1.0,-1.0],"replay":null,"warning":warning}
	if not data is Dictionary or not positive(data.get("best")): return result
	result.best = float(data.best)
	result.splits = splits(data.get("splits"),result.best)
	if data.get("history") is Array:
		for row in data.history.slice(0,20):
			if not row is Dictionary or not positive(row.get("time")): continue
			if not Replay.number(row.get("date")) or float(row.date)<0 or float(row.date)>4102444800: continue
			if not Replay.number(row.get("peak_kmh")) or float(row.peak_kmh)<0 or float(row.peak_kmh)>2000: continue
			result.history.append({"time":float(row.time),"splits":splits(row.get("splits"),float(row.time)),"date":int(row.date),"peak_kmh":float(row.peak_kmh)})
	if data.has("replay") and data.replay!=null:
		result.replay = Replay.decode(data.replay,identity,result.best)
		if result.replay==null: result.warning = "Best time retained. Its ghost is incompatible or incomplete."
	return result

static func save(legacy_path: String, identity: Dictionary, best: float, best_splits: Array, history: Array, replay) -> String:
	var path = ProjectSettings.globalize_path(path_for(legacy_path))
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK: return "Could not create the records folder."
	var data = {"version":VERSION,"course":identity.course,"best":best,"splits":best_splits,
		"history":history,"replay":replay.to_data() if replay else null}
	var text_value = JSON.stringify(data,"",true,true)
	if text_value.to_utf8_buffer().size()>MAX_BYTES: return "Run data is too large to save."
	var file = FileAccess.open_compressed(path+".tmp",FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
	if not file: return "Could not write the record."
	file.store_string(text_value)
	file.flush()
	var error = file.get_error()
	file.close()
	if error!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK: return "Could not finish saving the record."
	return ""

static func positive(value: Variant) -> bool:
	return Replay.number(value) and float(value)>0.0 and float(value)<=86400.0

static func splits(value: Variant, finish: float) -> Array:
	var empty = [-1.0,-1.0,-1.0]
	if not value is Array or value.size()!=3: return empty
	var last = -1.0
	for time in value:
		if not Replay.number(time) or (float(time)!=-1.0 and (float(time)<last or float(time)<0 or float(time)>finish)): return empty
		last = maxf(last,float(time))
	return value.duplicate()
