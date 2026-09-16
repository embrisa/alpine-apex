extends "res://tests/massif_playtest.gd"
## Rendered acceptance only. Captures/readback are excluded from timed descents.

func inspect_massif() -> void:
	game.active = false
	game.summit_ready = false
	game.hud.hide_menu()
	game.hud.root.hide()
	var observer = Camera3D.new()
	game.add_child(observer)
	observer.far = 32000
	observer.fov = 75
	var quick = "--quick-review" in OS.get_cmdline_user_args()
	for condition in ([["clear","day"]] if quick else [["clear","day"],["clear","dusk"],["snowfall","day"]]):
		game.weather.set_preset(condition[0])
		game.weather.set_time_of_day(condition[1])
		observer.make_current()
		for index in ([0,3] if quick else range(6)):
			var heading: float = field.faces[index].heading
			var forward = Vector3(sin(heading),0,cos(heading))
			observer.position = field.spawn_point()+Vector3.UP*65
			observer.look_at(observer.position+forward*10000-Vector3.UP*1900)
			await capture("summit_%s_%s_%d" % [condition[0],condition[1],index])
		game.camera.make_current()
		for z in ([2700] if quick else [600,1250,2700]):
			for close in [false,true]:
				place_on_face(0,z,close)
				await capture("descent_%s_%s_%d_%s" % [condition[0],condition[1],z,"pov" if close else "chase"])
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("night")
	observer.make_current()
	observer.position = field.spawn_point()+Vector3.UP*65
	observer.look_at(observer.position+Vector3(0,-1900,10000))
	await capture("summit_night")
	game.weather.set_time_of_day("day")
	for level in [0,1,2]:
		game.set_graphics_quality(level)
		await capture("summit_quality_%d" % level)
	# A same-camera pair makes the added scenery directly reviewable.
	game.world.wilderness.visible = false
	await capture("summit_backdrop_off")
	game.world.wilderness.visible = true
	await capture("summit_backdrop_on")
	observer.queue_free()
	game.camera.make_current()
	game.hud.root.show()
	game.start_run(false)
	game.summit_ready = false
	place_on_face(0,2750)
	game.active = true
	await capture("return_approach")
	game._begin_summit_return(false)
	await create_timer(0.18).timeout
	await capture("return_fade",0)
	await create_timer(0.35).timeout
	await capture("return_summit")
	game.workshop.open_library()
	game.workshop.survey_height = 4500
	game.workshop.focus_point = Vector3.ZERO
	game.workshop._update_survey()
	await capture("race_zone")
	preload("res://tests/test_report.gd").write(OUTPUT+"/wilderness.json",JSON.stringify({"backdrop":game.world.wilderness.report(),"captures":inspection_captures,"actual_pixels":[actual_pixels.x,actual_pixels.y],"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"unranked":true},"\t"))
