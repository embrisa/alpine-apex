extends SceneTree
## Stratified open/woodland and elevation coverage on the actual cached field.
const Definition = preload("res://scripts/world/mountain_definition.gd")
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ",message)
func run() -> void:
	var field = Definition.generate(849205174,15)
	var rows: Array = []
	for face in field.faces:
		for band in 3:
			var count = 0; var thick = 0; var relief = 0; var open_count = 0; var open_thick = 0
			var depth_sum = 0.0; var max_relief = 0.0
			for z in range(400+band*650,1050+band*650,40):
				for fraction in range(-10,11):
					var q = Vector2(fraction*.04*z,z)
					var p: Vector2 = face.to_world(q)
					if field.rock_fraction_at(p.x,p.y)>=.5: continue
					count += 1
					var depth: float = field.snow_depth_at(p.x,p.y); depth_sum += depth
					if depth>=.16: thick += 1
					var open = field.nearby_obstacle_indices(Vector3(p.x,0,p.y),12).is_empty()
					if open:
						open_count += 1
						if depth>=.16: open_thick += 1
					var w: float = face.snow_relief_weight(q.x,q.y)
					var h: float = absf(face.snow_relief_at(q.x,q.y)*w)
					max_relief = maxf(max_relief,h)
					if h>.025: relief += 1
			var row = {"face":face.index,"band":band,"snow_samples":count,"thick_fraction":float(thick)/maxi(count,1),"relief_fraction":float(relief)/maxi(count,1),"open_samples":open_count,"open_thick_fraction":float(open_thick)/maxi(open_count,1),"mean_depth_m":depth_sum/maxi(count,1),"max_relief_m":max_relief}
			rows.append(row)
			check(count>50 and row.thick_fraction>=.85,"Most snow is thick on every face/elevation band: "+str(row))
			check(open_count==0 or row.open_thick_fraction>=.85,"Open snow has the same thick cover: "+str(row))
			check(row.relief_fraction>=.55,"Small physical features cover most snowy terrain: "+str(row))
	preload("res://tests/test_report.gd").write("res://artifacts/snow_control_fix/coverage.json",JSON.stringify({"revision":field.SNOW_REVISION,"height_sha256":field.height_checksum,"rows":rows,"failures":failures},"\t"))
	print("SNOW_COVERAGE rows=",rows.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
