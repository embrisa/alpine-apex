extends "res://tests/performance_descent.gd"
## One startup/traversal warmup, then one capture-free Off/50/100 arm.
var blur_trial = 0
var dispatch_start = 0

func configure_comparison() -> void:
	assert(repetitions==4 and scenario_replay and trial_seconds>0,"Use warmup, Off, 50, 100 on one bounded scenario")
	# Actual active-camera preparation below compiles/uploads before timing.

func prepare_comparison_trial(index: int) -> void:
	blur_trial=index
	for view in ["chase","first_person"]:
		game.camera_settings.update_profile(view,{"motion_blur_enabled":index>=2,"motion_blur_strength":[0.0,0.0,50.0,100.0][index]})
	game.scene_motion_blur.suspend()
	game.start_run(false); game.summit_ready=false; game.active=true
	game.hud.hide_menu(); root.grab_focus()
	for i in 30: await process_frame
	game.active=false
	dispatch_start=game.scene_motion_blur.status().dispatches
	game.display_settings.reset_history()

func comparison_metadata() -> Dictionary:
	var status=game.scene_motion_blur.status()
	var dispatched: bool=status.dispatches>dispatch_start
	if not status.unavailable.is_empty() or dispatched!=(blur_trial>=2):
		failures.append("Motion blur dispatch/availability did not match the selected arm")
	return {"excluded_route_warmup":blur_trial==0,"blur_strength":[0,0,50,100][blur_trial],"blur":status,"arm_dispatches":status.dispatches-dispatch_start,"blur_requests_motion":game.scene_motion_blur.needs_motion_vectors,"blur_requests_color":game.scene_motion_blur.access_resolved_color,"blur_requests_depth":game.scene_motion_blur.access_resolved_depth}
