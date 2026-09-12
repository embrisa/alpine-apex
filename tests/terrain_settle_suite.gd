extends SceneTree
const Probe=preload("res://tests/terrain_settle_probe.gd")
const Snow=preload("res://tests/planted_snow_probe.gd")
const Assist=preload("res://scripts/core/snow_contact_assist.gd")
var output="res://artifacts/terrain_settle"
var reference=""
var checks=0
var failures: Array[String]=[]

class Corner extends Snow.SnowRipple:
	func _init(shape: String):
		super(0.0,32.0,.2)
		for z in NZ:
			for x in NX:
				var px=X_MIN+x*CELL; var pz=Z_MIN+z*CELL
				match shape:
					"concave": heights[z*NX+x]=-.8*pz if pz<0.0 else -.2*pz
					"convex": heights[z*NX+x]=-.2*pz if pz<0.0 else -.8*pz
					"cross": heights[z*NX+x]=-.46*pz+px*(.65 if pz>0.0 else -.65)

func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output="res://"+arg.trim_prefix("--output=")
		if arg.begins_with("--reference-assist="): reference="res://"+arg.trim_prefix("--reference-assist=")
	DirAccess.make_dir_recursive_absolute(output)
	for shape in ["concave","cross","convex"]:
		var field=Corner.new(shape)
		var sim=Probe.Hop.rider(field,{"kmh":72.0}); sim.velocity+=sim.support_basis().y*.5
		var assist=Assist.new() if reference.is_empty() else load(reference).new()
		var before: Vector3=sim.velocity
		var correction: Vector3=assist.advance(Probe.DT,sim,field,false)
		if shape=="convex": check(correction==Vector3.ZERO and assist.suppressed,"Real convex takeoff profile still releases")
		else: check(correction.length()>.001 and not assist.suppressed,shape+": reachable snow retains support despite nearby normal changes")
		check((before+correction).length_squared()<=before.length_squared()+.00001,"Retention only dissipates energy: "+shape)
	var mountain=preload("res://tests/validation_mountain.gd").load_standard()
	if mountain==null: quit(2); return
	var reports: Array=[]
	var contact_fixture=Probe.ROUGH.duplicate(); contact_fixture.name="rough_contact_only"
	for fixture in [Probe.ROUGH,contact_fixture,Probe.SMOOTH]:
		var field=Snow.ContactOnly.new(mountain) if fixture.name=="rough_contact_only" else mountain
		var rows: Array=[]; var result=Probe.measure(field,fixture,rows,reference); reports.append(result)
		check(result.ticks==1800 and result.crash.is_empty(),fixture.name+": clean 15-second ordinary-input completion")
		check(result.min_load>=0.0 and result.unsupported_grip==0.0 and result.reach<=.281,fixture.name+": unilateral support stays within physical reach")
		if fixture.name.begins_with("rough"):
			check(result.flights.size()>=2 and result.flights.size()<=3,fixture.name+": balanced retention allows two to three terrain departures")
			var peak_height=0.0
			for flight in result.flights: peak_height=maxf(peak_height,flight.height)
			check(result.airtime<2.0 and peak_height<2.25,fixture.name+": occasional hops keep bounded airtime and height")
		else: check(result.flights.is_empty(),"Smooth mountain snow remains planted")
		FileAccess.open(output+"/"+fixture.name+".json",FileAccess.WRITE).store_string(JSON.stringify({"summary":result,"rows":rows}))
	var report={"model":Probe.Hop.Sim.MODEL_VERSION,"checks":checks,"failures":failures,"results":reports,"reference_assist":reference,"height":mountain.height_checksum,"unranked":true}
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TERRAIN_SETTLE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"output":output}))
	quit(0 if failures.is_empty() else 1)
