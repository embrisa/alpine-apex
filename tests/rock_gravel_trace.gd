extends SceneTree
## Select a real exposed-rock patch on a warm mountain; record ordinary input.
const Trace=preload("res://tests/performance_trace.gd")
const Placement=preload("res://scripts/presentation/gravel_placement.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var field=preload("res://tests/validation_mountain.gd").load_standard()
	if field==null: quit(2); return
	field.build_material_map()
	var placement=Placement.new(field)
	var sites=[]
	# Stratified bounded survey of authored terrain, without a bake or RNG change.
	for z in range(-60,61):
		for x in range(-60,61):
			var patch=placement.patch(Vector2i(x*4,z*4))
			if patch.z==0 or not placement.suitable(Vector2(patch.x,patch.y)): continue
			var anchor=Vector3(patch.x,field.sample(patch.x,patch.y).height,patch.y)
			if placement.grass_source._mineral_overlap(anchor): continue
			sites.append({"anchor":anchor,"radius":patch.z,"slope":field.sample(patch.x,patch.y).normal.y})
	sites.sort_custom(func(a,b):return a.slope>b.slope)
	var attempts=[]; var accepted=false
	for site in sites.slice(0,120):
		var anchor: Vector3=site.anchor
		var key=Vector2i(floori(anchor.x/8),floori(anchor.z/8))
		if not placement.cell(key).any(func(i):return i.asset.begins_with("dense")): continue
		var downhill=Vector3.DOWN.slide(field.contact_normal(anchor.x,anchor.z))
		var heading=atan2(downhill.x,downhill.z)
		var sim=Trace.Simulation.new(preload("res://config/ski_default.tres").duplicate(true))
		sim.reset(anchor,heading); sim.prime_contacts(field)
		var initial=Trace.Inputs.state(sim); var commands=[]; var checkpoints=[]; var coverage=[]
		var command=RiderInput.new(); command.tuck=.35; command.brake=.08
		var contacts=0; var travelled=0.0
		for tick in 1800:
			if tick%12==0: commands.append(Trace.Inputs.encode(command))
			var previous=sim.position; sim.step(1.0/120,command,field); travelled+=sim.position.distance_to(previous)
			if not sim.obstacle_contact.is_empty(): contacts+=1
			if sim.ticks%120==0:
				checkpoints.append(Trace.Inputs.state(sim))
				coverage.append({"tick":sim.ticks,"position":[sim.position.x,sim.position.y,sim.position.z],"speed_kmh":sim.speed_kmh(),"rock":field.rock_fraction_at(sim.position.x,sim.position.z)})
			if sim.crashed or contacts>0 or field.reached_base(sim.position): break
		attempts.append({"anchor":str(anchor),"ticks":sim.ticks,"crash":sim.crash_reason,"obstacle_contacts":contacts,"travelled_m":travelled})
		if sim.ticks!=1800 or sim.crashed or contacts>0 or travelled<15: continue
		var settings=preload("res://scripts/presentation/camera_settings.gd").new()
		preload("res://tests/scenery_camera.gd").configure(settings)
		var data={"identity":Trace.identity(field),"input_fields":Trace.Inputs.FIELDS,"seed":849205174,"face":3,"heading":heading,
			"scenario_origin":[anchor.x,anchor.z],"command_ticks":12,"commands":commands,"initial_state":initial,"checkpoints":checkpoints,"coverage":coverage,
			"travelled_m":travelled,"obstacle_contacts":contacts,"producer_sha256":FileAccess.get_sha256("res://tests/rock_gravel_trace.gd"),
			"presentation":{"camera":settings.snapshot(),"camera_effects_enabled":true},
			"result":{"side":0,"ticks":sim.ticks,"seconds":15,"finished":false,"crash":"","position":[sim.position.x,sim.position.y,sim.position.z]}}
		preload("res://tests/test_report.gd").write("res://artifacts/rock_gravel/standard_trace.json",JSON.stringify(Trace.Inputs.storage(data),"",true,true))
		print("GRAVEL_TRACE ",JSON.stringify(attempts[-1])); accepted=true; break
	preload("res://tests/test_report.gd").write("res://artifacts/rock_gravel/survey.json",JSON.stringify({"sites":sites.size(),"attempts":attempts,"accepted":accepted},"\t"))
	quit(0 if accepted else 1)
