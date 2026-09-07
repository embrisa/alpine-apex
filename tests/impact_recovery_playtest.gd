extends SceneTree
## Native visual verification. Actual hop, fall, landing and turns; unranked.
const DT = 1.0/120.0
const OUT = "res://artifacts/impact_recovery/"
var game
var captures: Array = []
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("This playtest requires native rendering")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.automated = true
	game.effects.muted = true
	game.weather.set_preset("clear")
	root.size = Vector2i(1440,900)
	game.start_run(true)
	_setup(50.0)
	for i in range(60): await _step()
	game.intent.jump_held = true
	for i in range(20): await _step()
	await capture("jump_ready","JUMP READY")
	game.intent.jump_held = false
	game.intent.jump = true
	await _step()
	game.intent.jump = false
	for i in range(25): await _step()
	await capture("released_hop","AIRBORNE")
	for i in range(100):
		await _step()
		if game.sim.grounded: break
	if game.sim.crashed or not game.sim.grounded: failures.append("Normal released hop must land")
	_setup(65.0)
	# A controlled vertical drop supplies real normal impact and body reaction.
	game.sim.position.y += 3.2
	game.sim.grounded = false
	game.sim.velocity += Vector3.DOWN*3.0
	game.sim.reset_pose_history()
	for i in range(200):
		await _step()
		if game.sim.grounded or game.sim.crashed: break
	await capture("landing_absorption","HARD LANDING")
	for i in range(180): await _step()
	await capture("impact_recovery","RECOVERING")
	for i in range(720): await _step()
	await capture("recovered_line","")
	if game.sim.crashed or game.sim.impacts.reserve<.99: failures.append("Survived landing should recover on a steady line")
	_setup(120.0)
	game.intent.steer = 1.0
	for i in range(240): await _step()
	game.intent.steer = -1.0
	for i in range(45): await _step()
	await capture("turn_transfer","")
	for i in range(90): await _step()
	await capture("opposite_carve","")
	if game.sim.crashed: failures.append("Rendered reversal must remain controlled")
	game.camera.effects_enabled = false
	for i in range(15): await _step()
	await capture("comfort_view","")
	# Explicit HUD diagnostic states cover warning priority and long labels.
	game.sim.impacts.reserve = .20
	game.sim.impacts.since_hit = 1.0
	game.sim.grounded = true
	game.intent.jump_held = true
	game._process(DT)
	await capture("warning_fixture","LOW IMPACT RESERVE",true)
	game.sim.impacts.reserve = 0.0
	game.sim.crash("IMPACT LIMIT / HARD LANDING")
	game._process(DT)
	await capture("crash_label_fixture","IMPACT LIMIT",true)
	var report = {"captures":captures,"failures":failures,"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),"human_playtest":false}
	FileAccess.open(OUT+"native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("IMPACT_NATIVE ",JSON.stringify(report))
	game.active = false
	game.effects.stop_audio()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _setup(kmh: float) -> void:
	game.start_speed_lab(kmh)
	game.session.eligible = false
	var z = 150.0
	game.sim.reset(Vector3(0,game.field.sample(0,z).height,z))
	game.sim.prime_contacts(game.field)
	game.sim.velocity = game.sim.support_basis().z*kmh/3.6
	game.previous_position = game.sim.position
	game.camera.close_view = false
	game.camera.reset()
	game.intent = RiderInput.new()
	game.hud.toast_time = 0.0
	game.hud.menu.visible = false
	game.hud.menu_mode = "racing"

func _step() -> void:
	await physics_frame
	game.previous_position = game.sim.position
	game.sim.step(DT,game.intent,game.field)
	game.session.elapsed += DT
	game._process(DT)

func capture(id: String, expected: String, diagnostic: bool = false) -> void:
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+id+".png")
	var hud = game.hud
	if not expected.is_empty() and not hud.state_label.text.begins_with(expected): failures.append(id+": expected "+expected+", got "+hud.state_label.text)
	if not root.get_visible_rect().encloses(hud.state_label.get_global_rect()): failures.append(id+": state label outside viewport")
	if not root.get_visible_rect().encloses(hud.impact_label.get_global_rect()): failures.append(id+": impact label outside viewport")
	if game.session.eligible: failures.append("Playtest must remain unranked")
	captures.append({"id":id,"diagnostic_fixture":diagnostic,"status":hud.state_label.text,"impact_reserve":game.sim.impacts.reserve,"normal_impact_speed_m_s":game.sim.landing_force,"speed_kmh":game.sim.speed_kmh(),"grounded":game.sim.grounded,"crash":game.sim.crash_reason,"eligible":game.session.eligible})
