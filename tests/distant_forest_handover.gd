extends "res://tests/distant_forest_review.gd"
## Current Meshy near/mid/card and canopy aid, with both background policies.
func capture_case():
	var poses=JSON.parse_string(FileAccess.get_file_as_string("res://art_source/trees/meshy_snow_v1/game_views.json"))
	var near_pose:Transform3D;var far_pose:Transform3D
	for pose in poses:
		if pose.id=="spruce_6m_snow":near_pose=str_to_var(pose.camera)
		if pose.id=="spruce_85m_snow":far_pose=str_to_var(pose.camera)
	far_pose.origin+=(far_pose.origin-near_pose.origin).normalized()*30
	for spec in [[7,1],[10,1],[7,0],[7,2]]:
		preset=spec[0];style=spec[1]
		game.set_graphics_preset(preset);game.display_settings.apply_viewport(root);Engine.max_fps=30
		game.forest_appearance.select(style);game.world.update_weather(game.weather.state,0,false)
		var label="p%d_%s"%[preset,game.forest_appearance.STYLES[style]]
		for aid in [0,100]:
			for selected in variants:
				variant=selected;apply_variant();camera.transform=near_pose
				game.world.scenery.density_forest.update_residency(camera.position)
				game.world.assets.foliage_sight.initialized=false
				for warm in 90:
					game.world.assets.update_foliage_sight(camera,camera.position-camera.basis.z*3,1.0/30,true,60,aid)
					await process_frame
				game.display_settings.reset_history()
				for frame in 110:
					camera.transform=near_pose.interpolate_with(far_pose,float(frame)/109)
					game.world.scenery.density_forest.update_residency(camera.position)
					game.world.assets.update_foliage_sight(camera,camera.position-camera.basis.z*3,1.0/30,true,60,aid)
					await process_frame
					if frame in [0,6,12,24,40,50,58,64,72,84,96,109]:
						await RenderingServer.frame_post_draw
						var path="%s_aid%d_%s_%03d.webp"%[label,aid,variant,frame]
						assert(root.get_texture().get_image().save_webp(output+"/"+path,true)==OK)
						views.append({"image":path,"camera":str(camera.global_transform),"frame":frame,"aid":aid,"nominal_tree_distance_m":lerpf(6,115,float(frame)/109),"aid_parameters":str(game.world.assets.foliage_sight.parameters)})
				print("DISTANT_HANDOVER ",label," aid=",aid," variant=",variant)
		case_reports.append({"label":label,"mid_to_card_m":64.0*game.graphics.tree_mid_m/280.0,"fade_half_width_m":5.0,"display":game.display_settings.report(root,pixels)})
func metadata(phase:String):
	return metadata_command(["capture","--root",ProjectSettings.globalize_path("res://"),"--scope",ProjectSettings.globalize_path("res://config/benchmark_metadata_scope.json"),"--producer","tests/distant_forest_handover.gd","--engine",OS.get_executable_path()],output+"/inputs_"+phase+".json")
