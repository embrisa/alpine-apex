@tool
extends EditorExportPlugin
const Sources = preload("res://scripts/world/generation_sources.gd")
func _get_name() -> String: return "MountainDependencyManifest"
func _export_begin(features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
	if not "generation_export" in features: return
	var identity_path = OS.get_environment("ALPINE_BUILD_IDENTITY")
	if identity_path.is_empty() or not FileAccess.file_exists(identity_path):
		push_error("Build identity missing. Export through scripts/build_collaboration.ps1.")
		return
	var identity_text = FileAccess.get_file_as_string(identity_path)
	var build_identity = JSON.parse_string(identity_text)
	if not preload("res://scripts/diagnostics/build_identity.gd").valid(build_identity):
		push_error("Invalid prepared build identity.")
		return
	var receipt = JSON.parse_string(FileAccess.get_file_as_string(Sources.MANIFEST))
	var template_path = str(get_option("custom_template/debug" if is_debug else "custom_template/release"))
	var manifest = Sources.export_manifest()
	if not receipt is Dictionary or manifest.is_empty() or template_path.is_empty() or FileAccess.get_sha256(template_path)!=receipt.get("engine_sha256",""):
		push_error("Run scripts/prepare_generation_export.gd with the selected target runtime before exporting. Target engine identity is missing or changed.")
		add_file(Sources.MANIFEST,"{}".to_utf8_buffer(),false)
		return
	if build_identity.get("engine_sha256")!=receipt.engine_sha256:
		push_error("Build identity and generation receipt target different engines.")
		return
	add_file("res://config/build_identity.json",JSON.stringify({"schema":1,"payload":identity_text,"sha256":identity_text.sha256_text()}).to_utf8_buffer(),false)
	manifest.engine = receipt.engine; manifest.engine_sha256 = receipt.engine_sha256
	add_file(Sources.MANIFEST,JSON.stringify(manifest,"",true,true).to_utf8_buffer(),false)
	print("GENERATION_EXPORT_MANIFEST ",manifest.physical_sha256," ",manifest.scenery_sha256)
func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	# The export-start receipt replaces this development copy.
	if path==Sources.MANIFEST: skip()
