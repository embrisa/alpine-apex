extends SceneTree
const Layout=preload("res://scripts/world/flavor_layout.gd")
const Mountain=preload("res://scripts/world/mountain_definition.gd")
const Race=preload("res://scripts/racing/race_definition.gd")
const Props=preload("res://scripts/world/prop_collision_surface.gd")
var checks=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL: ",label)
	else: print("PASS: ",label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/flavor_integration")
	var begin=Time.get_ticks_usec()
	var field=Mountain.generate(Mountain.DEFAULT_SEED)
	var terrain_hash=field.height_checksum; var obstacle_hash=field.obstacle_checksum
	var layout=Layout.new(); layout.generate(field)
	var again=Layout.new(); again.generate(field)
	check(layout.fingerprint==again.fingerprint,"Discoveries repeat for the same mountain seed")
	check(layout.sites.size()>=8 and layout.sites.size()<=Layout.MAX_SITES,"Mountain has a sparse but discoverable site population")
	var ids: Dictionary={}
	for p in layout.placements:
		ids[p.asset_id]=true
		check(not Layout.seat(field,p.asset_id,p.position,p.yaw).is_empty(),p.asset_id+" has a suitable terrain footprint")
		check(Layout.obstacle_clear(field,p.position,2),p.asset_id+" avoids existing obstacles")
	check(ids.has("alpine_refuge") and ids.has("marmot_monument"),"Huts and the custom mascot appear in the default mountain")
	check(ids.size()==10,"The default mountain includes every flavor family")
	check(not Race.gate_error(layout.placements[0].position,0,field).is_empty(),"Gate placement immediately rejects a discovery site")
	check(field.height_checksum==terrain_hash and field.obstacle_checksum==obstacle_hash,"Placement preserves authoritative terrain and existing obstacle hashes")
	var discoveries=preload("res://scripts/world/mountain_flavor.gd").new()
	discoveries.layout=layout
	check(discoveries.discover_near(Vector3(0,9000,0)).is_empty(),"Distant sites do not announce themselves")
	check(not discoveries.discover_near(layout.placements[0].position).is_empty(),"Arriving at a site announces its name")
	check(discoveries.discover_near(layout.placements[0].position).is_empty(),"Staying at a site cannot repeat the announcement")
	discoveries.free()
	var other_layouts: Array=[]
	for seed_value in [0,42,13579,2147483647]:
		var other_field=Mountain.generate(seed_value)
		var other=Layout.new(); other.generate(other_field)
		check(other.fingerprint!=layout.fingerprint,"Seed %d has its own discoveries" % seed_value)
		check(other.sites.size()>=8 and other.sites.size()<=Layout.MAX_SITES,"Seed %d keeps a bounded discovery population" % seed_value)
		other_layouts.append({"seed":seed_value,"sites":other.sites.size(),"props":other.placements.size(),"fingerprint":other.fingerprint})
	var laboratory=preload("res://scripts/world/test_slope.gd").new(849205174)
	var lab_layout=Layout.new(); lab_layout.generate(laboratory)
	check(lab_layout.placements.is_empty(),"The laboratory keeps its original obstacles")
	var race=Race.suggested(field,field.seed_value)
	check(race!=null,"Default mountain offers a valid Mountain Sprint")
	if race:
		check(race.validate_surface(field).is_empty(),"Suggested start and finish have safe clearings and foundations")
		var session=preload("res://scripts/core/run_session.gd").new()
		session.race=race; session.reset(); session.eligible=false
		var forward=Basis(Vector3.UP,race.finish_heading)*Vector3.BACK
		check(is_equal_approx(session.finish_fraction(race.finish-forward*20,race.finish+forward*20),.5),"Finish timing intersects the arch plane within the tick")
		check(is_equal_approx(session.finish_fraction(race.finish+forward*20,race.finish-forward*20),.5),"Reverse passage also finishes")
		var right=Basis(Vector3.UP,race.finish_heading)*Vector3.RIGHT
		check(session.finish_fraction(race.finish+right*6-forward*20,race.finish+right*6+forward*20)<0,"Missing the arch laterally never finishes")
		check(session.finish_fraction(race.finish+Vector3.UP*8-forward*20,race.finish+Vector3.UP*8+forward*20)<0,"Flying above the arch never finishes")
		check(session.finish_fraction(race.finish,race.finish)<0,"Standing at the finish cannot award a time")
		var code=race.to_data(); code.schema=2
		check(not Race.decode(JSON.stringify(code)).has("race"),"Earlier finish rules cannot load or share the new records")
		code=race.to_data(); code.race.props_version=999
		check(not Race.decode(JSON.stringify(code)).has("race"),"Unsupported prop layouts are rejected")
		var changed=Race.decode(race.share_text()).race; changed.finish_heading=wrapf(changed.finish_heading+.1,-PI,PI)
		check(changed.record_identity()!=race.record_identity(),"Gate orientation affects record identity")
	var adapter=Props.new(field)
	var p=layout.placements[0].position
	adapter.register_props(1,[{"transform":Transform3D(Basis.IDENTITY,p+Vector3.UP),"size":Vector3(2,2,2)}])
	check(not adapter.sweep_obstacle(p-Vector3.BACK*10,p+Vector3.BACK*10).is_empty(),"Spatially indexed prop collision catches a high-speed sweep")
	adapter.unregister_props(1)
	check(adapter.indexed.is_empty() and adapter.grid.is_empty(),"Removal clears the collision spatial index")
	var out={"checks":checks,"failures":failures,"sites":layout.sites.size(),"assets":layout.placements.size(),"ids":ids.keys(),"fingerprint":layout.fingerprint,"other_seeds":other_layouts,"elapsed_ms":(Time.get_ticks_usec()-begin)/1000.,"placements":layout.placements,"suggested":race.to_data() if race else {}}
	FileAccess.open("res://artifacts/flavor_integration/data_results.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("FLAVOR_INTEGRATION ",JSON.stringify({"checks":checks,"failures":failures,"sites":layout.sites.size(),"assets":layout.placements.size(),"ids":ids.keys()}))
	quit(0 if failures.is_empty() else 1)
