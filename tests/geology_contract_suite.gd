extends SceneTree
const Definition=preload("res://scripts/world/mountain_definition.gd")
const Cache=preload("res://scripts/world/mountain_cache_v11.gd")
const Props=preload("res://scripts/world/prop_collision_surface.gd")
const Layout=preload("res://scripts/world/flavor_layout.gd")
var checks=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr(label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/geology_v11")
	var field=Definition.generate(849205174,11)
	var recipe=Definition.from_field(field,"Default Mountain")
	var rebuilt=recipe.reconstruct()
	check(rebuilt.has("field"),"v11 recipe reconstructs")
	var again=rebuilt.field
	check(again.cache_hit and again.height_checksum==field.height_checksum and again.obstacle_checksum==field.obstacle_checksum,"Warm cache retains both physical fingerprints")
	check(again.geology.fingerprint()==field.geology.fingerprint(),"Cached mineral layouts and proxy identity match")
	check(again.geology.statistics==field.geology.statistics,"Cache restores placement diagnostics")
	check(again.exposure_image.get_data()==field.exposure_image.get_data(),"Ice and rock exposure survive cache round-trip")
	var independently_baked: Dictionary=FileAccess.open("res://artifacts/geology_v11/field_849205174.bin",FileAccess.READ).get_var(false)
	check(independently_baked.height_sha256==field.height_checksum and independently_baked.obstacle_sha256==field.obstacle_checksum,"Independent cold bake repeats both fingerprints")
	var adapter=Props.new(field)
	var compared=false
	for entry in field.geology.collision.entries:
		var box: AABB=entry.aabb
		var a=box.get_center()+Vector3.UP*(box.size.y+5)
		var b=box.get_center()-Vector3.UP*(box.size.y+5)
		var direct=field.geology.collision.sweep(a,b)
		if direct.is_empty(): continue
		var through_adapter=adapter.sweep_obstacle_contact(a,b)
		check(not through_adapter.is_empty() and through_adapter.get("id")==direct.id,"Flavor adapter delegates mineral impacts to the field")
		check(not Layout.obstacle_clear(field,entry.pose.origin,10),"Hut and gate clearance includes mineral footprints")
		compared=true; break
	check(compared,"A physical mineral is available for collision integration checks")
	var world=Node3D.new()
	world.set_script(preload("res://scripts/world/alpine_world.gd"))
	world.surface=field
	root.add_child(world)
	var crash=preload("res://scripts/world/crash_collision.gd").new()
	crash.world=world; root.add_child(crash)
	var entry: Dictionary=field.geology.collision.entries[0]
	crash._prepare_minerals(entry.aabb.get_center())
	check(crash.mineral_bodies.has(entry.id),"Jolt collision activates by formation bounds")
	if crash.mineral_bodies.has(entry.id):
		var body: StaticBody3D=crash.mineral_bodies[entry.id]
		check(body.transform.is_equal_approx(entry.pose),"Jolt and solver use the identical placement transform")
		var hulls: Array=field.geology.catalog.records[entry.record].hull_points
		var owner: int=body.get_shape_owners()[0]
		check(body.shape_owner_get_shape_count(owner)==hulls.size(),"Jolt and solver use the same convex pieces")
		check(body.get_child_count()==0,"Convex pieces do not allocate individual scene Nodes")
		for i in hulls.size(): check(body.shape_owner_get_shape(owner,i).points==hulls[i],"Jolt hull points match the offline proxy")
	crash._prepare_minerals(Vector3(0,20000,0))
	check(crash.mineral_bodies.is_empty(),"Distant crash collision is released")
	crash.queue_free(); world.queue_free()
	var old=Definition.generate(849205174,10)
	check(old.GENERATOR_VERSION==10 and not "geology" in old,"Explicit v10 keeps its archived terrain and obstacle path")
	var old_recipe=Definition.decode(FileAccess.get_file_as_string("res://examples/mountains/default-v10.apexmountain"))
	check(old_recipe.has("mountain") and old_recipe.mountain.height_checksum==old.height_checksum and old_recipe.mountain.obstacle_checksum==old.obstacle_checksum,"Archived v10 fingerprints remain compatible")
	FileAccess.open("res://examples/mountains/default-v11.apexmountain",FileAccess.WRITE).store_string(recipe.share_text()+"\n")
	FileAccess.open("res://artifacts/geology_v11/integration_contracts.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"geology_sha256":field.geology.fingerprint(),"cache_load_ms":again.generation_ms},"\t"))
	print("GEOLOGY_CONTRACTS ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
