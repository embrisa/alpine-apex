extends RefCounted
## Reusable focused checks for a parent's isolated, already-loaded main scene.
const Navigation = preload("res://scripts/racing/session_navigation.gd")
const TerrainInput = preload("res://scripts/ui/session_navigation_input.gd")
const Mountain = preload("res://scripts/world/mountain_definition.gd")
var failures: Array[String] = []
var checks: int = 0

class Surface:
	extends RefCounted
	const GENERATOR_ID = "alpine-drainage"
	var blocked = false
	func is_summit_mountain() -> bool: return true
	func spawn_point() -> Vector3: return Vector3.ZERO
	func ski_bounds() -> Rect2: return Rect2(-3072,-3072,6144,6144)
	func sample(x: float, _z: float) -> Dictionary: return {"height":-x*1.3,"normal":Vector3(-1.3,1,0).normalized()}
	func sweep_obstacle(_a: Vector3, _b: Vector3) -> Dictionary: return {"tree":true} if blocked else {}

func check(value: bool, caption: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",caption)
	if not value: failures.append(caption)

func model_checks() -> void:
	var surface = Surface.new()
	var model = Navigation.new()
	model.bind_mountain("full-physical-reference-A")
	check(model.count()==0 and model.shown,"A fresh session starts empty and visible")
	check(not model.add_point(surface,Vector3(NAN,0,0)).error.is_empty(),"Nonfinite coordinates are rejected")
	check(not model.add_point(surface,Vector3(4000,0,0)).error.is_empty(),"Off-map points are rejected")
	check(not model.add_point(surface,Vector3(2850,0,0)).error.is_empty(),"Points outside the playable return disk are rejected")
	var result = model.add_point(surface,Vector3(2849,0,0))
	check(result.error.is_empty(),"Personal points do not inherit the 25 m endpoint margin or 40 degree slope limit")
	surface.blocked = true
	check(not model.add_point(surface,Vector3(100,0,0)).error.is_empty(),"Unsupported tree/rock placements are rejected")
	surface.blocked = false
	for i in 31: model.add_point(surface,Vector3(100+i,500,50))
	check(model.count()==32,"All 32 personal landmarks can be retained")
	var original = model.points()
	check(not model.add_point(surface,Vector3(100,0,100)).error.is_empty() and model.points()==original,"Marker 33 is rejected without discarding earlier points")
	check(model.point(2).position.y==-130.0,"Positions use authoritative support height")
	check(model.move_point(2,surface,Vector3(125,0,50)).error.is_empty() and model.count()==32 and model.point(2).id==2,"Move keeps the selected stable ID at the count limit")
	check(model.point(3)==original[2],"Moving affects no other point")
	var copy = model.points()
	copy[0].position = Vector3.ZERO
	check(model.point(1).position!=Vector3.ZERO,"Returned collections cannot mutate the session list")
	model.set_shown(false)
	var retained = model.points()
	model.bind_mountain("full-physical-reference-A")
	check(model.points()==retained and not model.shown,"Same-identity bind retains points and hidden state")
	check(model.remove_point(2) and not model.remove_point(999),"Removal targets an existing ID only")
	check(model.add_point(surface,Vector3(120,0,0)).id==33,"Removing a point never recycles its ID")
	model.clear_points()
	check(model.add_point(surface,Vector3(120,0,0)).id==34,"Clear-all does not reuse IDs within a mountain session")
	model.bind_mountain("full-physical-reference-B")
	check(model.count()==0 and model.shown,"Changed physical mountain identity clears memory-only points")
	var definition = Mountain.new()
	var before = definition.identity()
	definition.generation_settings.tree_population = 2.0
	check(before!=definition.identity(),"The full identity distinguishes same-seed physical settings")
	before = definition.identity()
	definition.height_checksum = "a".repeat(64)
	check(before!=definition.identity(),"The full identity includes terrain fingerprints")
	check(Navigation.new().count()==0,"An unrelated application owner starts empty")
	var input_state = TerrainInput.new()
	input_state.enter(true)
	check(input_state.button(JOY_BUTTON_A,true).is_empty(),"Held menu confirm cannot place upon entering terrain mode")
	input_state.button(JOY_BUTTON_A,false)
	check(input_state.button(JOY_BUTTON_A,true)=="confirm" and input_state.button(JOY_BUTTON_A,true).is_empty(),"One release/press makes one deliberate placement")
	input_state.motion(JOY_AXIS_LEFT_Y,-1.0)
	check(input_state.pan().is_zero_approx(),"A carried stick is ignored before neutral")
	input_state.motion(JOY_AXIS_LEFT_Y,0.0)
	input_state.motion(JOY_AXIS_LEFT_Y,-1.0)
	check(input_state.pan().y<-.9,"A new stick excursion pans after neutral")
	input_state.reset()
	input_state.motion(JOY_AXIS_LEFT_X,1.0)
	check(input_state.pan().is_zero_approx() and input_state.button(JOY_BUTTON_A,true).is_empty(),"Panel focus suspends terrain controls")

func scene_checks(tree: SceneTree, game) -> void:
	var workshop = game.workshop
	var model = workshop.navigation_state
	var tool = workshop.navigation_panel
	game.set_process(false)
	game.set_physics_process(false)
	game.automated = false # Route simulated events through the real menu owner.
	game.preferences_enabled = false
	game.session.record_directory = "res://artifacts/session_navigation_checks/records"
	game.session.benchmark_path = "res://artifacts/session_navigation_checks/benchmark.json"
	game.session.eligible = false
	game.effects.muted = true
	game.effects.haptic_hardware_enabled = false
	game.voice.set_muted(true)
	game.hud.feedback.persist = false
	game.hud.feedback.muted = true
	game.active = false
	game.hud.show_menu("title")
	game.navigation._select_device(-1)
	model.clear_points()
	model.set_shown(true)
	var before = snapshot(game)
	game.hud.navigation_requested.emit()
	for i in 3: await tree.process_frame
	check(workshop.mode=="navigation" and game.navigation.scope()==tool.panel,"Summit Map entry opens its own focus scope without race creation")
	game._present_camera(0.0,game.sim.position)
	check(game.presentation_camera==workshop.survey,"Navigation dispatch selects the overhead survey camera")
	var anchors = supported_points(game,32)
	check(anchors.size()==32,"The loaded fixture provides 32 supported test points")
	if anchors.size()!=32: return
	# Actual pointer events use the production picker outside the drawer.
	workshop.survey_height = 140.0
	if game.field.has_method("fixture_descriptor"):
		# Frame the middle of the compact map so actual pointer rays land on it.
		workshop.focus_point = Vector3(0,game.field.sample(0,180).height,180)
		workshop.survey_height = 100.0
	workshop._update_survey()
	var viewport_rect: Rect2 = game.get_viewport().get_visible_rect()
	var terrain_left: float = tool.panel.get_global_rect().end.x+24.0
	for row in 5:
		for column in 8:
			var screen = Vector2(lerpf(terrain_left,viewport_rect.end.x-24.0,float(column)/7.0),lerpf(viewport_rect.size.y*.35,viewport_rect.size.y*.75,float(row)/4.0))
			var hit = workshop.pick_terrain(screen)
			if not hit is Vector3 or not Navigation.anchor(game.field,hit).error.is_empty(): continue
			tool.overlay.refresh()
			if tool.overlay.nearest(screen)>=0: continue
			var click = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = screen
			game.navigation.route(click)
			if model.count()==5: break
		if model.count()==5: break
	check(model.count()==5 and workshop.navigation_beams.beams.size()==5,"Five points have separate world beams")
	if model.count()!=5: return
	check(snapshot(game)==before,"Opening and placing freezes position, velocity, timing, eligibility and race identity")
	var beam = workshop.navigation_beams.beams.values()[0]
	check(beam.get_child_count()==1 and beam.base_material==null,"Each personal marker omits the dense race halo")
	check(not beam is CollisionObject3D and beam.get_child(0) is MeshInstance3D,"Personal landmarks create presentation meshes only")
	var original = model.points()
	model.move_point(original[1].id,game.field,anchors[8])
	check(model.point(original[1].id).position==anchors[8] and model.point(original[0].id)==original[0],"Only the selected personal point moves")
	tool.select_point(original[1].id)
	tool.begin_move()
	tool.back()
	check(model.point(original[1].id).position==anchors[8] and workshop.mode=="navigation" and not tool.input_state.terrain_active,"Back cancels a pending move before leaving the map")
	model.remove_point(original[2].id)
	check(model.count()==4,"Remove deletes just one selected point")
	model.set_shown(false)
	check(not workshop.navigation_beams.visible and model.count()==4,"Hide applies immediately without deleting points")
	model.set_shown(true)
	check(workshop.navigation_beams.visible,"Show restores personal world beams")
	var total = model.count()
	tool.enter_terrain()
	var drawer_click = InputEventMouseButton.new()
	drawer_click.button_index = MOUSE_BUTTON_LEFT
	drawer_click.pressed = true
	drawer_click.position = tool.panel.get_global_rect().get_center()
	tool.route_event(drawer_click)
	check(model.count()==total and not tool.input_state.terrain_active,"Clicks over the drawer never place points and suspend map movement")
	var camera_height: float = workshop.survey_height
	drawer_click.button_index = MOUSE_BUTTON_WHEEL_UP
	tool.route_event(drawer_click)
	check(workshop.survey_height==camera_height,"GUI scrolling cannot zoom the map")
	# Unhandled shortcuts must not open another tool or reach a rider action.
	for code in [KEY_R,KEY_F2,KEY_F4,KEY_F6]:
		var key = InputEventKey.new()
		key.physical_keycode = code; key.pressed = true
		game._unhandled_input(key)
	check(snapshot(game)==before and workshop.mode=="navigation" and not game.hud.tuning_panel.visible,"Navigation blocks retry and unrelated tool shortcuts")
	game.navigation._select_device(9001)
	tool.device_switched = false
	tool.begin_add()
	var pad = InputEventJoypadButton.new()
	pad.device = 9001; pad.button_index = JOY_BUTTON_A; pad.pressed = true
	game.navigation.route(pad)
	check(model.count()==total,"Controller Add activation cannot also place at the reticle")
	# Aim the reticle at real terrain; the selected survey focus is a test camera only.
	for point in anchors:
		workshop.focus_point = point
		workshop.survey_height = 45.0 if game.field.has_method("fixture_descriptor") else 140.0
		tool.update_survey(0.0)
		if tool.preview is Vector3 and tool.overlay.nearest(tool.target_screen())<0: break
	check(tool.preview is Vector3,"Controller reticle is positioned over supported real terrain")
	pad.pressed = false; game.navigation.route(pad)
	pad.pressed = true; game.navigation.route(pad)
	check(model.count()==total+1,"A deliberate controller release/confirm places at a supported reticle")
	game.navigation.route(pad)
	check(model.count()==total+1,"Repeated held confirm cannot add duplicate points")
	var motion = InputEventJoypadMotion.new()
	motion.device = 9001; motion.axis = JOY_AXIS_LEFT_Y; motion.axis_value = 0.0
	game.navigation.route(motion)
	motion.axis_value = -.8; game.navigation.route(motion)
	var focus: Vector3 = workshop.focus_point
	tool.update_survey(.05)
	check(workshop.focus_point!=focus,"A neutralized controller pans in terrain mode")
	var mouse = InputEventMouseMotion.new()
	mouse.relative = Vector2(8,0)
	game.navigation.route(mouse)
	check(not tool.input_state.terrain_active and model.count()==total+1,"Device switching suspends terrain without placement")
	tool.begin_add()
	tool.suspend()
	check(tool.input_state.pan().is_zero_approx(),"Focus loss clears held map pan state")
	tool.back()
	check(workshop.mode.is_empty() and game.hud.menu_mode=="title" and not game.active,"Leaving returns to the originating summit menu")
	check(snapshot(game)==before,"Open/edit/close preserves solver/session state")
	var retained = model.points()
	game.restart()
	game.active = false
	game.session.eligible = false
	check(model.points()==retained,"Retry retains personal points")
	workshop.show_race(workshop.suggested_race)
	workshop.show_race(null)
	check(model.points()==retained and workshop.navigation_beams.beams.size()==retained.size(),"Race preview/cleanup cannot erase personal beams")
	if game.current_mountain:
		game.returning_to_summit = true
		game._return_to_summit_midpoint()
		game._return_to_summit_complete()
		game.active = false
		check(model.points()==retained,"Return to summit retains personal points")
	game.start_run(game.current_mountain==null)
	game.active = false
	game.session.eligible = false
	check(model.points()==retained,"Same-mountain free/lab restart retains personal points")
	game.hud.show_menu("paused")
	before = snapshot(game)
	workshop.open_navigation()
	for i in 30: game._physics_process(1.0/120.0)
	check(snapshot(game)==before,"Thirty inactive fixed ticks do not advance the paused session")
	tool.focus_panel(); tool.back()
	check(game.hud.menu_mode=="paused" and not game.active,"Map Back returns to pause without resuming or respawning")
	game.resume()
	check(game.active and game.sim.position==before.position and game.sim.velocity==before.velocity,"Resume retains position and velocity")
	check(not game.rider_axes_armed and not game.jump_prepared and not game.air_controls_armed,"Resume requires fresh neutral gameplay controls")
	game.active = false
	for point in anchors:
		if model.count()<32: model.add_point(game.field,point)
	workshop.open_navigation()
	tool.begin_add()
	check(model.count()==32 and "32" in tool.status.text and "LIMIT" in tool.count_label.text,"Point limit is visible in the actual map UI")
	game.hud.feedback.reduced_motion = true
	game._process(.05)
	check(workshop.navigation_beams.beams.values().all(func(item): return item.motion_reduced),"Reduced Motion reaches every visible personal beam")
	game.hud.feedback.reduced_motion = false
	tool.clear_all()
	check(model.count()==0 and workshop.navigation_beams.beams.is_empty(),"Clear-all empties only the personal render owner")
	for i in 5: model.add_point(game.field,anchors[i])
	tool.focus_panel(); tool.back()
	check(Navigation.acquire(tree,model.mountain_identity)==model,"SceneTree owns the session list across node replacement")
	if workshop.suggested_race:
		retained = model.points()
		await game.play_custom_race(workshop.suggested_race)
		game.active = false
		# A seeded paused-race fixture makes clock/progress/velocity retention nontrivial.
		game.session.elapsed = 12.5
		game.session.split_times[0] = 4.25
		game.session.eligible = true # All stores already point at isolated artifacts.
		game.sim.velocity = game.sim.support_basis().z*12.0
		game.hud.show_menu("paused")
		before = snapshot(game)
		var race_code: String = game.session.race.share_text()
		workshop.open_navigation()
		for i in 60: game._physics_process(1.0/120.0)
		tool.focus_panel(); tool.back()
		check(snapshot(game)==before and game.session.race.share_text()==race_code,"A paused authored race retains nonzero velocity/time/splits, eligibility, recorder and exact share identity")
		check(model.points()==retained,"Switching to an authored race on the same mountain preserves all points")
		game.session.eligible = false
		game.session.recording = null
		game.automated = true
		game.start_run(game.current_mountain==null)
		game.active = false
		game.session.eligible = false
		game.automated = false

static func supported_points(game, count: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var center: Vector3 = game.sim.position
	var basis = Basis(Vector3.UP,game.sim.heading)
	for i in 500:
		var point = center+basis*Vector3((i%5-2)*20.0,0.0,(i/5+1)*30.0)
		var anchored = Navigation.anchor(game.field,point)
		if anchored.error.is_empty(): result.append(anchored.position)
		if result.size()==count: break
	return result

static func snapshot(game) -> Dictionary:
	return {"position":game.sim.position,"velocity":game.sim.velocity,"ticks":game.sim.ticks,
		"elapsed":game.session.elapsed,"eligible":game.session.eligible,"timed":game.timed,
		"race":game.session.race.identity() if game.session.race else "","splits":game.session.split_times.duplicate(),
		"recorder":game.session.recording.get_instance_id() if game.session.recording else 0}
