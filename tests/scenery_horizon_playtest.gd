extends "res://tests/scenery_snow_playtest.gd"
## Actual production settings/materials. Captures are separate from timing.
var horizon_views: Array=[]
var selected_tier=2
var selected_quality=0
func select_horizon(quality: int,tier: int=2) -> void:
	var profile=game.graphics.duplicate()
	profile.backdrop_tier=tier; profile.offmap_shadow_quality=quality
	await game.world.wilderness.apply_quality(profile)
	selected_tier=tier; selected_quality=quality
	game.world.update_weather(game.weather.state,0.0,false)
	game.display_settings.reset_history()
	assert(game.world.wilderness.horizon.tier==tier)

func pair(label: String,qualities: Array=[0,1,2],tier: int=2) -> void:
	var camera=root.get_camera_3d(); var pose=camera.global_transform
	for quality in qualities:
		await select_horizon(quality,tier)
		await capture(label+"_q%d" % quality,12)
		assert(camera.global_transform==pose and root.get_camera_3d()==camera)
	horizon_views.append({"label":label,"pose":str(pose),"weather":game.weather.snapshot(),"geometry_tier":tier,"qualities":qualities,"atlas":game.world.wilderness.horizon.report()})
	print("HORIZON_REVIEW ",label)

func inspect_massif() -> void:
	OUTPUT="res://artifacts/scenery_mountain_shadows/final_review"
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game.active=false; game.summit_ready=false; game.set_process(false)
	game.hud.hide_menu(); game.hud.root.hide()
	game.weather.set_time_cycle(false); game.weather.set_automatic(false)
	var observer=Camera3D.new(); game.add_child(observer)
	observer.far=32000; observer.fov=75; observer.make_current()
	for condition in [["clear","day"],["clear","dusk"],["clear","night"],["cloudy","day"]]:
		game.weather.set_preset(condition[0]); game.weather.set_time_of_day(condition[1])
		var heading: float=field.faces[3].heading
		observer.position=field.spawn_point()+Vector3.UP*65
		observer.look_at(observer.position+Vector3(sin(heading)*10000,-1900,cos(heading)*10000))
		await pair("summit_%s_%s" % condition)
	game.weather.set_preset("clear"); game.weather.set_time_of_day("dusk")
	for position_xz in [Vector2(3450,0),Vector2(4050,500)]:
		var p: Vector2=position_xz
		observer.position=Vector3(p.x,game.world.wilderness.data.height_at(p)+3.0,p.y)
		observer.look_at(observer.position+Vector3(1200,-70,500))
		await pair("connector_%d" % p.x)
	game.camera.make_current(); place_on_face(0,2750,false); game._process(0.0)
	await pair("valley")
	observer.make_current()
	observer.position=field.spawn_point()+Vector3.UP*65
	observer.look_at(observer.position+Vector3(0,-1900,10000))
	for tier in [0,1,2]: await pair("geometry_%d" % tier,[0,2],tier)
	# Short chronological camera motion reveals grid/edge instability. The
	# paired skiing poses below are actual ordinary-input simulation, not timing.
	motion=true
	for quality in [0,2]:
		await select_horizon(quality)
		for frame in 16:
			var heading: float=field.faces[3].heading+lerpf(-.07,.07,float(frame)/15)
			observer.look_at(observer.position+Vector3(sin(heading)*10000,-1900,cos(heading)*10000))
			await capture("pan_q%d_%02d" % [quality,frame],2)
	if not review_trace.is_empty():
		game.weather.set_time_of_day("day")
		game.camera_settings.restore(review_trace.presentation.camera)
		game.camera.settings=game.camera_settings
		game.camera.effects_enabled=review_trace.presentation.camera_effects_enabled
		var origin=Vector2(review_trace.scenario_origin[0],review_trace.scenario_origin[1])
		for quality in [0,2]:
			await select_horizon(quality); game.camera.make_current()
			game.sim.reset(Vector3(origin.x,field.height_at(origin.x,origin.y),origin.y),review_trace.heading)
			game.sim.prime_contacts(field); game.previous_position=game.sim.position
			game.skier.reset_animation(game.sim); game.camera.close_view=false; game.camera.reset()
			for frame in 24:
				for tick in 60:
					var input=preload("res://tests/performance_input.gd").decode(review_trace.commands[game.sim.ticks/int(review_trace.command_ticks)])
					game.sim.step(1.0/120.0,input,game.world.ski_surface)
				game.previous_position=game.sim.position; game._process(.5)
				await capture("ski_q%d_%02d" % [quality,frame],2)
			assert(game.sim.crash_reason.is_empty())
	motion=false
	await select_horizon(0)
	preload("res://tests/test_report.gd").write(OUTPUT+"/report.json",JSON.stringify({"views":horizon_views,"pixels":str(actual_pixels),"captured_sequences":"16 camera frames and 24 ordinary-input skiing poses per Off/High arm; not real-time playback or controller acceptance","timed":false,"unranked":not game.session.eligible},"\t"))
	observer.queue_free()
