extends SceneTree
## Verify the production HUD and input wiring, not a detached preview selector.
var failures: Array[String] = []
var checks = 0
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	checks += 1
	print("PASS: " if value else "FAIL: ",message)
	if not value: failures.append(message)
func run():
	set_meta("test_lab_fixture",true)
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game); current_scene = game
	while not game.initialized: await process_frame
	await process_frame
	var full = game.skier.animation.full_motion
	var selector = game.skier.motion_comparison
	check(selector!=null and selector.is_inside_tree() and selector.button_pressed,"Production Interface settings contain the enabled full-motion comparison")
	var choose = game.hud.root.find_child("SkierGrabStyle",true,false)
	check(choose!=null and choose.item_count==2,"Production settings expose both recovered grab styles")
	game.start_run(true); game.session.eligible = false
	var event = InputEventKey.new(); event.physical_keycode = KEY_F8; event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	check(not full.enabled and not selector.button_pressed,"Actual F8 event switches the live production character and synchronizes the selector")
	selector.button_pressed = true
	check(full.enabled,"Settings selector restores the same live character sampler")
	choose.item_selected.emit(1)
	check(full.grab_style=="mute","Grab selector reaches the production fitting state")
	var body_before = game.sim.body.com
	game.active = false; game.skier.animation.hold()
	game.skier.pose(game.sim,.5)
	check(game.sim.body.com==body_before and game.skier.animation.full_motion.sample(0)==game.skier.animation.full_motion.sample(1),"Paused comparison preserves physical mass state and a single pose timestamp")
	game.effects.stop_audio(); game.queue_free(); await process_frame
	var result = {"checks":checks,"failures":failures}
	preload("res://tests/test_report.gd").write("res://artifacts/steep_motion_gameplay/ui.json",JSON.stringify(result,"\t"))
	print("MOTION_UI_RESULTS ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
