extends Node3D
## A bounded allocation: 600 snow + 900 rain + two 100-particle drifts.
## Local precipitation volumes translate with the camera but never rotate.
const HIGH_VOLUME_COUNTS = [600,900]
var volumes: Array[GPUParticles3D] = []
var drifts: Array[GPUParticles3D] = []
var quality: int = -1
var budget_scale: float = 1.0
var previous_camera = Vector3.ZERO
var previous_close: bool = false
var initialized: bool = false
var camera_velocity = Vector3.ZERO
var stretch: float = 0.0
var reset_count: int = 0
var lighting = preload("res://scripts/presentation/cloud_lighting.gd").new()

func _ready() -> void:
	for kind in [0,1]:
		var particle = GPUParticles3D.new()
		particle.amount = HIGH_VOLUME_COUNTS[kind]
		particle.lifetime = 8.0
		particle.explosiveness = 1.0
		particle.preprocess = 0.0
		particle.fixed_fps = 0
		particle.local_coords = true
		particle.visibility_aabb = AABB(Vector3(-16,-11,-23),Vector3(32,22,46))
		var process = ShaderMaterial.new()
		process.shader = preload("res://assets/weather_particles.gdshader")
		particle.process_material = process
		_prepare_draw(particle,kind)
		add_child(particle)
		volumes.append(particle)
	for side in [-1,1]:
		var particle = GPUParticles3D.new()
		particle.amount = 100
		particle.lifetime = 1.2
		particle.fixed_fps = 30
		particle.local_coords = false
		particle.visibility_aabb = AABB(Vector3(-20,-12,-20),Vector3(40,24,40))
		var process = ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(3,0.12,4)
		process.spread = 12.0
		process.gravity = Vector3(0,-0.6,0)
		process.initial_velocity_min = 3.0
		process.initial_velocity_max = 7.0
		_prepare_draw(particle,2)
		particle.process_material = process
		add_child(particle)
		drifts.append(particle)

func _prepare_draw(particle: GPUParticles3D, kind: int) -> void:
	var quad = QuadMesh.new()
	quad.size = Vector2.ONE
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/weather_particle_draw.gdshader")
	material.set_shader_parameter("kind",kind)
	lighting.register(material)
	quad.material = material
	particle.draw_pass_1 = quad
	particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particle.emitting = false
	particle.visible = false

func reset() -> void:
	initialized = false
	camera_velocity = Vector3.ZERO
	stretch = 0.0
	reset_count += 1
	for particle in volumes + drifts:
		particle.restart()

func set_budget_scale(value: float) -> void:
	if is_equal_approx(budget_scale,value): return
	budget_scale = clampf(value,.25,1.5)
	var previous = quality
	quality = -1
	set_quality(previous)

func set_quality(value: int) -> void:
	if quality == value:
		return
	quality = value
	for i in range(volumes.size()):
		volumes[i].amount = maxi(1,roundi((HIGH_VOLUME_COUNTS[i] if quality==2 else HIGH_VOLUME_COUNTS[i]/2)*budget_scale))
	for particle in drifts:
		particle.amount = maxi(1,roundi((100 if quality==2 else 50)*budget_scale))
	reset()

func particle_budget() -> int:
	if quality == 0:
		return 0
	var total = 0
	for particle in volumes + drifts:
		total += particle.amount
	return total

func update_weather(state, camera: Camera3D, rider_position: Vector3, field, dt: float, active: bool, title: bool, motion: float, quality_value: int, first_person: bool = false) -> void:
	set_quality(quality_value)
	if initialized and (previous_close != first_person or previous_camera.distance_to(camera.global_position)>12.0):
		reset()
	camera_velocity = (camera.global_position-previous_camera)/maxf(dt,0.0001) if initialized and (active or title) else Vector3.ZERO
	previous_camera = camera.global_position
	previous_close = first_person
	initialized = true
	stretch = motion if active and state.enabled else 0.0
	var animate: bool = active or title
	for i in range(volumes.size()):
		var particle = volumes[i]
		var strength: float = state.snow if i==0 else state.rain
		var enabled: bool = state.enabled and strength>0.002
		var process: ShaderMaterial = particle.process_material
		var material: ShaderMaterial = particle.draw_pass_1.material
		var flow: Vector3 = state.wind_velocity + Vector3.DOWN*(2.3 if i==0 else 16.0) - camera_velocity
		particle.global_position = camera.global_position
		process.set_shader_parameter("airflow",flow)
		process.set_shader_parameter("clock",state.visual_time)
		process.set_shader_parameter("enabled",enabled)
		material.set_shader_parameter("flow",flow)
		material.set_shader_parameter("stretch",stretch)
		material.set_shader_parameter("opacity",strength*(0.82 if i==0 else 0.60))
		_set_emission(particle,enabled,animate)
	var right: Vector3 = camera.global_basis.x.slide(Vector3.UP).normalized()
	for i in range(drifts.size()):
		var particle = drifts[i]
		var p: Vector3 = rider_position + right*(-6.0 if i==0 else 6.0) - camera.global_basis.z*6.0
		var height: float = field.sample(p.x,p.z).height
		p.y = height + 0.25
		var n: Vector3 = field.contact_normal(p.x,p.z)
		var drift: Vector3 = state.wind_velocity.slide(n)
		var process: ParticleProcessMaterial = particle.process_material
		particle.global_position = p
		particle.basis = Basis(Quaternion(Vector3.UP,n))
		process.direction = particle.basis.inverse()*drift.normalized() if drift.length()>0.1 else Vector3.RIGHT
		process.initial_velocity_min = maxf(1.0,drift.length()*0.7)
		process.initial_velocity_max = maxf(2.0,drift.length()*1.3)
		var material: ShaderMaterial = particle.draw_pass_1.material
		material.set_shader_parameter("flow",drift-camera_velocity)
		material.set_shader_parameter("opacity",state.spindrift*(0.18+state.gust*0.20))
		_set_emission(particle,state.enabled and state.spindrift>0.002 and absf(rider_position.y-height)<7.0,animate)

func _set_emission(particle: GPUParticles3D, enabled: bool, animate: bool) -> void:
	if enabled and not particle.visible:
		particle.restart()
	particle.visible = enabled
	particle.emitting = enabled
	particle.speed_scale = 1.0 if enabled and animate else 0.0
