extends RefCounted
## Sixteen recent swept segments, shared by every grass batch; no tuft state.
const SLOTS = 16
const RECOVERY = 1.25
const TELEPORT = 30.0
var starts = PackedVector4Array()
var ends = PackedVector4Array()
var cursor = 0
var previous = Vector3.ZERO
var initialized = false
var receivers: Array[ShaderMaterial] = []
func _init() -> void:
	starts.resize(SLOTS); ends.resize(SLOTS)
func register(material: ShaderMaterial) -> void:
	if not receivers.has(material): receivers.append(material)
	_upload()
func reset() -> void:
	starts.fill(Vector4.ZERO); ends.fill(Vector4.ZERO)
	initialized = false; cursor = 0; _upload()
func update(actor: Vector3, velocity: Vector3, dt: float, active: bool) -> void:
	if not actor.is_finite(): reset(); return
	if not initialized or previous.distance_to(actor)>TELEPORT:
		reset(); previous=actor; initialized=true
	if not active: previous=actor; return
	var step = clampf(dt,0,.1)
	for i in SLOTS: ends[i].w=maxf(0,ends[i].w-step/RECOVERY)
	if previous.distance_squared_to(actor)>.0001 and velocity.length_squared()>.04:
		# Merge short consecutive segments into a <=4 m sweep. At 170 km/h the
		# entire path remains covered; keep corners rather than a chord across turns.
		var last = posmod(cursor-1,SLOTS)
		var a = Vector3(starts[last].x,starts[last].y,starts[last].z)
		var b = Vector3(ends[last].x,ends[last].y,ends[last].z)
		var merge = ends[last].w>.88 and b.distance_to(previous)<.02 and a.distance_to(actor)<4.0 and (b-a).normalized().dot((actor-previous).normalized())>.985
		var at = last if merge else cursor
		if not merge:
			starts[at]=Vector4(previous.x,previous.y,previous.z,1)
			cursor=(cursor+1)%SLOTS
		ends[at]=Vector4(actor.x,actor.y,actor.z,1)
	previous=actor; _upload()
func _upload() -> void:
	for material in receivers:
		material.set_shader_parameter("grass_sweep_start",starts)
		material.set_shader_parameter("grass_sweep_end",ends)
func influence_at(root_position: Vector3) -> float:
	# Diagnostic of the same spatial contract (including airborne separation).
	var strength = 0.0
	for i in SLOTS:
		if ends[i].w<=0: continue
		var a = Vector3(starts[i].x,starts[i].y,starts[i].z)
		var b = Vector3(ends[i].x,ends[i].y,ends[i].z)
		var ab = Vector2(b.x-a.x,b.z-a.z)
		var t = clampf(Vector2(root_position.x-a.x,root_position.z-a.z).dot(ab)/maxf(.0001,ab.length_squared()),0,1)
		var p = a.lerp(b,t)
		var horizontal = Vector2(root_position.x-p.x,root_position.z-p.z).length()
		strength=maxf(strength,(1-smoothstep(.1,1.05,horizontal))*(1-smoothstep(.35,1.2,absf(root_position.y-p.y)))*smoothstep(0,1,ends[i].w))
	return strength
