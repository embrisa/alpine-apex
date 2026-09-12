extends SceneTree
## Contact timing and lifecycle; visual feel still requires the rendered review.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Tracks = preload("res://scripts/presentation/snow_tracks.gd")
const Response = preload("res://scripts/presentation/snow_response.gd")
var failures: Array = []
var checks = 0
class Flat extends RefCounted:
	var rock = false
	var drop_x = INF
	var strip_z = INF
	var depth = .24
	var rock_x = INF
	var boundary_x = 100.0
	func bounds() -> Rect2: return Rect2(-100,-100,100+boundary_x,200)
	func sample(x: float,_z: float) -> Dictionary: return {"height":-2.0 if x>drop_x else 0.0,"normal":Vector3.UP}
	func rock_fraction_at(x: float,z: float) -> float: return 1.0 if rock or x>rock_x or absf(z-strip_z)<.2 else 0.0
	func snow_depth_at(_x: float,_z: float) -> float: return depth
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
	for response in responses: response.snow_contact = false; response.track_contact = false
	tracks.update_contact(sim,field,sim.position,true,responses)
	check(tracks.live_active==[false,false] and not tracks.foot_history[0].is_finite(),"Departure hides live cuts and breaks history")
	for response in responses: response.snow_contact = true; response.track_contact = true; response.contact_position.z+=40
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
	await raised_carving_checks(field)
	await grounded_continuity_checks()
	effects.stop_audio(); effects.queue_free()
	for visual in visuals: visual.queue_free()
	tracks.queue_free(); await process_frame
	print("SNOW_CONTACT_VISUAL_CHECKS ",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func raised_carving_checks(field) -> void:
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	sim.contacts_initialized = true
	sim.velocity = Vector3.BACK*25.0
	for i in 2:
		var ski = sim.skis[i]
		ski.position = Vector3((i-.5)*.5,0,0)
		ski.forward = Vector3.BACK
		ski.grounded = true
		ski.load_n = 500.0
		ski.grip_n = 300.0
		ski.edge_angle = .4
		ski.snow_depth = .24
		ski.penetration = .08
	var flat = Tracks.new()
	var raised = Tracks.new()
	for ribbon in [flat,raised]:
		ribbon.lighting = preload("res://scripts/presentation/cloud_lighting.gd").new()
		root.add_child(ribbon)
	var state = physical_state(sim)
	var plain = [Response.new(),Response.new()]
	var lifted = [Response.new(),Response.new()]
	var matched = true
	for frame in 90:
		for i in 2:
			plain[i].sample(sim,sim.skis[i],field)
			plain[i].contact_position.z += frame*.11
			lifted[i].sample(sim,sim.skis[i],field)
			lifted[i].contact_position = plain[i].contact_position+Vector3.UP*(.18 if i==frame/30%2 else 0.0)
			plain[i].resolve_track_contact(sim,sim.skis[i],field)
			lifted[i].resolve_track_contact(sim,sim.skis[i],field)
		flat.update_contact(sim,field,sim.position,true,plain)
		raised.update_contact(sim,field,sim.position,true,lifted)
		matched = matched and flat.live_active==[true,true] and raised.live_active==[true,true]
		matched = matched and flat.live_gpu_strokes()==raised.live_gpu_strokes() and flat.gpu_stamps==raised.gpu_stamps
	check(matched and flat.written>10,"Only cosmetic elevation changes: both live and retained GPU/ribbon geometry stay identical through ski lift swaps")
	check(state==physical_state(sim),"Cosmetic elevation chronology leaves completed physics unchanged")
	flat.reset(); raised.reset()
	var ski = sim.skis[0]
	ski.grounded = false; ski.load_n = 0.0; ski.grip_n = 0.0
	ski.snow_depth = 0.0; ski.penetration = 0.0
	state = physical_state(sim)
	for direction in [-1.0,1.0,-1.0]:
		sim.skis[1].edge_angle = direction*.4
		for i in 2:
			lifted[i].sample(sim,sim.skis[i],field)
			lifted[i].contact_position.y += .18 if i==0 else 0.0
			lifted[i].resolve_track_contact(sim,sim.skis[i],field)
		raised.update_contact(sim,field,sim.position,true,lifted)
		check(lifted[0].track_contact and lifted[0].cosmetic_track and raised.live_active==[true,true],"Near-surface unloaded carving keeps separate ski marks, edge sign %s"%direction)
		check(not lifted[0].supported and not lifted[0].snow_contact and lifted[0].powder==0.0 and lifted[0].grains==0.0 and lifted[0].mist==0.0 and lifted[0].sparks==0.0,"Track continuation grants no support, snow spray or sparks")
		check(lifted[0].track_depth_m>0.0 and lifted[0].track_depth_m<=Response.COSMETIC_DEPTH_M,"Unloaded impression remains modest and bounded")
	# Ignore the explicitly changed loaded ski edge above in this mutation check.
	sim.skis[1].edge_angle = .4
	check(state==physical_state(sim),"Low-load track resolution leaves completed contacts and forces unchanged")
	for reason in ["air","drop","tip_drop","rock","tip_rock","crash","no_turn","speed","separating","physical_reach","visual_reach","depth"]:
		field.drop_x = INF; field.strip_z = INF; field.rock = false; field.depth = .24
		sim.grounded = true; sim.crashed = false; sim.velocity = Vector3.BACK*25.0
		ski.clearance_m = 0.0; ski.normal_speed_ms = 0.0
		sim.skis[1].edge_angle = .4
		if reason=="air": sim.grounded = false
		if reason=="drop": field.drop_x = -.3
		if reason=="tip_drop": field.drop_x = -.15
		if reason=="rock": field.rock = true
		if reason=="tip_rock": field.strip_z = sim.tuning.ski_length*.5
		if reason=="crash": sim.crashed = true
		if reason=="no_turn": sim.skis[1].edge_angle = 0.0
		if reason=="speed": sim.velocity = Vector3.ZERO
		if reason=="separating": ski.normal_speed_ms = 1.01
		if reason=="physical_reach": ski.clearance_m = .121
		if reason=="depth": field.depth = 0.0
		lifted[0].sample(sim,ski,field)
		lifted[0].contact_position.y += .25 if reason=="visual_reach" else .18
		lifted[0].resolve_track_contact(sim,ski,field)
		raised.update_contact(sim,field,sim.position,true,lifted)
		check(not lifted[0].track_contact and not raised.live_active[0] and not raised.foot_history[0].is_finite(),"True exclusion breaks cosmetic history: "+reason)
		check(raised.live_gpu_strokes()[5]==0.0,"Excluded live GPU footprint has zero depth: "+reason)
	field.rock = false; field.drop_x = INF; field.strip_z = INF; field.depth = .24
	sim.grounded = true; sim.crashed = false; sim.skis[1].edge_angle = .4
	sim.velocity = Vector3.BACK*25.0; ski.clearance_m = 0.0; ski.normal_speed_ms = 0.0
	for i in 2:
		lifted[i].sample(sim,sim.skis[i],field)
		lifted[i].resolve_track_contact(sim,sim.skis[i],field)
	raised.update_contact(sim,field,sim.position,true,lifted)
	var revision: int = raised.revision
	raised.update_contact(sim,field,sim.position,false,lifted)
	check(raised.live_active==[false,false] and raised.live_gpu_strokes()[5]==0 and raised.live_gpu_strokes()[13]==0 and raised.revision>revision,"Inactive transition clears both GPU footprints and invalidates cached upload")
	raised.update_presentation(field,sim.position,true,lifted,sim.tuning.ski_length)
	check(raised.live_active==[true,true],"Ghost presentation API accepts evaluated responses without a solver")
	field.strip_z = sim.tuning.ski_length*.5
	raised.update_presentation(field,sim.position,true,lifted,sim.tuning.ski_length)
	check(not raised.foot_history[0].is_finite() and raised.live_gpu_strokes()[5]==0,"Mixed snow/rock breaks the live/history anchor and GPU footprint together")
	field.strip_z = INF
	var count: int = raised.written
	for response in lifted: response.contact_position.z += 40.0
	raised.update_presentation(field,sim.position,true,lifted,sim.tuning.ski_length)
	check(raised.written==count and raised.live_transforms[0].basis.z.length()<2.2,"Re-entry after an excluded interval cannot bridge to pre-gap history")
	count = raised.written
	for response in lifted: response.contact_position.z += 40.0
	raised.update_presentation(field,sim.position,true,lifted,sim.tuning.ski_length)
	check(raised.written==count and raised.live_transforms[0].basis.z.length()<2.2,"Supported teleport also starts a local footprint without a bridge")
	raised.reset()
	check(raised.written==0 and raised.live_gpu_strokes()[5]==0 and raised.live_gpu_strokes()[13]==0,"Reset clears retained history and GPU live depth")
	flat.queue_free(); raised.queue_free(); await process_frame

func physical_state(sim) -> Array:
	var state = [sim.position,sim.velocity,sim.grounded,sim.crashed,sim.heading,sim.edge_angle]
	for ski in sim.skis:
		state.append([ski.position,ski.orientation,ski.grounded,ski.load_n,ski.grip_n,ski.edge_angle,ski.penetration,ski.snow_depth,ski.material_kind,ski.clearance_m,ski.normal_speed_ms,ski.forward])
	return state

func grounded_continuity_checks() -> void:
	# Mechanisms measured in native v2: right/44 burial, reversal/288 root
	# extension, right/264 release. These are contact/geometry regressions,
	# not a substitute for rerunning the ordinary-input native chronology.
	var field = Flat.new()
	field.depth = .10
	var sim = Sim.new()
	sim.reset(Vector3.ZERO)
	sim.contacts_initialized = true
	sim.velocity = Vector3.BACK*25.0
	var tracks = Tracks.new()
	tracks.lighting = preload("res://scripts/presentation/cloud_lighting.gd").new()
	root.add_child(tracks)
	var responses = [Response.new(),Response.new()]
	var cases = [
		{"name":"right44_burial","load":.432818,"root_clearance":-.208734,"normal_speed":.217982,"lift":-.115854},
		{"name":"reversal288_extension","load":.664996,"root_clearance":.131302,"normal_speed":-.033332,"lift":.015564},
		{"name":"release264_unloaded","load":.676818,"root_clearance":-.071062,"normal_speed":.048928,"lift":.019259}]
	for measured in cases:
		for inner in 2:
			tracks.reset()
			var continuous = true
			var independent = true
			var shallow_only = true
			var immutable = true
			for frame in 60:
				for i in 2:
					var ski = sim.skis[i]
					ski.position = Vector3((i-.5)*.7,0,frame*.11)
					ski.forward = Vector3.BACK
					ski.grounded = true; ski.load_n = measured.load if i==inner else 700.0
					ski.snow_depth = field.depth; ski.penetration = .05
					ski.material_kind = 0
					ski.clearance_m = measured.root_clearance if i==inner else 0.0
					ski.normal_speed_ms = measured.normal_speed if i==inner else 0.0
					# Cross entry, hold, reversal and zero-edge/zero-grip release.
					ski.edge_angle = 0.0 if frame<15 or frame>=45 else (.4 if frame<30 else -.4)
					ski.grip_n = 0.0 if frame<15 or frame>=45 else 300.0
				var before = var_to_bytes(physical_state(sim))
				for i in 2:
					responses[i].sample(sim,sim.skis[i],field)
					if i==inner:
						responses[i].contact_position.y = measured.lift
						if measured.name=="right44_burial":
							# Measured rigid direction intersects more deeply at the tip.
							responses[i].contact_forward = Vector3(.486916,-.100904,.867601).normalized()
					responses[i].resolve_track_contact(sim,sim.skis[i],field)
				tracks.update_contact(sim,field,sim.position,true,responses)
				continuous = continuous and tracks.live_active==[true,true]
				var light = responses[inner]
				shallow_only = shallow_only and light.cosmetic_track and light.track_depth_m>0.0 and light.track_depth_m<=.012
				shallow_only = shallow_only and not light.supported and not light.snow_contact and light.powder==0 and light.grains==0 and light.mist==0 and light.sparks==0
				shallow_only = shallow_only and light.contact_width_m==.30 and light.width_m==.28
				for i in 2:
					var tip: Vector3 = tracks.live_transforms[i]*Vector3(0,0,.5)
					var expected: Vector3 = responses[i].contact_position+responses[i].contact_forward*(sim.tuning.ski_length*.5+.12)
					independent = independent and Vector2(tip.x-expected.x,tip.z-expected.z).length()<.0002 and absf(tip.y)<.0001
					independent = independent and tracks.live_gpu_strokes()[i*8+5]>0.0
				immutable = immutable and before==var_to_bytes(physical_state(sim))
			check(continuous and tracks.written>10,"Measured grounded continuity through entry/hold/reversal/release: %s ski%d"%[measured.name,inner])
			check(independent and shallow_only,"Independent projected shallow ribbons/GPU with no support or particles: %s ski%d"%[measured.name,inner])
			check(immutable,"Measured continuity preserves physical bytes including root reach/velocity: %s ski%d"%[measured.name,inner])
	# Grounded status is not permission to paint through a drop, rock or void.
	# Prime a valid mark before each rejection so stale live/history is tested.
	for reason in ["air","crash","center_drop","edge_drop","rock","edge_rock","void","depth","deep_center","deep_tip","visual_lift","physical_lift"]:
		field.rock = false; field.rock_x = INF; field.drop_x = INF; field.depth = .10; field.boundary_x = 100.0
		sim.grounded = true; sim.crashed = false
		for i in 2:
			var ski = sim.skis[i]
			ski.position = Vector3(-.5 if i==0 else .25,0,0)
			ski.forward = Vector3.BACK; ski.grounded = true; ski.load_n = 700.0 if i==0 else .67
			ski.snow_depth = .10; ski.penetration = .05; ski.material_kind = 0
			ski.edge_angle = 0.0; ski.grip_n = 0.0; ski.clearance_m = .1313; ski.normal_speed_ms = 0.0
			responses[i].sample(sim,ski,field); responses[i].resolve_track_contact(sim,ski,field)
		tracks.update_contact(sim,field,sim.position,true,responses)
		check(tracks.live_active==[true,true],"Grounded valid primer: "+reason)
		var ski = sim.skis[1]
		if reason=="air": sim.grounded = false
		if reason=="crash": sim.crashed = true
		if reason=="center_drop": field.drop_x = .20
		if reason=="edge_drop": field.drop_x = .30
		if reason=="rock": field.rock = true
		if reason=="edge_rock": field.rock_x = .30
		if reason=="void": field.boundary_x = .30
		if reason=="depth": field.depth = 0.0
		if reason=="deep_center": ski.position.y = -.5
		if reason=="physical_lift": ski.position.y = .121
		var before = var_to_bytes(physical_state(sim))
		responses[1].sample(sim,ski,field)
		if reason=="visual_lift": responses[1].contact_position.y = .25
		if reason=="deep_tip":
			responses[1].contact_position.y = -.10
			responses[1].contact_forward = Vector3(0,-.3,1).normalized()
		responses[1].resolve_track_contact(sim,ski,field)
		tracks.update_contact(sim,field,sim.position,true,responses)
		check(not responses[1].track_contact and not tracks.live_active[1] and not tracks.foot_history[1].is_finite() and tracks.live_gpu_strokes()[13]==0.0,"Grounded rejection clears ribbon/history/GPU: "+reason)
		if reason in ["edge_drop","edge_rock","void","deep_tip","visual_lift","physical_lift"]:
			check(tracks.live_active[0],"One-ski rejection preserves the other mark: "+reason)
			check(not responses[1].track_rejection.is_empty() and responses[1].track_rejection.probe!="","Rejection identifies the actual footprint pass/point: "+reason)
		check(before==var_to_bytes(physical_state(sim)),"Grounded exclusion preserves completed physical bytes: "+reason)
	tracks.queue_free(); await process_frame
