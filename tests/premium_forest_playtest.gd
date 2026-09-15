extends "res://tests/colorful_forest_playtest.gd"
## Actual Standard-mountain production renderer review for the complete premium
## catalog. Readbacks are visual evidence only and never performance timing.

const PREMIUM_FAMILIES := ["spruce", "fir", "pine", "birch", "dead", "broken", "golden", "maple"]

func resident_batches(id: String) -> Dictionary:
	var result := {"near": 0, "mid": 0, "far": 0, "shadow": 0}
	for batch in game.world.scenery.batches:
		if batch.multimesh.mesh.get_meta("forest_asset", "") != id:
			continue
		var label: String = str({0: "near", 1: "mid", 2: "far", 5: "shadow"}.get(int(batch.get_meta("art_lod", 0)), ""))
		if not label.is_empty():
			result[label] += 1
	return result

func settle_live_residency() -> void:
	var forest = game.world.scenery.density_forest
	forest.update_residency(camera.global_position)
	for frame in 24:
		forest.update_residency(camera.global_position)
		await process_frame

func unobscured_view_direction(point: Vector3, distance_m: float) -> Vector2:
	# Keep the target inside its normal, populated Standard stand.  We only choose
	# the least-blocked of twelve real camera headings, rather than hiding nearby
	# instances or presenting an isolated asset gallery as a live-game view.
	var trees = field.tree_data
	var best_score := INF
	var best := Vector2(0, -1)
	for heading in 12:
		var angle := TAU * float(heading) / 12.0
		var direction := Vector2(sin(angle), cos(angle))
		var score := 0.0
		for other_index in trees.nearby(point, distance_m + 24.0):
			var other: Vector3 = trees.positions[other_index] - point
			var depth := Vector2(other.x, other.z).dot(direction)
			if depth <= 1.0 or depth >= distance_m - 1.0:
				continue
			var lateral := absf(Vector2(other.x, other.z).cross(direction))
			# A soft cylinder accounts for the target silhouette and the neighbouring
			# canopy.  Prefer a clear sight line but retain all production instances.
			if lateral < 5.5:
				score += (5.5 - lateral) * (1.0 + (distance_m - depth) / distance_m)
		if score < best_score:
			best_score = score
			best = direction
	return best

func capture_distance(id: String, family: String, point: Vector3, distance_m: float, expected_lod: String, label: String, direction: Vector2) -> void:
	var record: Dictionary = game.world.assets.tree_record(id)
	var height_m := float(record.get("height_m", 8.0))
	var camera_height := clampf(height_m * 0.62, 5.5, 13.0)
	aim(point, Vector3(direction.x * distance_m, camera_height, direction.y * distance_m), height_m * 0.52)
	await settle_live_residency()
	await capture(label)
	var lod: String = str({"near": "0", "mid": "1", "far": "2"}.get(expected_lod, "1"))
	var material: ShaderMaterial = game.world.assets.mesh(id + "_lod" + lod).surface_get_material(0)
	assert(material != null and (material.resource_name.begins_with("FC_") or material.shader.resource_path.contains("pc_")), "Live production material missing for " + id)
	observations.append({"family": family, "asset": id, "distance_m": distance_m, "expected_lod": expected_lod,
		"batches": resident_batches(id), "premium_tree": bool(game.world.assets.tree_record(id).get("premium_tree", false)),
		"material": material.resource_name, "camera": str(camera.global_transform), "view_direction": [direction.x, direction.y],
		"live_population_preserved": game.world.scenery.family_counts})

func mountain_views() -> void:
	var high = Quality.numbered(7)
	game.world.assets.apply_quality(high)
	game.world.scenery.apply_quality(high)
	var forest = game.world.preparation.forest
	var origin := Vector3(1608, field.sample(1608, 1416).height, 1416)
	var selected := {}
	var nearest := {}
	for index in forest.positions.size():
		var id: String = forest.assets[forest.asset_indices[index]]
		var family := id.get_slice("_", 1)
		if family not in PREMIUM_FAMILIES:
			continue
		var distance: float = forest.positions[index].distance_squared_to(origin)
		if not nearest.has(family) or distance < nearest[family]:
			nearest[family] = distance
			selected[family] = index
	assert(selected.size() == PREMIUM_FAMILIES.size(), "Standard forest must expose every premium family")
	for family in PREMIUM_FAMILIES:
		var index: int = selected[family]
		var id: String = forest.assets[forest.asset_indices[index]]
		var point: Vector3 = forest.positions[index]
		assert(bool(game.world.assets.tree_record(id).get("premium_tree", false)), "Standard forest chose a non-premium asset: " + id)
		var direction := unobscured_view_direction(point, 100.0)
		# 18 m remains inside the dense-forest near band, but outside the crown
		# volume for a useful player-scale whole-tree inspection.
		await capture_distance(id, family, point, 18.0, "near", "%s_near" % family, direction)
		await capture_distance(id, family, point, 38.0, "mid", "%s_mid" % family, direction)
		await capture_distance(id, family, point, 100.0, "far", "%s_far" % family, direction)
	# Chronological samples cross the production dense-forest dither bands. The
	# final photos use a real selected tree and the resident game batches above.
	for transition in [{"name": "near_mid", "start": 30.0, "end": 5.0}, {"name": "mid_far", "start": 82.0, "end": 48.0}]:
		var index: int = selected.spruce
		var id: String = forest.assets[forest.asset_indices[index]]
		var point: Vector3 = forest.positions[index]
		var direction := unobscured_view_direction(point, 82.0)
		for frame in 7:
			var distance_m: float = lerpf(float(transition.start), float(transition.end), float(frame) / 6.0)
			await capture_distance(id, "spruce", point, distance_m, "transition", "%s_%02d" % [transition.name, frame], direction)
		observations.append({"transition": transition.name, "asset": id, "from_m": transition.start, "to_m": transition.end,
			"renderer": "actual Standard mountain density_forest batches"})
