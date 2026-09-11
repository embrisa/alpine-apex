extends "res://tests/massif_playtest.gd"
## Close scenery inspection from a standing eye height, within the return zone.
## Sampled camera travel with readback overhead; never performance evidence.
const Fixture = preload("res://tests/offmap_v2_fixture.gd")
func inspect_massif() -> void:
	game.active=false; game.summit_ready=false; game.set_process(false)
	game.hud.hide_menu(); game.hud.root.hide()
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.weather.set_time_cycle(false)
	game.world.update_weather(game.weather.state,0.0,false)
	var observer=Camera3D.new(); game.add_child(observer)
	observer.far=32000; observer.fov=75; observer.make_current()
	var fixture=Fixture.new(); await fixture.build(game.world)
	motion=true
	for baseline in [true,false]:
		fixture.select(game.world,baseline)
		for frame in 24:
			var fraction=float(frame)/23.0
			var direction=Vector2.RIGHT.rotated(lerpf(-.04,.04,fraction))
			var p=direction*lerpf(2670.0,2835.0,fraction)
			observer.position=Vector3(p.x,field.sample(p.x,p.y).height+1.8,p.y)
			observer.look_at(observer.position+Vector3(direction.x*1000,0,direction.y*1000))
			await capture("boundary_motion_%s_%03d" % ["before" if baseline else "after",frame],4)
	motion=false
	fixture.select(game.world,false); fixture.dispose()
	var report={"frames":48,"version":15,"seed":field.seed_value,"camera_height_m":1.8,"radii_m":[2670,2835],"capture_overhead":true,"unranked":true,"geometry":game.world.wilderness.report()}
	report.script_sha256=FileAccess.get_sha256("res://tests/offmap_boundary_motion.gd")
	FileAccess.open(OUTPUT+"/boundary_motion.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	observer.queue_free()
