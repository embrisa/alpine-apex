extends SceneTree
## Actual ecology and candidate jobs on the prepared current world, across worker counts.
const Definition=preload("res://scripts/world/mountain_definition.gd")
const Job=preload("res://scripts/world/generation_job.gd")
var failures=[]
var checks=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func run()->void:
	var field=Definition.Cache.generate(Definition.DEFAULT_SEED)
	if field==null:quit(2);return
	var settings=Definition.Settings
	for i in 4:
		check(settings.targets(settings.preset(i)).trees==[85000,170000,340000,850000][i],"Preset physical tree target "+str(i))
	var custom=settings.preset();custom.tree_population=1.37
	check(settings.targets(custom).trees==232900,"Custom tree factor retains its meaning")
	var reference=Definition.from_field(field).to_reference();reference.version=15
	check(not Definition.reference_error(reference).is_empty(),"Old physical world rejected without migration")
	check(not Definition.parse_seed("849205174 / v15").has("seed"),"Old versioned seed rejected")
	check(Definition.parse_seed("849205174 / v16").version==16,"Current versioned seed accepted")
	var ecology_reference=[];var candidate_reference=[];var candidate_total=0
	field.job=Job.new();field._build_ecology();field.candidate_count()
	for workers in [1,2,6]:
		field.job=Job.new();field.job.worker_count=workers
		var ecology=field.job.map_tiles(12,func(i):return field._ecology_rows(320+i*8,328+i*8))
		var candidates=field.job.map_tiles(8,func(i):return field._candidate_rows(330+i*72,346+i*72))
		if workers==1:
			ecology_reference=ecology;candidate_reference=candidates
			for tile in candidates:candidate_total+=tile.positions.size()
		else:
			check(ecology==ecology_reference,"Actual upper ecology stable across "+str(workers)+" workers")
			check(candidates==candidate_reference,"Ordered placement candidates stable across "+str(workers)+" workers")
	check(candidate_total>1000,"Worker comparison covers a populated spatial workload")
	field.job=Job.new();field.job.cancel()
	check(field._candidate_rows(350,366).positions.is_empty(),"Cancelled candidate tile publishes no trees")
	var result={"checks":checks,"failures":failures,"candidate_count":candidate_total,"ecology_rows":96,"candidate_rows":128,"workers":[1,2,6]}
	FileAccess.open("res://artifacts/natural_forest_20260917/ecology_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("NATURAL_FOREST_ECOLOGY ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
