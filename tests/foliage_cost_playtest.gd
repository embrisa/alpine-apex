extends "res://tests/foliage_playtest.gd"
## Diagnostic controls only; no production material switches or settings.
func stand_views(profile) -> void:
	await super.stand_views(profile)
	Engine.max_fps=0
	host.apply_quality(profile); assets.apply_quality(profile)
	camera.position=Vector3(-2.4,2.1,-4.8); camera.look_at(Vector3(.1,4.2,0))
	for i in 180: await process_frame
	forest.set_process(false)
	var mat: ShaderMaterial=assets.mesh(asset+"_lod0").surface_get_material(0)
	var original: Shader=mat.shader
	var opaque=Shader.new()
	opaque.code=original.code.replace("if(needles.a<.5) discard;","").replace("ALPHA=needles.a;","ALPHA=1.0;")
	var geometry=Shader.new()
	geometry.code=original.code.get_slice("void fragment()",0)+"""
void fragment() {
 float threshold=pc_lod_threshold(FRAGCOORD.xy);
 if(pc_lod_ranges.w==1.0) threshold=1.0-threshold;
 if(lod_coverage<threshold) discard;
 ALBEDO=vec3(.04,.15,.05); ROUGHNESS=.91; SPECULAR=.16;
 needle_transmission=.12;
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
"""
	for node in host.batches: node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for repetition in 3:
		for pair in [["production_cutout_no_shadows",original],["opaque_texture_control",opaque],["opaque_geometry_control",geometry]]:
			mat.shader=pair[1]
			for i in 180: await process_frame
			var frames=[]; var gpu=[]; var cpu=[]; var previous=Time.get_ticks_usec()
			for i in 360:
				assets.update_wind({"wind_velocity":Vector3(2.5,0,.8),"enabled":true},1.0/120,true)
				await process_frame
				var now=Time.get_ticks_usec(); frames.append((now-previous)/1000.0); previous=now
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			results.append({"repetition":repetition,"mode":pair[0],"frame_ms":Costs.stats(frames),"gpu_ms":Costs.stats(gpu),"cpu_ms":Costs.stats(cpu),"limitation":"Opaque controls change occlusion. Differences include depth/overdraw effects and are not additive pure shader timings."})
	mat.shader=original
