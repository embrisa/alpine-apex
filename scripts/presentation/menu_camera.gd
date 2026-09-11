extends Camera3D
## Live menu presentation. All positions are read-only consumers of the world.
const SHOT_SECONDS = 24.0
const FADE_SECONDS = 0.7
const ORBIT_RATE = PI / 45.0 # 4 degrees/second.
const MAX_SHOTS = 6
var field
var solids
var shots: Array[Dictionary] = []
var context: String = ""
var shot_index: int = -1 # Player, scenic 0, player, scenic 1 ...
var next_scenic: int = 0
var shot_time: float = 0.0
var orbit_angle: float = -2.57
var fade_time: float = -1.0
var fade_alpha: float = 0.0
var cut_serial: int = 0
var focus_point = Vector3.ZERO
var previous_focus = Vector3.ZERO
var pose_ready = false
var motion_reduced = false

func setup(surface, collision_surface = null) -> void:
	if field == surface: return
	field = surface
	solids = collision_surface
	near = 0.15
	far = 32000.0
	fov = 60.0
	shots.clear()
	leave()
	var candidates: Array[Vector2] = []
	if "features" in field:
		for feature in field.features:
			if feature.get("position") is Vector2: candidates.append(feature.position)
	var spawn: Vector3 = field.spawn_point()
	var center = Vector2(spawn.x,spawn.z)
	if candidates.is_empty():
		var radius = minf(field.bounds().size.x,field.bounds().size.y)*0.18
		for i in 12: candidates.append(center + Vector2.from_angle(TAU*i/12.0)*radius)
	# Interleave sectors so the first six accepted views cover different faces.
	var ordered: Array[Vector2] = []
	for sector in 6:
		for point in candidates:
			var bearing = posmod(int(floor((point-center).angle()/TAU*6.0)),6)
			if bearing == sector and point.distance_to(center)>150.0:
				ordered.append(point)
	for round_index in 16:
		for sector in 6:
			var sector_points = ordered.filter(func(point): return posmod(int(floor((point-center).angle()/TAU*6.0)),6)==sector)
			if round_index>=sector_points.size(): continue
			sector_points.sort_custom(func(a,b): return a.distance_squared_to(center)<b.distance_squared_to(center))
			# Stagger altitude as well as bearing: ridges, bowls and lower glades.
			var point: Vector2 = sector_points[(round_index+sector)%sector_points.size()]
			if not field.ski_bounds().grow(-35.0).has_point(point): continue
			if shots.any(func(shot): return Vector2(shot.site.x,shot.site.z).distance_to(point)<350.0): continue
			var site = Vector3(point.x,field.sample(point.x,point.y).height+2.0,point.y)
			var outward = (point-center).normalized()
			var desired = site+Vector3(outward.x*70.0,35.0,outward.y*70.0)
			var position_value = safe_position(site,desired,3.0)
			if position_value.distance_to(site)<35.0: continue
			# Look out along the face with a shallow pitch, retaining the skyline
			# instead of filling the whole frame with a close uphill rock wall.
			var view_direction = outward.rotated(0.55 if sector%2==0 else -0.55)
			var target = position_value+Vector3(view_direction.x*450.0,-70.0,view_direction.y*450.0)
			target.y = maxf(target.y,field.sample(target.x,target.z).height+20.0)
			if safe_position(target,position_value,3.0).distance_to(position_value)>2.0: continue
			var drift = Vector3(-outward.y,0,outward.x)*8.0
			if safe_position(target,position_value+drift,3.0).distance_to(position_value+drift)>2.0: continue
			if safe_position(target,position_value-drift,3.0).distance_to(position_value-drift)>2.0: continue
			shots.append({"focus":target,"site":site,"position":position_value,"drift":drift})
			if shots.size()==MAX_SHOTS: return

func select_context(value: String) -> void:
	if context == value: return
	leave()
	context = value

func leave() -> void:
	context = ""
	shot_index = -1
	next_scenic = 0
	shot_time = 0.0
	orbit_angle = -2.57
	fade_time = -1.0
	fade_alpha = 0.0
	pose_ready = false

func cancel_fade() -> void:
	fade_time = -1.0
	fade_alpha = 0.0
	shot_time = 0.0

