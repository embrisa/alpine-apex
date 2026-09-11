extends SceneTree
## Opens the default mountain for manual recording without personal-data writes.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output = "res://artifacts/player_recordings/"+Time.get_datetime_string_from_system(true).replace(":","-")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--record-output="): output = "res://"+arg.get_slice("=",1).trim_prefix("res://")
	if not output.begins_with("res://artifacts/") or ".." in output: printerr("Recording output must stay under artifacts/"); quit(2); return
	if FileAccess.file_exists(output+"/latest.json"): printerr("Choose a fresh recording folder; existing clips are preserved."); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var field = preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	set_meta("mountain_to_load",{"definition":preload("res://scripts/world/mountain_definition.gd").from_field(field,"Run recording"),"field":field})
	var game = load("res://main.tscn").instantiate()
	game.set_script(preload("res://tests/performance_record_game.gd"))
	game.record_directory = output
	root.add_child(game); current_scene = game
