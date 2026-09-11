extends SceneTree
var game
var failures: Array = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text); printerr("FAIL: ",text)
func run() -> void:
	set_meta("test_lab_fixture",true)
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game)
	while not game.initialized: await process_frame
	check(game.animation_workshop==null,"Workshop is lazy at startup")
	game.open_animation_workshop()
	await process_frame
	check(game.animation_workshop!=null and not game.hud.visible,"Tools opens isolated editor")
	check(not game.active and not game.skier.is_processing_unhandled_input(),"Gameplay and F8 input disabled")
	var time: float = game.session.elapsed; var position: Vector3 = game.sim.position
	for i in 5: await physics_frame
	check(game.session.elapsed==time and game.sim.position==position,"Editor does not advance live simulation or records")
	var editor = game.animation_workshop
	var event = InputEventKey.new(); event.physical_keycode = KEY_R; event.pressed = true
	game._unhandled_input(event)
	check(game.animation_workshop==editor,"Gameplay shortcuts cannot restart through workshop")
	editor.close_workshop(); await process_frame
	check(game.animation_workshop==null and game.hud.visible and game.hud.menu_mode=="title","Closing restores title menu")
	check(not game.active and game.skier.is_processing_unhandled_input(),"Closing restores input ownership without starting skiing")
	game.start_run(false); await physics_frame
	game.open_animation_workshop(); await process_frame
	time = game.session.elapsed; position = game.sim.position
	game.animation_workshop.close_workshop(); await process_frame
	check(not game.active and game.hud.menu_mode=="paused","Opening while skiing returns to pause")
	check(game.session.elapsed==time and game.sim.position==position,"Session state survives editor lifecycle")
	game.resume(); await physics_frame
	check(game.active,"Rider resumes explicitly after closing editor")
	print("WORKSHOP_LIFECYCLE ",JSON.stringify({"checks":checks,"failures":failures}))
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
