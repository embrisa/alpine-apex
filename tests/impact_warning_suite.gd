extends SceneTree
const Warning = preload("res://scripts/presentation/impact_warning.gd")
var checks = 0
var failures: Array = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); printerr("FAIL: ",label)

func _initialize() -> void:
	var warning = Warning.new()
	for reserve in [1.0,0.85,0.7]:
		warning.update(reserve,1.0)
		check(warning.strength==0.0,"No warning at or above 70 percent")
	var previous = 0.0
	for reserve in [0.69,0.6,0.5,0.3,0.1,0.0]:
		warning.reset()
		warning.update(reserve,3.0)
		check(warning.strength>previous,"Lower reserve increases warning strength")
		previous = warning.strength
	check(warning.strength<=1.0,"Maximum danger remains bounded")
	var reference: Array = []
	for fps in [30,60,120]:
		warning.reset()
		for i in fps: warning.update(0.1,1.0/fps)
		var attack = Vector3(warning.strength,warning.phase,warning.pulse)
		for i in fps: warning.update(0.7,1.0/fps)
		var release = Vector3(warning.strength,warning.phase,warning.pulse)
		if reference.is_empty(): reference = [attack,release]
		check(attack.distance_to(reference[0])<0.00001,"Attack and pulse phase agree at %d FPS"%fps)
		check(release.distance_to(reference[1])<0.00001,"Recovery and pulse phase agree at %d FPS"%fps)
	warning.reset()
	warning.update(0.0,0.45)
	check(absf(warning.strength-(1.0-exp(-1.0)))<0.000001,"Gradual attack reaches 63 percent after 450 ms")
	var peak: float = warning.strength
	warning.update(0.7,1.0)
	check(absf(warning.strength-peak*exp(-1.0))<0.000001,"Gentle recovery retains 37 percent after one second")
	var bounded = true
	for i in 1200:
		warning.update(0.0,1.0/120.0)
		bounded = bounded and warning.pulse>=0.3-0.000001 and warning.pulse<=1.0
	check(bounded,"Pulse never blacks out or exceeds its cap over ten seconds")
	warning.update(0.1,0.25,false)
	check(warning.strength>0.0 and warning.pulse==0.65 and warning.phase==0.0,"Comfort retains a steady warning")
	warning.update(0.7,10.0)
	check(warning.strength==0.0 and warning.phase==0.0,"Recovery fully clears the effect")
	for reserve in [-1.0,2.0,NAN]:
		warning.update(reserve,1.0)
		check(is_finite(warning.strength) and warning.strength>=0.0 and warning.strength<=1.0,"Invalid or outlying input stays bounded")
	warning.update(0.0,1.0)
	warning.reset()
	check(warning.strength==0.0 and warning.phase==0.0,"Lifecycle reset removes all transient state")
	var report = {"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://artifacts/impact_warning")
	FileAccess.open("res://artifacts/impact_warning/unit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("IMPACT_WARNING_RESULTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
