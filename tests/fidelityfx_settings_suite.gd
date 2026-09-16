extends SceneTree
const Settings = preload("res://scripts/presentation/pc_graphics_settings.gd")
var failures: Array[String] = []

func check(ok: bool, description: String) -> void:
	print("PASS: " if ok else "FAIL: ",description)
	if not ok: failures.append(description)

func _initialize() -> void:
	var settings = Settings.new()
	check(settings.upscaler=="auto" and not settings.frame_generation,"Automatic upscaling and opt-in frame generation defaults")
	for mode in Settings.UPSCALERS:
		settings.apply_arguments(PackedStringArray(["--upscaler="+mode,"--frame-generation=on"]))
		check(settings.upscaler==mode and settings.frame_generation,"Command line accepts "+mode+" and independent frame generation")
		var path = "res://artifacts/fidelityfx/settings-test.cfg"
		DirAccess.make_dir_recursive_absolute("res://artifacts/fidelityfx")
		check(settings.save_preferences(path)==OK,"Isolated graphics preferences save")
		var restored = Settings.new()
		restored.load_preferences(path)
		check(restored.snapshot()==settings.snapshot(),"All options survive preferences reload")
	settings.restore({"upscaler":"fake", "frame_generation":"true"})
	check(settings.upscaler=="auto" and settings.frame_generation,"Malformed preference types cannot disable valid typed options")
	settings.apply_arguments(["--frame-generation=off"])
	check(not settings.frame_generation,"Frame generation can be disabled independently")
	settings.restore({"upscaler":"bilinear","frame_generation":true})
	check(not settings.is_temporal() and not settings.frame_generation_enabled() and settings.frame_generation,"Bilinear stays spatial while retaining the frame-generation preference for a compatible mode")
	if not Settings.has_native_fsr():
		check(not settings.fsr_status().engine_integration and not settings.fsr_status().frame_generation_active,"Stock/headless engine never reports SDK features as active")
	print("FIDELITYFX_SETTINGS_RESULTS ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
