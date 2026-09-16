extends RefCounted
## Stateless math kernels. The reference solver remains usable without a native
## library, including verifier platforms for which no binary is packaged yet.
# Manual Windows loading avoids discovery errors on platforms using the script.
const EXTENSION = "res://addons/alpine_skier/alpine_skier.windows.gdextension.cfg"

static func create(type_name: String):
	if not ClassDB.class_exists(type_name):
		if OS.get_name()!="Windows": return null
		var status = GDExtensionManager.load_extension(EXTENSION)
		if status not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
			push_warning("Native skier math unavailable; using the reference implementation.")
			return null
	return ClassDB.instantiate(type_name)
