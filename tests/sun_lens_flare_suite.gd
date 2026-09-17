extends SceneTree
const Flare=preload("res://scripts/presentation/sun_lens_flare.gd")
const Weather=preload("res://scripts/presentation/weather_state.gd")
var checks=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
	var direction=Vector3(0,.4,-.9).normalized()
	check(Flare.requested_strength(true,true,false,2,1.25,direction)==1,"High daytime strength")
	check(Flare.requested_strength(true,true,false,1,1.25,direction)<1,"Balanced is restrained")
	for row in [[false,true,false,2,1.25,direction],[true,false,false,2,1.25,direction],[true,true,true,2,1.25,direction],[true,true,false,0,1.25,direction],[true,true,false,2,0.0,direction],[true,true,false,2,1.25,-direction],[true,true,false,2,NAN,direction]]:
		check(Flare.requested_strength(row[0],row[1],row[2],row[3],row[4],row[5])==0,"Inactive/optional/reduced/low/night/below-horizon/nonfinite gate")
	var projection=Projection.create_perspective(70,16.0/9,.15,32000)
	var camera=Transform3D(Basis.looking_at(direction),Vector3(12,500,20))
	var centre=Flare.project_sun(camera,projection,direction)
	check(centre.uv.distance_to(Vector2.ONE*.5)<.00001 and centre.strength>.99,"Sun projection follows live camera")
	check(Flare.project_sun(camera,projection,-direction).strength==0,"Behind sun hidden")
	check(Flare.project_sun(camera,projection,Vector3.RIGHT).strength==0,"Offscreen sun hidden")
	var device_projection=projection;device_projection.y.y=-device_projection.y.y
	var above=Vector3(0,.2,-1).normalized()
	var ordinary=Flare.project_sun(Transform3D.IDENTITY,projection,above)
	var corrected=Flare.project_sun(Transform3D.IDENTITY,device_projection,above)
	check(ordinary.uv.y<.5 and ordinary.uv.is_equal_approx(corrected.uv),"Camera and device projections agree above the centre")
	var edge=Flare.project_sun(Transform3D.IDENTITY,projection,Vector3(.98*tan(deg_to_rad(35))*16/9,0,-1).normalized())
	check(edge.strength<.1,"Viewport edge fades")
	for uv in [Vector2(.5,.5),Vector2(.05,.05),Vector2(.95,.95),Vector2(.05,.95)]:
		var bounds=Flare.draw_bounds(uv,Vector2i(2880,1620))
		check(bounds.position.x>=0 and bounds.position.y>=0 and bounds.end.x<=2880 and bounds.end.y<=1620,"Drawing stays within target")
		check(bounds.size.x*bounds.size.y<2880*1620*.7,"Flare never requires a full-screen draw")
	var weather=Weather.new();weather.sun_direction=direction;weather.sun_color=Color(1,.9,.8);weather.sun_energy=1.25
	var before=[weather.sun_direction,weather.sun_color,weather.sun_energy,weather.cloud_offset,weather.cloud_coverage]
	var flare=Flare.new()
	flare.update_state(weather,true,true,false,2,1.0/60,2400,[],camera,projection)
	check(before==[weather.sun_direction,weather.sun_color,weather.sun_energy,weather.cloud_offset,weather.cloud_coverage],"Weather snapshot remains unchanged")
	if DisplayServer.get_name()=="headless":check(not flare.enabled and not flare.access_resolved_color and not flare.access_resolved_depth,"Headless requests no rendering resources")
	flare.suspend();check(not flare.enabled and not flare.access_resolved_color and not flare.access_resolved_depth,"Suspend removes resolve requests")
	var report={"checks":checks,"failures":failures}
	preload("res://tests/test_report.gd").write("res://artifacts/sun_lens_flare/automated.json",JSON.stringify(report,"\t"))
	print("SUN_LENS_FLARE_SUITE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
