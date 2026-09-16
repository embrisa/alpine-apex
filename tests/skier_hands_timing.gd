extends "res://tests/steep_motion_gameplay.gd"
## The same 4K High production course for the two glove meshes.
var hand_variant_ready = false

func _initialize():
	process_frame.connect(_apply_hand_variant)
	super._initialize()

func _apply_hand_variant():
	if hand_variant_ready or game==null or not game.initialized: return
	hand_variant_ready = true
	var result = preload("res://tests/helpers/skier_hand_comparison.gd").apply(game.skier,"--hands-baseline" in OS.get_cmdline_user_args())
	var evidence_dir = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="): evidence_dir = arg.trim_prefix("--evidence=").validate_filename()
	assert(not evidence_dir.is_empty())
	var path = ProjectSettings.globalize_path("res://artifacts/"+evidence_dir)
	assert(DirAccess.make_dir_recursive_absolute(path)==OK)
	preload("res://tests/test_report.gd").write(path+"/hand_variant.json",JSON.stringify(result,"\t"))
	print("HAND_TIMING_VARIANT ",result)
