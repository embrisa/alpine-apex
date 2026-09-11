extends "res://tests/massif_playtest.gd"
## Matched v2/v3 views in one v15 world. Readback is never timing evidence.
const Fixture = preload("res://tests/offmap_v2_fixture.gd")
var comparison_pairs: Array = []

func inspect_massif() -> void:
	game.active=false; game.summit_ready=false
	game.set_process(false) # Main otherwise reclaims the riding camera each frame.
	game.hud.hide_menu(); game.hud.root.hide()
	game.weather.set_time_cycle(false)
	var observer = Camera3D.new(); game.add_child(observer)
	observer.far=32000; observer.fov=75; observer.make_current()
	var fixture = Fixture.new(); await fixture.build(game.world)
	var quick = "--quick-review" in OS.get_cmdline_user_args()
	var clips = "--clips" in OS.get_cmdline_user_args()
	var conditions = [["clear","day"]] if quick else [["clear","day"],["clear","dusk"],["snowfall","day"],["clear","night"]]
	for condition in conditions:
		game.weather.set_preset(condition[0]); game.weather.set_time_of_day(condition[1])
		for face in ([0,3] if quick else range(6)):
			var heading: float = field.faces[face].heading
			observer.make_current()
			observer.position=field.spawn_point()+Vector3.UP*65
			observer.look_at(observer.position+Vector3(sin(heading)*10000,-1900,cos(heading)*10000))
			await pair(fixture,"summit_%s_%s_%d" % [condition[0],condition[1],face])
		for face in ([0] if quick else [0,3]):
			for distance_m in ([2750] if quick else [1250,2750]):
				for close in [false,true]:
					game.camera.make_current(); place_on_face(face,distance_m,close)
					await pair(fixture,"ride_%s_%s_%d_%d_%s" % [condition[0],condition[1],face,distance_m,"pov" if close else "chase"])
		if not quick:
			for bearing in [Vector2.RIGHT,Vector2.DOWN]:
				var p=bearing*3048.0
				observer.make_current()
				observer.position=Vector3(p.x,field.sample(p.x,p.y).height+1.8,p.y)
				observer.look_at(observer.position+Vector3(bearing.x*1000,-80,bearing.y*1000))
				await pair(fixture,"boundary_%s_%s_%s" % [condition[0],condition[1],"east" if bearing==Vector2.RIGHT else "south"])
	if not quick:
		game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
		observer.make_current(); observer.position=field.spawn_point()+Vector3.UP*65
		observer.look_at(observer.position+Vector3(0,-1900,10000))
		for level in 3:
			game.set_graphics_quality(level); await fixture.panorama.apply_quality(game.world.quality)
			await pair(fixture,"quality_%d" % level)
		game.set_graphics_quality(2); await fixture.panorama.apply_quality(game.world.quality)
	if clips:
		motion=true
		for tour in [0,3]:
			for baseline in [true,false]:
				fixture.select(game.world,baseline)
				observer.make_current()
				for frame in 24:
					var heading: float = field.faces[tour].heading+lerpf(-.18,.18,float(frame)/23)
					observer.position=field.spawn_point()+Vector3.UP*65
					observer.look_at(observer.position+Vector3(sin(heading)*10000,-1900,cos(heading)*10000))
					game.world.update_weather(game.weather.state,0.0,false)
					await capture("pan_%d_%s_%03d" % [tour,"before" if baseline else "after",frame],2)
		for baseline in [true,false]:
			fixture.select(game.world,baseline); game.camera.make_current()
			for frame in 24:
				place_on_face(0,2650+frame*3,false)
				game._process(0.0)
				await capture("ride_motion_%s_%03d" % ["before" if baseline else "after",frame],2)
		motion=false
	fixture.select(game.world,false); fixture.dispose()
	FileAccess.open(OUTPUT+"/offmap_v3.json",FileAccess.WRITE).store_string(JSON.stringify({"version":field.GENERATOR_VERSION,"seed":field.seed_value,"pairs":comparison_pairs,"clips":clips,"actual_pixels":[actual_pixels.x,actual_pixels.y],"display":game.display_settings.report(root,actual_pixels),"geometry":game.world.wilderness.report(),"unranked":true,"capture_overhead":true},"\t"))
	observer.queue_free()

func pair(fixture, label: String) -> void:
	var selected = root.get_camera_3d()
	# Refresh pose, riding-camera placement and weather once, then restore the
	# explicitly selected survey camera. Main stays paused for matched readback.
	game._process(0.0)
	selected.make_current()
	game.world.update_weather(game.weather.state,0.0,false)
	for i in 30: await process_frame
	for baseline in [true,false]:
		fixture.select(game.world,baseline)
		await capture(label+("_before" if baseline else "_after"),12)
		assert(root.get_camera_3d()==selected,"Comparison camera was replaced")
	comparison_pairs.append(label)
	print("OFFMAP_PAIR ",label)

func place_on_face(index: int,z: float,close: bool = false) -> void:
	super.place_on_face(index,z,close)
	# Exercise the real riding lens at a representative descent speed. This is
	# a paused presentation fixture, not a claim of simulated movement.
	var forward=Vector3(sin(field.faces[index].heading),0,cos(field.faces[index].heading))
	game.sim.velocity=forward.slide(field.sample(game.sim.position.x,game.sim.position.z).normal).normalized()*22.0
