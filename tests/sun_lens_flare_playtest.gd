extends SceneTree
## Production slopes fixture. Separate capped review and capture-free cost modes.
const Flare=preload("res://scripts/presentation/sun_lens_flare.gd")
const Costs=preload("res://scripts/diagnostics/frame_costs.gd")
const Report=preload("res://tests/test_report.gd")
var game
var output="res://artifacts/sun_lens_flare/native"
var timing=false
var timing_on_only=false
var smoke=false
var failures: Array[String]=[]
var checks=0
var rows: Array=[]
var blocker: MeshInstance3D
var window_pixels=Vector2i(1920,1080)
var visibility_sample=PackedFloat32Array()

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FLARE_FAIL ",label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--timing":timing=true;window_pixels=Vector2i(3840,2160)
		if arg=="--timing-on-only":timing=true;timing_on_only=true;window_pixels=Vector2i(3840,2160)
		if arg=="--smoke":smoke=true
		if arg.begins_with("--flare-output="):output=arg.get_slice("=",1)
	check(DisplayServer.get_name()!="headless","Native renderer required")
	check(not timing or OS.get_environment("ALPINE_VALIDATION_MODE")=="FpsCritical","Timing requires FpsCritical")
	if not failures.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("test_map_fixture","perf-slopes")
	game=load("res://main.tscn").instantiate();game.automated=true
	root.add_child(game);current_scene=game
	while not game.initialized or game.loading.busy:await process_frame
	game.set_process(false);game.set_physics_process(false)
	game.preferences_enabled=false;game.set_audio_muted(true);game.effects.haptic_hardware_enabled=false
	game.display_settings.display_mode="windowed";game.display_settings.fps_limit=0 if timing else 60
	game.display_settings.upscaler="auto";game.display_settings.frame_generation=false
	game.display_settings.apply_display(root,window_pixels);game.display_settings.apply_viewport(root)
	game.weather.set_automatic(false);game.weather.set_time_cycle(false);game.weather.set_quality(2)
	game.start_run(false);game.set_physics_process(false)
	game.hud.feedback.reduced_motion=false;game.camera.effects_enabled=true
	game.application_focused=true
	blocker=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=Vector3(8,8,2);blocker.mesh=mesh
	var material=StandardMaterial3D.new();material.albedo_color=Color(.17,.23,.2);material.roughness=1
	blocker.material_override=material;game.add_child(blocker);blocker.hide()
	check(not game.session.eligible and game.field.fixture_id=="perf-slopes","Isolated production slopes map")
	check(game.world.backdrop==null and game.world.wilderness==null,"No full mountain preparation")
	if timing:
		prepare("chase","edge")
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
		root.grab_focus()
		for on in ([true] if timing_on_only else [false,true]):await measure(on)
	else:
		for view in ["chase","first_person"]:
			for scenario in (["edge","riding","cloudy"] if smoke else ["centre","edge","riding","behind","terrain","opaque","cloudy","night"]):
				await capture_pair(view,scenario)
		if not smoke:
			await lifecycle()
			for view in ["chase","first_person"]:await movement(view)
	check(game.sun_lens_flare.status().unavailable.is_empty(),"Shader and HDR/depth buffers supported: "+game.sun_lens_flare.status().unavailable)
	var report={"checks":checks,"failures":failures,"rows":rows,"timing":timing,"smoke":smoke,"map":game.field.fixture_descriptor(),"engine":Engine.get_version_info(),"executable":OS.get_executable_path(),"device":RenderingServer.get_video_adapter_name(),"backend":RenderingServer.get_current_rendering_driver_name(),"graphics":game.graphics.snapshot(),"display":game.display_settings.report(root,window_pixels),"performance_scope":"Fixed production slopes scene, same view and settings; no full-mountain or skiing FPS claim","human_acceptance":false}
	Report.write(output+"/report.json",JSON.stringify(report,"\t"))
	print("SUN_LENS_FLARE_NATIVE ",JSON.stringify({"checks":checks,"failures":failures,"output":output,"rows":rows.size()}))
	game.effects.stop_audio();game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)

