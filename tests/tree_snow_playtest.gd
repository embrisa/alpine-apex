extends "res://tests/planted_snow_playtest.gd"
## Close rendered inspection of permanent tree-base snow on all six faces.
func comparison_field():
	if not "--tree-preview" in OS.get_cmdline_user_args(): return super.comparison_field()
	var data = FileAccess.open("res://artifacts/planted_snow/tree_snow_preview.bin",FileAccess.READ).get_var(false)
	var preview = preload("res://scripts/world/generators/alpine_massif_v14.gd").new(849205174,false)
	preview.heights = data.heights; preview.tree_snow_height = data.tree_snow_height; preview.tree_snow_statistics = data.tree_snow_statistics
	preview.exposure_image = Image.create_from_data(preview.NX,preview.NZ,false,Image.FORMAT_RGBA8,data.exposure)
	for ob in data.obstacles: preview.add_obstacle(ob)
	preview.geology.restore(data.placements,data.geology_statistics)
	preview.height_checksum = data.height_sha256; preview.obstacle_checksum = data.obstacle_sha256
	return preview
func source_hashes() -> Dictionary:
	output = "res://artifacts/planted_snow/tree_views"
	DirAccess.make_dir_recursive_absolute(output)
	var hashes = super.source_hashes()
	hashes["tests/tree_snow_playtest.gd"] = FileAccess.get_sha256("res://tests/tree_snow_playtest.gd")
	return hashes

func ride(fixture: Dictionary) -> void:
	if fixture.name!="face_4_band_2": return
	game.active = false
	game.skier.hide()
	game.effects.reset()
	for face_id in 6:
		if "--inspect-lod" in OS.get_cmdline_user_args() and face_id>0: break
		var found = false
		for id in range(0,field.obstacles.size(),3):
			var p: Vector3 = field.obstacles[id].position
			var sector = posmod(roundi(wrapf(atan2(p.x,p.z)-field.face_phase,0,TAU)/(TAU/6)),6)
			if sector!=face_id: continue
			var rise: float = field.TreeSnow.sample_delta(field,field.tree_snow_height,p.x,p.z)
			var surrounding = 0.0
			for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
				surrounding += field.TreeSnow.sample_delta(field,field.tree_snow_height,p.x+direction.x*6.0,p.z+direction.y*6.0)*.25
			var prominence = rise-surrounding
			var n: Vector3 = field.contact_normal(p.x,p.z)
			if rise<.15 or prominence<.08 or prominence>.28 or n.y<.84 or field.nearby_obstacle_indices(p,9).size()>5: continue
			var downhill = Vector3(n.x,0,n.z).normalized()
			var across = Vector3.UP.cross(downhill)
			var eye = p-downhill*8.0+across*4.0
			eye.y = field.sample(eye.x,eye.z).height+1.45
			var hit: Dictionary = field.sweep_obstacle_contact(eye,p+Vector3.UP*.6)
			if not hit.is_empty() and hit.get("id",id)!=id: continue
			observer.position = eye; observer.look_at(p+Vector3.UP*.35); observer.make_current()
			label.text = "PHYSICAL TREE SNOW · FACE %d · %.0f cm local prominence"%[face_id+1,prominence*100]
			for frame in 100: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(output+"/face_%d.jpg"%face_id,.96)
			if "--side-views" in OS.get_cmdline_user_args():
				eye = p+across*9.0
				eye.y = field.sample(eye.x,eye.z).height+1.0
				observer.position = eye; observer.look_at(p+Vector3.UP*.30)
				for frame in 30: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(output+"/face_%d_side.jpg"%face_id,.96)
			if "--inspect-lod" in OS.get_cmdline_user_args():
				for chunk in game.world.terrain_chunks:
					var exact_mesh = ArrayMesh.new()
					exact_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,chunk.mesh.surface_get_arrays(0))
					chunk.mesh = exact_mesh
				for frame in 5: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(output+"/face_%d_exact.jpg"%face_id,.96)
				game.world.snow_material.set_shader_parameter("snow_geometry_debug",true)
				for frame in 5: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(output+"/face_%d_geometry.jpg"%face_id,.96)
			rows.append({"face":face_id,"tree_id":id,"position":[p.x,p.y,p.z],"physical_rise_m":rise,"prominence_6m":prominence})
			found = true
			break
		if not found: failures.append("No readable tree-base view on face %d"%face_id)
