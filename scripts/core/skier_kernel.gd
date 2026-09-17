extends RefCounted
## Stateless math kernels. The reference solver remains usable without a native
## library, including verifier platforms for which no binary is packaged yet.
# Manual Windows loading avoids discovery errors on platforms using the script.
const EXTENSION = "res://addons/alpine_skier/alpine_skier.windows.gdextension.cfg"
const EXTENSION_MACOS = "res://addons/alpine_skier/alpine_skier.macos.gdextension.cfg"

static func extension_path() -> String:
	# One packaged library per supported platform; other platforms use the script.
	match OS.get_name():
		"Windows": return EXTENSION
		"macOS": return EXTENSION_MACOS if Engine.get_architecture_name()=="arm64" else ""
		_: return ""

static func create(type_name: String):
	if not ClassDB.class_exists(type_name):
		var path = extension_path()
		if path.is_empty() or not FileAccess.file_exists(path): return null
		var status = GDExtensionManager.load_extension(path)
		if status not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
			push_warning("Native skier math unavailable; using the reference implementation.")
			return null
	# A platform library can support the fitting kernels before it includes a
	# newer optional kernel. Keep the reference path usable on that platform.
	return ClassDB.instantiate(type_name) if ClassDB.class_exists(type_name) else null
