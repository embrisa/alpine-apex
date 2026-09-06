extends RefCounted
const Definition = preload("res://scripts/world/mountain_definition.gd")
var directory: String = "user://mountains_v1"
var warning: String = ""

func save(mountain) -> String:
	var absolute = ProjectSettings.globalize_path(directory)
	if DirAccess.make_dir_recursive_absolute(absolute)!=OK: return "Could not create the mountain library folder."
	return write_file(absolute.path_join(mountain.identity()+".apexmountain"),mountain)

static func write_file(path: String, mountain) -> String:
	var parsed = Definition.decode(mountain.share_text())
	if not parsed.has("mountain"): return parsed.error
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file: return "Could not write this mountain. Choose a writable location."
	file.store_string(mountain.share_text())
	file.flush()
	var error = file.get_error()
	file.close()
	if error!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK:
		DirAccess.remove_absolute(path+".tmp")
		return "Could not finish saving the mountain."
	return ""

static func read_file(path: String) -> Dictionary:
	var file = FileAccess.open(path,FileAccess.READ)
	if not file: return {"error":"Could not read this mountain file."}
	if file.get_length()>Definition.MAX_BYTES: return {"error":"Mountain files must be smaller than 4 KB."}
	return Definition.decode(file.get_as_text())

func load_all() -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	warning = ""
	if not DirAccess.dir_exists_absolute(directory): return result
	for name in DirAccess.get_files_at(directory):
		if not name.ends_with(".apexmountain"): continue
		var parsed = read_file(directory.path_join(name))
		if parsed.has("mountain"):
			var id: String = parsed.mountain.identity()
			if not seen.has(id):
				result.append(parsed.mountain)
				seen[id] = true
		else: warning = "Some mountain files could not be loaded: "+parsed.error
	result.sort_custom(func(a,b): return a.title.naturalnocasecmp_to(b.title)<0)
	return result
