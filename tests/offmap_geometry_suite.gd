extends SceneTree
## Actual mesh seams, protected collar, staged construction, and source immutability.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Data = preload("res://scripts/world/wilderness_data.gd")
const Apron = preload("res://scripts/world/alpine_backdrop.gd")
const Panorama = preload("res://scripts/world/alpine_wilderness.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var checks = 0
var failures: Array = []
var stages = 0
class Assets:
	extends RefCounted
	func terrain_material(_bias: float = 0.0,_scale: float = .075) -> ShaderMaterial: return ShaderMaterial.new()

func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func checkpoint(_label: String,_percent: float) -> void:
	stages += 1
	await process_frame

func run() -> void:
	var shared_asset=load(Data.DEFAULT_ASSET)
	var authored_buffer: PackedFloat32Array=shared_asset.levels[2].groups[0].buffer.duplicate()
	for seed in [849205174,638201943]:
		stages = 0
		var field = Definition.generate(seed,15)
		var source = preload("res://scripts/world/mountain_data.gd").new()
		source.generate(field,seed)
		field.build_material_map()
		var before = [field.heights.to_byte_array(),var_to_bytes(field.obstacles),field.material_image.get_data(),source.height_image.get_data(),source.environment_image.get_data()]
		var apron = Apron.new(); var panorama = Panorama.new()
		root.add_child(apron); root.add_child(panorama)
		panorama.prepare(field,source)
		await apron.build(field,Assets.new(),source,panorama.data,checkpoint)
		panorama.apron_sources = apron.triangle_sources
		await panorama.apply_quality(Quality.preset(2),checkpoint)
		check(panorama.data.asset==shared_asset and shared_asset.levels[2].groups[0].buffer==authored_buffer,"Seed %d reuses the same unmodified authored background asset" % seed)
		check(panorama.placement.adapted_instances==0 if seed==849205174 else panorama.placement.adapted_instances>0,"Seed %d adapts baked triangle anchors only when the map connection changes" % seed)
		check(stages>=52,"Seed %d builds apron/ridges through real loading checkpoints" % seed)
		var baseline = preload("res://tests/fixtures/offmap_v1/alpine_backdrop.gd").new()
		root.add_child(baseline); baseline.build(field,Assets.new(),source)
		var retained_cells=0
		for z in range(-3072,3072,32):
			for x in range(-3072,3072,32):
				retained_cells+=int(Data.Footprint.owns_cell(Vector2(x+16,z+16)))
		check(retained_cells*128+apron.triangles<4718592+baseline.triangles,"Seed %d cuts unused physical corners and reduces the combined terrain triangle budget" % seed)
		var boundary: Dictionary = {}
		var physical_edge_vertices: Dictionary = {}
		var physical_match = true
		var protected_match = true
		var apron_presentation = true
		for node in apron.get_children():
			apron_presentation = apron_presentation and node.gi_mode==GeometryInstance3D.GI_MODE_DISABLED and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var arrays = node.mesh.surface_get_arrays(0)
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				var v: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
				var p = Vector2(v.x,v.z)
				var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][i]
				if absf(p.x)==4096.0 or absf(p.y)==4096.0: boundary[Vector2i(p)] = [v.y,n,arrays[Mesh.ARRAY_COLOR][i]]
				if apron._on_surface_edge(p):
					physical_edge_vertices[Vector2i(p)]=true
					physical_match = physical_match and absf(v.y-field.sample(p.x,p.y).height)<.001 and n.distance_to(field.render_normal(p.x,p.y))<.002
				if panorama.data.blend_at(p)==0.0 and not apron._on_surface_edge(p):
					protected_match = protected_match and absf(v.y-source.sample_height(p))<.001 and arrays[Mesh.ARRAY_TEX_UV][i].x==0.0
		check(physical_match and protected_match,"Seed %d preserves physical-edge stitches and protected collar" % seed)
		var complete_perimeter=true
		for z in range(-3072,3072,32):
			for x in range(-3072,3072,32):
				var p=Vector2(x,z)
				if not Data.Footprint.owns_cell(p+Vector2.ONE*16): continue
				var corners=[p,p+Vector2(32,0),p+Vector2(32,32),p+Vector2(0,32)]
				for side in 4:
					var a: Vector2=corners[side]; var b: Vector2=corners[(side+1)%4]
					if not Data.Footprint.edge_segment(a,b): continue
					for i in 9: complete_perimeter=complete_perimeter and physical_edge_vertices.has(Vector2i(a.lerp(b,float(i)/8)))
		check(complete_perimeter,"Seed %d stitches every 4 m vertex around the complete irregular perimeter" % seed)
		check(apron_presentation,"Seed %d apron has no shadows or GI contribution" % seed)
		var seen: Dictionary = {}
		var matched = true
		for node in panorama.ridge_nodes():
			var arrays = node.mesh.surface_get_arrays(0)
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				var v: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
				var p = Vector2(v.x,v.z)
				if not (absf(p.x)==4096.0 or absf(p.y)==4096.0): continue
				if p.x < -4096 or p.x > 4096 or p.y < -4096 or p.y > 4096: continue
				var key = Vector2i(p); seen[key] = true
				if not boundary.has(key): matched = false; continue
				matched = matched and absf(v.y-boundary[key][0])<.001 and arrays[Mesh.ARRAY_NORMAL][i].distance_to(boundary[key][1])<.002
				matched = matched and arrays[Mesh.ARRAY_COLOR][i].is_equal_approx(boundary[key][2])
		check(matched and seen.size()==1024,"Seed %d actual apron/panorama meshes match all 1024 shared positions, normals and masks" % seed)
		var shared_vertices: Dictionary = {}
		var all_joins = true
		for renderer in [apron,panorama]:
			for node in (renderer.ridge_nodes() if renderer==panorama else renderer.get_children()):
				var arrays = node.mesh.surface_get_arrays(0)
				for i in arrays[Mesh.ARRAY_VERTEX].size():
					var v: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
					var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][i]
					var mask: Color = arrays[Mesh.ARRAY_COLOR][i]
					all_joins = all_joins and v.is_finite() and n.is_finite() and absf(n.length()-1.0)<.002
					var key = Vector2i((Vector2(v.x,v.z)*1000.0).round())
					if shared_vertices.has(key):
						var other: Array = shared_vertices[key]
						all_joins = all_joins and absf(v.y-other[0])<.003 and n.distance_to(other[1])<.002 and mask.is_equal_approx(other[2])
					else: shared_vertices[key] = [v.y,n,mask]
		check(all_joins,"Seed %d has finite unit normals and matching vertices across every apron chunk, ridge sector and radial band" % seed)
		check(before==[field.heights.to_byte_array(),var_to_bytes(field.obstacles),field.material_image.get_data(),source.height_image.get_data(),source.environment_image.get_data()],"Seed %d leaves every physical and stored scenery array byte-identical" % seed)
		check(panorama.data.height_cache.is_empty() and panorama.data.sample_cache.is_empty(),"Seed %d releases construction caches after upload" % seed)
		baseline.queue_free(); apron.queue_free(); panorama.queue_free()
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://artifacts/offmap_v3")
	FileAccess.open("res://artifacts/offmap_v3/geometry.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
