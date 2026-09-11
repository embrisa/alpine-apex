extends SceneTree
## Default-seed evidence only. Reuses the retained, version-independent test
## planner/pilot against a validated v15 field; never changes production state.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
const Sources = preload("res://scripts/world/generation_sources.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
const Survey = preload("res://tests/alpine_v13_route_survey.gd")
const Pilot = preload("res://tests/alpine_v13_pilot.gd")
const SEED = 849205174
const VERSION = 15
const DT = 1.0 / 120.0
const MAX_TICKS = 96000
const STALL_TICKS = 3600
const OUTPUT = "res://artifacts/v15_route_audit"
var report: Dictionary = {}
var failures: Array = []
var checks = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL ", label)

func write_json(path: String, value: Variant) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check(false, "Cannot write " + path)
		return
	file.store_string(JSON.stringify(value, "\t", true, true))
	file.flush()
	check(file.get_error() == OK, "Write succeeded: " + path)

func source_hashes() -> Dictionary:
	var paths: Array = Sources.dependencies(false)
	for folder in ["res://scripts/core", "res://scripts/world"]:
		for name in DirAccess.get_files_at(folder):
			if name.ends_with(".gd"):
				paths.append(folder.path_join(name))
	paths.append_array(["res://tests/alpine_v15_route_audit.gd",
		"res://tests/alpine_v13_route_survey.gd", "res://tests/alpine_v13_pilot.gd",
		"res://config/ski_default.tres", "res://project.godot"])
	paths.sort()
	var hashes: Dictionary = {}
	for path in paths:
		hashes[path] = FileAccess.get_sha256(path)
	return hashes

func checkpoint() -> void:
	report.checks = checks
	report.harness_failures = failures.duplicate()
	write_json(OUTPUT + "/audit.json", report)

func run() -> void:
	if DirAccess.make_dir_recursive_absolute(OUTPUT) != OK:
		printerr("Cannot create audit output directory")
		quit(1)
		return
	report = {"schema": 1, "status": "running", "started_utc": Time.get_datetime_string_from_system(true),
		"unranked": true, "performance_measurement": false, "faces": [],
		"identity": {"source_sha256": source_hashes(), "model": Simulation.MODEL_VERSION,
			"engine": Engine.get_version_info().string, "engine_sha256": Sources.engine_identity()},
		"method": {"survey": "Retained height-ordered graph, 6 x 12 m; one 3 x 6 m refinement if needed",
			"node_clearance_m": Survey.NODE_CLEARANCE, "edge_clearance_m": Survey.EDGE_CLEARANCE,
			"graph_min_contact_normal_y": 0.60, "graph_min_edge_drop_m": 0.2,
			"graph_max_edge_grade": 1.5, "graph_max_exposed_run_m": 30,
			"rejoin_scope": "Reachable graph nodes with multiple accepted incoming edges; not independently skied branches",
			"support_check_spacing_m": 4.0, "obstacles": "Production tree and mineral swept rider contract",
			"pilot": "Retained ordinary-input pilot v4; one attempt per face; first swept-clear path, otherwise first nonempty path, otherwise unsurveyed radial target",
			"pilot_hz": 120, "intent_interval_ticks": 12, "jump_release_ticks": 1,
			"pilot_limit_seconds": MAX_TICKS * DT, "stall_seconds": STALL_TICKS * DT,
			"stall_definition": "No 2 m advance of maximum radius for 30 simulation seconds",
			"completion": "Uncrashed production reached_base (radius >= 2850 m), not a timed race",
			"limitations": "Sampled geometry is not dynamic skiability. Pilot crashes/stalls do not prove a face unskiable. No rendered, performance, human/controller or additional-seed acceptance."}}
	for face_index in 6:
		report.faces.append({"face_index": face_index, "face_label": face_index + 1,
			"survey_status": "pending", "pilot": {"status": "pending", "attempts": 0}})
	checkpoint()
	print("V15_AUDIT_GENERATE seed=", SEED, " Standard")
	var field = Definition.generate(SEED, VERSION)
	check(field != null, "Default v15 field exists")
	if field == null:
		report.status = "harness_failed"
		checkpoint()
		quit(1)
		return
	check(field.valid and field.GENERATOR_VERSION == VERSION and field.seed_value == SEED,
		"Valid current v15 default seed")
	check(field.faces.size() == 6 and field.CELL == 4.0, "Six faces on 4 m support")
	check(field.generation_settings == Cache.Settings.preset(), "Standard settings")
	report.identity.merge(Definition.from_field(field).to_reference())
	report.identity.physical_source_signature = Sources.signature()
	report.identity.recipe_key = Cache.recipe_key(SEED)
	report.cache = {"hit": field.cache_hit, "source": field.generation_stages.get("cache_source", "fresh")}
	report.population = {"trees": field.tree_data.size(), "minerals": field.geology.placements.size()}
	checkpoint()
	# Graph sampling reads immutable heights/materials/reservations. Each worker
	# owns its graph. Actual collision sweeps and pilots run serially below because
	# the mineral collision implementation memoizes projection spans lazily.
	var job = Cache.Job.new()
	var surveys = job.map_tiles(6, func(i):
		print("V15_AUDIT_SURVEY_START face_index=", i)
		var result = Survey.survey(field, i)
		print("V15_AUDIT_SURVEY_END face_index=", i, " safe_samples=", result.safe_samples)
		return result)
	check(surveys.size() == 6, "All six surveys returned")
	for i in surveys.size():
		var survey: Dictionary = surveys[i]
		var row: Dictionary = report.faces[i]
		check(survey.face == i and survey.paths.size() == 2, "Survey shape for face %d" % i)
		row.survey_status = "surveyed"
		row.heading_radians = field.faces[i].heading
		row.sampling = {"across_m": survey.across_m, "downhill_m": survey.downhill_m,
			"refinement": survey.refinement, "safe_samples": survey.safe_samples}
		row.reachable_columns = survey.reachable_columns
		row.reachable_rows = survey.reachable_columns.filter(func(n): return n > 0).size()
		row.total_rows_after_start = survey.reachable_columns.size()
		row.graph_rejoin_nodes = survey.merge_nodes
		var widths: Array = survey.reachable_columns.slice(20 * int(survey.refinement))
		widths.sort()
		row.minimum_reachable_width_m = widths.min() * survey.across_m
		row.median_reachable_width_m = widths[widths.size() / 2] * survey.across_m
		row.paths = []
		for path in survey.paths:
			row.paths.append(inspect_path(field, i, path))
		var both = not survey.paths[0].is_empty() and not survey.paths[1].is_empty()
		row.graph_continuity = "two_endpoint_paths" if both else "no_complete_graph_path"
		row.endpoint_separation_m = survey.paths[0][-1].distance_to(survey.paths[1][-1]) if both else 0.0
		row.distributed_alternatives = both and row.endpoint_separation_m >= 500.0
		row.branch_rejoin_status = "sampled_alternatives_and_graph_rejoins" if row.distributed_alternatives and row.graph_rejoin_nodes > 0 else "not_established"
		checkpoint()
	# Route search is over before any pilot starts; no timing result is claimed.
	for i in surveys.size():
		var row: Dictionary = report.faces[i]
		var chosen = -1
		for side in row.paths.size():
			if row.paths[side].status == "checked" and row.paths[side].sweep_hits == 0:
				chosen = side
				break
		if chosen < 0:
			for side in row.paths.size():
				if not row.paths[side].points.is_empty():
					chosen = side
					break
		var path: Array = [[0.0, 12.0], [0.0, field.FOOT_RADIUS]] if chosen < 0 else row.paths[chosen].points
		row.pilot = {"status": "running", "attempts": 1, "path_index": chosen}
		checkpoint()
		row.pilot = run_pilot(field, i, path, chosen)
		checkpoint()
	check(source_hashes() == report.identity.source_sha256, "Sources stayed unchanged throughout audit")
	for row in report.faces:
		check(row.survey_status == "surveyed", "Survey completed for face %d" % row.face_index)
		check(row.pilot.status in ["completed", "crashed", "stalled", "tick_limit"],
			"Pilot has a terminal outcome for face %d" % row.face_index)
	report.status = "complete" if failures.is_empty() else "harness_failed"
	report.finished_utc = Time.get_datetime_string_from_system(true)
	checkpoint()
	print("V15_ROUTE_AUDIT status=", report.status, " checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func inspect_path(field, face_index: int, path: Array) -> Dictionary:
	var result = {"status": "no_path", "points": path.map(func(p): return [p.x, p.y])}
	if path.size() < 2:
		return result
	result.merge({"status": "checked", "length_m": 0.0, "support_samples": 0,
		"nonfinite_samples": 0, "minimum_contact_normal_y": 1.0, "exposed_rock_samples": 0,
		"sweep_segments": 0, "sweep_hits": 0, "first_sweep_hit": {}, "reaches_base": false})
	var face = field.faces[face_index]
	for i in range(1, path.size()):
		var a: Vector2 = face.to_world(path[i - 1])
		var b: Vector2 = face.to_world(path[i])
		var distance_m = a.distance_to(b)
		result.length_m += distance_m
		var steps = maxi(1, ceili(distance_m / 4.0))
		var previous = Vector3(a.x, field.sample(a.x, a.y).height, a.y)
		for j in range(steps + 1):
			var p = a.lerp(b, float(j) / steps)
			var at = Vector3(p.x, field.sample(p.x, p.y).height, p.y)
			var normal: Vector3 = field.contact_normal(p.x, p.y)
			result.support_samples += 1
			if not at.is_finite() or not normal.is_finite():
				result.nonfinite_samples += 1
			result.minimum_contact_normal_y = minf(result.minimum_contact_normal_y, normal.y)
			result.exposed_rock_samples += int(field.rock_fraction_at(p.x, p.y) > 0.5)
			result.reaches_base = result.reaches_base or field.reached_base(at)
			if j > 0:
				var hit: Dictionary = field.sweep_obstacle_contact(previous, at)
				result.sweep_segments += 1
				if not hit.is_empty():
					result.sweep_hits += 1
					if result.first_sweep_hit.is_empty():
						result.first_sweep_hit = {"segment": i, "position": [at.x, at.y, at.z],
							"reason": hit.get("reason", "obstacle"), "fraction": hit.get("fraction", 0.0)}
			previous = at
	check(result.nonfinite_samples == 0, "Finite route support on face %d" % face_index)
	return result

func run_pilot(field, face_index: int, path: Array, chosen: int) -> Dictionary:
	var sim = Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
	var heading: float = field.faces[face_index].heading
	sim.reset(field.launch_point(heading), heading)
	sim.prime_contacts(field)
	var intent = RiderInput.new()
	var commands: Array = []
	var samples: Array = []
	var status = "tick_limit"
	var ticks = 0
	var maximum_radius = Vector2(sim.position.x, sim.position.z).length()
	var progress_radius = maximum_radius
	var progress_tick = 0
	print("V15_AUDIT_PILOT_START face_index=", face_index, " path=", chosen)
	for tick in MAX_TICKS:
		if tick % 12 == 0:
			intent = Pilot.intent(sim, field, face_index, path)
			commands.append([intent.steer, intent.tuck, intent.brake, intent.jump, intent.jump_held,
				intent.air_pitch, intent.air_yaw, intent.air_tilt, intent.grab])
		sim.step(DT, intent, field)
		# Jump is an edge, not twelve repeated release requests.
		intent.jump = false
		ticks += 1
		if not sim.position.is_finite() or not sim.velocity.is_finite():
			check(false, "Nonfinite pilot state on face %d" % face_index)
			status = "invalid_state"
			break
		var radius = Vector2(sim.position.x, sim.position.z).length()
		maximum_radius = maxf(maximum_radius, radius)
		if radius >= progress_radius + 2.0:
			progress_radius = radius
			progress_tick = ticks
		if tick % 120 == 0:
			samples.append([ticks, sim.position.x, sim.position.y, sim.position.z, sim.speed_kmh()])
		if sim.crashed:
			status = "crashed"
			break
		if field.reached_base(sim.position):
			status = "completed"
			break
		if ticks - progress_tick >= STALL_TICKS:
			status = "stalled"
			break
	var evidence_path = OUTPUT + "/pilot_%d.json" % face_index
	write_json(evidence_path, {"face_index": face_index, "path_index": chosen,
		"command_fields": ["steer", "tuck", "brake", "jump", "jump_held", "air_pitch", "air_yaw", "air_tilt", "grab"],
		"command_ticks": 12, "jump_release_ticks": 1, "ticks": ticks, "commands": commands,
		"sample_fields": ["tick", "x", "y", "z", "speed_kmh"], "samples": samples})
	var result = {"status": status, "attempts": 1, "completed": status == "completed", "path_index": chosen,
		"target_kind": "unsurveyed_radial" if chosen < 0 else "survey_path",
		"ticks": ticks, "simulation_seconds": ticks * DT, "maximum_radius_m": maximum_radius,
		"base_progress_percent": maximum_radius / field.FOOT_RADIUS * 100.0, "crash_reason": sim.crash_reason,
		"position": [sim.position.x, sim.position.y, sim.position.z], "speed_kmh": sim.speed_kmh(),
		"evidence": evidence_path, "evidence_sha256": FileAccess.get_sha256(evidence_path)}
	print("V15_AUDIT_PILOT_END ", JSON.stringify(result))
	return result
