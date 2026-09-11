extends "res://tests/massif_playtest.gd"
## Camera motion/readback is visual evidence, never timing evidence.
const CLIP_FRAMES = 24
func inspect_massif() -> void:
	motion = true
	game.active = false; game.summit_ready = false
	game.hud.hide_menu(); game.hud.root.hide()
	var observer = Camera3D.new()
	game.add_child(observer); observer.far = 32000; observer.fov = 75
	observer.make_current()
	var fixture = preload("res://tests/offmap_fixture.gd").new()
	fixture.build(game.world)
	var clips: Array = []
	var tours: Array = []
	for face in 6: tours.append({"name":"summit_face_%d" % face,"face":face,"summit":true,"weather":"clear","time":"day","quality":2})
	for condition in [["clear","day"],["clear","dusk"],["snowfall","day"]]:
		for close in [false,true]:
			tours.append({"name":"%s_%s_%s" % [condition[0],condition[1],"pov" if close else "chase"],"face":0,"summit":false,"close":close,"weather":condition[0],"time":condition[1],"quality":2})
	tours.append({"name":"summit_night","face":0,"summit":true,"weather":"clear","time":"night","quality":2})
	for level in 3: tours.append({"name":"summit_quality_%d" % level,"face":0,"summit":true,"weather":"clear","time":"day","quality":level})
	for tour in tours:
		game.set_graphics_quality(tour.quality)
		fixture.panorama.apply_quality(game.world.quality)
		Engine.max_fps = 30
		game.weather.set_preset(tour.weather); game.weather.set_time_of_day(tour.time)
		for baseline in [true,false]:
			fixture.select(game.world,baseline)
			var label: String = tour.name+"_"+("baseline" if baseline else "upgraded")
			for frame in CLIP_FRAMES:
				if tour.summit:
					observer.make_current()
					var heading: float = field.faces[tour.face].heading+lerpf(-.20,.20,float(frame)/(CLIP_FRAMES-1))
					observer.position = field.spawn_point()+Vector3.UP*65
					observer.look_at(observer.position+Vector3(sin(heading)*10000,-1900,cos(heading)*10000))
				else:
					game.camera.make_current()
					place_on_face(tour.face,1250+frame*3,tour.close)
				await capture(label+"_%03d" % frame,2)
			clips.append(label)
			print("OFFMAP_MOTION ",label)
	fixture.select(game.world,false); fixture.dispose()
	FileAccess.open(OUTPUT+"/motion.json",FileAccess.WRITE).store_string(JSON.stringify({"clips":clips,"frames_per_clip":CLIP_FRAMES,"actual_pixels":[actual_pixels.x,actual_pixels.y],"unranked":true,"capture_overhead":true,"geometry":game.world.wilderness.report()},"\t"))
