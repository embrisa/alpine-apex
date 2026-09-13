extends RefCounted
## Revalidate a historical pose against explicitly captured current inputs.
## Old evidence remains immutable; a current note never certifies old pixels.

static func same_engine(saved: Dictionary, current: Dictionary) -> bool:
	# JSON numbers deserialize as floats; Dictionary equality also compares types.
	return saved == JSON.parse_string(JSON.stringify(current))

static func current_sources(previous: Dictionary) -> Dictionary:
	var note_path = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--navigation-input-note="):
			note_path = argument.trim_prefix("--navigation-input-note=")
	if note_path.is_empty(): return {"sources":previous.duplicate(true),"drift":{},"errors":[],"note":""}
	var result = {"sources":{},"drift":{},"errors":[],"note":note_path}
	if not FileAccess.file_exists(note_path):
		result.errors.append("Missing captured development note: "+note_path); return result
	var note = JSON.parse_string(FileAccess.get_file_as_string(note_path))
	if not note is Dictionary or not note.get("evidence",{}).get("inputs",{}) is Dictionary:
		result.errors.append("Invalid captured development note"); return result
	var inputs: Dictionary = note.evidence.inputs
	for path in previous:
		var actual = FileAccess.get_sha256("res://"+path)
		if actual.is_empty() or inputs.get(path,"")!=actual:
			result.errors.append("Uncaptured or changed current input: "+path)
		result.sources[path] = actual
		if actual!=previous[path]: result.drift[path] = {"previous":previous[path],"current":actual}
	var runtime = OS.get_executable_path().replace("\\","/")
	var relative = runtime.trim_prefix(ProjectSettings.globalize_path("res://").replace("\\","/"))
	result.runtime_sha256 = FileAccess.get_sha256(runtime)
	if result.runtime_sha256.is_empty() or inputs.get(relative,"")!=result.runtime_sha256:
		result.errors.append("Runtime is not pinned by the captured development note: "+relative)
	result.note_sha256 = FileAccess.get_sha256(note_path)
	result.scope = "Current-source revalidation of historical coordinates; no inheritance of old visual acceptance"
	return result
