extends SceneTree
const Surface=preload("res://scripts/art/flavor_test_surface.gd")
const Props=preload("res://scripts/world/prop_collision_surface.gd")
const Sim=preload("res://scripts/core/ski_simulation.gd")
var failures: Array=[]
var checks=0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); printerr("FAIL: ",label)
	else: print("PASS: ",label)

func run() -> void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/flavor_v1/manifest.json"))
	check(manifest.assets.size()==12,"Twelve distinct assets are present")
	var world=Node3D.new(); root.add_child(world)
	var terrain=Surface.new(); var surface=Props.new(terrain)
	check(surface.sample(3,15)==terrain.sample(3,15),"Adapter preserves exact terrain sampling")
	check(surface.contact_normal(4,40).is_equal_approx(terrain.contact_normal(4,40)),"Adapter preserves support normals")
	for record in manifest.assets:
		for model in record.models:
			check(FileAccess.get_sha256("res://"+model.path)==model.sha256,record.id+" export hash")
			var instance=load("res://"+model.path).instantiate()
			check(_triangles(instance)==model.triangles,record.id+" imported triangle count")
			check(_shared_textures(instance),record.id+" imported materials reuse shared textures")
			instance.free()
		var prop=load("res://assets/graphics/flavor_v1/scenes/"+record.id+".tscn").instantiate()
		world.add_child(prop); prop.bind_surface(surface)
		check(prop.get_node("SolidParts").get_child_count()==record.colliders.size(),record.id+" Jolt and solver share shape count")
		check(surface.groups.size()==1,record.id+" registered once")
		prop.bind_surface(surface); check(surface.groups.size()==1,record.id+" rebind is idempotent")
		prop.free(); check(surface.groups.is_empty(),record.id+" unregisters on removal")
	for kind in ["start_gate","finish_gate"]:
		var gate=load("res://assets/graphics/flavor_v1/scenes/"+kind+".tscn").instantiate()
		world.add_child(gate); gate.bind_surface(surface)
		check(surface.sweep_obstacle(Vector3(0,0,-10),Vector3(0,0,10)).is_empty(),kind+" center passage clear")
		check(surface.sweep_obstacle(Vector3(0,0,10),Vector3(0,0,-10)).is_empty(),kind+" reverse passage clear")
		for x in [-4.6,4.6]:
			check(surface.sweep_obstacle(Vector3(x,0,-10),Vector3(x,0,10)).is_empty(),kind+" full rider fits near edge")
		for x in [-5.6,5.6]:
			var hit=surface.sweep_obstacle_contact(Vector3(x,0,-10),Vector3(x,0,10))
			check(not hit.is_empty() and hit.reason=="GATE IMPACT" and hit.fraction<.5,kind+" support blocks high-speed sweep")
		var overhead=surface.sweep_obstacle_contact(Vector3(0,3,-10),Vector3(0,3,10))
		check(not overhead.is_empty(),kind+" crossbeam catches airborne rider")
		var pose=Transform3D(Basis(Vector3.UP,.8),Vector3(22,terrain.sample(22,30).height,30))
		gate.transform=pose; gate.sync_collision()
		check(surface.sweep_obstacle(pose*Vector3(0,0,-8),pose*Vector3(0,0,8)).is_empty(),kind+" rotated passage clear")
		check(not surface.sweep_obstacle(pose*Vector3(5.6,0,-8),pose*Vector3(5.6,0,8)).is_empty(),kind+" rotated support blocks")
		gate.transform=Transform3D.IDENTITY; gate.sync_collision()
		await physics_frame
		await physics_frame
		var space=world.get_world_3d().direct_space_state
		var query=PhysicsRayQueryParameters3D.create(Vector3(0,1,-10),Vector3(0,1,10),8)
		check(space.intersect_ray(query).is_empty(),kind+" Jolt opening is empty")
		query=PhysicsRayQueryParameters3D.create(Vector3(5.6,1,-10),Vector3(5.6,1,10),8)
		check(not space.intersect_ray(query).is_empty(),kind+" Jolt support is solid")
		query=PhysicsRayQueryParameters3D.create(Vector3(0,4.8,-10),Vector3(0,4.8,10),8)
		check(not space.intersect_ray(query).is_empty(),kind+" Jolt crossbeam is solid")
		gate.free()
	# Both production gate scenes, with the real independent ski solver.
	for pair in [["start_gate",26.],["finish_gate",108.]]:
		var gate=load("res://assets/graphics/flavor_v1/scenes/"+pair[0]+".tscn").instantiate()
		world.add_child(gate); gate.position=Vector3(0,terrain.sample(0,pair[1]).height,pair[1]); gate.bind_surface(surface)
	for speed in [0.,30.,60.]:
		var sim=Sim.new(); sim.reset(Vector3.ZERO); sim.prime_contacts(surface)
		sim.velocity=Vector3(0,-.16,1).normalized()*speed
		var input=RiderInput.new(); input.tuck=1
		for tick in 3600:
			sim.step(1./120.,input,surface)
			if sim.crashed or sim.position.z>140: break
		check(not sim.crashed and sim.position.z>140,"Real skier passes both gates from %.0f km/h"%(speed*3.6))
	var impact_sim=Sim.new(); var spawn=Vector3(5.6,terrain.sample(5.6,15).height,15)
	impact_sim.reset(spawn); impact_sim.prime_contacts(surface); impact_sim.velocity=Vector3(0,-.16,1).normalized()*40
	for tick in 90:
		impact_sim.step(1./120.,RiderInput.new(),surface)
		if impact_sim.impacts.reserve<1: break
	check(impact_sim.impacts.reserve<1 and impact_sim.position.z<26,"Real skier spends impact reserve and cannot pass through support")
	var box_pose=Transform3D(Basis.IDENTITY,Vector3(0,1,0))
	check(Props.sweep_box(Vector3(.6,1,0),Vector3(2,1,0),box_pose,Vector3.ONE).is_empty(),"Overlapping rider may escape outwards")
	var report={"checks":checks,"failures":failures,"physics_hz":120,"solver_modified":false}
	var out=FileAccess.open("res://artifacts/flavor_v1/godot_validation.json",FileAccess.WRITE); out.store_string(JSON.stringify(report,"\t")); out.close()
	print("FLAVOR_VALIDATION ",JSON.stringify(report))
	world.free(); quit(0 if failures.is_empty() else 1)

func _triangles(node: Node) -> int:
	var result=0
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var arrays=node.mesh.surface_get_arrays(i)
			result+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size()/3
	for child in node.get_children(): result+=_triangles(child)
	return result

func _shared_textures(node: Node) -> bool:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var material=node.get_active_material(i)
			if not material is StandardMaterial3D: continue
			for texture in [material.albedo_texture,material.normal_texture,material.roughness_texture,material.metallic_texture,material.ao_texture]:
				if texture and not texture.resource_path.begins_with("res://assets/graphics/flavor_v1/textures/"):
					printerr("Embedded texture retained: ",material.resource_name," / ",texture.resource_path)
					return false
	for child in node.get_children():
		if not _shared_textures(child): return false
	return true
