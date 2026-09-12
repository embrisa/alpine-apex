extends "res://tests/powder_upload_suite.gd"
## Native proof that accepted cosmetic live strokes reach the same GPU map,
## and inactive/rock/departure transitions erase them without a phantom cut.
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Response = preload("res://scripts/presentation/snow_response.gd")

class Snow extends RefCounted:
	var rock = false
	func sample(_x: float, _z: float) -> Dictionary: return {"height":0.0,"normal":Vector3.UP}
	func snow_depth_at(_x: float, _z: float) -> float: return .24
	func rock_fraction_at(_x: float, _z: float) -> float: return 1.0 if rock else 0.0

func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("Native RenderingDevice required"); quit(2); return
	Engine.max_fps = 120
	tracks = Tracks.new(); tracks.lighting = Clouds.new(); root.add_child(tracks)
	tracks.apply_quality(Graphics.preset(2))
	surface = Powder.new(); root.add_child(surface)
	RenderingServer.call_on_render_thread(surface._render_setup)
	for i in 300:
		if surface.available: break
		await process_frame
	if not surface.available: printerr("Powder compute failed to initialize"); quit(2); return
	var sim = Sim.new(); sim.reset(Vector3.ZERO)
	sim.contacts_initialized = true; sim.velocity = Vector3.BACK*25.0
	var snow = Snow.new()
	var responses = [Response.new(),Response.new()]
	for i in 2:
		var ski = sim.skis[i]
		ski.position = Vector3((i-.5)*.6,0,0); ski.forward = Vector3.BACK
		ski.grounded = i==1; ski.load_n = 500.0 if i==1 else 0.0
		ski.grip_n = 300.0 if i==1 else 0.0; ski.edge_angle = .4
		ski.snow_depth = .24 if i==1 else 0.0; ski.penetration = .08 if i==1 else 0.0
	var blank = await submit_live()
	for i in 2:
		responses[i].sample(sim,sim.skis[i],snow)
		responses[i].contact_position.y += .18 if i==0 else 0.0
		responses[i].resolve_track_contact(sim,sim.skis[i],snow)
	responses[0].track_contact = false
	tracks.update_contact(sim,snow,sim.position,true,responses)
	var loaded_only = await submit_live()
	responses[0].resolve_track_contact(sim,sim.skis[0],snow)
	tracks.update_contact(sim,snow,sim.position,true,responses)
	var cosmetic = await submit_live()
	verify(cosmetic!=loaded_only and tracks.live_gpu_strokes()[5]>0.0,"Native map contains the separate near-surface cosmetic footprint")
	var full = tracks.gpu_stamps.duplicate(); full.append_array(tracks.live_gpu_strokes())
	var expected = await render_and_read([{"offset":0,"bytes":full.to_byte_array()}],Vector2.ZERO)
	verify(cosmetic==expected,"Cosmetic partial upload matches complete buffer byte-for-byte")
	responses[0].contact_position.y = 0.0
	tracks.update_contact(sim,snow,sim.position,true,responses)
	verify(await submit_live()==cosmetic,"Changing only rendered ski elevation preserves the native impression")
	tracks.update_contact(sim,snow,sim.position,false,responses)
	verify(await submit_live()==blank,"Inactive transition removes both GPU live cuts")
	tracks.update_contact(sim,snow,sim.position,true,responses)
	snow.rock = true
	tracks.update_contact(sim,snow,sim.position,true,responses)
	verify(await submit_live()==blank,"Rock rejection removes both GPU live cuts")
	snow.rock = false
	tracks.update_contact(sim,snow,sim.position,true,responses)
	sim.grounded = false
	tracks.update_contact(sim,snow,sim.position,true,responses)
	verify(await submit_live()==blank,"Airborne transition removes both GPU live cuts")
	sim.grounded = true
	tracks.update_contact(sim,snow,sim.position,true,responses)
	tracks.reset()
	verify(await submit_live()==blank,"Reset leaves no GPU live or retained impression")
	var folder = "res://artifacts/orchestration_20260912/carving/gpu"
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"device":RenderingServer.get_video_adapter_name()},"\t"))
	print("CARVING_TRACK_GPU ",checks," failures=",failures)
	surface.queue_free(); tracks.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

func submit_live() -> PackedByteArray:
	var updates = tracks.take_gpu_updates()
	updates.append({"offset":tracks.capacity*32,"bytes":tracks.live_gpu_strokes().to_byte_array()})
	return await render_and_read(updates,Vector2.ZERO)

func verify(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
