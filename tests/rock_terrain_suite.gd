extends SceneTree
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Intent = preload("res://scripts/core/rider_input.gd")
const Response = preload("res://scripts/presentation/snow_response.gd")
const TerrainMaterial = preload("res://scripts/core/terrain_material.gd")
const Recovery = preload("res://scripts/core/impact_recovery.gd")
const Grid = preload("res://scripts/world/heightfield_surface.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array = []
var metrics = {}

class MaterialPlane:
	extends RefCounted
	var rock = true
	var mixed = false
	var gradient = .46
	func sample(_x: float,z: float) -> Dictionary:
		return {"height":-z*gradient,"normal":Vector3(0,1,gradient).normalized()}
	func snow_depth_at(_x: float,_z: float) -> float: return .20
	func rock_fraction_at(x: float,_z: float) -> float: return float(x>=0.0) if mixed else float(rock)
	func sweep_obstacle(_a: Vector3,_b: Vector3) -> String: return ""

class MaskGrid extends Grid:
	const MASK_ORIGIN = Vector2.ZERO
	var exposure_image: Image
	func _init() -> void:
		NX=3; NZ=3; X_MIN=0; Z_MIN=0
		heights=PackedFloat32Array([0,0,0,-4,-4,-4,-8,-8,-8])
		exposure_image=Image.create(3,3,false,Image.FORMAT_RGBA8)
		exposure_image.fill(Color(0,0,0,1))
		exposure_image.set_pixel(1,1,Color(1,0,0,1))

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func skier(surface, speed: float = 25.0):
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	sim.prime_contacts(surface)
	sim.velocity=Vector3.BACK.slide(surface.sample(0,0).normal).normalized()*speed
	return sim

func advance(sim, surface, seconds: float, steer: float = 0.0) -> void:
	var intent = Intent.new()
	intent.steer=steer; intent.tuck=1.0
	for i in roundi(seconds/DT): sim.step(DT,intent,surface)

func run() -> void:
	var rock = MaterialPlane.new()
	var snow = MaterialPlane.new(); snow.rock=false
	var a = skier(rock); var b = skier(snow)
	advance(a,rock,5); advance(b,snow,5)
	check(not a.crashed and absf(a.impacts.reserve-.8)<.001,"Five seconds on rock costs twenty percent reserve")
	check(b.impacts.reserve==1.0,"Snow gliding does not spend reserve")
	check(a.speed_kmh()<b.speed_kmh() and a.speed_kmh()>b.speed_kmh()*.70,"Rock glide is moderately slower on the same slope")
	check(a.snow_depth==0 and a.snow_penetration==0 and a.snow_drag==0,"Rock has no loose-snow physics")
	for ski in a.skis:
		check(ski.snow_depth==0 and ski.penetration==0 and ski.snow_drag==0,"Rock ski has no cached snow depth, penetration or drag")
	metrics.five_seconds={"rock_kmh":a.speed_kmh(),"snow_kmh":b.speed_kmh(),"reserve":a.impacts.reserve}
	var turn_rock = skier(rock); var turn_snow = skier(snow)
	# Compare response before the shared excessive-slip limit becomes active.
	advance(turn_rock,rock,.1,.6); advance(turn_snow,snow,.1,.6)
	check(absf(turn_rock.heading)<absf(turn_snow.heading)*.9,"Rock steering responds more slowly")
	advance(turn_rock,rock,.9,.6); advance(turn_snow,snow,.9,.6)
	var rock_yaw = absf(atan2(turn_rock.velocity.x,turn_rock.velocity.z))
	var snow_yaw = absf(atan2(turn_snow.velocity.x,turn_snow.velocity.z))
	check(rock_yaw<snow_yaw,"Reduced rock grip turns actual momentum less")
	metrics.turn={"rock_yaw_deg":rad_to_deg(rock_yaw),"snow_yaw_deg":rad_to_deg(snow_yaw)}
	var mixed = MaterialPlane.new(); mixed.mixed=true
	var split = skier(mixed)
	advance(split,mixed,.5)
	check(absf(split.rock_contact-.5)<.02 and absf(split.impacts.reserve-.99)<.002,"One rock ski spends reserve in proportion to support load")
	var snowy_ski = 0; var rocky_ski = 0
	for ski in split.skis:
		var response = Response.new(); response.sample(split,ski,mixed)
		if ski.material_kind==TerrainMaterial.Kind.ROCK:
			rocky_ski += 1
			check(response.sparks>0 and response.powder==0 and response.grains==0 and response.mist==0 and not response.snow_contact,"Loaded rock ski sparks and cannot emit snow")
		else:
			snowy_ski += 1
			check(response.snow_contact and response.sparks==0 and ski.snow_depth>0,"Snow ski retains independent snow response")
	check(snowy_ski==1 and rocky_ski==1,"Material boundary resolves separately under both skis")
	var effects=preload("res://scripts/presentation/speed_effects.gd").new()
	root.add_child(effects)
	effects.apply_quality(preload("res://scripts/presentation/graphics_quality.gd").preset(2))
	effects.update_effects(a,rock,a.position,DT,true)
	check(effects.rock_sparks.emitters[0].emitting and effects.rock_sparks.emitters[1].emitting,"Live effects emit sparks from both supported rock skis")
	var snow_emitting=false
	for spray in effects.sprays: snow_emitting = snow_emitting or spray.emitting
	check(not snow_emitting and effects.snow_tracks.written==0,"Live rock effects emit no powder, grains, mist or tracks")
	effects.update_effects(a,rock,a.position,DT,false)
	check(not effects.rock_sparks.emitters[0].emitting and effects.rock_sparks.emitters[0].speed_scale==0,"Pause stops spark emission and freezes its clock")
	var crash_fixture=skier(rock); crash_fixture.crash("TEST CRASH")
	effects.update_effects(crash_fixture,rock,crash_fixture.position,DT,true)
	check(not effects.rock_sparks.emitters[0].emitting,"Crash contact stops sparks")
	effects.reset()
	check(not effects.rock_sparks.emitters[1].emitting and effects.snow_tracks.written==0,"Effects reset clears rock emission and snow history")
	effects.stop_audio(); effects.queue_free()
	var tracks = preload("res://scripts/presentation/snow_tracks.gd").new()
	tracks.lighting=preload("res://scripts/presentation/cloud_lighting.gd").new()
	root.add_child(tracks)
	var snow_run = skier(snow)
	for i in 60:
		snow_run.step(DT,Intent.new(),snow)
		tracks.update_contact(snow_run,snow,snow_run.position,true)
	check(tracks.written>0,"Snow travel stamps track history")
	var count = tracks.written
	snow.rock=true
	for i in 120:
		snow_run.step(DT,Intent.new(),snow)
		tracks.update_contact(snow_run,snow,snow_run.position,true)
	check(tracks.written==count and not tracks.foot_history[0].is_finite(),"Entering rock stops stamps and breaks ribbon history")
	check(snow_run.snow_drag==0 and snow_run.skis[0].penetration==0,"Entering rock clears previous snow physics")
	snow.rock=false
	var reserve = snow_run.impacts.reserve
	advance(snow_run,snow,1.0)
	check(absf(snow_run.impacts.reserve-reserve)<.001,"Snow return waits for the recovery delay")
	advance(snow_run,snow,1.0)
	check(snow_run.impacts.reserve>reserve and snow_run.snow_depth>0,"Smooth snow restores reserve and snow contact physics")
	tracks.reset(); tracks.queue_free()
	var standing = skier(rock,0); rock.gradient=0
	standing.reset(Vector3.ZERO); standing.prime_contacts(rock)
	standing.impacts.reserve=.5
	advance(standing,rock,2)
	check(standing.impacts.reserve==.5,"Standing on rock neither wears nor refills reserve")
	var air = skier(rock)
	air.position.y=100; air.grounded=false; air.impacts.reserve=.5
	advance(air,rock,.5)
	var airborne_response=Response.new(); airborne_response.sample(air,air.skis[0],rock)
	check(air.impacts.reserve==.5 and air.rock_contact==0 and airborne_response.sparks==0,"Air above rock has no wear, contact forces or sparks")
	var passive=skier(rock,30)
	passive.tuning.aerodynamic_drag=0.0
	advance(passive,rock,1)
	check(passive.velocity.length()<30 and passive.velocity.dot(Vector3.BACK)>0,"Rock resistance dissipates energy without reversing travel")
	rock.gradient=.46
	var exhausted=skier(rock)
	advance(exhausted,rock,26)
	check(exhausted.crashed and exhausted.impacts.reserve<=.000001 and exhausted.crash_reason=="IMPACT LIMIT / ROCK WEAR","Sustained rock riding crashes only when reserve is exhausted")
	metrics.crash_seconds=exhausted.ticks*DT
	check(absf(exhausted.ticks*DT-25.0)<.02,"Full rock reserve lasts about twenty-five seconds")
	exhausted.reset(Vector3.ZERO)
	check(exhausted.impacts.reserve==1 and exhausted.rock_wear_rate==0 and not exhausted.crashed,"Restart clears rock wear and restores reserve")
	var recovery=Recovery.new()
	recovery.abrade(DT,.04)
	recovery.hit(7,7,"ROCK IMPACT",a.tuning)
	var after_first=recovery.reserve
	for i in 60:
		recovery.step(DT,false,a.tuning); recovery.abrade(DT,.04)
	recovery.hit(7,7,"SECOND IMPACT",a.tuning)
	check(after_first-recovery.reserve>.31,"Continuous abrasion cannot merge separate collision damage")
	var grid=MaskGrid.new()
	var before=[]
	for p in [Vector2(4,4),Vector2(0,0),Vector2(2,4),Vector2(2.3,5.8)]: before.append(grid.rock_fraction_at(p.x,p.y))
	grid.build_material_map()
	var after=[]
	for p in [Vector2(4,4),Vector2(0,0),Vector2(2,4),Vector2(2.3,5.8)]: after.append(grid.rock_fraction_at(p.x,p.y))
	check(before==after and after[0]==1 and after[1]==0 and is_equal_approx(after[2],.5),"Headless material sampling equals bilinear render-map sampling including boundaries")
	var wrapped=preload("res://scripts/world/prop_collision_surface.gd").new(grid)
	check(wrapped.rock_fraction_at(4,4)==1,"Runtime prop adapter preserves terrain material")
	check(Sim.MODEL_VERSION==31,"Rock response is retained in the pole propulsion physics identity")
	DirAccess.make_dir_recursive_absolute("res://artifacts/rock_terrain")
	var report={"checks":checks,"failures":failures,"metrics":metrics}
	FileAccess.open("res://artifacts/rock_terrain/physics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ROCK_RESULTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
