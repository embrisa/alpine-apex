extends SceneTree
## Explicit two-revision ecological survey. Missing caches only bake with --prepare.
const Definition=preload("res://scripts/world/mountain_definition.gd")
const Cache=Definition.Cache
const OUT="res://artifacts/natural_forest_20260917"
var seed_number=849205174
var baseline=false
var prepare=false
var failures=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,message:String)->void:
	if not value:failures.append(message);printerr("FAIL ",message)
func run()->void:
	if Definition.CURRENT_VERSION!=16:printerr("This v15/v16 comparison requires checkout Dev94; use current opening/world producers for later generators.");quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):seed_number=int(arg.get_slice("=",1))
		if arg=="--baseline":baseline=true
		if arg=="--prepare":prepare=true
	if not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("Explicit natural forest two-seed population survey"):quit(2);return
	DirAccess.make_dir_recursive_absolute(OUT)
	var job=Cache.Job.new()
	var key=Cache.cache_key(seed_number)
	var data=Cache.Archive.read(Cache.path_for(seed_number),key,job)
	var field=Cache.restore(seed_number,Cache.Settings.preset(),data,job) if not data.is_empty() else null
	var warm=field!=null
	var original_bake_ms:float=data.get("meta",{}).get("bake_ms",0.0)
	if field==null:
		if not prepare or OS.get_environment("ALPINE_VALIDATION_MODE")!="Exclusive":printerr("Explicit --prepare and Exclusive admission required for missing seed ",seed_number);quit(2);return
		field=Cache.Terrain.new(seed_number,true,Cache.Settings.preset(),job)
		if not field.valid:quit(1);return
		check(Cache.Archive.write(Cache.path_for(seed_number),key,Cache.sections(field),job),"Prepared archive published")
	data.clear()
	var report=survey(field)
	report.baseline=baseline;report.cache_hit=warm;report.version=field.GENERATOR_VERSION
	report.seed=seed_number;report.generation_ms=field.generation_ms;report.stages=field.generation_stages;report.original_bake_ms=original_bake_ms
	var prefix=OUT+("/old_" if baseline else "/new_")+str(seed_number)
	if baseline:
		var base_heights:PackedFloat32Array=field.heights.duplicate()
		for i in base_heights.size():base_heights[i]-=field.tree_snow_height[i]
		var minerals=[]
		for mineral in field.geology.placements:minerals.append({"asset":mineral.asset,"pose":mineral.pose})
		FileAccess.open(prefix+".bin",FileAccess.WRITE).store_var({"trees":field.tree_data.positions,"dimensions":field.tree_data.dimensions,"ids":field.tree_data.candidate_ids,"base_heights":base_heights,"minerals":minerals,"parameters":field.parameters,"faces":field.faces.map(func(face):return {"landforms":face.landforms,"channels":face.channels,"shelves":face.shelves})})
	else:
		var old_path=OUT+"/old_"+str(seed_number)
		var old=FileAccess.open(old_path+".bin",FileAccess.READ).get_var()
		var old_report=JSON.parse_string(FileAccess.get_file_as_string(old_path+".json"))
		check(field.tree_data.size()==170000,"Standard achieved target170000")
		check(field.tree_data.size()==roundi(old_report.count*.85),"Matched seed exactly15percent fewer")
		check(field.parameters==old.parameters,"Foundation recipe unchanged")
		for i in field.faces.size():
			check(field.faces[i].landforms==old.faces[i].landforms and field.faces[i].channels==old.faces[i].channels and field.faces[i].shelves==old.faces[i].shelves,"Landforms/openings unchanged face"+str(i))
		var maximum_base_difference=0.0
		for i in field.heights.size():maximum_base_difference=maxf(maximum_base_difference,absf(field.heights[i]-field.tree_snow_height[i]-old.base_heights[i]))
		check(maximum_base_difference<.001,"Terrain change limited to tree-local snow")
		report.maximum_base_difference_m=maximum_base_difference
		check(old.minerals.size()==field.geology.placements.size(),"Mineral count unchanged")
		var mineral_changed=0
		for i in old.minerals.size():
			var before=old.minerals[i];var after=field.geology.placements[i]
			if before.asset!=after.asset or before.pose.basis!=after.pose.basis or before.pose.origin.x!=after.pose.origin.x or before.pose.origin.z!=after.pose.origin.z:mineral_changed+=1
		check(mineral_changed==0,"Mineral assets/orientations/ground positions unchanged")
		report.mineral_changed=mineral_changed
		var old_ids={}
		for id in old.ids:old_ids[id]=true
		var added=0;var added_upper=0
		for i in field.tree_data.size():
			if old_ids.has(field.tree_data.candidate_ids[i]):continue
			added+=1
			if field.tree_data.positions[i].y>old_report.elevation.p99:added_upper+=1
		report.added_candidate_ids=added;report.added_above_old_p99=added_upper
		check(added_upper>50,"Sparse trees extend above old high-altitude distribution")
		check(report.elevation.max>=4150 and report.elevation.max<4300,"User-selected sparse upper band reaches around4200m")
		check(report.minimum_radius_m>=120,"Summit centre retains at least120m clear radius")
		var restored=Cache.generate(seed_number)
		check(restored!=null and restored.cache_hit and restored.tree_data.positions==field.tree_data.positions and restored.heights==field.heights,"Warm cache exact positions/support roundtrip")
		restored=null
	report.failures=failures
	FileAccess.open(prefix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("NATURAL_FOREST_SURVEY ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
func survey(field)->Dictionary:
	var bins={};var face_counts=[0,0,0,0,0,0];var relative_bins={};var altitudes=[];var upper_samples=[]
	var min_radius=INF;var scattered=0;var root_errors=0;var max_root_error=0.0
	var neighbor_distances=[];var survey_exclusions={"slope":0,"rock":0,"opening":0,"mineral":0,"spacing":0,"samples":0}
	for i in field.tree_data.size():
		var p:Vector3=field.tree_data.positions[i];var q=Vector2(p.x,p.z)
		altitudes.append(p.y);min_radius=minf(min_radius,q.length())
		var band=str(floori(p.y/100)*100);bins[band]=bins.get(band,0)+1
		var pair=field.adjacent_faces(q);var face=pair[0];var local:Vector2=face.to_local(q);var other:Vector2=pair[1].to_local(q)
		if pair[1].sector_weight(other.x,other.y)>face.sector_weight(local.x,local.y):face=pair[1];local=other
		face_counts[face.index]+=1
		var treeline:float=face.treeline_height+face.forest_noise.get_noise_2d(local.x*.6+317,local.y*.6)*210
		var relative=str(floori((p.y-treeline)/50)*50);relative_bins[relative]=relative_bins.get(relative,0)+1
		var root_error:float=absf(p.y-field.height_at(p.x,p.z));max_root_error=maxf(max_root_error,root_error)
		if root_error>.001:root_errors+=1
		if field.tree_data.ecology[i]==1:scattered+=1
		if i%17==0:
			survey_exclusions.samples+=1
			var clearance:float=field.tree_data.dimensions[i].x+2*field.generation_settings.tree_spacing
			if field.contact_normal(p.x,p.z).y<.68:survey_exclusions.slope+=1
			if field.rock_fraction_at(p.x,p.z)>.38:survey_exclusions.rock+=1
			if not field.geology.clear(p,clearance):survey_exclusions.mineral+=1
			for nearby_face in pair:
				var local_p:Vector2=nearby_face.to_local(q)
				if nearby_face.natural_opening(local_p,clearance) or nearby_face.drop_protected(local_p,clearance):survey_exclusions.opening+=1;break
			var nearest=INF
			for other_id in field.tree_data.nearby(p,32):
				if other_id==i:continue
				var other_p:Vector3=field.tree_data.positions[other_id]
				var distance:float=q.distance_to(Vector2(other_p.x,other_p.z));nearest=minf(nearest,distance)
				var required:float=maxf(4.2*field.generation_settings.tree_spacing,field.tree_data.dimensions[i].x+field.tree_data.dimensions[other_id].x+2*field.generation_settings.tree_spacing)
				if distance<required-.001:survey_exclusions.spacing+=1
			if is_finite(nearest):neighbor_distances.append(nearest)
		if p.y>3500 and i%7==0 and upper_samples.size()<80:upper_samples.append({"position":[p.x,p.y,p.z],"face":face.index,"tree_index":i,"treeline":treeline})
	altitudes.sort()
	neighbor_distances.sort()
	var terrain_bins={};var suitable_bins={}
	for z in range(-2780,2781,32):
		for x in range(-2780,2781,32):
			var p=Vector2(x,z)
			if p.length()<120 or p.length()>2780:continue
			var h:float=field.height_at(x,z);var key=str(floori(h/100)*100);terrain_bins[key]=terrain_bins.get(key,0)+1
			if field.contact_normal(x,z).y<.77 or field.rock_fraction_at(x,z)>.20:continue
			var blocked=false
			for face in field.adjacent_faces(p):
				if face.natural_opening(face.to_local(p),3) or face.drop_protected(face.to_local(p),3):blocked=true;break
			if not blocked:suitable_bins[key]=suitable_bins.get(key,0)+1
	check(root_errors==0,"All physical roots seated")
	return {"count":field.tree_data.size(),"requested":field.population.requested_trees,"saturated":field.population.tree_saturated,"minerals":field.geology.placements.size(),"by_100m_altitude":bins,"by_face":face_counts,"by_50m_relative_treeline":relative_bins,"elevation":{"min":altitudes[0],"p50":altitudes[altitudes.size()/2],"p95":altitudes[int(altitudes.size()*.95)],"p99":altitudes[int(altitudes.size()*.99)],"max":altitudes[-1]},"minimum_radius_m":min_radius,"scattered":scattered,"max_root_error_m":max_root_error,"upper_samples":upper_samples,"terrain_32m_sample_bins":terrain_bins,"suitable_32m_sample_bins":suitable_bins,"sampled_exclusions":survey_exclusions,"nearest_32m_sample":{"count":neighbor_distances.size(),"min":neighbor_distances[0],"p50":neighbor_distances[neighbor_distances.size()/2],"p95":neighbor_distances[int(neighbor_distances.size()*.95)]}}
