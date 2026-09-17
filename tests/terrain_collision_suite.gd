extends SceneTree
## Real Jolt ray contacts against the exact shared-grid triangle reference.
const Crash=preload("res://scripts/world/crash_collision.gd")
const Map=preload("res://scripts/diagnostics/performance_map.gd")
const Terrain=preload("res://scripts/world/terrain_preparation.gd")
var checks=0
var failures=[]
var ray_count=0
var max_error=0.0
var minimum_normal_dot=1.0
class World extends Node3D:
	var surface=Map.new("perf-slopes")
	var terrain_chunks: Array[MeshInstance3D]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL ",label)
func chunk(world,side: int,z_origin: int=0,clipped: bool=false) -> MeshInstance3D:
	var points=PackedVector3Array()
	for z in side:
		for x in side: points.append(world.surface.vertex(x,z_origin+z))
	var indices=Terrain.base_indices(side-1)
	if clipped: indices=indices.slice(0,indices.size()/2)
	var arrays=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=points; arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node=MeshInstance3D.new(); node.mesh=mesh
	node.set_meta("terrain_center",Vector2(mesh.get_aabb().get_center().x,mesh.get_aabb().get_center().z))
	node.set_meta("trimmed_perimeter",clipped); world.add_child(node); return node
func run() -> void:
	var world=World.new(); root.add_child(world)
	var crash=Crash.new(); crash.world=world; root.add_child(crash)
	for spec in [[65,false],[33,false],[65,true]]:
		var node=chunk(world,spec[0],0,spec[1])
		var candidate=crash._terrain_body(node)
		var shape=candidate.get_child(0).shape
		check((shape is ConcavePolygonShape3D) if spec[1] else (shape is HeightMapShape3D),"clipped triangle/full grid representation "+str(spec))
		check(candidate.collision_layer==8 and candidate.collision_mask==16 and candidate.get_meta("audio_material")==0,"terrain collision ownership "+str(spec))
		var reference=crash._static(node.mesh.create_trimesh_shape(),Vector3.ZERO); reference.collision_layer=32
		await physics_frame; await physics_frame
		var extent=(spec[0]-1)*4.0
		for z in 31:
			for x in 31:
				var p=Vector2(world.surface.X_MIN+(x+.371)*extent/31.0,world.surface.Z_MIN+(z+.613)*extent/31.0)
				var from=Vector3(p.x,500,p.y); var to=Vector3(p.x,-500,p.y)
				var old=root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,32))
				var now=root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,8))
				check(old.is_empty()==now.is_empty(),"contact/hole presence")
				if not spec[1]: check(not old.is_empty() and not now.is_empty(),"complete full-grid coverage")
				if old.is_empty() or now.is_empty(): continue
				var error=absf(old.position.y-now.position.y)
				var normal_dot=old.normal.dot(now.normal)
				max_error=maxf(max_error,error); minimum_normal_dot=minf(minimum_normal_dot,normal_dot); ray_count+=1
				check(error<.001 and normal_dot>.99999,"sub-mm grid contact and matching diagonal normal")
		candidate.queue_free(); reference.queue_free(); node.queue_free(); await physics_frame; await physics_frame
	# Existing preparation/retention distances, including discontinuous return.
	world.terrain_chunks.append_array([chunk(world,65),chunk(world,65,64)])
	crash.prepare(Vector3.ZERO)
	check(crash.terrain.size()==1,"initial terrain coverage")
	crash.prepare(Vector3(0,0,200))
	check(crash.terrain.size()==2,"forward coverage without a gap")
	crash.prepare(Vector3(0,0,1000)); await process_frame
	check(crash.terrain.is_empty(),"far travel retires terrain")
	crash.prepare(Vector3.ZERO)
	check(crash.terrain.size()==1 and crash.terrain[0].get_child(0).shape is HeightMapShape3D,"return recreates grid collision")
	var result={"checks":checks,"failures":failures,"ray_contacts":ray_count,"max_error_m":max_error,"minimum_normal_dot":minimum_normal_dot,"scope":"Jolt grid, clipped holes and prepare/retire/return; no frame/FPS claim"}
	preload("res://tests/test_report.gd").write("res://artifacts/collision_heightfield_20260917/suite.json",JSON.stringify(result,"\t"))
	crash.queue_free(); world.queue_free(); await process_frame
	print("TERRAIN_COLLISION_RESULTS ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
