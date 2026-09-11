extends "res://tests/planted_snow_playtest.gd"

func source_hashes() -> Dictionary:
	output = "res://artifacts/planted_snow/track_diagnostic"
	DirAccess.make_dir_recursive_absolute(output)
	return super.source_hashes()

func ride(fixture: Dictionary) -> void:
	if fixture.name!="face_4_band_2": return
	reset_fixture(fixture)
	var controls = RiderInput.new(); controls.tuck = 1.0
	for frame in 61:
		controls.steer = Probe.steering(fixture,frame/30.0)
		for tick in 4:
			game.previous_position = game.sim.position
			game.sim.step(DT,controls,game.world.ski_surface)
			game.skier.step_animation(DT,game.sim,controls,field)
		game.intent = controls; game._process(1.0/30); place_observer()
		await process_frame
	for mode in ["both","powder_only","ribbon_only","bare"]:
		game.effects.snow_tracks.visible = mode in ["both","ribbon_only"]
		game.effects.powder_surface._visibility(mode in ["both","powder_only"])
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(output+"/"+mode+".jpg",.96)
	game.effects.powder_surface._visibility(true)
	game.effects.powder_surface.patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output+"/powder_no_self_shadow.jpg",.96)
	game.world.sun.shadow_enabled = false
	game.world.environment.fog_enabled = false
	game.world.environment.volumetric_fog_enabled = false
	game.effects.powder_surface.material.set_shader_parameter("powder_loose_depth",0.0)
	game.effects.powder_surface.material.set_shader_parameter("snow_geometry_debug",true)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output+"/plain_cut.jpg",.96)
	var geometric_shader = Shader.new()
	geometric_shader.code = FileAccess.get_file_as_string("res://assets/graphics/powder_surface.gdshader").replace('#include "res://assets/graphics/alpine_surface_fragment.gdshaderinc"','void fragment() { ALBEDO=vec3(.45,.5,.56); ROUGHNESS=1.; NORMAL=normalize(cross(dFdx(VERTEX),dFdy(VERTEX))); }')
	game.effects.powder_surface.material.shader = geometric_shader
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output+"/geometric_normals.jpg",.96)
	var track = game.effects.snow_tracks
	var stamps = []
	for i in track.written:
		stamps.append(Array(track.gpu_stamps.slice(i*8,i*8+8)))
	FileAccess.open(output+"/stamps.json",FileAccess.WRITE).store_string(JSON.stringify({"center":str(game.effects.powder_surface.center),"stamps":stamps},"\t"))
	RenderingServer.call_on_render_thread(read_atlas)
	for frame in 4: await process_frame
	rows.append({"exact_surface":track.material.get_shader_parameter("exact_surface"),"surface_size":str(track.material.get_shader_parameter("surface_size")),"powder":game.effects.powder_surface.budget(),"contact_depths":[game.sim.skis[0].penetration,game.sim.skis[1].penetration],"track_count":track.written})

func read_atlas() -> void:
	var powder = game.effects.powder_surface
	var bytes: PackedByteArray = powder.rd.texture_get_data(powder.surface_rid,0)
	FileAccess.open(output+"/atlas.rgh",FileAccess.WRITE).store_buffer(bytes)
