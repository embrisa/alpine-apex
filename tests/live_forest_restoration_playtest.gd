extends "res://tests/colorful_forest_playtest.gd"
## Short actual-Standard review of the restored live forest. Readbacks are
## visual evidence only; they neither measure performance nor alter the terrain.

const LIVE_FAMILIES := ["spruce", "fir", "pine", "birch", "dead", "broken", "golden", "maple"]
const REVIEW_FAMILIES := ["spruce", "golden"]
const LIVE_ASSET_COUNT := 30

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
	# Keep the target in its normal populated stand. The chosen heading only
	# avoids a foreground canopy hiding it; it never hides production instances.
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
			if lateral < 5.5:
				score += (5.5 - lateral) * (1.0 + (distance_m - depth) / distance_m)
		if score < best_score:
			best_score = score
			best = direction
	return best

func capture_distance(id: String, family: String, point: Vector3, distance_m: float, expected_lod: String, label: String, direction: Vector2) -> void:
	var record: Dictionary = game.world.assets.tree_record(id)
	assert(not bool(record.get("premium_tree", false)), "Premium live tree remained active: " + id)
	var height_m := float(record.get("height_m", 8.0))
	var camera_height := clampf(height_m * 0.62, 5.5, 13.0)
	aim(point, Vector3(direction.x * distance_m, camera_height, direction.y * distance_m), height_m * 0.52)
	await settle_live_residency()
	await capture(label)
	var lod: String = str({"near": "0", "mid": "1", "far": "2"}.get(expected_lod, "1"))
	var material: ShaderMaterial = game.world.assets.mesh(id + "_lod" + lod).surface_get_material(0)
	assert(material != null and (material.resource_name.begins_with("FC_") or material.shader.resource_path.contains("pc_")), "Live production material missing for " + id)
	var batches := resident_batches(id)
	if expected_lod in ["near", "mid", "far"]:
		assert(int(batches[expected_lod]) > 0, "Live renderer did not populate the %s LOD for %s" % [expected_lod, id])
	observations.append({"family": family, "asset": id, "distance_m": distance_m, "expected_lod": expected_lod,
		"batches": batches, "premium_tree": false, "material": material.resource_name,
		"camera": str(camera.global_transform), "view_direction": [direction.x, direction.y],
		"live_population_preserved": game.world.scenery.family_counts})

func mountain_views() -> void:
	var high = Quality.numbered(7)
	game.world.assets.apply_quality(high)
	game.world.scenery.apply_quality(high)
	# Keep the evidence on the actual High preset's production bands. This avoids
	# treating an arbitrary close-up as a LOD transition and keeps every camera
	# safely outside the target's canopy.
	var dither_half_width_m: float = 5.0
	var near_distance_m: float = maxf(20.0, high.tree_near_m - 20.0)
	var mid_distance_m: float = (high.tree_near_m + high.tree_mid_m) * 0.5
	var far_distance_m: float = minf(high.tree_mid_m + 30.0, high.tree_far_m - 20.0)
	assert(near_distance_m < high.tree_near_m and mid_distance_m > high.tree_near_m and mid_distance_m < high.tree_mid_m and far_distance_m > high.tree_mid_m, "High preset must expose ordered live forest LOD bands")
	var lod_bands_m := {"near_to_mid": high.tree_near_m, "mid_to_far": high.tree_mid_m, "draw_distance": high.tree_far_m, "dither_half_width": dither_half_width_m}
	var catalog: PackedStringArray = game.world.assets.tree_ids()
	assert(catalog.size() == LIVE_ASSET_COUNT, "Live catalog must restore all 30 pre-premium assets")
	var catalog_families := {}
	for id in catalog:
		var record: Dictionary = game.world.assets.tree_record(id)
		assert(not bool(record.get("premium_tree", false)), "Premium catalog entry remained active: " + id)
		catalog_families[record.family] = int(catalog_families.get(record.family, 0)) + 1
	var restored_families: Array = catalog_families.keys()
	var expected_families: Array = LIVE_FAMILIES.duplicate()
	restored_families.sort()
	expected_families.sort()
	assert(restored_families == expected_families, "Live catalog families differ from the pre-premium forest")
	observations.append({"catalog_assets": catalog.size(), "catalog_families": catalog_families,
		"premium_asset_count": 0, "review_families": REVIEW_FAMILIES, "lod_bands_m": lod_bands_m})
	var forest = game.world.preparation.forest
	var origin := Vector3(1608, field.sample(1608, 1416).height, 1416)
	var selected := {}
	var nearest := {}
	for index in forest.positions.size():
		var id: String = forest.assets[forest.asset_indices[index]]
		var family := id.get_slice("_", 1)
		if family not in LIVE_FAMILIES:
			continue
		var distance: float = forest.positions[index].distance_squared_to(origin)
		if not nearest.has(family) or distance < nearest[family]:
			nearest[family] = distance
			selected[family] = index
	assert(selected.size() == LIVE_FAMILIES.size(), "Standard forest must expose every restored family")
	for family in REVIEW_FAMILIES:
		var index: int = selected[family]
		var id: String = forest.assets[forest.asset_indices[index]]
		var point: Vector3 = forest.positions[index]
		var direction := unobscured_view_direction(point, far_distance_m)
		await capture_distance(id, family, point, near_distance_m, "near", "%s_near" % family, direction)
		await capture_distance(id, family, point, mid_distance_m, "mid", "%s_mid" % family, direction)
		await capture_distance(id, family, point, far_distance_m, "far", "%s_far" % family, direction)
	var spruce_index: int = selected.spruce
	var spruce_id: String = forest.assets[forest.asset_indices[spruce_index]]
	var spruce_point: Vector3 = forest.positions[spruce_index]
	# These chronological samples cross the live dither bands while remaining a
	# short rendered review, rather than a benchmark or a full descent.
	for transition in [{"name": "near_mid", "start": high.tree_near_m + dither_half_width_m, "end": high.tree_near_m - dither_half_width_m}, {"name": "mid_far", "start": high.tree_mid_m + dither_half_width_m, "end": high.tree_mid_m - dither_half_width_m}]:
		var transition_direction := unobscured_view_direction(spruce_point, maxf(float(transition.start), float(transition.end)))
		for frame in 7:
			var distance_m: float = lerpf(float(transition.start), float(transition.end), float(frame) / 6.0)
			await capture_distance(spruce_id, "spruce", spruce_point, distance_m, "transition", "%s_%02d" % [transition.name, frame], transition_direction)
		observations.append({"transition": transition.name, "asset": spruce_id, "from_m": transition.start, "to_m": transition.end,
			"renderer": "actual Standard mountain density_forest batches"})
	print("LIVE_FOREST_RESTORATION_RENDER ", JSON.stringify({"families": LIVE_FAMILIES, "captures": captures.size(), "renderer": "actual Standard mountain density_forest"}))
