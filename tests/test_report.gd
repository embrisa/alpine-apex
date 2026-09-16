extends RefCounted
## Suite report writer. FileAccess.open() returns null when the artifacts
## folder is missing, and a chained store_*() on null raises a script error
## that leaves a headless suite running forever after all checks passed.
## Every suite writes its reports through here: the folder is created, a
## failed open is reported, and the caller never dereferences null.
static func write(path: String, text: String) -> void:
	var file = _open(path)
	if file: file.store_string(text); file.close()

static func write_line(path: String, text: String) -> void:
	var file = _open(path)
	if file: file.store_line(text); file.close()

static func write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file = _open(path)
	if file: file.store_buffer(bytes); file.close()

static func write_var(path: String, value: Variant, full_objects: bool = false) -> void:
	var file = _open(path)
	if file: file.store_var(value,full_objects); file.close()

## Suites that keep the handle for several writes open it here; the folder
## exists and a null handle is reported instead of silently dereferenced.
static func open_write(path: String) -> FileAccess:
	return _open(path)

static func _open(path: String) -> FileAccess:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file==null: printerr("Could not write report ",path," (",error_string(FileAccess.get_open_error()),")")
	return file
