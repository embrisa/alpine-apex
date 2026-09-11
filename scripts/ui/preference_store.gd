extends RefCounted
## Small, versioned presentation stores. Temp-write + same-directory rename.
static func read_values(path: String, schema: int) -> Dictionary:
	var config = ConfigFile.new()
	if config.load(path)!=OK or config.get_value("store","schema",0)!=schema: return {}
	var values = config.get_value("store","values",{})
	return values if values is Dictionary else {}

static func write_values(path: String, schema: int, values: Dictionary) -> Error:
	var config = ConfigFile.new()
	config.set_value("store","schema",schema)
	config.set_value("store","values",values)
	var error = config.save(path+".tmp")
	if error!=OK: return error
	return DirAccess.rename_absolute(path+".tmp",path)
