extends "res://art_source/trees/meshy_snow_v1/prepare.gd"
## Matched close/whole-tree views of explicit GLB files; no forest or FPS claim.
func run():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="Shared")
	var paths=[];var output=OUT+"/quality_review";var smooth=false;var normal_map=true;var fit_longest=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):paths.append(arg.get_slice("=",1))
		if arg.begins_with("--review-output="):output=arg.get_slice("=",1)
		if arg=="--smooth":smooth=true
		if arg=="--no-normal-map":normal_map=false
		if arg=="--fit-longest":fit_longest=true
	assert(not paths.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(2560,1440);Engine.max_fps=30
	stage=Node3D.new();root.add_child(stage)
	var we=WorldEnvironment.new();environment=Environment.new();we.environment=environment
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.4,.55,.7)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(.72,.83,1);environment.ambient_light_energy=.42
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;stage.add_child(we)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-36,-32,0);sun.light_energy=1;sun.shadow_enabled=true;stage.add_child(sun)
	camera=Camera3D.new();stage.add_child(camera);camera.make_current();camera.fov=55
	var node=MeshInstance3D.new();stage.add_child(node)
	var clay=StandardMaterial3D.new();clay.albedo_color=Color(.6,.6,.6);clay.roughness=1;clay.cull_mode=BaseMaterial3D.CULL_DISABLED
	var receipt=[]
	for path in paths:
		var state=GLTFState.new();var document=GLTFDocument.new();assert(document.append_from_file(path,state)==OK,path)
		var imported=document.generate_scene(state);var parts=gather(imported);assert(parts.size()==1)
		var a:Array=parts[0].arrays;var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		var box=AABB(v[0],Vector3.ZERO)
		for p in v:box=box.expand(p)
		var center=Vector2.ZERO;var count=0
		for p in v:
			if p.y<box.position.y+box.size.y*.015:center+=Vector2(p.x,p.z);count+=1
		center/=maxi(1,count)
		if fit_longest:
			for i in v.size():v[i]=(v[i]-box.get_center())*(12.0/box.size[box.get_longest_axis_index()])+Vector3(0,6,0)
		else:
			for i in v.size():v[i]=(v[i]-Vector3(center.x,box.position.y,center.y))*(12.0/box.size.y)
		a[Mesh.ARRAY_VERTEX]=v
		if smooth:
			var n:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
			var original=n.duplicate();var groups={}
			for i in v.size():
				if not groups.has(v[i]):groups[v[i]]=[]
				groups[v[i]].append(i)
			for indices in groups.values():
				for i in indices:
					var sum=Vector3.ZERO
					for j in indices:
						if original[i].dot(original[j])>0.05:sum+=original[j]
					n[i]=sum.normalized()
			a[Mesh.ARRAY_NORMAL]=n
		var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);mesh.surface_set_material(0,parts[0].material)
		if smooth:
			var st=SurfaceTool.new();st.create_from(mesh,0);st.generate_tangents();mesh=st.commit()
		if not normal_map:mesh.surface_get_material(0).normal_enabled=false
		node.mesh=mesh;imported.free()
		var name_value=path.get_base_dir().get_file()+"_"+path.get_file().get_basename()
		var row={"source":path,"triangles":mesh.surface_get_array_index_len(0)/3,"vertices":mesh.surface_get_array_len(0),"smoothed_normals":smooth,"normal_map":normal_map,"fit_longest":fit_longest,"captures":[]}
		for mode_value in ["texture","clay"]:
			node.material_override=clay if mode_value=="clay" else null
			for view in ["whole","branch"]:
				camera.position=Vector3(7,7,17) if view=="whole" else Vector3(2,6,4)
				camera.look_at(Vector3(0,6,0))
				for i in 12:await process_frame
				await RenderingServer.frame_post_draw
				var file=output+"/"+name_value+"_"+mode_value+"_"+view+".webp"
				assert(root.get_texture().get_image().save_webp(file,true)==OK);row.captures.append(file)
		print("MESHY_QUALITY ",name_value," triangles=",row.triangles);receipt.append(row)
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"));quit()
