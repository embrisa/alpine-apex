extends SceneTree
const Catalog=preload("res://scripts/world/mineral_catalog.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var catalog=Catalog.new(true)
	var packed=preload("res://scripts/world/mineral_catalog_data.gd").new()
	packed.records=catalog.records
	packed.families=catalog.families
	packed.fingerprint=catalog.fingerprint
	packed.source_sha256=FileAccess.get_sha256(Catalog.PATH)
	var error=ResourceSaver.save(packed,Catalog.PACKED_PATH,ResourceSaver.FLAG_COMPRESS)
	if error!=OK: printerr("Catalog packing failed: ",error); quit(1); return
	var restored=Catalog.new()
	if restored.packed_data==null or restored.records.size()!=120 or restored.fingerprint!=catalog.fingerprint:
		printerr("Packed catalog validation failed"); quit(1); return
	print("PACKED_GEOLOGY_CATALOG ",restored.records.size()," assets; ",restored.fingerprint)
	quit(0)
