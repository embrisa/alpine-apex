extends "res://tests/performance_descent.gd"
## Optional matched fixed framing; the frozen before-camera lives in review artifacts.
var camera_baseline_path = ""
var matched = false
func configure_comparison() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--camera-matched": matched = true
		if arg.begins_with("--camera-baseline-script="): camera_baseline_path = arg.get_slice("=",1)
func prepare_comparison_trial(index: int) -> void:
	# The parent assigns current settings before its initial render-size check.
	# Install the historical fixture afterward, before this trial can render.
	if not camera_baseline_path.is_empty() and index==0:
		var previous = game.camera
		game.camera = load(camera_baseline_path).new()
		game.camera.near = previous.near
		game.camera.far = previous.far
		game.add_child(game.camera)
		previous.queue_free()
		game.camera.make_current()
	game.camera_settings.reset()
	game.camera.effects_enabled = true
	if matched:
		game.camera_settings.apply_preset("chase","Stable")
		game.camera_settings.update_profile("chase",{"slope_follow":0})
		game.camera.effects_enabled = false
	if not camera_baseline_path.is_empty():
		game.camera.settings = load("res://artifacts/camera_v2/baseline_settings.gd").new()
		game.camera.settings.restore({"rest_fov":60.0,"fast_fov":60.0,"rest_distance":3.5,"fast_distance":3.5,"rest_height":3.5,"fast_height":3.5,"vertical_smoothing":75.0})
		game.camera.settings.chase_pitch_offset = -45.0+rad_to_deg(atan2(2.9,7.0))
func comparison_metadata() -> Dictionary:
	return {"camera_comparison":"fixed 60 degree lens, 3.5 m boom and height, -45 degree pitch, 75 percent stabilization; motion off" if matched else "Connected default","baseline_script":camera_baseline_path,"camera_source_sha256":FileAccess.get_sha256(camera_baseline_path if not camera_baseline_path.is_empty() else "res://scripts/presentation/chase_camera.gd")}
