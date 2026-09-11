extends RefCounted
const Race = preload("res://scripts/racing/race_definition.gd")
var directory: String = "user://races_v3"
var warning: String = ""

func save(race) -> String:
	var parsed = Race.decode(race.share_text())
	if not parsed.get("error","").is_empty(): return parsed.error
	var absolute = ProjectSettings.globalize_path(directory)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		return "Could not create the local race folder."
	var path = absolute.path_join(race.identity()+".json")
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file: return "Could not write the race. Your draft is still open."
	file.store_string(race.share_text())
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path+".tmp",path) != OK:
		return "Could not finish saving the race. Your draft is still open."
	return ""

func load_all() -> Array:
	var races: Array = []
	warning = ""
	if not DirAccess.dir_exists_absolute(directory): return races
	for name in DirAccess.get_files_at(directory):
		if not name.ends_with(".json"): continue
		var file = FileAccess.open(directory.path_join(name),FileAccess.READ)
		if not file or file.get_length()>Race.MAX_BYTES:
			warning = "Some saved races could not be read."
			continue
		var parsed = Race.decode(file.get_as_text())
		if parsed.has("race"):
			races.append(parsed.race)
		else:
			warning = "Some saved races use unsupported or invalid definitions."
	races.sort_custom(func(a,b): return a.title.naturalnocasecmp_to(b.title)<0)
	return races
