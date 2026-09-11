extends "res://tests/interface_performance_suite.gd"
## Fast isolated native display regression using the explicit laboratory.
func run() -> void:
 output = "res://artifacts/interface_overhaul/display"
 DirAccess.make_dir_recursive_absolute(output)
 set_meta("test_lab_fixture",true)
 original_window = Output.capture_window(root)
 original_cap = Engine.max_fps
 game = load("res://main.tscn").instantiate()
 game.automated = true
 root.add_child(game)
 current_scene = game
 while not game.initialized: await process_frame
 game.preferences_enabled = false
 game.active = false
 game.set_physics_process(false)
 game.effects.muted = true
 game.hud.feedback.muted = true
 game.set_graphics_preset(7)
 game.display_settings.apply_display(root,PIXELS)
 await wait_seconds(.5)
 await load("res://tests/interface_display_native_checks.gd").run(self)
 await finish()