func prepare(view: String, scenario: String) -> void:
	blocker.hide();game.sun_lens_flare.suspend()
	game.weather.set_preset("cloudy" if scenario=="cloudy" else "clear")
	game.weather.set_time_of_day("night" if scenario=="night" else "day")
	game.weather.update_weather(0,false,false)
	game.camera.close_view=view=="first_person"
	game.camera.reset();game.menu_camera.leave();game.hud.hide_menu();game.active=true
	var pos=Vector3(0,game.field.sample(0,196).height,196)
	game.sim.reset(pos,0);game.sim.prime_contacts(game.field);game.sim.velocity=Vector3(0,-.28,1).normalized()*12
	game.previous_position=game.sim.position;game.skier.reset_animation(game.sim)
	game._process(1.0/60)
	game.presentation_camera=game.camera;game.camera.make_current()
	game.weather.state.cloud_offset=Vector2.ZERO
	if scenario=="terrain":game.weather.state.sun_direction=Vector3(0,.12,-1).normalized()
	if scenario=="riding":
		# A modest upward manual look with slope and rider still in frame.
		game.camera.look_at(game.camera.global_position+Vector3(0,-.05,1)*100)
		game.weather.state.sun_direction=Vector3(.3,.20,1).normalized()
	var sun: Vector3=game.weather.state.sun_direction
	var aim=sun if scenario!="behind" else -sun
	if scenario!="riding":game.camera.look_at(game.camera.global_position+aim*100)
	if scenario=="edge":game.camera.rotate_object_local(Vector3.UP,deg_to_rad(25))
	if scenario=="cloudy":
		# Deterministic overcast ray through the shared cloud field, not an arbitrary
		# clear hole inside the cloudy preset. This affects this visual fixture only.
		game.weather.state.cloud_coverage=1.0
		var projected=Vector2(game.camera.global_position.x,game.camera.global_position.z)+Vector2(sun.x,sun.z)*maxf(game.world.cloud_lighting.height_m-game.camera.global_position.y,0)/maxf(sun.y,.035)
		game.weather.state.cloud_offset=projected-Vector2.ONE*(1.0/.003)
	game.world.update_weather(game.weather.state,0,false)
	if scenario=="opaque":
		blocker.global_position=game.camera.global_position+sun*18
		blocker.look_at(game.camera.global_position);blocker.show()
	game.hud.update_hud(game.sim,game.session,game.intent,"Automatic review",16.7,0,1.0/60,false,"SUN LENS FLARE")
	game._update_screen_effects(1.0/60)

func update_flare(on: bool,dt: float) -> void:
	game.sun_lens_flare.update_state(game.weather.state,on,true,false,game.graphics.level,dt,game.world.cloud_lighting.height_m,
		[game.camera.close_view,root.size,root.scaling_3d_scale,root.msaa_3d,game.graphics.level],game.camera.global_transform,game.camera.get_camera_projection())

func settle(on: bool,frames: int=36) -> void:
	for frame in frames:
		update_flare(on,1.0/60)
		await process_frame
	await RenderingServer.frame_post_draw

func capture_pair(view: String,scenario: String) -> void:
	prepare(view,scenario)
	var source=[game.sim.ticks,game.sim.position,game.sim.velocity,game.weather.state.sun_direction]
	await settle(false)
	var off=root.get_texture().get_image();off.save_webp(output+"/"+view+"_"+scenario+"_off.webp")
	await settle(true)
	if scenario=="riding":check(game.sun_lens_flare.enabled,"Course-readability view has a visible daytime sun")
	if not game.sun_lens_flare.status().unavailable.is_empty():
		check(false,game.sun_lens_flare.status().unavailable);return
	visibility_sample=PackedFloat32Array()
	if game.sun_lens_flare.enabled:
		game.sun_lens_flare.sample_visibility_for_review(func(values):visibility_sample=values)
		var deadline=Time.get_ticks_msec()+2000
		while visibility_sample.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
		check(visibility_sample.size()==2,"Rendered depth visibility sample delivered")
		if visibility_sample.size()==2:
			if scenario in ["terrain","opaque"]:check(visibility_sample[1]<.001,scenario+" blocks the rendered sun")
			if scenario in ["centre","edge","riding"]:check(visibility_sample[1]>.8,"Open rendered sun is visible")
			if scenario=="cloudy":check(visibility_sample[1]<.8,"Shared rendered cloud field attenuates the sun")
	var on=root.get_texture().get_image();on.save_webp(output+"/"+view+"_"+scenario+"_on.webp")
	var difference=0.0;var maximum=0.0;var count=0
	for y in range(4,on.get_height(),8):
		for x in range(4,on.get_width(),8):
			var a=on.get_pixel(x,y);var b=off.get_pixel(x,y)
			var delta=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			difference+=delta;maximum=maxf(maximum,delta);count+=1
	check(source==[game.sim.ticks,game.sim.position,game.sim.velocity,game.weather.state.sun_direction],"Flare never changes completed state")
	var status=game.sun_lens_flare.status()
	if game.sun_lens_flare.enabled:
		var expected=game.camera.unproject_position(game.camera.global_position+game.weather.state.sun_direction*1000)/root.get_visible_rect().size
		check(status.sun_uv.distance_to(expected)<.003,"Rendered depth sample matches the actual camera projection: "+str(expected)+" / "+str(status.sun_uv))
	if scenario in ["behind","night"]:check(not game.sun_lens_flare.enabled,"Offscreen/night removes compositor resolves")
	rows.append({"view":view,"case":scenario,"visibility":Array(visibility_sample),"mean_pixel_delta":difference/maxi(1,count),"max_pixel_delta":maximum,"status":status,"camera":str(game.camera.global_transform),"sun":str(game.weather.state.sun_direction),"weather_enabled":game.weather.state.enabled,"coverage":game.weather.state.cloud_coverage,"sun_energy":game.weather.state.sun_energy})
	print("FLARE_VIEW ",view," ",scenario," ",difference/maxi(1,count)," ",JSON.stringify(status))

