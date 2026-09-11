extends SceneTree
const Race = preload("res://scripts/racing/race_definition.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
var checks = 0
var failures: Array[String] = []
var game
var field

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func point(x: float) -> Vector3: return Vector3(x,field.sample(x,0).height,0)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	field = game.field
	var fingerprint: String = field.height_checksum
	game.session.record_directory = "user://summit_return_test_%d" % OS.get_process_id()
	game.workshop.store.directory = game.session.record_directory.path_join("races")
	game.hud.feedback.reduced_motion = true
	game.start_run(false)
	game.weather.set_time_of_day("dusk")
	var hour: float = game.weather.daylight.hour
	var quality: int = game.graphics.level
	game.camera.close_view = true
	game.sim.impacts.reserve = 0.3
	game.sim.velocity = Vector3(90,0,0)
	game.session.elapsed = 45
	check(game._resolve_zone_exit(1.0/120.0,point(2840),point(2860)),"Free skiing resolves a base crossing through the live session path")
	check(game.active and game.summit_ready and game.sim.position==field.spawn_point() and game.sim.velocity.is_zero_approx(),"Reduced motion returns immediately to a stationary summit")
	check(game.session.elapsed==0 and game.sim.impacts.reserve==1 and game.session.recording==null and not game.session.eligible,"Return clears clock, impacts and recording; free skiing remains unranked")
	check(game.camera.close_view and game.weather.daylight.hour==hour and game.graphics.level==quality,"Return preserves camera preference, time of day and graphics")
	check(game.previous_position==game.sim.position and not game.camera.initialized,"Return resets pose/camera interpolation without a cross-mountain streak")
	game.automated = false
	Input.action_press("tuck")
	game._physics_process(1.0/120.0)
	check(game.summit_ready and not game.summit_drop_armed,"Holding tuck through return cannot drop in")
	Input.action_release("tuck")
	game._physics_process(1.0/120.0)
	check(game.summit_drop_armed and game.summit_ready,"Neutral re-arms the summit controls without starting")
	Input.action_press("tuck")
	game._physics_process(1.0/120.0)
	Input.action_release("tuck")
	check(not game.summit_ready,"A fresh tuck starts the next descent")
	game.automated = true
	game.start_run(false)
	game.summit_ready = false
	game.sim.reset(point(2849)+Vector3.UP*300,PI/2)
	game.sim.velocity = Vector3(1000,0,0)
	game._physics_process(1.0/120.0)
	check(game.summit_ready and game.sim.position==field.spawn_point(),"An airborne high-speed physics tick triggers the actual return wiring")
	# Valid race: the finite gate lies inside the 25 m endpoint margin.
	var race = Race.new()
	race.title = "Boundary ordering fixture"
	race.mountain = Race.mountain_reference(field,game.world.mountain.seed_value)
	race.start = point(2700)
	race.finish = point(2820)
	race.heading = PI/2
	race.finish_heading = PI/2
	check(race.validate_surface(field).is_empty(),"A new race with a finish safely inside the zone is valid")
	var old = race.to_data()
	old.schema = 1
	check(not Race.decode(JSON.stringify(old)).has("race"),"Old race codes are rejected rather than migrated")
	game.session.configure(race)
	game.timed = true
	game.session.eligible = true # Only the isolated test record directory is writable.
	game.sim.reset(point(2780),PI/2)
	game.sim.prime_contacts(field)
	game.session.begin_capture(game.sim)
	game.sim.position = point(2860)
	var record_path: String = game.session.record_path()
	var key = game.session.Replay.key(game.session.course_id)
	game._resolve_zone_exit(1.0,point(2780),point(2860))
	var saved = game.session.Records.load_record(record_path,key)
	check(saved.best>0 and saved.best<1 and game.summit_ready and game.session.race==null,"An earlier finish saves its fractional time, then returns to summit free skiing")
	# Deliberately inject a malformed race to test the boundary/finish tie defense.
	for finish_x in [2850.0,2880.0]:
		race.title = "Injected outside race %.0f" % finish_x
		race.start = Vector3(2700,0,0)
		race.finish = Vector3(finish_x,0,0)
		race.finish_base_y = 0.0
		game.session.configure(race)
		game.timed = true
		game.session.eligible = true
		game.sim.crashed = false
		var invalid_path: String = game.session.record_path()
		game._resolve_zone_exit(1.0,Vector3(2800,0,0),Vector3(2900,0,0))
		check(game.session.Records.load_record(invalid_path,game.session.Replay.key(race.record_identity())).best<0 and game.session.race==null,"Boundary wins a tie/later finish without a saved result at %.0f" % finish_x)
	check(game.session.Records.load_record(record_path,key).best==saved.best,"Aborted runs cannot overwrite the earlier personal best")
	race.start = point(2700)
	race.finish = point(2820)
	race.validate_surface(field)
	game.session.configure(race)
	game.session.eligible = false
	game.timed = true
	game.sim.crash(field.boundary_message)
	game._resolve_zone_exit(1.0,point(2780),point(4000))
	check(game.return_message.begins_with("Finished"),"A later outer safety-boundary crash cannot erase a finish before the return line")
	game.start_run(false)
	game.workshop.open_library()
	game.workshop.begin_creation()
	check(game.workshop.zone_outline.visible,"Race authoring shows the shared zone outline")
	check(not game.workshop.place_point(point(2840)),"Authoring rejects an endpoint inside the warning band but outside the endpoint margin")
	game.workshop.close()
	check(not game.workshop.zone_outline.visible,"Zone outline is hidden during skiing")
	game.hud.update_summit_return(120,true)
	check(game.hud.summit_return_label.visible and "120 m" in game.hud.summit_return_label.text,"Approach warning displays distance in metres")
	game.hud.update_summit_return(170,true)
	check(not game.hud.summit_return_label.visible,"Approach warning disappears beyond 150 m")
	# A visible fade freezes gameplay; explicit restart cancels its callbacks.
	game.start_run(false)
	game.hud.feedback.reduced_motion = false
	game._begin_summit_return(false)
	check(game.returning_to_summit and not game.active,"Fade freezes active skiing immediately")
	game._begin_summit_return(false)
	game.restart()
	game.sim.position = point(50)
	await create_timer(0.5).timeout
	check(not game.returning_to_summit and game.sim.position==point(50),"Restart cancels duplicate/stale fade callbacks")
	game._begin_summit_return(false)
	var pause = InputEventAction.new()
	pause.action = "pause_run"
	pause.pressed = true
	game._unhandled_input(pause)
	await create_timer(0.5).timeout
	check(game.summit_ready and not game.active and game.hud.menu_mode=="paused","Pause during the fade leaves the returned rider paused")
	game.hud.feedback.reduced_motion = true
	game.start_run(false)
	game.summit_ready = false
	game.sim.crash("BOUNDARY RAGDOLL TEST")
	game._physics_process(1.0/120.0)
	# Physical bones live under the visual skeleton, not the ragdoll helper Node.
	for body in game.skier.ragdoll.bodies.values(): body.global_position += Vector3(2900,0,0)
	game._process(1.0/60.0)
	check(not game.skier.ragdoll.running and game.summit_ready,"A moving ragdoll beyond the line is recovered through presentation lifecycle")
	check(field.height_checksum==fingerprint,"All returns preserve the physical terrain fingerprint")
	game.hud.feedback.reduced_motion = false
	game._begin_summit_return(false)
	game.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	check(not is_instance_valid(game),"Freeing a world during the fade safely cancels its transition")
	print("SUMMIT_RETURN_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"height_sha256":fingerprint}))
	quit(0 if failures.is_empty() else 1)
