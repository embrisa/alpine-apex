extends SceneTree
## Static guard for the macOS startup contracts that do not require a Windows DLL.
var checks := 0
var failures: Array[String] = []

func check(value: bool, caption: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ", caption)
	if not value:
		failures.append(caption)

func _initialize() -> void:
	var track_shader := FileAccess.get_file_as_string("res://assets/graphics/ski_track.gdshader")
	var wind_script := FileAccess.get_file_as_string("res://scripts/presentation/procedural_wind.gd")
	check(not track_shader.contains("varying float berm_side"), "Ski-track berm side remains vertex-local for Metal's varying budget")
	check(FileAccess.file_exists("res://addons/alpine_wind/alpine_wind.windows.gdextension.cfg"), "Windows native-wind configuration remains available for manual loading")
	check(not FileAccess.file_exists("res://addons/alpine_wind/alpine_wind.gdextension"), "macOS does not auto-discover a Windows-only GDExtension")
	check(wind_script.contains("alpine_wind.windows.gdextension.cfg") and wind_script.contains("OS.has_feature(\"windows\")"), "Native wind remains Windows-only and macOS selects Original fallback")
	var Settings := preload("res://scripts/presentation/pc_graphics_settings.gd")
	check(Settings.resolve_upscaler("auto",false,"metal")=="bilinear", "Auto upscaling resolves to spatial bilinear on stock Metal")
	check(Settings.resolve_upscaler("auto",false,"d3d12")=="fsr2" and Settings.resolve_upscaler("auto",false,"vulkan")=="fsr2", "Auto keeps FSR 2 on other stock renderers")
	check(Settings.resolve_upscaler("auto",true,"d3d12")=="sdk", "Auto defers to the SDK provider on the custom DX12 engine")
	check(Settings.resolve_upscaler("fsr2",false,"metal")=="fsr2" and Settings.resolve_upscaler("native",false,"metal")=="native", "Explicit upscaler choices stay authoritative on Metal")
	var settings := Settings.new()
	settings.apply_arguments(["--upscaler=bilinear","--render-scale=0.5"])
	check(settings.upscaler=="bilinear" and is_equal_approx(settings.render_scale,0.5), "Command line accepts spatial bilinear at the 50 percent floor")
	print("MACOS COMPATIBILITY SUITE: ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