func lifecycle() -> void:
	prepare("chase","centre")
	for gate in ["inactive","focus","transition","return","quitting","crash","loading","preview","menu","weather","tuning","survey","summit","finished","optional","reduced"]:
		match gate:
			"inactive":game.active=false
			"focus":game.application_focused=false
			"transition":game.transitioning=true
			"return":game.returning_to_summit=true
			"quitting":game.quitting=true
			"crash":game.sim.crashed=true
			"loading":game.loading.busy=true
			"preview":game.presentation_camera=game.camera_preview
			"menu":game.hud.menu.show()
			"weather":game.hud.weather_panel.show()
			"tuning":game.hud.tuning_panel.show()
			"survey":game.workshop.mode="navigation"
			"summit":game.summit_ready=true
			"finished":game.session.finished=true
			"optional":game.camera.effects_enabled=false
			"reduced":game.hud.feedback.reduced_motion=true
		game._update_screen_effects(1.0/60)
		check(not game.sun_lens_flare.enabled and not game.sun_lens_flare.access_resolved_color and not game.sun_lens_flare.access_resolved_depth,gate+" removes draw and resolve requests")
		game.transitioning=false;game.returning_to_summit=false;game.quitting=false;game.sim.crashed=false;game.loading.busy=false
		game.application_focused=true;game.presentation_camera=game.camera;game.hud.hide_menu();game.hud.weather_panel.hide();game.hud.tuning_panel.hide();game.workshop.mode="";game.summit_ready=false;game.session.finished=false;game.camera.effects_enabled=true;game.hud.feedback.reduced_motion=false;game.active=true
		game._update_screen_effects(1.0/60)
		check(game.sun_lens_flare.enabled,gate+" recovers on the riding camera")
	rows.append({"case":"lifecycle","gates":16})

func movement(view: String) -> void:
	prepare(view,"centre")
	var origin=game.camera.global_transform
	for frame in 120:
		game.camera.global_transform=origin
		game.camera.rotate_object_local(Vector3.UP,deg_to_rad(sin(frame/119.0*PI)*52))
		update_flare(true,1.0/60);await process_frame
		if frame in [0,20,40,60,80,100,119]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp(output+"/"+view+"_motion_%03d.webp" % frame)
	rows.append({"case":"movement","view":view,"frames":120,"seconds":2.0,"scope":"Chronological manual-look sweep; no simulation or FPS claim"})

func measure(on: bool) -> void:
	var warm_end=Time.get_ticks_usec()+2000000
	while Time.get_ticks_usec()<warm_end:update_flare(on,1.0/120);await process_frame
	var frames: Array=[];var gpu: Array=[];var cpu: Array=[];var lost=0
	var start=Time.get_ticks_usec();var previous=start;var before=game.sun_lens_flare.status().dispatches
	while Time.get_ticks_usec()-start<15000000:
		update_flare(on,1.0/120)
		await process_frame
		var now=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		if not root.has_focus() or root.mode==Window.MODE_MINIMIZED:lost+=1
	check(lost==0,"Capture-free timing stayed focused")
	check(frames.size()>120 and gpu.all(func(v):return is_finite(v) and v>0),"Complete valid render samples")
	check((game.sun_lens_flare.status().dispatches>before)==on,"Real GPU flare dispatch matches measured arm")
	check(game.sun_lens_flare.status().review_readbacks==0,"No visibility readbacks in measured process")
	check(root.size==window_pixels,"Requested timing resolution retained")
	rows.append({"on":on,"frame_ms":Costs.stats(frames),"gpu_ms":Costs.stats(gpu),"render_cpu_ms":Costs.stats(cpu),"fps":1000/Costs.stats(frames).mean,"focus_lost":lost,"samples":frames.size(),"flare":game.sun_lens_flare.status()})
	print("FLARE_TIMING ",JSON.stringify(rows.back()))
