extends RefCounted
## Main-thread grouping of bounded contact reports. No forces or collision edits.
const Events = preload("res://scripts/presentation/riding_audio_events.gd")
const Condition = preload("res://scripts/presentation/snow_condition.gd")
const TerrainMaterial = preload("res://scripts/core/terrain_material.gd")
var clusters: Dictionary = {}
var touching: Dictionary = {}
var clock = 0.0
var last_tick = -1
var last_update_us = 0
var max_update_us = 0
var reports_read = 0
var capture_max_bone_us = 0
var capture_sum_max_us = 0
var elapsed_since_sample = 0.0
var slide: Dictionary = {"speed":0.0,"intensity":0.0,"pan":0.0,"material":0,"condition":2}

func reset() -> void:
	clusters.clear()
	touching.clear()
	clock = 0.0
	last_tick = -1
	elapsed_since_sample = 0.0
	slide.intensity = 0.0

func sample(ragdoll, field, camera: Camera3D, dt: float) -> Array[Dictionary]:
	elapsed_since_sample += maxf(0.0,dt)
	var tick: int = Engine.get_physics_frames()
	if tick==last_tick: return []
	last_tick = tick
	var started = Time.get_ticks_usec()
	reports_read = 0
	var reports: Array[Dictionary] = []
	var capture_sum_us = 0
	for bone in ragdoll.bodies.values():
		if bone.contact_tick<0 or bone.contact_tick<tick-2: continue
		capture_max_bone_us = maxi(capture_max_bone_us,bone.report_max_us)
		capture_sum_us += bone.report_us
		for i in range(bone.contact_count):
			reports_read += 1
			var id: int = bone.collider_ids[i]
			if id==0: continue
			var position: Vector3 = bone.positions[i]
			var collider = instance_from_id(id)
			if not is_instance_valid(collider): continue
			var material: int = int(collider.get_meta("audio_material",Events.AudioMaterial.GENERIC))
			var condition = 2
			if material==Events.AudioMaterial.SNOW:
				material = TerrainMaterial.at(field,position.x,position.z)
				var depth: float = field.snow_depth_at(position.x,position.z) if field!=null and field.has_method("snow_depth_at") else 0.0
				condition = Condition.at(field,position,depth)
			var pan = _pan(position,camera)
			var speed: float = bone.velocities[i].slide(bone.normals[i]).length()
			# Impulse is only a secondary estimate, capped by actual incoming speed.
			var closing_speed: float = bone.closing[i]
			var severity: float = maxf(closing_speed,minf(bone.impulses[i]/maxf(bone.mass,.1),closing_speed*1.3))
			reports.append({"body":bone.get_instance_id(),"collider":id,"speed":severity,"slide_speed":speed,"weight":clampf(bone.mass/15.0,.1,1.0),"pan":pan,"material":material,"condition":condition,"equipment":bone.bone_name.ends_with("Foot")})
	capture_sum_max_us = maxi(capture_sum_max_us,capture_sum_us)
	var events = observe_reports(reports,elapsed_since_sample)
	elapsed_since_sample = 0.0
	last_update_us = Time.get_ticks_usec()-started
	max_update_us = maxi(max_update_us,last_update_us)
	return events

func observe_reports(reports: Array[Dictionary], dt: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	clock += maxf(0.0,dt)
	slide.intensity=0.0
	var strongest_slide=0.0
	var fresh_pairs: Dictionary = {}
	for report in reports:
		var pair = "%d:%d" % [report.body,report.collider]
		if not touching.has(pair): fresh_pairs[pair]=true
		touching[pair]=clock
		if report.slide_speed*report.weight>strongest_slide:
			strongest_slide=report.slide_speed*report.weight
			slide={"speed":report.slide_speed,"intensity":report.weight,"pan":report.pan,"material":report.material,"condition":report.condition}
		if not fresh_pairs.has(pair) or report.speed<=.6: continue
		var id: int=report.collider
		if not clusters.has(id): clusters[id]={"until":clock+.06,"speed":0.0,"material":report.material,"pan":report.pan,"detail":0.0,"equipment_speed":0.0}
		var cluster: Dictionary=clusters[id]
		if report.get("equipment",false): cluster.equipment_speed=maxf(cluster.equipment_speed,report.speed)
		if report.speed>cluster.speed:
			cluster.speed=report.speed
			cluster.material=report.material
			cluster.pan=report.pan
			cluster.detail=report.weight
	for id in clusters.keys():
		var cluster: Dictionary=clusters[id]
		if clock>=cluster.until:
			events.append(Events._event(Events.Kind.IMPACT,cluster.material,cluster.speed,cluster.pan,cluster.detail))
			if cluster.equipment_speed>1.0:
				events.append(Events._event(Events.Kind.EQUIPMENT,Events.AudioMaterial.GENERIC,cluster.equipment_speed,cluster.pan,.8))
			clusters.erase(id)
	for pair in touching.keys():
		if clock-touching[pair]>=.08: touching.erase(pair)
	return events

static func _pan(position: Vector3, camera: Camera3D) -> float:
	if camera==null: return 0.0
	var direction = (position-camera.global_position).normalized()
	return clampf(direction.dot(camera.global_basis.x),-1,1)
