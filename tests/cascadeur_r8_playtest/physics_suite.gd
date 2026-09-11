extends SceneTree
const Base=preload("res://scripts/core/ski_simulation.gd")
const Trial=preload("res://tests/cascadeur_r8_playtest/simulation.gd")
const Intent=preload("res://scripts/core/rider_input.gd")
const SnowPlane=preload("res://tests/physics_suite.gd").SnowPlane
const DT=1.0/120.0
var checks=0
var failures=[]
var reports=[]
var sink_limit_m=.12
var experiment=Trial.EXPERIMENT_ID
var output_folder="res://artifacts/cascadeur_r8_contact"

class Surface extends SnowPlane:
	var rock=false
	func rock_fraction_at(_x:float,_z:float)->float:return 1.0 if rock else 0.0

func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func make_sim(field,trial:bool,enabled:bool=true,speed:float=18.0):
	var sim=Trial.new() if trial else Base.new()
	if trial:sim.pressure_enabled=enabled
	sim.reset(Vector3.ZERO);sim.prime_contacts(field);sim.velocity=sim.support_basis().z*speed;sim.reset_pose_history()
	return sim
func identity(sim):
	return [sim.position,sim.velocity,sim.body.roll,sim.body.pitch,sim.skis[0].position,sim.skis[1].position,sim.normal_load]
