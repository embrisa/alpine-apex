extends PhysicalBone3D
## Read-only contact capture. Fixed storage; never changes Jolt integration.
const CAPACITY = 4
var contact_count = 0
var contact_tick = -1
var collider_ids = PackedInt64Array([0,0,0,0])
var positions = PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
var normals = PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP])
var velocities = PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
var closing = PackedFloat32Array([0,0,0,0])
var impulses = PackedFloat32Array([0,0,0,0])
var previous_linear = Vector3.ZERO
var previous_angular = Vector3.ZERO
var has_previous = false
var report_us = 0
var report_max_us = 0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var report_started = Time.get_ticks_usec()
	contact_tick = Engine.get_physics_frames()
	contact_count = mini(CAPACITY,state.get_contact_count())
	for i in range(contact_count):
		collider_ids[i] = state.get_contact_collider_id(i)
		positions[i] = state.get_contact_local_position(i)
		normals[i] = state.get_contact_local_normal(i)
		var other = state.get_contact_collider_velocity_at_position(i)
		var relative = state.get_contact_local_velocity_at_position(i)-other
		velocities[i] = relative
		var incoming = previous_linear+previous_angular.cross(positions[i]-state.transform.origin)-other if has_previous else relative
		closing[i] = maxf(0.0,maxf(-incoming.dot(normals[i]),-relative.dot(normals[i])))
		impulses[i] = state.get_contact_impulse(i).length()
	previous_linear = state.linear_velocity
	previous_angular = state.angular_velocity
	has_previous = true
	report_us = Time.get_ticks_usec()-report_started
	report_max_us = maxi(report_max_us,report_us)

func clear_audio_contacts() -> void:
	contact_count = 0
	contact_tick = -1
	has_previous = false
