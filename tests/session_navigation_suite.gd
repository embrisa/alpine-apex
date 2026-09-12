extends SceneTree
## Isolated lab state/input/lifecycle checks, including an actual main scene rebuild.
const Checks = preload("res://tests/session_navigation_checks.gd")
var audit = Checks.new()

func _initialize() -> void: call_deferred("run")

func load_game():
	set_meta("test_lab_fixture",true)
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	while not game.initialized: await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.active = false
	game.session.eligible = false
	return game

func run() -> void:
	audit.model_checks()
	var game = await load_game()
	await audit.scene_checks(self,game)
	var model = game.workshop.navigation_state
	var before = model.points()
	var identity: String = model.mountain_identity
	game.effects.stop_audio()
	game.free()
	await process_frame
	game = await load_game()
	audit.check(game.workshop.navigation_state==model and model.points()==before and model.mountain_identity==identity,"An actual same-mountain main-scene rebuild retains all personal points")
	audit.check(game.workshop.navigation_beams.beams.size()==before.size(),"Scene rebuild reconstructs personal render instances")
	var other = Checks.Navigation.acquire(self,identity+"-different-physical-field")
	audit.check(other.count()==0 and game.workshop.navigation_beams.beams.is_empty(),"Different full physical identity clears retained data and connected beams")
	DirAccess.make_dir_recursive_absolute("res://artifacts/session_navigation_checks")
	FileAccess.open("res://artifacts/session_navigation_checks/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":audit.checks,"failures":audit.failures,"scope":"Model, real UI input ownership, scene rebuild; no native visual/performance acceptance"},"\t"))
	game.effects.stop_audio()
	game.free()
	quit(0 if audit.failures.is_empty() else 1)
