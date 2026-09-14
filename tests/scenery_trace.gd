extends SceneTree
## Add explicit scenery framing to a preserved ordinary trace; inputs stay intact.
func _initialize() -> void:
	var input=""; var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input=arg.trim_prefix("--input=")
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	assert(not input.is_empty() and not output.is_empty() and not FileAccess.file_exists(output))
	var data=JSON.parse_string(FileAccess.get_file_as_string(input))
	assert(preload("res://tests/performance_trace.gd").preflight_error(data,preload("res://scripts/world/mountain_definition.gd").CURRENT_VERSION,false).is_empty())
	assert(not data.has("camera_samples") and not data.has("stress"))
	var settings=preload("res://scripts/presentation/camera_settings.gd").new()
	preload("res://tests/scenery_camera.gd").configure(settings)
	data.presentation={"camera":settings.snapshot(),"camera_effects_enabled":true}
	data.scenery_camera_source={"input":input,"input_sha256":FileAccess.get_sha256(input),
		"producer_sha256":FileAccess.get_sha256("res://tests/scenery_trace.gd"),
		"camera_sha256":FileAccess.get_sha256("res://tests/scenery_camera.gd")}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(data,"",true,true))
	print("SCENERY_TRACE ",output); quit()
