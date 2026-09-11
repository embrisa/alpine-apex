extends SceneTree
## Portable mesh/texture and equipment origin contracts for the detailed set.
var checks = 0
var failures: Array[String] = []
func _initialize(): call_deferred("run")
func check(value: bool,label: String):
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func mesh_nodes(node: Node) -> Array:
	var result: Array = [node] if node is MeshInstance3D else []
	for child in node.get_children(): result.append_array(mesh_nodes(child))
	return result
func artwork_is_mirrored(right: Mesh,left: Mesh) -> bool:
	# Match UV landmarks to reflected positions, independent of exported vertex order.
	var expected: Dictionary = {}
	var original=right.surface_get_arrays(0)
	for i in range(original[Mesh.ARRAY_VERTEX].size()):
		var uv: Vector2=original[Mesh.ARRAY_TEX_UV][i]
		var key=Vector2i(roundi(uv.x*100000),roundi(uv.y*100000))
		var p: Vector3=original[Mesh.ARRAY_VERTEX][i]
		if not expected.has(key): expected[key]=[]
		expected[key].append(Vector3(-p.x,p.y,p.z))
	var mirrored=left.surface_get_arrays(0)
	for i in range(mirrored[Mesh.ARRAY_VERTEX].size()):
		var uv: Vector2=mirrored[Mesh.ARRAY_TEX_UV][i]
		var key=Vector2i(roundi(uv.x*100000),roundi(uv.y*100000))
		var p: Vector3=mirrored[Mesh.ARRAY_VERTEX][i]
		var found=false
		for candidate in expected.get(key,[]):
			if p.distance_to(candidate)<.002: found=true; break
		if not found: return false
	return true
func run():
	var bounds: Dictionary = {}
	var total = 0
	for spec in [["ski","ski_detailed_v1",1],["ski_left","ski_detailed_v1_left",1],["binding","binding_detailed_v2",2],["pole","pole_detailed_v1",2]]:
		var id: String=spec[0]
		var scene = load("res://assets/graphics/models/%s.glb"%spec[1]).instantiate()
		root.add_child(scene)
		var nodes = mesh_nodes(scene)
		check(nodes.size()==1,id+" is one portable equipment mesh")
		var mesh_node: MeshInstance3D = nodes[0]
		check(mesh_node.global_transform.is_equal_approx(Transform3D.IDENTITY),id+" has baked transforms for mesh extraction")
		var mesh: Mesh = mesh_node.mesh
		var triangles = mesh.get_faces().size()/3
		total += triangles*spec[2]
		check(triangles<=12100 and triangles>500,id+" has a bounded detailed triangle count")
		var pbr = false
		for i in range(mesh.get_surface_count()):
			var mat = mesh.surface_get_material(i)
			if id=="binding": check(not mat.resource_name.contains("Riser"),"Binding has no platform or column material")
			if mat is StandardMaterial3D and mat.albedo_texture and mat.normal_texture and mat.roughness_texture:
				pbr = mat.albedo_texture.get_width()<=2048 and mat.normal_texture.get_width()<=2048
		check(pbr,id+" retains bounded albedo, normal and roughness textures")
		bounds[id] = mesh.get_aabb()
		if id=="binding":
			var mounts = [0,0]
			for surface in mesh.get_surface_count():
				for point in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					if absf(point.x)>.055 or absf(point.y)>.0001: continue
					if point.z>.13 and point.z<.23: mounts[0] += 1
					if point.z>-.16 and point.z<-.06: mounts[1] += 1
			check(mounts[0]>10 and mounts[1]>10,"Both toe and heel mounting patches are flush, not just the overall lowest vertex")
		scene.queue_free()
	check(total<=48200,"Complete paired equipment stays below 48,200 triangles")
	check(absf(bounds.ski.position.z+1.02)<.02 and absf(bounds.ski.end.z-1.15)<.02,"Ski retains the existing visual fore/aft extent")
	check(absf(bounds.ski.position.y+.016)<.003,"Ski base retains the contact origin")
	check(bounds.ski.size.x>=.10 and bounds.ski.size.x<=.15,"Ski keeps a plausible narrow sidecut")
	check(absf(bounds.pole.position.y+1.18)<.015 and absf(bounds.pole.end.y-.015)<.005,"Pole keeps its grip pivot and tip length")
	check(absf(bounds.binding.position.y)<.001 and bounds.binding.end.y<.080,"Binding housing rests on its base with no elevated spacer")
	var skier = preload("res://scripts/presentation/skier_visual.gd").new()
	root.add_child(skier)
	await process_frame
	check(skier.skis.size()==2 and skier.poles.size()==2,"Rider assembles two independent skis and poles")
	check(skier.skis[0].mesh!=skier.skis[1].mesh and skier.poles[0].mesh==skier.poles[1].mesh,"Skis have distinct handed meshes while poles share geometry")
	check(skier.skis[0].mesh.surface_get_material(0)==skier.skis[1].mesh.surface_get_material(0),"Left and right skis share the same PBR material and textures")
	check(artwork_is_mirrored(skier.skis[0].mesh,skier.skis[1].mesh),"Every left ski UV landmark matches the mirrored right ski within 2 mm")
	check(skier.skis[0].mesh.surface_get_material(0).shader==preload("res://assets/graphics/equipment_lit.gdshader") and skier.poles[0].mesh.surface_get_material(0).shader==preload("res://assets/graphics/equipment_lit.gdshader"),"Equipment conversion retains two-sided surfaces")
	for i in range(2):
		check(skier.skis[i].get_child(0).position.is_equal_approx(Vector3(0,0,-.15)) and skier.skis[i].get_child(1).position.is_equal_approx(Vector3(0,.017,-.15)),"Binding rests directly on ski and boot sits on its low seat")
	skier.queue_free()
	await process_frame
	print("EQUIPMENT_ASSET_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"paired_triangles":total}))
	quit(0 if failures.is_empty() else 1)
