extends RefCounted
## Reusable presentation data. Contains no scene nodes or GPU resources.
const Terrain = preload("res://scripts/world/terrain_preparation.gd")
const Forest = preload("res://scripts/presentation/forest_placement.gd")
const Cache = preload("res://scripts/world/scenery_cache.gd")
var mountain = preload("res://scripts/world/mountain_data.gd").new()
var terrain = Terrain.new()
var forest = Forest.new()
var readability = preload("res://scripts/presentation/snow_readability.gd").new()
var minerals: Array = []
var macro_bounds: Dictionary = {}
var cache_hit: bool = false
var ready: bool = false
var timings: Dictionary = {}

func load_cached(field, quality, job) -> bool:
	job.begin_stage("preparation_cache_read")
	cache_hit = Cache.load_into(self,field,quality,job)
	job.end_stage("preparation_cache_read")
	ready = cache_hit
	return cache_hit

func build(field, metadata: Dictionary, quality, job) -> void:
	job.begin_stage("scenery_maps",mountain.GRID_SIZE*mountain.GRID_SIZE)
	mountain.generate(field,field.seed_value,job)
	job.end_stage("scenery_maps",mountain.GRID_SIZE*mountain.GRID_SIZE)
	if job.is_cancelled(): return
	job.begin_stage("terrain_arrays",576)
	terrain.build(field,job); job.end_stage("terrain_arrays")
	if job.is_cancelled(): return
	job.begin_stage("snow_readability",field.NX*field.NZ)
	readability.prepare(field,job); job.end_stage("snow_readability",field.NX*field.NZ)
	if job.is_cancelled(): return
	job.begin_stage("tree_scenery_preparation",field.tree_data.size())
	forest.build(field,metadata,job); job.end_stage("tree_scenery_preparation")
	if job.is_cancelled(): return
	job.begin_stage("mineral_batches",field.geology.placements.size())
	_build_minerals(field,job); job.end_stage("mineral_batches")
	if job.is_cancelled(): return
	job.begin_stage("preparation_cache_write")
	Cache.save(self,field,quality,job); job.end_stage("preparation_cache_write")
	ready = not job.is_cancelled(); timings = job.snapshot().timings_ms

func _build_minerals(field, job) -> void:
	var groups: Dictionary = {}
	for i in field.geology.placements.size():
		if i%128==0 and job.is_cancelled(): return
		var placed: Dictionary = field.geology.placements[i]
		var record: Dictionary = field.geology.catalog.records[placed.asset]
		var macro: bool = record.category in ["cliffs","huge_boulders"]
		if macro:
			if not macro_bounds.has(placed.asset): macro_bounds[placed.asset] = []
			macro_bounds[placed.asset].append(placed.pose*record.aabb)
		var region = 256 if macro else 128; var p: Vector3 = placed.pose.origin
		var key = "%s:%d:%d" % [placed.asset,floori(p.x/region),floori(p.z/region)]
		if not groups.has(key): groups[key] = {"asset":placed.asset,"ids":PackedInt32Array()}
		var ids: PackedInt32Array = groups[key].ids; ids.append(i); groups[key].ids = ids
	for group in groups.values():
		if job.is_cancelled(): return
		var record: Dictionary = field.geology.catalog.records[group.asset]
		var buffer = PackedFloat32Array(); buffer.resize(group.ids.size()*16)
		var bounds = AABB(); var grass = PackedInt32Array()
		for i in group.ids.size():
			var placed: Dictionary = field.geology.placements[group.ids[i]]
			Forest.put_pose(buffer,i*16,placed.pose)
			buffer[i*16+12] = placed.snow; buffer[i*16+13] = placed.moss; buffer[i*16+14] = 1.0 if placed.solid else 0.0; buffer[i*16+15] = float(placed.id%251)/251.0
			var box: AABB = placed.pose*record.aabb; bounds = box if i==0 else bounds.merge(box)
			if placed.grass: grass.append(group.ids[i])
		minerals.append({"asset":group.asset,"buffer":buffer,"bounds":bounds.grow(.15),"grass":grass,"category":record.category})
		job.advance(group.ids.size())
