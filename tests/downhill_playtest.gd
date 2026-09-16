extends SceneTree
## Rendered v11 turns and bump absorption. Fixed 120 Hz inputs; never ranked.
const Definition=preload("res://scripts/world/mountain_definition.gd")
const DT=1.0/120.0
const OUTPUT="res://artifacts/handling_v15/visual"
var game
var field
var observer: Camera3D
var rows: Array=[]
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("Rendered playtest requires a display."); quit(2); return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size=Vector2i(1920,1080)
	field=Definition.generate(849205174,11)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Default Mountain"),"field":field})
	game=load("res://main.tscn").instantiate()
	game.automated=true
	root.add_child(game); current_scene=game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.summit_ready=false; game.session.eligible=false
	game.hud.root.hide(); game.hud.hide_menu(); game.speed_periphery.hide()
	game.effects.muted=true
	game.camera.close_view=false; game.camera.effects_enabled=false
	game.weather.set_preset("clear")
	observer=Camera3D.new(); game.add_child(observer)
	observer.fov=52; observer.far=15000; observer.near=.05
	for request in [{"name":"left_tucked","steer":-1.0,"speed":120.0,"face":0,"z":2150.0},
		{"name":"right_tucked","steer":1.0,"speed":120.0,"face":0,"z":2150.0},
		{"name":"bumps","steer":0.0,"speed":120.0,"face":0,"z":2150.0},
		{"name":"gentle_snow","steer":0.0,"speed":60.0,"face":5,"z":800.0}]:
		await ride(request)
	preload("res://tests/test_report.gd").write(OUTPUT+"/results.json",JSON.stringify({"model":game.sim.MODEL_VERSION,"seed":849205174,"generator":11,"unranked":not game.session.eligible,"height_sha256":field.height_checksum,"fixtures":rows,"failures":failures,"pixels":[root.size.x,root.size.y],"capture_overhead_included":true},"\t"))
	print("DOWNHILL_VISUAL_RESULTS ",JSON.stringify({"fixtures":rows.size(),"failures":failures,"path":OUTPUT}))
	game.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func ride(request: Dictionary) -> void:
	var face=field.faces[request.face]
	var x: float=face.gully_x(request.z,-1) if request.z<1850 else face.glade_x(request.z,-1)
	var point: Vector2=face.to_world(Vector2(x,request.z))
	game.sim.reset(Vector3(point.x,field.sample(point.x,point.y).height,point.y),face.heading)
	game.sim.prime_contacts(game.world.ski_surface)
	game.sim.velocity=game.sim.support_basis().z*request.speed/3.6
	game.sim.effective_tuck=1.0
	game.skier.reset_animation(game.sim); game.effects.reset(); game.camera.reset()
	game.intent=RiderInput.new(); game.intent.steer=request.steer; game.intent.tuck=1.0
	var captures=[]
	for frame in 180:
		for tick in 2:
			game.previous_position=game.sim.position
			game.sim.step(DT,game.intent,game.world.ski_surface)
			game.skier.step_animation(DT,game.sim,game.intent,field)
		game._process(1.0/60.0)
		game.speed_periphery.hide()
		game.skier.pose(game.sim,1.0)
		var basis: Basis=game.sim.support_basis()
		var focus: Vector3=game.sim.position+Vector3.UP*.75
		observer.global_position=focus+basis.x*4.5+basis.z*2.0+Vector3.UP*1.2
		observer.look_at(focus); observer.make_current()
		await process_frame; await RenderingServer.frame_post_draw
		if frame in [29,89,179]:
			var name="%s_%03d.png" % [request.name,frame]
			root.get_texture().get_image().save_png(OUTPUT+"/"+name)
			captures.append({"image":name,"s":(frame+1)/60.0,"speed_kmh":game.sim.speed_kmh(),"grounded":game.sim.grounded,"support_offset_m":game.sim.support_offset_m,"load_n":[game.sim.skis[0].load_n,game.sim.skis[1].load_n]})
		if game.sim.crashed: failures.append(request.name+": "+game.sim.crash_reason); break
	rows.append({"request":request,"captures":captures,"airtime_s":game.sim.total_airtime,"crash":game.sim.crash_reason})
	print("DOWNHILL_VISUAL_FIXTURE ",request.name)
