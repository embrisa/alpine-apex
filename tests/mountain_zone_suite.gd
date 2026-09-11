extends SceneTree
const Zone = preload("res://scripts/world/mountain_zone.gd")
var checks = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func _initialize() -> void:
	var zone = Zone.new()
	zone.enabled = true
	for i in 16:
		var direction = Vector3(cos(TAU*i/16.0),0,sin(TAU*i/16.0))
		var before = direction*2800+Vector3.UP*12000
		var after = direction*3000+Vector3.DOWN*4000
		check(absf(zone.swept_exit_fraction(before,after)-0.25)<0.00001,"Altitude-independent swept exit in bearing %d" % i)
	check(zone.contains(Vector3.ZERO) and not zone.contains(Vector3(2850,0,0)),"Summit is inside; the exact line is outside")
	check(zone.swept_exit_fraction(Vector3(2840,0,0),Vector3(2850,0,0))==1.0,"Arrival exactly on the line returns at tick end")
	check(zone.swept_exit_fraction(Vector3(2800,0,0),Vector3(-2800,0,0))<0,"A fast chord within the zone does not trigger")
	check(zone.swept_exit_fraction(Vector3.ZERO,Vector3(2850000,0,0))>0,"High speed cannot tunnel through the boundary")
	check(zone.swept_exit_fraction(Vector3(2900,0,0),Vector3(2800,0,0))==0,"An already-outside rider is recovered immediately")
	check(zone.swept_exit_fraction(Vector3(0,0,2800),Vector3(0,9000,2800))<0,"Vertical flight alone does not trigger a return")
	check(zone.endpoint_error(Vector3(2825,0,0)).is_empty() and not zone.endpoint_error(Vector3(2826,0,0)).is_empty(),"Endpoints keep the 25 m margin including the complete 12 m finish radius")
	check(not zone.contains(Vector3(NAN,0,0)),"Invalid coordinates cannot enter the zone")
	zone.center = Vector2(40,-60)
	check(zone.distance_to_boundary(Vector3(40,200,-60))==2850,"Zone geometry uses the summit center")
	zone.enabled = false
	check(zone.contains(Vector3(99999,0,0)) and zone.swept_exit_fraction(Vector3.ZERO,Vector3(99999,0,0))<0,"Non-summit fixtures retain their existing rules")
	print("MOUNTAIN_ZONE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
