extends RefCounted
## One unilateral ski/terrain contact. World metres, seconds, radians and Newtons.
const TerrainMaterial = preload("res://scripts/core/terrain_material.gd")
const SnowResponse = preload("res://scripts/core/snow_contact_response.gd")
var snow_response = SnowResponse.new()
var crush = preload("res://scripts/core/snow_crush_contact.gd").new()
var crush_m: float:
	get: return crush.amount_m
var crush_rate_m_s: float:
	get: return crush.rate_m_s
var crush_vertical_m: float:
	get: return crush.vertical_m
var _compression_m = 0.0
var _normal_dissipated_j = 0.0
var _traction_utilization = 0.0
var compression_m: float:
	get: return _compression_m # normal metres, bounded by loose depth
var normal_dissipated_j: float:
	get: return _normal_dissipated_j # tick work estimate in joules, not cumulative
var traction_utilization: float:
	get: return _traction_utilization # actual lateral reaction / available ski grip
var _snow_power_per_kg = 0.0
var material_kind = TerrainMaterial.Kind.SNOW
var side: float
var position = Vector3.ZERO
var previous_position = Vector3.ZERO
var velocity = Vector3.ZERO
var normal = Vector3.UP
var forward = Vector3.BACK
var orientation = Basis.IDENTITY
var previous_orientation = Basis.IDENTITY
var heading = 0.0
var edge_angle = 0.0
var grounded = false
var load_n = 0.0
var normal_acceleration = 0.0
var grip_n = 0.0
var slip_angle = 0.0
var penetration = 0.0
var snow_depth = 0.0
var snow_drag = 0.0
var landing_speed = 0.0
var extension = 0.0
var height_reference = 0.0
var anchor = Vector3.ZERO
var gross_load = 0.0
var clearance_m = 0.0 # signed vertical reach; positive means leg extension
var normal_speed_ms = 0.0 # relative to the distributed support normal

func _init(side_value: float) -> void:
	side = side_value

func reset(origin: Vector3, yaw: float, half_stance: float) -> void:
	material_kind = TerrainMaterial.Kind.SNOW
	heading = yaw
	edge_angle = 0.0
	position = origin+Vector3(cos(yaw),0,-sin(yaw))*side*half_stance
	previous_position = position
	velocity = Vector3.ZERO
	normal = Vector3.UP
	forward = Vector3(sin(yaw),0,cos(yaw))
	orientation = Basis(Vector3.UP.cross(forward),Vector3.UP,forward)
	previous_orientation = orientation
	grounded = false
	load_n = 0.0
	normal_acceleration = 0.0
	grip_n = 0.0
	penetration = 0.0
	snow_drag = 0.0
	snow_depth = 0.0
	landing_speed = 0.0
	extension = 0.0
	clearance_m = 0.0
	normal_speed_ms = 0.0
	gross_load = 0.0
	clear_snow_response()

func clear_snow_response() -> void:
	crush.reset()
	_compression_m = 0.0
	_normal_dissipated_j = 0.0
	_traction_utilization = 0.0
	_snow_power_per_kg = 0.0

func probe(surface, root: Vector3, root_basis: Basis, speed: Vector3, gravity: Vector3, dt: float, half_stance: float, stiffness: float = 60.0, damping: float = 12.0, damping_limit: float = INF, tuning = null) -> void:
	anchor = root+root_basis.x*side*half_stance
	var previous_material = material_kind
	material_kind = TerrainMaterial.at(surface,anchor.x,anchor.z)
	if previous_material!=material_kind: clear_snow_response()
	if material_kind==TerrainMaterial.Kind.ROCK:
		snow_depth = 0.0
		penetration = 0.0
		snow_drag = 0.0
	var sample_value: Dictionary = crush.sample(surface,anchor.x,anchor.z)
	height_reference = float(sample_value.height)-(anchor.y-root.y)
	normal = sample_value.normal
	clearance_m = root.y-height_reference
	normal_speed_ms = speed.dot(normal)
	# A preloaded spring supports the resting rider at zero offset. Normal
	# compliance belongs to translation, not cosmetic snow penetration or IK.
	# The unilateral clamp removes tensile force during rebound.
	# Digressive damping settles small motion without kicking the root off a
	# fast ripple. Its reaction always opposes normal velocity; it adds no work.
	var damper = clampf(damping*normal_speed_ms,-maxf(0.0,damping_limit),maxf(0.0,damping_limit))
	gross_load = maxf(0.0,-gravity.dot(normal)-stiffness*clearance_m*normal.y-damper)
	_snow_power_per_kg = 0.0
	if material_kind==TerrainMaterial.Kind.SNOW and tuning!=null and surface.has_method("snow_depth_at"):
		snow_depth = clampf(surface.snow_depth_at(anchor.x,anchor.z),0.0,.35)
		snow_response.evaluate(clearance_m,normal.y,normal_speed_ms,gravity.dot(normal),snow_depth,stiffness,damping,damping_limit,tuning)
		gross_load = snow_response.reaction
		_compression_m = snow_response.compression_m
		_snow_power_per_kg = snow_response.dissipated_per_kg
	forward = Vector3(sin(heading),-(normal.x*sin(heading)+normal.z*cos(heading))/maxf(normal.y,.05),cos(heading)).normalized()

func finish(root: Vector3, root_basis: Basis, half_stance: float, dt: float, max_extension: float, mass: float, fraction: float, supported: bool) -> void:
	anchor = root+root_basis.x*side*half_stance
	extension = clampf(root.y-height_reference,-max_extension,max_extension) if supported else move_toward(extension,0.0,dt*2.0)
	grounded = supported
	position = Vector3(anchor.x,root.y+anchor.y-root.y-extension,anchor.z)
	if grounded:
		position.y = height_reference+(anchor.y-root.y)
	normal_acceleration = maxf(0.0,gross_load)*fraction if grounded else 0.0
	load_n = mass*normal_acceleration
	# finish() runs before and after translation. Both calls belong to one
	# tick; retain the full boot displacement, including steering at its start.
	velocity = (position-previous_position)/maxf(dt,.0001)
	var up = normal if grounded else root_basis.y
	var ahead = forward if grounded else root_basis.z
	orientation = Basis(up.cross(ahead).normalized(),up,ahead)*Basis(Vector3.BACK,-edge_angle)
	if not grounded:
		grip_n = 0.0
		penetration = 0.0
		snow_depth = 0.0
		snow_drag = 0.0
		_compression_m = 0.0
		_traction_utilization = 0.0

func complete_snow_work(dt: float, mass: float) -> void:
	# Called only at the start-of-tick force integration, never from finish().
	var share = normal_acceleration/maxf(gross_load,.000001) if grounded else 0.0
	_normal_dissipated_j = _snow_power_per_kg*mass*share*dt

func complete_traction(applied: float, capacity: float) -> void:
	_traction_utilization = clampf(applied/maxf(capacity,.000001),0.0,1.0) if grounded else 0.0