func run():
	for depth in [0.0,.02,.22]:
		var field=Surface.new(.25);field.depth=depth
		var base=make_sim(field,false);var off=make_sim(field,true,false)
		var equal=true
		for tick in 480:
			var input=Intent.new();input.steer=.6 if tick<240 else -.6
			base.step(DT,input,field);off.step(DT,input,field);equal=equal and identity(base)==identity(off)
		check(equal,"Disabled trial is exact base physics, depth "+str(depth))
	for direction in [-1.0,1.0]:
		var field=Surface.new(.25);field.depth=.22
		var sim=make_sim(field,true);var duplicate=make_sim(field,true)
		var row={"direction":direction,"peak_separation_m":0.0,"peak_sink_m":0.0,"air_ticks":0,"max_contact_error_m":0.0,"minimum_load_n":INF,"max_sink_step_m":0.0,"repeatable":true,"probe_pure":true,"final_speed_mps":0.0,"crash":""}
		var old=[0.0,0.0]
		for tick in 720:
			var input=Intent.new();input.steer=direction*.65 if tick>=120 and tick<500 else -direction*.55 if tick>=500 and tick<620 else 0.0
			sim.step(DT,input,field);duplicate.step(DT,input,field)
			row.repeatable=row.repeatable and identity(sim)==identity(duplicate)
			if not sim.grounded:row.air_ticks+=1
			var depths=[]
			for i in 2:
				var ski=sim.skis[i];var sample=field.sample(ski.position.x,ski.position.z)
				var actual=(sample.height-ski.position.y)*sample.normal.y;depths.append(actual)
				row.peak_sink_m=maxf(row.peak_sink_m,actual);row.minimum_load_n=minf(row.minimum_load_n,ski.load_n)
				row.max_sink_step_m=maxf(row.max_sink_step_m,absf(ski.crush.pressure_m-old[i]));old[i]=ski.crush.pressure_m
				var state=[ski.crush.pressure_m,ski.crush.pressure_rate_m_s,ski.crush.amount_m]
				for probe in 3:
					var pure=ski.crush.sample(field,ski.position.x,ski.position.z)
					if ski.grounded:row.max_contact_error_m=maxf(row.max_contact_error_m,absf(ski.position.y-pure.height))
				row.probe_pure=row.probe_pure and state==[ski.crush.pressure_m,ski.crush.pressure_rate_m_s,ski.crush.amount_m]
			row.peak_separation_m=maxf(row.peak_separation_m,absf(depths[0]-depths[1]))
			if sim.crashed:row.crash=sim.crash_reason;break
		row.final_speed_mps=sim.velocity.length();reports.append(row)
		check(row.crash=="" and row.air_ticks==0,"Turns and reversal stay supported "+str(direction))
		check(row.peak_separation_m>.045,"Visible pressure-driven ski height separation "+str(direction))
		check(row.peak_sink_m<=sink_limit_m+.0001 and row.minimum_load_n>=0,"Bounded loose-layer sink and unilateral loads "+str(direction))
		check(row.max_contact_error_m<.0001,"Both physical skis share their queried support "+str(direction))
		check(row.max_sink_step_m<=.00251,"Bounded fixed-tick sink movement "+str(direction))
		check(row.repeatable and row.probe_pure,"Repeatable ticks and read-only probes "+str(direction))
		var hop=Intent.new();hop.jump=true;sim.step(DT,hop,field)
		check(sim.jump_executed and not sim.grounded and sim.skis[0].crush.pressure_m==0.0,"Hop clears pressure history "+str(direction))
		var landed=false
		for tick in 300:
			sim.step(DT,Intent.new(),field)
			landed=landed or sim.grounded
		check(landed and not sim.crashed,"Pressure contacts recover after ordinary landing "+str(direction))
		sim.reset(Vector3.ZERO);sim.prime_contacts(field)
		check(sim.skis[0].crush.pressure_m==0 and sim.skis[1].crush.pressure_m==0,"Restart clears pressure history "+str(direction))
	var field=Surface.new(.0);field.depth=.22;var sim=make_sim(field,true,true,20.0)
	var energy=.5*sim.velocity.length_squared()+9.81*sim.position.y
	var increase=0.0;var air_ticks=0
	for tick in 960:
		var input=Intent.new();input.steer=.55*sin(tick*DT*4.0)
		sim.step(DT,input,field);increase=maxf(increase,.5*sim.velocity.length_squared()+9.81*sim.position.y-energy)
		if not sim.grounded:air_ticks+=1
	check(increase<.01,"Flat snow cannot add travel energy")
	check(air_ticks==0 and not sim.crashed,"Repeated pressure transfer cannot launch the rider")
	field.rock=true;sim.step(DT,Intent.new(),field)
	check(sim.skis[0].crush.pressure_m==0 and sim.skis[1].crush.pressure_m==0,"Firm rock clears sinking")
	for depth in [0.0,.02]:
		field=Surface.new(.25);field.depth=depth
		var regular=make_sim(field,false);var firm_trial=make_sim(field,true)
		var exact=true
		for tick in 240:
			var input=Intent.new();input.steer=.6
			regular.step(DT,input,field);firm_trial.step(DT,input,field)
			exact=exact and identity(regular)==identity(firm_trial)
		check(exact,"Enabled trial preserves firm or thin snow contacts "+str(depth))
	field=Surface.new(.25);field.depth=.22;sim=make_sim(field,true)
	for tick in 180:sim.step(DT,Intent.new(),field)
	sim.pressure_enabled=false
	for tick in 120:sim.step(DT,Intent.new(),field)
	check(sim.skis[0].crush.pressure_m==0 and sim.skis[1].crush.pressure_m==0 and sim.grounded and not sim.crashed,"F9 disabling settles back to surface support")
	var bank_field=preload("res://tests/snow_crush_suite.gd").Bank.new(.20,8,.35,1,.25)
	bank_field.depth=.22;sim=make_sim(bank_field,true,true,38.0)
	var bank_depth_error=0.0;var bank_contact_error=0.0
	for tick in 180:
		sim.step(DT,Intent.new(),bank_field)
		for ski in sim.skis:
			var raw=bank_field.sample(ski.position.x,ski.position.z)
			bank_depth_error=maxf(bank_depth_error,ski.crush_m-bank_field.depth)
			if ski.grounded:bank_contact_error=maxf(bank_contact_error,absf(raw.height-ski.crush_vertical_m-ski.position.y))
	check(bank_depth_error<.0001 and bank_contact_error<.0001 and not sim.crashed,"Snowbanks and pressure sinking share depth and support telemetry")
	var result={"experiment":experiment,"base_model":Base.MODEL_VERSION,"checks":checks,"failures":failures,"cases":reports,"flat_max_energy_increase_j_kg":increase,"flat_air_ticks":air_ticks}
	DirAccess.make_dir_recursive_absolute(output_folder)
	FileAccess.open(output_folder+"/physics.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("R8_CONTACT_RESULTS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
