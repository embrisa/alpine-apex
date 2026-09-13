extends RefCounted
## Frozen process identity. Never participates in gameplay compatibility keys.
const MANIFEST = "res://config/build_identity.json"
const Sources = preload("res://scripts/world/generation_sources.gd")
static var cached: Dictionary = {}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema")!=1: return false
	if value.get("dev")!=null and (not (value.dev is int or value.dev is float) or not is_finite(value.dev) or value.dev<1 or value.dev!=floorf(value.dev)): return false
	for key in ["commit","changes_sha256","source_sha256"]:
		if not value.get(key) is String: return false
		if not value[key].is_empty() and not _hex(value[key],40 if key=="commit" else 64): return false
	if value.get("dev")!=null and value.commit.is_empty(): return false
	return value.get("compatibility") is Dictionary and value.get("categories") is Array and (value.get("modified")==null or value.modified is bool)

static func _hex(value: String, length: int) -> bool:
	if value.length()!=length: return false
	for c in value:
		if not c in "0123456789abcdef": return false
	return true

static func decode_package(text: String) -> Dictionary:
	var envelope = JSON.parse_string(text)
	if not envelope is Dictionary or envelope.get("schema")!=1 or not envelope.get("payload") is String: return {}
	if envelope.payload.sha256_text()!=envelope.get("sha256"): return {}
	var value = JSON.parse_string(envelope.payload)
	return value if valid(value) and _hex(str(value.get("engine_sha256","")),64) else {}

static func current() -> Dictionary:
	if not cached.is_empty(): return cached.duplicate(true)
	var value: Dictionary = {}
	var packaged = OS.has_feature("generation_export")
	if packaged and FileAccess.file_exists(MANIFEST):
		value = decode_package(FileAccess.get_file_as_string(MANIFEST))
	elif not packaged:
		var output: Array = []
		var python = OS.get_environment("ALPINE_PYTHON")
		if python.is_empty(): python = "python"
		var code = OS.execute(python,PackedStringArray([ProjectSettings.globalize_path("res://scripts/versioning.py"),"identity","--root",ProjectSettings.globalize_path("res://"),"--json"]),output,false,false)
		if code==0 and not output.is_empty():
			var candidate = JSON.parse_string(output[0])
			if valid(candidate): value = candidate
	if value.is_empty():
		value = {"schema":1,"dev":null,"commit":"","modified":null,"changes_sha256":"","source_sha256":"","categories":[],"compatibility":{},
			"warning":"Build identity unavailable: missing/invalid package metadata or checkout Git/Python history."}
	value.source = "package" if packaged else "checkout"
	if packaged: value.packaged_engine_sha256 = value.get("engine_sha256","")
	value.engine = Engine.get_version_info()
	value.engine_sha256 = Sources.engine_identity()
	if packaged and value.get("packaged_engine_sha256")!=value.engine_sha256:
		value.warning = "Packaged engine identity does not match the running executable."
	cached = value
	return cached.duplicate(true)

static func short_label() -> String:
	var value = current()
	var result = "Dev %d"%value.dev if value.dev!=null else "Dev unknown"
	if value.get("modified",false): result += " + modified"
	if not value.categories.is_empty(): result += " · "+", ".join(value.categories)
	var compatibility: Dictionary = value.compatibility
	if compatibility.get("world")!=null: result += " · World %d"%compatibility.world
	if compatibility.get("physics")!=null: result += " · Physics %d"%compatibility.physics
	if not value.commit.is_empty(): result += " · "+value.commit.left(8)
	return result

static func details() -> String:
	return "Alpine Apex — "+short_label()+"\n"+JSON.stringify(current(),"  ",true,true)
