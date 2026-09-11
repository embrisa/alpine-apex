extends SceneTree
## Native, unranked integration review of the actual main scene and 4 m massif.
const DT=1./120.
var game
var failures: Array=[]
var shots: Array=[]
var profile: Dictionary={}
var output="res://artifacts/flavor_integration/world"
class Driver extends RefCounted:
	var controls=RiderInput.new()
	func sample(_grounded: bool = true): return controls
	func cancel_air_input(): pass
	func sample_camera_look(): return Vector2.ZERO
	func device_label(): return "Test driver"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name()=="headless": quit(2); return
	root.borderless=true; root.position=Vector2i.ZERO; root.size=Vector2i(3840,2160); Engine.max_fps=120
	game=load("res://main.tscn").instantiate(); root.add_child(game); current_scene=game
	while not game.initialized: await process_frame
	game.set_physics_process(false); game.set_process(false)
	game.active=false; game.preferences_enabled=false; game.effects.muted=true
	game.world.update_weather(game.weather.state,0,false)
	var race=game.workshop.suggested_race
	check(race!=null,"Mountain Sprint is available in the normal game")
	if not race: quit(1); return
	game.workshop.open_library()
	check(game.workshop.races.any(func(r): return r.identity()==race.identity()),"Suggested race is selectable without creating a save")
	await capture("race_library")
	await game.play_custom_race(race); game.session.eligible=false
	var gate_count=game.world.ski_surface.groups.size()-game.world.flavor.props.size()
	check(gate_count==2,"Only the active race adds two collidable gates")
	var driver=Driver.new(); game.input_router=driver
	game.session.eligible=false
	var crossed=false
	var captured_start=false; var captured_finish=false
	for tick in 6000:
		var direction: Vector3=race.finish-game.sim.position
		driver.controls.tuck=.7
		driver.controls.steer=clampf(wrapf(game.sim.heading-atan2(direction.x,direction.z),-PI,PI)*3.,-.4,.4)
		game._physics_process(DT)
		if tick%2==0:
			game._process(1./60.); await process_frame
		if not captured_start and tick>120:
			captured_start=true; await capture("race_start")
		if not captured_finish and game.sim.position.distance_to(race.finish)<22:
			captured_finish=true; await capture("race_finish_approach")
		if game.session.finished or game.sim.crashed: break
	check(game.session.finished and not game.sim.crashed,"Real main-game fixed-step dispatch completes the gate race")
	profile.race_time=game.session.elapsed; profile.crash=game.sim.crash_reason
	await capture("race_result")
	game.restart(); game.session.eligible=false
	check(game.world.ski_surface.groups.size()-game.world.flavor.props.size()==2,"Retry keeps exactly one gate pair")
	game.start_run(false); game.active=false
	check(game.world.ski_surface.groups.size()==game.world.flavor.props.size(),"Free skiing removes race collision while keeping discoveries")
	# Inspect every new flavor family on its actual generated mountain footing.
	game.hud.root.hide(); game.skier.hide(); game.speed_periphery.hide()
	# Static art inspection needs no Jolt jobs or moving crash-collision patches.
	PhysicsServer3D.set_active(false)
	var camera=Camera3D.new(); camera.far=32000; game.add_child(camera); camera.current=true
	var seen: Dictionary={}
	for prop in game.world.flavor.props:
		if seen.has(prop.asset_id): continue
		seen[prop.asset_id]=true
		var size: Array=prop.record.dimensions_m
		var distance=maxf(2.5,maxf(size[0],size[1])*1.9)
		var center=prop.position+Vector3.UP*size[1]*.48
		camera.position=center+Basis(Vector3.UP,prop.rotation.y)*Vector3(distance*.5,distance*.32,distance)
		camera.position.y=maxf(camera.position.y,game.field.sample(camera.position.x,camera.position.z).height+1.6)
		camera.look_at(center)
		await capture(prop.asset_id)
		if prop.asset_id=="alpine_refuge":
			profile.near_hut=await measure()
			game.world.flavor.hide()
			profile.same_view_without_props=await measure()
			game.world.flavor.show()
	check(seen.size()==10,"All ten flavor families are present on the default mountain")
	var report={"failures":failures,"captures":shots,"profile":profile,"engine":Engine.get_version_info().string,
		"device":RenderingServer.get_video_adapter_name(),"render_pixels":root.get_texture().get_image().get_size(),
		"physics_hz":Engine.physics_ticks_per_second,"sites":game.world.flavor.layout.sites.size(),"props":game.world.flavor.props.size(),"layout":game.world.flavor.layout.fingerprint}
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FLAVOR_WORLD ",JSON.stringify(report)); game.effects.stop_audio(); game.free(); quit(0 if failures.is_empty() else 1)
func capture(label: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png"); shots.append(label)
func measure() -> Dictionary:
	var rid=root.get_viewport_rid(); RenderingServer.viewport_set_measure_render_time(rid,true)
	for i in 120: await process_frame
	var frames: Array=[]; var gpu: Array=[]; var cpu: Array=[]
	var previous=Time.get_ticks_usec()
	for i in 360:
		await process_frame
		var now=Time.get_ticks_usec(); frames.append((now-previous)/1000.); previous=now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	frames.sort(); gpu.sort(); cpu.sort()
	return {"scope":"Static near-hut view of the full default mountain; no screenshot overhead in samples",
		"samples":frames.size(),"p95_ms":frames[342],"p99_ms":frames[356],"gpu_p95_ms":gpu[342],"render_cpu_p95_ms":cpu[342],
		"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"static_memory_bytes":OS.get_static_memory_usage(),
		"render_scale":root.scaling_3d_scale,"output_pixels":[root.size.x,root.size.y]}
