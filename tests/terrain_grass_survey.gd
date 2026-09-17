extends SceneTree
## Bounded offline survey of the actual Standard surface; never changes habitat.
const Grass=preload("res://scripts/presentation/terrain_grass.gd")
const Placement=preload("res://scripts/presentation/grass_placement.gd")
const Cache=preload("res://scripts/world/mountain_cache_v17.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var seed_number=849205174
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_number=int(arg.get_slice("=",1))
	var field=Cache.generate(seed_number)
	if not field: quit(1); return
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Grass.MANIFEST))
	var heights={}
	for record in catalog.assets: heights[record.id]=record.height
	var placement=Placement.new(field,heights)
	var counts={"green":0,"dusted":0,"snow":0}
	var examples={"green":[],"dusted":[],"snow":[]}
	var bins={"green":{},"dusted":{},"snow":{}}
	var forest_cells=[]
	var before=field.height_checksum+field.obstacle_checksum
	# Six faces; a 64 m stratified survey. This is coverage, not timing.
	for z in range(-42,43):
		for x in range(-42,43):
			var key=Vector2i(x*4,z*4)
			var centre=Vector2(key)*Placement.CELL+Vector2.ONE*8
			var h=placement.habitat(centre)
			if h.is_empty(): continue
			var items=placement.cell(key)
			if items.size()>20 and h.forest>.3: forest_cells.append({"key":[key.x,key.y],"count":items.size(),"forest":h.forest})
			for item in items:
				var finish: String=item.asset.get_slice("_",3)
				if not counts.has(finish): finish=item.asset.get_slice("_",item.asset.get_slice_count("_")-1)
				counts[finish]+=1
				var sector=posmod(floori((atan2(item.pose.origin.z,item.pose.origin.x)+PI)*6.0/TAU),6)
				if not bins[finish].has(sector): bins[finish][sector]=[]
				var choices: Array=bins[finish][sector]
				if choices.size()<2 and (choices.is_empty() or choices[0].key!=[key.x,key.y]):
					var p: Vector3=item.pose.origin
					choices.append({"position":[p.x,p.y,p.z],"key":[key.x,key.y],"sector":sector,"asset":item.asset,"coverage":item.coverage,"burial":item.burial,"visible_height":item.height*item.pose.basis.y.normalized().y-item.burial,"forest":item.forest})
	for finish in bins:
		for sector in range(6): examples[finish].append_array(bins[finish].get(sector,[]))
	forest_cells.sort_custom(func(a,b): return a.count>b.count)
	var result={"seed":field.seed_value,"generator":field.GENERATOR_VERSION,"settings":field.generation_settings,"counts":counts,"examples":examples,"dense_cells":forest_cells.slice(0,12),"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"physical_unchanged":before==field.height_checksum+field.obstacle_checksum,"source_signature":preload("res://scripts/world/generation_sources.gd").signature(true)}
	DirAccess.make_dir_recursive_absolute("res://artifacts/terrain_grass_20260913")
	preload("res://tests/test_report.gd").write("res://artifacts/terrain_grass_20260913/survey_%d.json" % seed_number,JSON.stringify(result,"\t"))
	print("GRASS_SURVEY ",JSON.stringify(counts)," dense_cells=",forest_cells.size())
	quit(0 if counts.green>0 and counts.dusted>0 and counts.snow>0 and result.physical_unchanged else 1)
