extends RefCounted
## Fixture-only route selection. Never changes terrain, contacts, obstacles or tuning.
const Solver = preload("res://scripts/core/ski_simulation.gd")
const InputFrame = preload("res://scripts/core/rider_input.gd")
const VERSION = 1
const RIDE_SECONDS = 15
const RIDE_SPEED_KMH = 60.0
const MAX_CANDIDATES = 8
const MAX_PREFLIGHT_MS = 45000
const MODES = ["ride_glide","ride_carve"]

static func v3(p: Vector3) -> Array: return [p.x,p.y,p.z]
static func from3(p: Array) -> Vector3: return Vector3(p[0],p[1],p[2])

static func controls_at(mode: String, frame_time: float):
	var controls = InputFrame.new()
	controls.tuck = .2
	controls.steer = sin(frame_time*.65)*.45 if mode=="ride_carve" else 0.0
	return controls

static func initialize_sim(sim, surface, origin: Vector2, heading: float, speed: float) -> void:
	var p = Vector3(origin.x,surface.sample(origin.x,origin.y).height,origin.y)
	sim.reset(p,heading)
	sim.prime_contacts(surface)
	sim.velocity = sim.support_basis().z*speed/3.6

static func digest(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()

static func physical_identity(field, surface, tuning, fps: int) -> Dictionary:
	var hashes = {}
	# Include all core dependencies and actual surface implementation dependencies.
	for directory in ["res://scripts/core","res://scripts/world","res://scripts/world/generators"]:
		for filename in DirAccess.get_files_at(directory):
			if filename.ends_with(".gd"):
				var path = directory.path_join(filename)
				hashes[path] = FileAccess.get_sha256(path)
	var values = {}
	for property in tuning.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["script","resource_name","resource_local_to_scene"]:
			values[property.name] = tuning.get(property.name)
	# Group keys are Node IDs; exclude those, retain every actual collision box.
	var boxes: Array[String] = []
	for entry in surface.indexed:
		var box: Dictionary = entry[1]
		var pose: Transform3D = box.transform
		boxes.append(JSON.stringify({"p":v3(pose.origin),"x":v3(pose.basis.x),"y":v3(pose.basis.y),"z":v3(pose.basis.z),"size":v3(box.size),"reason":box.get("reason","")},"",true,true))
	boxes.sort()
	var result = {"schema":VERSION,"seed":field.seed_value,"height_sha256":field.height_checksum,
		"tree_snow_sha256":digest(field.tree_snow_height.to_byte_array()),
		"generator":field.GENERATOR_VERSION,"generation_settings":field.generation_settings,
		"obstacle_sha256":field.obstacle_checksum,"material_sha256":digest(field.material_image.get_data()) if field.material_image else "absent",
		"surface_script":surface.get_script().resource_path,"grid":[field.X_MIN,field.Z_MIN,field.NX,field.NZ,field.CELL],
		"prop_boxes_sha256":JSON.stringify(boxes).sha256_text(),"prop_boxes":boxes.size(),"model":Solver.MODEL_VERSION,
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"sources":hashes,
		"tuning_sha256":JSON.stringify(values,"",true,true).sha256_text(),
		"fixture_sha256":FileAccess.get_sha256("res://tests/local_snow_boundary_playtest.gd"),
		"selector_sha256":FileAccess.get_sha256("res://tests/local_snow_boundary_route.gd"),
		"seconds":RIDE_SECONDS,"initial_speed_kmh":RIDE_SPEED_KMH,"fps":fps,"hz":120,
		"inputs":"tuck=.2; glide steer=0; carve steer=sin(frame_time*.65)*.45; held for 120/fps ticks"}
	# JSON normalizes numeric types identically on create and reuse.
	return JSON.parse_string(JSON.stringify(result,"",true,true))

static func material_probe(surface, p: Vector3) -> Dictionary:
	var sample_value: Dictionary = surface.sample(p.x,p.z)
	var normal: Vector3 = sample_value.normal
	var center_rock: float = surface.rock_fraction_at(p.x,p.z)
	var nearest = 0.0 if center_rock>=.5 else -1.0
	var nearest_point: Array = [p.x,sample_value.height,p.z] if center_rock>=.5 else []
	var minimum = center_rock
	var maximum = center_rock
	var residual = 0.0
	# 24 real field probes: 4/8/12 m rings. Distances are sampled upper bounds,
	# not an exact nearest-rock search and not inferred from a scenery mesh.
	for radius in [4.0,8.0,12.0]:
		for i in 8:
			var q = Vector2(p.x,p.z)+Vector2(cos(i*TAU/8),sin(i*TAU/8))*radius
			var height: float = surface.sample(q.x,q.y).height
			var rock: float = surface.rock_fraction_at(q.x,q.y)
			minimum = minf(minimum,rock); maximum = maxf(maximum,rock)
			if rock>=.5 and nearest<0.0: nearest = radius; nearest_point = [q.x,height,q.y]
			var planar: float = sample_value.height-(normal.x*(q.x-p.x)+normal.z*(q.y-p.z))/maxf(normal.y,.01)
			residual = maxf(residual,absf(height-planar))
	return {"center":v3(p),"center_rock":center_rock,"snow_depth_m":surface.snow_depth_at(p.x,p.z),
		"rock_min":minimum,"rock_max":maximum,"sampled_rock_distance_m":nearest,"sampled_rock_point":nearest_point,
		"mixed_patch":minimum<.15 and maximum>=.5,"max_plane_residual_m":residual,"samples":25,"radius_m":12.0}

static func preflight(surface, tuning, origin: Vector2, heading: float, mode: String, fps: int, deadline: int) -> Dictionary:
	var sim = Solver.new(tuning.duplicate(true))
	initialize_sim(sim,surface,origin,heading,RIDE_SPEED_KMH)
	var spawn: Vector3 = sim.position
	var trace: Array = []
	var probes: Array = []
	var completed = 0
	var grounded_ticks = 0
	var snow_ticks = 0
	var path_m = 0.0
	var heading_work = 0.0
	var steer_positive = 0
	var steer_negative = 0
	var carve_positive = 0
	var carve_negative = 0
	var rock_contact_max = 0.0
	var speed_min = RIDE_SPEED_KMH
	var speed_max = RIDE_SPEED_KMH
	var stop = "duration"
	for frame in RIDE_SECONDS*fps:
		if Time.get_ticks_msec()>=deadline: stop = "preflight_wall_budget"; break
		var controls = controls_at(mode,float(frame)/fps)
		for tick in int(120/fps):
			var previous: Vector3 = sim.position
			var previous_heading: float = sim.heading
			sim.step(1.0/120,controls,surface)
			completed += 1
			if not sim.position.is_finite() or not sim.velocity.is_finite() or not is_finite(sim.heading): stop = "nonfinite"; break
			path_m += sim.position.distance_to(previous)
			heading_work += absf(angle_difference(previous_heading,sim.heading))
			if sim.grounded: grounded_ticks += 1
			if sim.grounded and sim.rock_contact<.15 and sim.snow_depth>.01: snow_ticks += 1
			rock_contact_max = maxf(rock_contact_max,sim.rock_contact)
			speed_min = minf(speed_min,sim.speed_kmh()); speed_max = maxf(speed_max,sim.speed_kmh())
			if controls.steer>.1: steer_positive += 1
			if controls.steer<-.1: steer_negative += 1
			var carving_snow = false
			for ski in sim.skis:
				if ski.grounded and ski.load_n>1.0 and absf(ski.edge_angle)>.08 and ski.grip_n/ski.load_n>.05 and sim.rock_contact<.15:
					carving_snow = true
			if carving_snow and controls.steer>.1: carve_positive += 1
			if carving_snow and controls.steer<-.1: carve_negative += 1
			if sim.crashed: stop = "crash: "+sim.crash_reason; break
		if stop!="duration": break
		trace.append({"p":v3(sim.position),"v":v3(sim.velocity),"heading":sim.heading,"grounded":sim.grounded,"ticks":sim.ticks})
		# Every .5 s, including the first and last captured position.
		if frame%maxi(1,int(fps/2))==0 or frame==RIDE_SECONDS*fps-1:
			var probe = material_probe(surface,sim.position)
			probe.frame = frame; probes.append(probe)
	var grounded_fraction = float(grounded_ticks)/maxi(1,completed)
	var snow_fraction = float(snow_ticks)/maxi(1,completed)
	var mixed = 0
	var uneven_mixed = 0
	for probe in probes:
		if probe.mixed_patch: mixed += 1
		if probe.mixed_patch and probe.max_plane_residual_m>=.15: uneven_mixed += 1
	var safe = completed==1800 and stop=="duration" and not sim.crashed and grounded_fraction>=.85 and snow_fraction>=.70 and path_m>=80.0
	if mode=="ride_carve": safe = safe and heading_work>=.25 and steer_positive>120 and steer_negative>120 and carve_positive>=60 and carve_negative>=60
	return {"mode":mode,"safe":safe,"stop":stop,"ticks":completed,"seconds":completed/120.0,"grounded_fraction":grounded_fraction,
		"snow_fraction":snow_fraction,"path_m":path_m,"displacement_m":sim.position.distance_to(spawn),"heading_work_rad":heading_work,
		"steer_positive_ticks":steer_positive,"steer_negative_ticks":steer_negative,"rock_contact_max":rock_contact_max,
		"carve_positive_ticks":carve_positive,"carve_negative_ticks":carve_negative,
		"speed_min_kmh":speed_min,"speed_max_kmh":speed_max,"mixed_patch_samples":mixed,"uneven_mixed_patch_samples":uneven_mixed,
		"material_probes":probes,"trace":trace}

static func select(field, surface, tuning, anchor: Vector2, fps: int) -> Dictionary:
	var began = Time.get_ticks_msec()
	var deadline = began+MAX_PREFLIGHT_MS
	var candidates: Array = []
	var survey: Array = []
	# A local 96x96 m survey, 25 origins; at most eight two-ride preflights.
	for z in range(-2,3):
		for x in range(-2,3):
			var origin = anchor+Vector2(x,z)*24.0
			var normal: Vector3 = surface.contact_normal(origin.x,origin.y)
			var rock: float = surface.rock_fraction_at(origin.x,origin.y)
			var site_ok = field.ski_bounds().grow(-16).has_point(origin) and normal.y>=.72 and rock<=.15
			survey.append({"origin":[origin.x,origin.y],"normal_y":normal.y,"rock":rock,"eligible":site_ok})
			if not site_ok: continue
			var p = Vector3(origin.x,surface.sample(origin.x,origin.y).height,origin.y)
			var probe = material_probe(surface,p)
			var score = (100.0 if probe.mixed_patch else 0.0)+minf(probe.max_plane_residual_m,2.0)-origin.distance_to(anchor)*.001
			candidates.append({"origin":[origin.x,origin.y],"heading":atan2(normal.x,normal.z),"score":score,"site_probe":probe})
	candidates.sort_custom(func(a,b): return a.score>b.score)
	var diagnostics: Array = []
	var selected = {}
	var selected_score = -1.0
	for index in mini(MAX_CANDIDATES,candidates.size()):
		if Time.get_ticks_msec()>=deadline: break
		var candidate: Dictionary = candidates[index]
		var origin = Vector2(candidate.origin[0],candidate.origin[1])
		var rides = {}
		var safe = true
		var coverage = 0
		for mode in MODES:
			rides[mode] = preflight(surface,tuning,origin,candidate.heading,mode,fps,deadline)
			safe = safe and rides[mode].safe
			coverage += mini(3,rides[mode].uneven_mixed_patch_samples)
		var diagnostic = candidate.duplicate(true)
		diagnostic.rides = rides.duplicate(true)
		for mode in MODES: diagnostic.rides[mode].erase("trace")
		diagnostics.append(diagnostic)
		if safe and coverage>selected_score:
			selected = {"origin":candidate.origin,"heading":candidate.heading,"rides":rides}
			selected_score = coverage
		if safe and coverage==6: break # three actual mixed/uneven probes in BOTH rides
	var missing: Array[String] = []
	if selected.is_empty(): missing.append("No safe shared 15-second glide/carve lane found within the bounded candidate/time budget")
	else:
		for mode in MODES:
			if selected.rides[mode].uneven_mixed_patch_samples<3:
				missing.append(mode+": fewer than three .5-second probes of mixed snow/rock within 12 m and >=.15 m plane residual")
	return {"schema":VERSION,"selected":selected,"candidate_diagnostics":diagnostics,"candidate_pool":candidates.size(),
		"anchor":[anchor.x,anchor.y],"origin_survey":survey,
		"candidates_tested":diagnostics.size(),"candidate_limit":MAX_CANDIDATES,"wall_limit_ms":MAX_PREFLIGHT_MS,
		"preflight_ms":Time.get_ticks_msec()-began,"missing_coverage":missing,
		"scope":"Each candidate uses two fresh Node-independent production solvers against unchanged world.ski_surface. Material distance is a 24-point ring sample, not exact nearest geology or visual acceptance."}

static func valid_selection(data: Dictionary, fps: int) -> bool:
	var chosen = data.get("selected",{})
	if not chosen is Dictionary: return false
	if chosen.is_empty(): return true # valid failure diagnostics; never used for a ride
	var origin = chosen.get("origin",[])
	if not origin is Array or origin.size()!=2 or not is_finite(float(origin[0])) or not is_finite(float(origin[1])): return false
	if not is_finite(float(chosen.get("heading",NAN))): return false
	var rides = chosen.get("rides",{})
	if not rides is Dictionary: return false
	for mode in MODES:
		var ride = rides.get(mode,{})
		if not ride is Dictionary or not ride.get("safe",false) or ride.get("ticks",0)!=1800: return false
		var trace = ride.get("trace",[])
		if not trace is Array or trace.size()!=RIDE_SECONDS*fps: return false
		for row in trace:
			if not row is Dictionary or not row.get("p") is Array or not row.get("v") is Array: return false
			if row.p.size()!=3 or row.v.size()!=3 or not row.has_all(["heading","grounded","ticks"]): return false
	return true
