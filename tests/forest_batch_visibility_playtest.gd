extends SceneTree
## Deterministic moving-camera comparison. Readback runs are never FPS evidence.
const Scenery = preload("res://scripts/world/alpine_scenery.gd")
const Forest = preload("res://scripts/presentation/density_forest.gd")
const Assets = preload("res://scripts/presentation/alpine_assets.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var output = "res://artifacts/spatial_batch_visibility/visual"
var hosts = []
var forests = []
var libraries = []
var records = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	root.size=Vector2i(1280,720); Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(output)
	var env = WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color(.43,.57,.70)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_energy=.65
	root.add_child(env)
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-8,-32,0); sun.light_energy=1.7; sun.shadow_enabled=true; sun.directional_shadow_max_distance=160; root.add_child(sun)
	var camera=Camera3D.new(); root.add_child(camera); camera.current=true; camera.fov=75; camera.far=2400
	var ground=MeshInstance3D.new(); ground.mesh=PlaneMesh.new(); ground.mesh.size=Vector2(5000,5000)
	var mat=StandardMaterial3D.new(); mat.albedo_color=Color(.75,.83,.90); ground.material_override=mat; ground.position.y=-.05; root.add_child(ground)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/trees/manifest.json"))
	for cell in [192.0,Forest.FAR_CELL]:
		var host=Scenery.new(); root.add_child(host); host.dense_woodlands=true; host.quality=Quality.preset(2)
		host.assets=Assets.new(preload("res://scripts/presentation/cloud_lighting.gd").new(),host.quality)
		var forest=Forest.new(); host.add_child(forest); forest.set_process(false)
		var rng=RandomNumberGenerator.new(); rng.seed=193763
		for z in range(-36,37):
			for x in range(-36,37):
				if x in [-1,0,1]: continue
				var p=Vector3(x*18+rng.randf_range(-4,4),0,z*18+rng.randf_range(-4,4))
				var asset: String=manifest.assets[posmod(x*7+z*5,24)].id
				var scale_m=rng.randf_range(9,17)/float(host.assets.tree_record(asset).height_m)
				forest.add_tree(asset,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_m),p),22)
		# A 192 m reference is retained solely for this current render comparison.
		var regrouped={}
		for group in forest.far_groups.values():
			for pose in group.transforms:
				var key="%d:%d:%s" % [floori(pose.origin.x/cell),floori(pose.origin.z/cell),group.asset]
				if not regrouped.has(key): regrouped[key]={"asset":group.asset,"transforms":[],"height_m":group.height_m}
				regrouped[key].transforms.append(pose)
		forest.far_groups=regrouped
		await forest.finish(host,Callable()); host.apply_quality(host.quality)
		host.hide(); hosts.append(host); forests.append(forest); libraries.append(host.assets)
	for preset in [1,7,10]:
		var profile=Quality.numbered(preset)
		for i in 2: hosts[i].apply_quality(profile); libraries[i].apply_quality(profile)
		for frame in 240:
			var t=float(frame)/239
			# Fast travel crosses signed 32 m and distant-cell boundaries; yaw includes off-camera casters.
			camera.position=Vector3(sin(t*TAU)*40,3,lerpf(-400,400,t))
			camera.rotation=Vector3(-.08,sin(t*TAU*2)*2.6,0)
			for i in 2:
				forests[i].update_residency(camera.position)
				libraries[i].wind_time=t*12; libraries[i].wind_ready=false
				libraries[i].update_wind({"wind_velocity":Vector3(7,0,0),"enabled":true},0,true)
				libraries[i].update_foliage_sight(camera,camera.position+Vector3(0,0,-4),1.0/60,true,60,50 if frame<120 else 100)
			# Same frozen camera/wind/state in both native renders; no temporal reconstruction.
			for i in 2:
				hosts[1-i].hide(); hosts[i].show()
				await process_frame
				if frame%12==0 or frame==239:
					await RenderingServer.frame_post_draw
					var path=output+"/p%d_f%03d_%s.png" % [preset,frame,"before" if i==0 else "after"]
					root.get_texture().get_image().save_png(path)
			if frame%12==0 or frame==239: records.append({"preset":preset,"frame":frame,"camera":camera.position,"yaw":camera.rotation.y,"wind":7,"low_sun":true,"aid":50 if frame<120 else 100})
		print("BATCH_VISUAL preset=",preset," complete")
	FileAccess.open(output+"/receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"1280x720 native moving-camera stand; paired stills, no FPS claim","reference_cell":192,"candidate_cell":Forest.FAR_CELL,"records":records},"\t"))
	quit()
