extends SceneTree
const Terrain=preload("res://scripts/world/generators/alpine_massif_v11.gd")
const Cache=preload("res://scripts/world/mountain_cache_v11.gd")
var failures: Array=[]
var reports: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); printerr("FAIL ",label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/geology_v11")
	var seeds=[849205174] if "--quick" in OS.get_cmdline_user_args() else [849205174,0,1,42,12981,2147483647]
	for seed_value in seeds:
		print("GENERATE_GEOLOGY ",seed_value)
		var field=Terrain.new(seed_value)
		print("GEOLOGY_STATISTICS ",seed_value," ",field.geology.statistics.categories," faces=",field.geology.statistics.faces)
		check(field.geology.placements.size()>200,"Seed %d has mountain-wide mineral placements" % seed_value)
		check(field.geology.placements.is_read_only() and field.geology.placements[0].is_read_only(),"Completed geology layout is immutable")
		check(field.geology.statistics.max_stamp_m<=8.001,"Foundation changes stay within 8 m")
		for count in field.geology.statistics.faces: check(count>20,"All six faces contain geology")
		var grounded=true; var collision_complete=true
		for placed in field.geology.placements:
			var row: Dictionary=field.geology.catalog.records[placed.asset]
			for local in row.seating:
				var p: Vector3=placed.pose*local
				grounded=grounded and p.y<=float(field.sample(p.x,p.z).height)+.001
			if not placed.solid:
				var top: Vector3=placed.pose*Vector3(0,row.size_m.y,0)
				collision_complete=collision_complete and top.y-field.sample(top.x,top.z).height<=.101
		check(grounded,"Seed %d formation foundations intersect final terrain" % seed_value)
		check(collision_complete,"Every exposed obstacle has collision")
		var ice_connected=true
		for placed in field.geology.placements:
			if not placed.ice: continue
			var p: Vector3=placed.pose.origin
			var x=clampi(roundi((p.x-field.X_MIN)/4),0,field.NX-1)
			var z=clampi(roundi((p.z-field.Z_MIN)/4),0,field.NZ-1)
			ice_connected=ice_connected and field.exposure_image.get_pixel(x,z).g>.05
		check(ice_connected,"Glacier formations and fragments join their continuous ice patch")
		var finite=true
		var summit_height: float=field.spawn_point().y
		for h in field.heights: finite=finite and is_finite(h) and h<=summit_height+.01
		check(finite,"Seed %d retains a finite highest-point summit" % seed_value)
		var trees_clear=true
		for ob in field.obstacles: trees_clear=trees_clear and ob.tree and field.geology_clear(ob.position,ob.radius+1.9)
		check(trees_clear,"Trees and legacy rock cylinders do not overlap mineral formations")
		for face in field.faces:
			var continuous=true
			for radius in range(400,2601,100):
				var angle: float=face.heading+PI/6
				var a=Vector2(sin(angle-.00001),cos(angle-.00001))*radius
				var b=Vector2(sin(angle+.00001),cos(angle+.00001))*radius
				continuous=continuous and absf(field.sample(a.x,a.y).height-field.sample(b.x,b.y).height)<.3
			check(continuous,"Seed %d face %d joins its neighbour continuously" % [seed_value,face.index])
			for side in [-1,1]:
				var clear=true
				var previous=field.launch_point(face.heading)
				for z in range(32,2851,8):
					var x: float=face.gully_x(z,side) if z<1850 else face.glade_x(z,side)
					var p: Vector2=face.to_world(Vector2(x,z))
					var next=Vector3(p.x,field.sample(p.x,p.y).height,p.y)
					if not field.geology.collision.sweep(previous,next).is_empty(): clear=false
					previous=next
				check(clear,"Seed %d face %d side %d drainage is clear" % [seed_value,face.index,side])
		var cached={"heights":field.heights,"placements":field.geology.placements,"stats":field.geology.statistics,
			"exposure":field.exposure_image.get_data(),"obstacles":field.obstacles,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum}
		preload("res://tests/test_report.gd").write_var("res://artifacts/geology_v11/field_%d.bin" % seed_value,cached,false)
		reports.append({"seed":seed_value,"generation_ms":field.generation_ms,"statistics":field.geology.statistics,
			"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum})
		field=null
		if not "--quick" in OS.get_cmdline_user_args():
			var reconstructed=Cache.generate(seed_value)
			check(reconstructed.height_checksum==cached.height_sha256 and reconstructed.obstacle_checksum==cached.obstacle_sha256,"Seed %d independent cache bake repeats both fingerprints" % seed_value)
			reconstructed=null
			var warm=Cache.generate(seed_value)
			check(warm.cache_hit and warm.height_checksum==cached.height_sha256 and warm.obstacle_checksum==cached.obstacle_sha256,"Seed %d warm cache reconstructs both fingerprints" % seed_value)
			warm=null
	preload("res://tests/test_report.gd").write("res://artifacts/geology_v11/generation_tests.json",JSON.stringify({"failures":failures,"seeds":reports},"\t"))
	print("GEOLOGY_GENERATION ",reports.size()," seeds; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
