extends RefCounted
## One-way canopy response, radians/seconds. Does not apply forces to the skier.
## Each branch cluster is a damped angular spring, integrated at exactly 120 Hz.
const DT = 1.0/120.0
const COUNT = 12
const MAX_ANGLE = .32
var angles = PackedVector3Array()
var velocities = PackedVector3Array()
var touching = PackedByteArray()
var branches: Array = []
var impacts = 0

func _init(definitions: Array = []) -> void:
	branches = definitions
	angles.resize(COUNT)
	velocities.resize(COUNT)
	touching.resize(COUNT)

func impulse(index: int, value: Vector3) -> void:
	velocities[index] = (velocities[index]+value).limit_length(5.0)
	impacts += 1

func step(from: Vector3, to: Vector3, velocity: Vector3, actor_radius: float = .55) -> void:
	for i in COUNT:
		var force = Vector3.ZERO
		if i<branches.size():
			var b: Dictionary = branches[i]
			var c = Vector3(b.center[0],b.center[1],b.center[2])
			var segment = to-from
			var t = clampf((c-from).dot(segment)/maxf(segment.length_squared(),.000001),0,1)
			var separation = from+segment*t-c
			var reach = minf(float(b.radius),1.8)+actor_radius*.7
			var contact = separation.length()<reach
			if contact:
				var direction = (velocity.normalized()*.7-separation.normalized()*.3).normalized()
				var lever = c-Vector3(0,b.pivot_y,0)
				var torque = lever.cross(direction)
				var axis = torque.normalized()
				if touching[i]==0 and velocity.length()>.1:
					impulse(i,axis*clampf(velocity.length()*.085,.15,3.0))
				force = axis*(1.0-separation.length()/reach)*7.0
			touching[i] = int(contact)
		var stiffness = 46.0+float(i/4)*9.0
		velocities[i] += (force-angles[i]*stiffness-velocities[i]*5.4)*DT
		angles[i] += velocities[i]*DT
		if angles[i].length()>MAX_ANGLE:
			angles[i] = angles[i].limit_length(MAX_ANGLE)
			# A passive stop removes outward energy rather than reversing it.
			var normal = angles[i].normalized()
			velocities[i] -= normal*maxf(0.0,velocities[i].dot(normal))

func energy() -> float:
	var result = 0.0
	for i in COUNT:
		result += .5*(velocities[i].length_squared()+(46.0+float(i/4)*9.0)*angles[i].length_squared())
	return result