func update_view(player: Vector3, delta: float, reduced_motion: bool, crash_moving: bool = false, side_framing: bool = true) -> void:
	if field == null or context.is_empty(): return
	var dt = clampf(delta,0.0,0.05)
	if reduced_motion and not motion_reduced: cancel_fade()
	motion_reduced = reduced_motion
	var target = player+Vector3.UP*1.1
	if reduced_motion and pose_ready:
		if context=="crashed" and crash_moving:
			global_position += target-previous_focus
			global_position = safe_position(target,global_position)
			focus_point = target
			_frame(target,side_framing)
		previous_focus = target
		return
	if not reduced_motion:
		shot_time += dt
		if context=="title" and not shots.is_empty():
			if fade_time<0.0 and shot_time>=SHOT_SECONDS: fade_time = 0.0
			if fade_time>=0.0:
				var before = fade_time
				fade_time += dt
				var cut = before<FADE_SECONDS*.5 and fade_time>=FADE_SECONDS*.5
				if cut:
					shot_index = next_scenic if shot_index<0 else -1
					if shot_index>=0: next_scenic = (next_scenic+1)%shots.size()
					shot_time = 0.0
					cut_serial += 1
					if Engine.has_singleton("AlpineFidelityFX"): Engine.get_singleton("AlpineFidelityFX").reset_history()
				fade_alpha = 1.0-absf(fade_time/(FADE_SECONDS*.5)-1.0)
				if cut: fade_alpha = 1.0 # Never expose a partially faded teleport.
				if fade_time>=FADE_SECONDS:
					fade_time = -1.0
					fade_alpha = 0.0
		if not (context=="crashed" and crash_moving): orbit_angle += ORBIT_RATE*dt
	var desired: Vector3
	if context=="title" and shot_index>=0:
		var shot = shots[shot_index]
		target = shot.focus
		desired = shot.position+shot.drift*sin(shot_time/SHOT_SECONDS*PI*.5)
	else:
		desired = player+Vector3(sin(orbit_angle)*9.0,4.5,cos(orbit_angle)*9.0)
	global_position = safe_position(target,desired)
	focus_point = target
	previous_focus = player+Vector3.UP*1.1
	_frame(target,side_framing and shot_index<0)
	pose_ready = true

func _frame(target: Vector3, side_framing: bool) -> void:
	if global_position.distance_squared_to(target)<0.01: target += Vector3.FORWARD
	if Vector2(target.x-global_position.x,target.z-global_position.z).length()<0.1: target += Vector3.FORWARD*0.2
	look_at(target)
	# Move the subject to the open right side without moving any menu panels.
	if side_framing:
		var aspect = get_viewport().get_visible_rect().size.aspect()
		rotate_object_local(Vector3.UP,atan(0.44*tan(deg_to_rad(fov)*.5)*aspect))

func safe_position(target: Vector3, desired: Vector3, clearance: float = 1.0) -> Vector3:
	var area: Rect2 = field.bounds().grow(-2.0)
	desired.x = clampf(desired.x,area.position.x,area.end.x)
	desired.z = clampf(desired.z,area.position.y,area.end.y)
	desired.y = maxf(desired.y,field.sample(desired.x,desired.z).height+clearance)
	var pivot = target
	pivot.y = maxf(pivot.y,field.sample(pivot.x,pivot.z).height+0.9)
	# At most 32 terrain probes and two solid sweeps, independent of mountain size.
	var count = clampi(ceili(pivot.distance_to(desired)/3.0),8,32)
	for i in range(1,count+1):
		var fraction = float(i)/count
		var probe = pivot.lerp(desired,fraction)
		var floor_y: float = field.sample(probe.x,probe.z).height+0.6
		if probe.y<floor_y: desired.y += (floor_y-probe.y)/fraction
	if field.has_method("ray_geology"):
		var hit: Dictionary = field.ray_geology(pivot,desired,0.65)
		if not hit.is_empty(): desired = pivot.lerp(desired,maxf(0.0,float(hit.fraction)-0.03))
	if solids != null and solids.has_method("sweep_obstacle_contact"):
		# The existing envelope is centred 0.8 m above its query positions.
		var hit: Dictionary = solids.sweep_obstacle_contact(pivot-Vector3.UP*.8,desired-Vector3.UP*.8)
		if not hit.is_empty() and not hit.get("boundary",false):
			desired = pivot.lerp(desired,maxf(0.0,float(hit.get("fraction",1.0))-0.03))
	desired.y = maxf(desired.y,field.sample(desired.x,desired.z).height+clearance)
	return desired
