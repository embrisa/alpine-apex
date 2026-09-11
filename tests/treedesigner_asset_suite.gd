extends SceneTree
const Assets = preload("res://scripts/presentation/alpine_assets.gd")
const Lighting = preload("res://scripts/presentation/cloud_lighting.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var failures: Array = []
var checks = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func _initialize() -> void:
	var assets = Assets.new(Lighting.new(),Quality.preset(2))
	for variant in [1,2,3]:
		var previous = 0
		for lod in [0,1,2]:
			var mesh: Mesh = assets.mesh("td_spruce_%d_lod%d" % [variant,lod])
			var arrays = mesh.surface_get_arrays(0)
			var triangles = mesh.get_faces().size()/3
			check(mesh.get_surface_count()==1,"Variant %d LOD %d shares one material surface" % [variant,lod])
			check(mesh.get_aabb().position.y>=(-.26 if lod==2 else -.15) and absf(mesh.get_aabb().end.y-(10.75 if lod==2 else 10.5))<.1,"Variant %d LOD %d retains tree height envelope and atlas padding" % [variant,lod])
			if lod<2:
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
				var mask = {}
				for c in colors: mask[roundi(c.a*10)]=true
				check(mask.has(0) and mask.has(6) and mask.has(10),"Wood, foliage and snow masks survive import")
				var valid_uv = uv.size()==colors.size()
				for p in uv: valid_uv=valid_uv and p.x>=-.001 and p.x<=.688 and p.y>.06 and p.y<.66
				check(valid_uv,"Branch cluster IDs and pivots survive glTF axis/UV conversion")
				check(triangles<30000,"Variant %d LOD %d stays within 30k triangle ceiling" % [variant,lod])
				if lod==1: check(triangles<previous*.8,"Mid detail reduces geometry while preserving foliage positions")
			else: check(triangles==2,"Far representation is a two-triangle directional card")
			previous=triangles
	var registrations = assets.lighting.materials.size()
	for level in [0,1,2,0,2]: assets.apply_quality(Quality.preset(level))
	check(registrations==assets.lighting.materials.size(),"Quality changes do not duplicate tree materials")
	print("TREE_ASSET_RESULT checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
