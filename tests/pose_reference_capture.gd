extends SceneTree
## Offline evidence only: production simulation and final pose writer on v14.
## No RunSession, replay recorder, settings store, or second pose writer.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Visual = preload("res://scripts/presentation/skier_visual.gd")
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Layout = preload("res://scripts/world/flavor_layout.gd")
const DT = 1.0/120.0
const SCENARIOS = ["regular","tuck","prepare_takeoff","carve_left","carve_right","landing"]
const TURN_TRANSITIONS = ["carve_reversal","carve_taps"]
var output = "res://artifacts/pose_review/capture"
var field
var layout
var skier
var scene: Node3D
var cameras: Array[Camera3D] = []
var views: Array[SubViewport] = []
var report: Dictionary = {}
var probe = false
var scenarios = SCENARIOS.duplicate()

func _initialize(): call_deferred("run")

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--scenarios="):
			scenarios = Array(arg.trim_prefix("--scenarios=").split(","))
			for name in scenarios: assert(name in SCENARIOS or name in TURN_TRANSITIONS,"Unknown capture scenario")
	probe = "--probe" in OS.get_cmdline_user_args()
	if not probe and DisplayServer.get_name()=="headless": quit(2); return
	if FileAccess.file_exists(output+"/manifest.json"):
		push_error("Capture already exists. Choose a new revision/output directory to preserve previous evidence.")
		quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	report = {"version":1,"created_utc":Time.get_datetime_string_from_system(true),"engine":Engine.get_version_info().string,
		"physics":Sim.MODEL_VERSION,"seed":849205174,"mountain_version":14,"capture_fps":60,"simulation_hz":120,"frame_origin":0,
		"unranked":true,"scope":"Production solver and final skier pose on actual v14 terrain. Studio lighting; distant scenery omitted. No race session exists.",
		"sources":source_hashes(),"scenarios":[],"failures":[],"notes":["Three synchronized cameras: reference oblique, anatomical front, skier left side.","Cameras follow yaw and translation, preserving slope pitch and bank. No limb or actor pose normalization.","High-style cosmetic ski burial enabled; studio background is not terrain geometry."]}
	print("POSE_REVIEW_LOADING_V14")
	field = Definition.generate(849205174,14)
	field.build_material_map()
	layout = Layout.for_field(field)
	report.terrain = {"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"cache_hit":field.cache_hit,"layout_fingerprint":layout.fingerprint}
	print("POSE_REVIEW_TERRAIN_READY cache=",field.cache_hit)
	scene = Node3D.new(); root.add_child(scene)
	skier = Visual.new(); skier.preview_only = true; skier.snow_burial_enabled = true
	scene.add_child(skier); await process_frame
	report.rig = {"names":[],"parents":[],"rest":[]}
	for i in skier.skeleton.get_bone_count():
		report.rig.names.append(skier.skeleton.get_bone_name(i))
		report.rig.parents.append(skier.skeleton.get_bone_parent(i))
		report.rig.rest.append(pack(skier.rest[i]))
	if not probe: setup_render()
	for name in scenarios:
		var selected = choose_fixture(name)
		if selected.is_empty(): report.failures.append(name+": no event-valid fixture"); continue
		await capture_sequence(name,selected)
	report.sources_after = source_hashes()
	report.stable_sources = report.sources==report.sources_after
	if not report.stable_sources: report.failures.append("Production source changed during capture")
	FileAccess.open(output+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("POSE_REVIEW_COMPLETE ",output," failures=",report.failures)
	scene.queue_free(); await process_frame
	quit(0 if report.failures.is_empty() else 1)

func setup_render():
	root.size = Vector2i(1800,1000); root.title = "Alpine Apex | Pose reference capture"
	Engine.max_fps = 120
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("a1a4aa")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("eef2ff"); env.environment.ambient_light_energy = .85
	scene.add_child(env)
	for spec in [[Vector3(-40,-30,0),1.5],[Vector3(-25,145,0),.65]]:
		var light = DirectionalLight3D.new(); light.rotation_degrees = spec[0]; light.light_energy = spec[1]; scene.add_child(light)
	for index in 3:
		var container = SubViewportContainer.new(); root.add_child(container)
		container.position = Vector2(index*600,0); container.size = Vector2(600,1000)
		var viewport = SubViewport.new(); viewport.size = Vector2i(600,1000)
		viewport.world_3d = root.world_3d; viewport.msaa_3d = Viewport.MSAA_4X
		container.add_child(viewport); views.append(viewport)
		var camera = Camera3D.new(); viewport.add_child(camera); camera.current = true
		camera.near = .03; camera.far = 50; camera.fov = 35
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 3.8
		cameras.append(camera)

func intent_at(name: String,tick: int):
	var input = RiderInput.new(); var t = tick*DT
	if name=="regular": input.tuck = .35*smoothstep(.5,2.0,t)
	if name=="tuck": input.tuck = smoothstep(.25,.9,t)*(1.0-smoothstep(1.65,2.4,t))
	if name=="prepare_takeoff":
		input.tuck = .7 if t<1.1 else 0.0
		input.jump_held = tick>=48 and tick<132
		input.jump = tick==132
	if name.begins_with("carve"):
		input.steer = (-.55 if name=="carve_left" else .55)*smoothstep(.25,.75,t)*(1.0-smoothstep(1.65,2.35,t))
	if name=="carve_reversal":
		input.steer = .55 if t>=.3 and t<1.2 else -.55 if t>=1.7 and t<2.5 else .55 if t>=2.5 and t<3.0 else 0.0
		if t>=1.2 and t<1.7: input.steer = -.7 if int((t-1.2)/.16)%2==0 else .7
	if name=="carve_taps":
		input.steer = (.8 if int((tick-60)/12)%2==0 else -.8) if tick>=60 and tick<300 else 0.0
	return input

func frame_count(name: String) -> int:
	if name in TURN_TRANSITIONS: return 240
	return 192 if name=="prepare_takeoff" else 180

func reset_sim(name: String,fixture: Dictionary):
	var sim = Sim.new(); var origin: Vector3 = fixture.origin
	if name=="landing": origin += Vector3.UP*1.2
	sim.reset(origin,fixture.heading); sim.prime_contacts(field)
	sim.velocity = sim.support_basis().z*(25.0 if name=="tuck" else 18.0)
	if name=="landing":
		sim.velocity += Vector3.DOWN*3.0; sim._begin_flight(sim.support_basis())
	sim.reset_pose_history()
	return sim

func choose_fixture(name: String) -> Dictionary:
	# Selection depends only on collision clearance, support and event availability.
	# Never select a fixture by how well its body pose resembles the reference.
	for z in [2150.0,1900.0,1550.0,1100.0,820.0,2050.0,1800.0,1300.0,950.0,650.0,2300.0,2200.0,1700.0,1450.0,1200.0,1000.0,750.0,500.0,400.0,350.0]:
		for side in [-1,1]:
			var face = field.faces[0]
			var x: float = face.glade_x(z,side) if z>1850 else face.gully_x(z,side)
			var p: Vector2 = face.to_world(Vector2(x,z))
			var fixture = {"origin":Vector3(p.x,field.sample(p.x,p.y).height,p.y),"heading":face.heading,"face":0,"local_x":x,"local_z":z}
			var sim = reset_sim(name,fixture); var airborne = 0; var hops = 0; var contacts = 0; var clear = true
			var initial_normal: Vector3 = sim.surface_normal
			var peak_bank = 0.0; var peak_supported = false
			for tick in frame_count(name)*2:
				var fixture_input = intent_at(name,tick)
				sim.step(DT,fixture_input,field)
				if name in ["carve_left","carve_right"] and absf(fixture_input.steer)>.45 and absf(sim.body.roll)>deg_to_rad(10):
					if sim.body.roll*fixture_input.steer<0: clear=false; break
				if (tick+1)%2==0 and absf(sim.body.roll)>absf(peak_bank):
					peak_bank=sim.body.roll; peak_supported=sim.grounded
				if sim.jump_executed: hops += 1
				if sim.grounded: contacts += 1
				else: airborne += 1
				if sim.crashed or not layout.point_clear(sim.position,8) or not sim.motion.obstacle_contact.is_empty(): clear=false; break
				# Untimed straight-downhill references need a stable supported
				# segment, not a mound traversal or obstacle recoil masquerading
				# as tuck release. This criterion uses terrain/contact only.
				if name in ["regular","tuck"] and sim.surface_normal.angle_to(initial_normal)>deg_to_rad(10): clear=false; break
			if not clear: continue
			# A supported reference turn must actually bank into the requested
			# direction. Terrain-driven counterbank is a different physical event;
			# this criterion never inspects animation or resemblance to a picture.
			if name in ["carve_left","carve_right"]:
				var direction = -1.0 if name=="carve_left" else 1.0
				if airborne>0 or not peak_supported or peak_bank*direction<deg_to_rad(10.0): continue
				fixture.peak_physical_bank_rad=peak_bank
				fixture.selection_policy="fully supported, direction-consistent held turn with matching peak bank"
			if name=="prepare_takeoff" and (hops!=1 or airborne<6): continue
			if name=="landing" and contacts<120: continue
			if name not in ["prepare_takeoff","landing"] and airborne>12: continue
			fixture.supported_ticks = contacts; fixture.airborne_ticks = airborne; fixture.executed_jumps = hops
			return fixture
	return {}

func capture_sequence(name: String,fixture: Dictionary):
	var sim = reset_sim(name,fixture); skier.reset_animation(sim)
	var trace: Array = []; var events: Array = []; var was_grounded: bool = sim.grounded; var old_landing = 0
	var frame_folder = output+"/"+name
	if not probe: DirAccess.make_dir_recursive_absolute(frame_folder)
	for frame in frame_count(name):
		for sub in 2:
			var tick = frame*2+sub; var input = intent_at(name,tick)
			sim.step(DT,input,field); skier.step_animation(DT,sim,input,field)
			if sim.jump_executed: events.append({"type":"jump","tick":sim.ticks,"time":sim.ticks*DT})
			if was_grounded and not sim.grounded: events.append({"type":"support_loss","tick":sim.ticks,"time":sim.ticks*DT})
			if not was_grounded and sim.grounded: events.append({"type":"contact","tick":sim.ticks,"time":sim.ticks*DT})
			if skier.animation.landing_events!=old_landing: events.append({"type":"landing_episode","tick":sim.ticks,"time":sim.ticks*DT}); old_landing=skier.animation.landing_events
			was_grounded = sim.grounded
		var invariant = [sim.position,sim.velocity,sim.ticks,sim.body.roll,sim.body.pitch,sim.body.joints.duplicate(true)]
		skier.pose(sim,1.0)
		assert(invariant==[sim.position,sim.velocity,sim.ticks,sim.body.roll,sim.body.pitch,sim.body.joints],"Pose wrote simulation")
		var full = skier.animation.full_motion
		var row = {"frame":frame,"time":sim.ticks*DT,"tick":sim.ticks,"grounded":sim.grounded,"jump_executed":sim.jump_executed,"phase":skier.animation.phase,
			"ski_edges_rad":[sim.skis[0].edge_angle,sim.skis[1].edge_angle],"ski_loads_n":[sim.skis[0].load_n,sim.skis[1].load_n],
			"state":pack(skier.animation.current),"diagnostics":pack(full.diagnostics),"clips":clip_times(full),"root":pack(skier.global_transform),
			"joints":pack(skier.rendered_joints),"rotations":pack(skier.rendered_rotations),"requested":pack(full.requested_joints),"requested_rotations":pack(full.requested_rotations),
			"physical_position":pack(sim.position),"body_roll_rad":sim.body.roll,"speed_mps":sim.velocity.length(),"landing_speed_mps":sim.motion.landing_speed_mps,
			"final_bones":[],"skis":[],"poles":[],"cameras":[],"input":pack({"steer":intent_at(name,frame*2+1).steer,"tuck":intent_at(name,frame*2+1).tuck,"jump_held":intent_at(name,frame*2+1).jump_held})}
		for i in skier.skeleton.get_bone_count(): row.final_bones.append(pack(skier.skeleton.get_bone_global_pose(i)))
		for ski in skier.skis: row.skis.append(pack(ski.global_transform))
		for pole in skier.poles: row.poles.append(pack(pole.global_transform))
		if not probe:
			position_cameras(sim,name)
			for camera in cameras: row.cameras.append({"transform":pack(camera.global_transform),"size":camera.size,"projection":"orthographic"})
			await process_frame; await RenderingServer.frame_post_draw
			var picture = root.get_texture().get_image()
			assert(picture.get_size()==Vector2i(1800,1000))
			picture.save_jpg(frame_folder+"/%04d.jpg"%frame,.94)
		trace.append(row)
		if sim.crashed: report.failures.append(name+": "+sim.crash_reason); break
	FileAccess.open(output+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify({"name":name,"fixture":pack(fixture),"events":events,"frames":trace},"\t"))
	report.scenarios.append({"name":name,"frames":trace.size(),"fixture":pack(fixture),"events":events})
	print("POSE_REVIEW_SEQUENCE ",name," frames=",trace.size()," events=",events)

func position_cameras(sim,name: String):
	# Horizontal heading frame: no banking or slope rotation hidden by the camera.
	var heading = Basis(Vector3.UP,atan2(skier.global_basis.z.x,skier.global_basis.z.z))
	var focus = sim.position+Vector3.UP*.65
	var oblique = Vector3(4.5,1.15,2.4) if not name.begins_with("carve") else Vector3(1.1,1.15,5)
	var directions = [oblique,Vector3(0,.45,5),Vector3(5,.25,0)]
	for i in 3:
		cameras[i].position = focus+heading*directions[i]
		cameras[i].look_at(focus,Vector3.UP)

func clip_times(full) -> Dictionary:
	var result = full.weights.duplicate(true)
	var total = 0.0
	for name in result: total += result[name].weight
	for name in result:
		var entry: Dictionary = result[name]; var clip: Dictionary = full.library.clips[name]
		var seam = minf(.25,clip.duration*.2)
		var t = clampf(entry.time,0,clip.duration)
		if entry.loop: t=seam+fposmod(entry.time,maxf(.01,clip.duration-seam))
		entry.normalized_weight = entry.weight/maxf(total,.000001)
		entry.source_time = t; entry.source_frame = minf(t*60,clip.frames-1)
		entry.seam_blend = smoothstep(clip.duration-seam,clip.duration,t) if entry.loop and t>clip.duration-seam else 0.0
		entry.seam_source_time = t-(clip.duration-seam) if entry.seam_blend>0 else null
	return result

func source_hashes() -> Dictionary:
	var result = {}
	for dir in ["res://scripts/core","res://scripts/presentation","res://scripts/world","res://config"]: hash_dir(dir,result)
	for file in ["res://assets/animation/steep_ski_motion.res","res://assets/graphics/models/skier_v7.glb","res://project.godot","res://tests/pose_reference_capture.gd"]:
		result[file] = FileAccess.get_sha256(file)
	# Pose and shaft evidence depends on rigid equipment geometry too. Older
	# captures omitted these assets; do not claim their provenance retroactively.
	for id in ["ski_detailed_v1","ski_detailed_v1_left",preload("res://scripts/presentation/skier_equipment.gd").BINDING_MESH,"skier_v7_boot_right","skier_v7_boot_left","pole_detailed_v1"]:
		var file = "res://assets/graphics/models/"+id+".glb"
		result[file] = FileAccess.get_sha256(file)
	return result

func hash_dir(path: String,result: Dictionary):
	for name in DirAccess.get_files_at(path):
		if name.get_extension() in ["gd","tres","json","gdshader","gdshaderinc"]: result[path+"/"+name]=FileAccess.get_sha256(path+"/"+name)
	for name in DirAccess.get_directories_at(path): hash_dir(path+"/"+name,result)

func pack(value):
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Basis: return [pack(value.x),pack(value.y),pack(value.z)]
	if value is Transform3D: return {"origin":pack(value.origin),"basis":pack(value.basis)}
	if value is Dictionary:
		var result = {}; for key in value: result[key]=pack(value[key])
		return result
	if value is Array:
		var result = []; for item in value: result.append(pack(item))
		return result
	return value
