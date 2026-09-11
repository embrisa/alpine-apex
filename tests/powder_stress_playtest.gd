extends "res://tests/snow_lab_playtest.gd"
## The shared prescribed-contact matrix, with this upgrade's output isolated.
func _initialize() -> void:
	output = "res://artifacts/powder_volume/stress"
	call_deferred("run")
func capture(id: String) -> void:
	if "--measure-only" in OS.get_cmdline_user_args(): return
	await super.capture(id)
