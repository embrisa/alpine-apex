extends SceneTree
## Contact timing and lifecycle; visual feel still requires the rendered review.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Tracks = preload("res://scripts/presentation/snow_tracks.gd")
const Response = preload("res://scripts/presentation/snow_response.gd")
var failures: Array = []
var checks = 0
class Flat extends RefCounted:
	var rock = false
	func sample(_x: float,_z: float) -> Dictionary: return {"height":0.0,"normal":Vector3.UP}
	func rock_fraction_at(_x: float,_z: float) -> float: return 1.0 if rock else 0.0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ",label)
	if not value: failures.append(label)
func run() -> void:
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	sim.contacts_initialized = true
	sim.velocity = Vector3.BACK*36.0
	var field = Flat.new()
	var tracks = Tracks.new()
	tracks.lighting = preload("res://scripts/presentation/cloud_lighting.gd").new()
	root.add_child(tracks)
	var responses = [Response.new(),Response.new()]
	for i in 2:
		var ski = sim.skis[i]
		ski.position = Vector3(i*.5,0,0)
		ski.forward = Vector3.BACK
		ski.grounded = true; ski.load_n = 700; ski.snow_depth = .24; ski.penetration = .08
		responses[i].sample(sim,ski)
	tracks.update_contact(sim,field,sim.position,true,responses)
	check(tracks.written==0 and tracks.live_active==[true,true],"Both tips open snow immediately before any history sample exists")
	for i in 2:
		var front: Vector3 = tracks.live_transforms[i]*Vector3(0,0,.5)
		check(front.distance_to(responses[i].contact_position+Vector3.BACK*(sim.tuning.ski_length*.5+.12))<.001,"Live track reaches visible ski tip %d"%i)
	for frame in 8:
		for response in responses: response.contact_position.z+=.1
		tracks.update_contact(sim,field,sim.position,true,responses)
		var front: Vector3 = tracks.live_transforms[0]*Vector3(0,0,.5)
		check(absf(front.z-(responses[0].contact_position.z+sim.tuning.ski_length*.5+.12))<.001,"Tip remains current between distance samples %d"%frame)
	var count: int = tracks.written
	tracks.update_contact(sim,field,sim.position,true,responses)
	check(tracks.written==count,"Stationary live footprints do not consume ring history")
	for response in responses: response.snow_contact = false
	tracks.update_contact(sim,field,sim.position,true,responses)
	check(tracks.live_active==[false,false] and not tracks.foot_history[0].is_finite(),"Departure hides live cuts and breaks history")
	for response in responses: response.snow_contact = true; response.contact_position.z+=40
	tracks.update_contact(sim,field,sim.position,true,responses)
	check(tracks.written==count and tracks.live_transforms[0].basis.z.length()<2.2,"Landing or teleport starts a local footprint without bridging the gap")
	field.rock = true
	tracks.update_contact(sim,field,sim.position,true,responses)
	check(tracks.live_active==[false,false],"Live footprints also reject exposed rock ahead of the contact")
	tracks.reset()
	check(tracks.written==0 and tracks.live_active==[false,false],"Reset clears both retained and live cuts")
	var effects = preload("res://scripts/presentation/speed_effects.gd").new()
	root.add_child(effects)
	var visuals: Array = [Node3D.new(),Node3D.new()]
	for i in 2:
		root.add_child(visuals[i])
		visuals[i].position = Vector3(i*2.0,0,10.0+i)
		visuals[i].basis = Basis(Vector3.UP,.4+i*.1)
	field.rock = false
	var before = [sim.position,sim.velocity,sim.skis[0].position,sim.skis[1].position]
	for reverse in [false,true]:
		sim.facing_backward = reverse
		effects.update_effects(sim,field,sim.position,.016,true,null,null,null,false,false,visuals)
		for i in 2:
			var visual = visuals[1-i if reverse else i]
			check(effects.responses[i].contact_position==visual.global_position and effects.responses[i].contact_forward.is_equal_approx(visual.global_basis.z),"Snow follows exact rendered equipment pose, switch=%s ski=%d"%[reverse,i])
	check(before==[sim.position,sim.velocity,sim.skis[0].position,sim.skis[1].position],"Rendered contact anchoring does not change physical ski state")
	effects.stop_audio(); effects.queue_free()
	for visual in visuals: visual.queue_free()
	tracks.queue_free(); await process_frame
	print("SNOW_CONTACT_VISUAL_CHECKS ",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
