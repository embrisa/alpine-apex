extends RefCounted
## Session/authoring rules only. Never changes the contact surface or ski forces.
const RULES_VERSION = 1
const RETURN_RADIUS_M = 2850.0
const WARNING_DISTANCE_M = 150.0
const ENDPOINT_MARGIN_M = 25.0
var enabled: bool = false
var center = Vector2.ZERO
var radius_m: float = RETURN_RADIUS_M

func _init(field = null) -> void:
	if field == null: return
	enabled = field.GENERATOR_ID == "alpine-drainage" and field.is_summit_mountain()
	if enabled:
		var summit: Vector3 = field.spawn_point()
		center = Vector2(summit.x,summit.z)

func distance_to_boundary(position: Vector3) -> float:
	return radius_m-(Vector2(position.x,position.z)-center).length() if enabled else INF

func contains(position: Vector3, margin_m: float = 0.0) -> bool:
	return position.is_finite() and (not enabled or distance_to_boundary(position)>margin_m)

func swept_exit_fraction(before: Vector3, after: Vector3) -> float:
	if not enabled: return -1.0
	if not before.is_finite() or not after.is_finite(): return 0.0
	if not contains(before): return 0.0
	if contains(after): return -1.0 # A disk is convex, including high-speed chords.
	var a = Vector2(before.x,before.z)-center
	var d = Vector2(after.x-before.x,after.z-before.z)
	var length_squared = d.length_squared()
	if length_squared<0.00000001: return 0.0
	var projection = a.dot(d)
	var discriminant = projection*projection-length_squared*(a.length_squared()-radius_m*radius_m)
	return clampf((-projection+sqrt(maxf(0.0,discriminant)))/length_squared,0.0,1.0)

func endpoint_error(position: Vector3) -> String:
	# Equality is allowed for the authoring margin; the return boundary is not.
	if enabled and (not position.is_finite() or distance_to_boundary(position)<ENDPOINT_MARGIN_M):
		return "Place race endpoints at least 25 m inside the summit-return boundary."
	return ""
