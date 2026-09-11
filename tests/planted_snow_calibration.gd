extends SceneTree
const Probe = preload("res://tests/planted_snow_probe.gd")
const Sim = preload("res://scripts/core/ski_simulation.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var old = load("res://artifacts/planted_snow/baseline/core/ski_simulation.gd")
	var field = Probe.SnowRipple.new(.30,32,.16)
	var fixture = {"kmh":160.0,"seconds":4.0,"input":"reversal","steer":1.0}
	var before = Probe.measure(old,field,fixture)
	print("CALIBRATION_BASE ",JSON.stringify(compact(before)))
	var rows: Array = []
	for spring in [.15,.4,.7]:
		for progression in [0.0,.5,2.0]:
			for rebound in [.5,1.0,1.5]:
				var overrides = {"snow_spring_ratio":spring,"snow_stop_progression":progression,"snow_rebound_damping_ratio":rebound}
				var row = Probe.measure(Sim,field,fixture,overrides)
				row.erase("samples"); row.overrides = overrides; rows.append(row)
				print("CALIBRATION ",JSON.stringify(overrides)," ",JSON.stringify(compact(row)))
	FileAccess.open("res://artifacts/planted_snow/calibration.json",FileAccess.WRITE).store_string(JSON.stringify({"before":before,"rows":rows},"\t"))
	quit()
func compact(row: Dictionary) -> Dictionary:
	return {"init":row.initiation_s,"reverse":row.reversal_s,"turn":row.turn_2s_deg,"air":row.airtime_s,"slip":row.mean_slip_rad}
