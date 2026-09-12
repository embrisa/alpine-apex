extends Node3D
## A single replay-owned fully equipped skier and independent bounded tracks.
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Pose = preload("res://scripts/presentation/ghost_pose.gd")
const Assets = preload("res://scripts/presentation/ghost_assets.gd")
const Tracks = preload("res://scripts/presentation/snow_tracks.gd")
const Stack = preload("res://scripts/presentation/ghost_track_stack.gd")
const Response = preload("res://scripts/presentation/snow_response.gd")
var visual
var snow_tracks
var ghost_assets
var replay:
	set(value):
		if replay==value: return
		replay = value
		reset_history()
var run_id = ""
var color = Color.WHITE
var source_assets
var player_history
var profile
var field
var last_time = -1.0
var last_segment = -1
var enabled = true
var emitting = false
var opacity = .15
var responses: Array = [Response.new(),Response.new()]

func _ready() -> void:
	ghost_assets = Assets.new(source_assets,color)
	visual = Visual.new()
	visual.preview_only = true
	visual.animation_enabled = false
	visual.assets = ghost_assets
	visual.lighting = source_assets.lighting
	add_child(visual)
	# Equipment meshes intentionally share immutable production geometry. Their
	# per-node overrides, like the body overrides, belong to this ghost alone.
	_isolate(visual)
	snow_tracks = Tracks.new()
	snow_tracks.lighting = source_assets.lighting
	add_child(snow_tracks)
	var old_material: ShaderMaterial = snow_tracks.material
	source_assets.lighting.materials.erase(old_material)
	snow_tracks.material = player_history.material.duplicate()
	source_assets.lighting.register(snow_tracks.material)
	snow_tracks.tracks.mesh.material = snow_tracks.material
	snow_tracks.live_tracks.mesh.material = snow_tracks.material
	apply_quality(profile)
	visual.visible = false

func _isolate(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		node.transparency = 0.0
		node.visibility_range_begin = 0.0; node.visibility_range_end = 0.0
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var mat = node.get_active_material(i)
			if mat and mat not in ghost_assets.materials.values(): node.set_surface_override_material(i,ghost_assets.material_for(mat))
	for child in node.get_children(): _isolate(child)

func apply_quality(value) -> void:
	profile = value
	if snow_tracks:
		var bounded = value.duplicate()
		bounded.snow_track_capacity = Stack.GHOST_CAPACITY
		snow_tracks.apply_quality(bounded)

static func opacity_at(distance: float) -> float:
	return clampf(lerpf(.15,.72,smoothstep(0.0,18.0,maxf(distance,0.0))),.15,.72)

func reset_history() -> void:
	last_time = -1.0; last_segment = -1; emitting = false
	if snow_tracks: snow_tracks.reset()
	if visual: visual.visible = false

func break_tracks() -> void:
	snow_tracks.foot_history.fill(Vector3.INF)
	for i in 2: snow_tracks._hide_live(i)

func update_ghost(time: float, rider_position: Vector3, show_in_world: bool, paused: bool = false, track_emission: bool = true) -> void:
	if replay==null or not enabled or not show_in_world:
		if last_time>=0: reset_history()
		return
	if paused and last_time>=0: time = last_time
	if last_time>=0 and time<last_time: reset_history()
	var sample_time = clampf(time,0.0,replay.duration)
	var data: Dictionary = replay.presentation_at(sample_time)
	if data.is_empty():
		visual.visible = false; break_tracks(); last_time = time; emitting = false
		return
	var advanced = last_time<0 or time>last_time
	if data.segment!=last_segment or (last_time>=0 and time-last_time>.12): break_tracks()
	if advanced or not visual.visible:
		Pose.apply(visual,data.a,data.b,data.weight,responses)
	opacity = opacity_at(visual.global_position.distance_to(rider_position))
	ghost_assets.tint(color,opacity)
	visual.visible = time<=replay.duration
	var crossed_finish = last_time>=0 and last_time<replay.duration and time>replay.duration and time-last_time<=.12
	emitting = track_emission and not paused and advanced and (time<=replay.duration or crossed_finish)
	if emitting:
		snow_tracks.update_presentation(field,visual.global_position,true,responses,float(data.a[-1]))
	elif time>replay.duration:
		break_tracks() # retained marks remain, independent of this model's finish
	last_time = time; last_segment = data.segment

func _exit_tree() -> void:
	if ghost_assets: ghost_assets.dispose()
	if snow_tracks: source_assets.lighting.materials.erase(snow_tracks.material)
