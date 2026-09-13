extends "res://scripts/core/ski_simulation.gd"
## Ordinary solver with explicit diagnostic immunity; collision impulses still win.
const Policy = preload("res://scripts/diagnostics/case_policy.gd")
class DiagnosticImpacts extends "res://scripts/core/impact_recovery.gd":
	var policy
	var prevented_damage = 0.0
	func reset() -> void:
		super.reset(); prevented_damage = 0.0
	func _apply_damage(damage: float, speed: float, reason: String, values) -> bool:
		var before = reserve
		var exhausted = super._apply_damage(damage,speed,reason,values)
		if policy and policy.values.immortal:
			prevented_damage += maxf(0,before-reserve); reserve = 1.0; return false
		return exhausted
	func abrade(dt: float, rate: float) -> bool:
		var before = reserve
		var exhausted = super.abrade(dt,rate)
		if policy and policy.values.immortal:
			prevented_damage += maxf(0,before-reserve); reserve = 1.0; return false
		return exhausted

var policy = Policy.new()
var prevented_crashes: Array = []
var boundary_collision = false

func _init(values: SkiTuning = null) -> void:
	super(values)
	impacts = DiagnosticImpacts.new(); impacts.policy = policy

func _resolve_obstacle(surface, from: Vector3) -> void:
	boundary_collision = surface.sweep_obstacle_contact(from,position).get("boundary",false)
	super._resolve_obstacle(surface,from)
	boundary_collision = false

func crash(reason: String) -> void:
	if policy.values.immortal and not boundary_collision:
		prevented_crashes.append({"tick":ticks,"reason":reason}); return
	super.crash(reason)
