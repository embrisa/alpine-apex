extends SceneTree
## Recipe-level opening reach and full/narrow powder-query agreement.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const OUT = "res://artifacts/natural_openings_20260917"
var failures = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); printerr("FAIL ",label)
func run() -> void:
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	var results = []
	for seed_number in [849205174,638201943]:
		var field = Definition.CurrentTerrain.new(seed_number,false)
		var lengths = []; var runs = []; var floor_samples = 0
		var corridor_samples = 0; var forks = 0; var link_lengths=[]; var linked_samples=0
		for face in field.faces:
			check(_connected_glades(face),"Every local glade has two joined ends and reaches the wider corridor network")
			var outgoing = {}
			for channel in face.channels:
				outgoing[channel.start]=outgoing.get(channel.start,0)+1
				for step in 41:
					var t = float(step)/40
					var q=Vector2(face._channel_centre(channel,t),lerpf(channel.start.y,channel.finish.y,t))
					for offset in [Vector2.ZERO,Vector2(-5,0),Vector2(5,0)]:
						check(face.natural_opening(q+offset),"Connected corridor retains clearance through bends and junctions")
						corridor_samples+=1
			var face_forks = 0
			for count in outgoing.values():
				if count>1:face_forks+=1
			check(face_forks>0,"Each face retains forked corridor choices")
			forks+=face_forks
			for passage in face.forest_passages:
				var delta: Vector2 = passage.finish-passage.start
				if passage.get("link",false):
					link_lengths.append(delta.length())
					check(delta.length()<450,"Local connecting corridors stay short or medium length")
					for step in 33:
						check(face.woodland_opening(face._passage_centre(passage,float(step)/32)),"Small corridor stays open through its complete connection")
						linked_samples+=1
					continue
				lengths.append(delta.length())
				var longest = 0; var current = 0
				# A straight skier sightline through each opening, including its old
				# extended ends. Neighboring openings are included in the query.
				for distance in range(-400,1001,4):
					var p: Vector2 = passage.start+delta.normalized()*distance
					current = current+4 if face.woodland_opening(p) else 0
					longest = maxi(longest,current)
				runs.append(longest)
			for channel in face.channels:
				for step in range(-1,22):
					var t = float(step)/20
					var z = lerpf(channel.start.y,channel.finish.y,t)
					for offset in [-80,-25,0,25,80]:
						var x = lerpf(channel.start.x,channel.finish.x,t)+offset
						check(face.channel_floor_weight(x,z)==face.channel_values(x,z).y,"Narrow powder query matches full generation query")
						floor_samples += 1
		lengths.sort(); runs.sort(); link_lengths.sort()
		var row = {"seed":seed_number,"generator":field.GENERATOR_VERSION,"passages":lengths.size(),"axis_mean_m":lengths.reduce(func(a,b):return a+b,0.0)/lengths.size(),"axis_max_m":lengths[-1],"straight_clear_run_p50_m":runs[runs.size()/2],"straight_clear_run_p95_m":runs[floori(runs.size()*.95)],"straight_clear_run_max_m":runs[-1],"floor_samples":floor_samples,"corridor_samples":corridor_samples,"forks":forks,"small_links":link_lengths.size(),"link_median_m":link_lengths[link_lengths.size()/2],"link_max_m":link_lengths[-1],"linked_samples":linked_samples}
		if not baseline:
			var old = JSON.parse_string(FileAccess.get_file_as_string(OUT+"/old_geometry.json"))
			var old_row = old.seeds.filter(func(r):return r.seed==seed_number)[0]
			check(row.straight_clear_run_p95_m < old_row.straight_clear_run_p95_m*.65,"Long straight woodland openings substantially shorter")
		results.append(row)
	DirAccess.make_dir_recursive_absolute(OUT)
	var report = {"seeds":results,"failures":failures,"scope":"Recipe opening sightlines, not actual downhill route or FPS acceptance"}
	FileAccess.open(OUT+("/old_geometry.json" if baseline else "/new_geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("NATURAL_OPENINGS_GEOMETRY ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)

func _connected_glades(face) -> bool:
	var neighbours=[]; var roots=[]; var complete=true
	for passage in face.forest_passages:neighbours.append([])
	for id in face.forest_passages.size():
		var passage: Dictionary=face.forest_passages[id]
		for t in ([0.0,1.0] if passage.get("link",false) else [.16,.76]):
			var p: Vector2=face._passage_centre(passage,t)
			var root=p.length()>=2780.0
			for channel in face.channels:
				var u=clampf((p.y-channel.start.y)/(channel.finish.y-channel.start.y),0,1)
				var centre=Vector2(face._channel_centre(channel,u),lerpf(channel.start.y,channel.finish.y,u))
				if p.distance_to(centre)<face._channel_width(channel,u)*.28+8:root=true;break
			if root and not id in roots:roots.append(id)
			var joined=root
			for other in face.forest_passages.size():
				if other==id:continue
				if face._passage_weight(p,face.forest_passages[other])>.6:
					joined=true;neighbours[id].append(other);neighbours[other].append(id)
			complete=complete and joined
	var visited={};var pending=roots.duplicate()
	while not pending.is_empty():
		var id=pending.pop_back()
		if visited.has(id):continue
		visited[id]=true;pending.append_array(neighbours[id])
	return complete and visited.size()==face.forest_passages.size()
