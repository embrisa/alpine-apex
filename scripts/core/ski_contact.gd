extends RefCounted
## One unilateral ski/snow contact. World metres, seconds, radians and Newtons.
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

func _init(side_value: float) -> void:
	side = side_value

func reset(origin: Vector3, yaw: float, half_stance: float) -> void:
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

func probe(surface, root: Vector3, root_basis: Basis, speed: Vector3, gravity: Vector3, dt: float, half_stance: float) -> void:
	anchor = root+root_basis.x*side*half_stance
	var sample_value: Dictionary = surface.sample(anchor.x,anchor.z)
	height_reference = float(sample_value.height)-(anchor.y-root.y)
	normal = surface.contact_normal(anchor.x,anchor.z) if surface.has_method("contact_normal") else sample_value.normal
	var ahead = anchor+speed*dt
	var next_normal: Vector3 = surface.contact_normal(ahead.x,ahead.z) if surface.has_method("contact_normal") else surface.sample(ahead.x,ahead.z).normal
	gross_load = -speed.dot(next_normal-normal)/maxf(dt,.0001)-gravity.dot(normal)
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
