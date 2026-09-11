extends Node3D
## Two bounded GPU emitters; no collision, lights or CPU particle simulation.
var emitters: Array[GPUParticles3D] = []

func _ready() -> void:
	for i in 2:
		var emitter = GPUParticles3D.new()
		emitter.amount = 96
		emitter.lifetime = .32
		emitter.fixed_fps = 60
		emitter.local_coords = false
		emitter.emitting = false
		emitter.visibility_aabb = AABB(Vector3(-40,-20,-40),Vector3(80,40,80))
		var process = ShaderMaterial.new()
		process.shader = preload("res://assets/graphics/rock_sparks.gdshader")
		emitter.process_material = process
		var quad = QuadMesh.new()
		quad.size = Vector2.ONE
		var draw = ShaderMaterial.new()
		draw.shader = preload("res://assets/graphics/rock_spark_draw.gdshader")
		quad.material = draw
		emitter.draw_pass_1 = quad
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(emitter)
		emitters.append(emitter)

func update_contact(sim, p: Vector3, active: bool, responses: Array) -> void:
	for i in 2:
		var ski = sim.skis[i]
		var emitter = emitters[i]
		emitter.position = ski.position+(p-sim.position)+ski.normal*.04
		emitter.basis = Basis(ski.normal.cross(ski.forward).normalized(),ski.normal,ski.forward)
		emitter.emitting = active and responses[i].sparks>.001
		emitter.speed_scale = 1.0 if active else 0.0
		emitter.process_material.set_shader_parameter("emission_ratio",responses[i].sparks if emitter.emitting else 0.0)
		emitter.process_material.set_shader_parameter("skier_velocity",sim.velocity)

func reset() -> void:
	for emitter in emitters:
		emitter.restart()
		emitter.emitting = false

func apply_quality(level: int) -> void:
	for emitter in emitters: emitter.amount = [32,64,96][clampi(level,0,2)]
