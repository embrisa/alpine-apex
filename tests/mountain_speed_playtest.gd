extends SceneTree
## Test-only pilot sends ordinary rider intent. It never edits velocity, height,
## collision, or the game solver; no navigation data enters shipped movement.
const Terrain = preload("res://scripts/world/generators/drainage_v3.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
var field
var game
var frames: Array[float] = []
var draws: Array[float] = []
var last_frame: int = 0
var capture_enabled: bool = false
var seed_number: int = 849205174
var version_number: int = Terrain.GENERATOR_VERSION
var speed_limit: float = 0.0
var recording: bool = false
var actual_pixels = Vector2i.ZERO
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/jump_upgrade")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_number = int(arg.get_slice("=",1))
		if arg.begins_with("--version="): version_number = int(arg.get_slice("=",1))
		if arg.begins_with("--speed-limit="): speed_limit = float(arg.get_slice("=",1))
	field = Definition.generate(seed_number,version_number)
	var rendered = DisplayServer.get_name()!="headless"
	capture_enabled = "--descent-captures" in OS.get_cmdline_user_args()
	if rendered:
		get_tree_setup()
		await process_frame
		game.set_physics_process(false)
		game.set_graphics_quality(0)
		game.weather.set_preset("snowfall")
		game.effects.muted = true
		game.automated = true
		game.start_run(false)
		game.session.eligible = false
		root.size = Vector2i(1440,900)
		await RenderingServer.frame_post_draw
		actual_pixels = root.get_texture().get_image().get_size()
		for i in 120: await process_frame
		process_frame.connect(_measure)
	var results: Array = []
	var sides = [-1.0,1.0] if "--both-routes" in OS.get_cmdline_user_args() else [1.0]
	for side in sides:
		var sim = game.sim if rendered else Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
		sim.reset(field.spawn_point(),field.spawn_heading())
		sim.prime_contacts(field)
		var input = RiderInput.new()
		var target_heading = 0.0
		var ticks = 0
		var sample_points: Array = []
		var air_captured = false
		var start_usec = Time.get_ticks_usec()
		recording = true
		for i in range(24000):
			ticks = i+1
			if i%12==0: target_heading = pilot_heading(sim,side)
			input.steer = clampf(-angle_difference(sim.heading,target_heading)*.8,-.35,.35)
			input.brake = clampf((sim.speed_kmh()-speed_limit)/20,0,1) if speed_limit>0 else 0.0
			input.tuck = .75
			if rendered:
				game.intent = input
				game.session.elapsed += 1.0/120.0
				await physics_frame
			sim.step(1.0/120.0,input,field)
			if i%1200==0:
				sample_points.append({"seconds":i/120.0,"x":sim.position.x,"z":sim.position.z,"kmh":sim.speed_kmh()})
				if rendered and capture_enabled:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://artifacts/jump_upgrade/descent_%d.png" % i)
			if rendered and capture_enabled and not air_captured and sim.total_airtime>.12:
				air_captured = true
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/jump_upgrade/descent_air.png")
			if sim.crashed or sim.position.z>=field.finish_z: break
		recording = false
		results.append({"entry_bias":"west" if side<0 else "east","finished":sim.position.z>=field.finish_z,"crashed":sim.crashed,"reason":sim.crash_reason,
			"sim_seconds":ticks/120.0,"wall_seconds":(Time.get_ticks_usec()-start_usec)/1000000.0,"peak_kmh":sim.peak_speed*3.6,
			"airtime_s":sim.total_airtime,"position":str(sim.position),"samples":sample_points})
		print("DESCENT ",JSON.stringify(results.back()))
	var output = {"seed":seed_number,"version":version_number,"pilot_speed_limit_kmh":speed_limit,"pilot_tuck":.75,"results":results,"rendered":rendered,"actual_pixels":[actual_pixels.x,actual_pixels.y],"capture_overhead_included":capture_enabled,
		"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"backend":RenderingServer.get_current_rendering_driver_name(),
		"graphics":"Low","weather":"Snowfall / High","warmup_frames":120,"frame_ms":timing(frames),"draw_calls":timing(draws)}
	var path = "res://artifacts/jump_upgrade/descent_v%d_%d_%s.json" % [version_number,seed_number,"native" if rendered else "headless"]
	preload("res://tests/test_report.gd").write(path,JSON.stringify(output,"\t"))
	if game:
		game.active = false
		game.effects.stop_audio()
		game.queue_free()
		await process_frame
	var passed = results.all(func(result): return result.finished and not result.crashed)
	if version_number==2 and speed_limit==0:
		passed = passed and results.all(func(result): return result.peak_kmh>140 and result.sim_seconds<90)
	quit(0 if passed else 1)

func get_tree_setup() -> void:
	set_meta("mountain_to_load",{"definition":Definition.from_field(field),"field":field})
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game

func pilot_heading(sim, side: float) -> float:
	var p: Vector3 = sim.position
	var downhill = Vector3.DOWN.slide(field.contact_normal(p.x,p.z))
	var preferred = atan2(downhill.x,downhill.z)
	preferred += side*.22*(1-smoothstep(100,220,p.z))
	var lookahead = clampf(sim.velocity.length()*2.7,25,90)
	var best = preferred
	var best_cost = INF
	for j in range(-8,9):
		var heading = preferred+j*.08
		if absf(heading)>1.1: continue
		var direction = Vector3(sin(heading),0,cos(heading))
		var cost = absf(j)*.5+absf(angle_difference(sim.heading,heading))*1.5
		var last = p
		for k in range(1,7):
			var probe = p+direction*(lookahead*k/6.0)
			probe.y = field.sample(probe.x,probe.z).height
			for lateral in [-4.0,0.0,4.0]:
				if not field.sweep_obstacle(last+Vector3.RIGHT*lateral,probe+Vector3.RIGHT*lateral).is_empty(): cost += 35.0
			cost += maxf(0,.8-field.contact_normal(probe.x,probe.z).y)*5.0
			last = probe
		if cost<best_cost:
			best_cost = cost
			best = heading
	return best

func _measure() -> void:
	var now = Time.get_ticks_usec()
	if recording and last_frame>0:
		frames.append((now-last_frame)/1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	last_frame = now

func timing(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"available":false}
	values.sort()
	var total = 0.0
	for value in values: total += value
	var slow_count = maxi(1,ceili(values.size()*.01))
	var slow_sum = 0.0
	for i in range(values.size()-slow_count,values.size()): slow_sum += values[i]
	return {"samples":values.size(),"mean":total/values.size(),"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)],"slowest_one_percent_mean":slow_sum/slow_count}
