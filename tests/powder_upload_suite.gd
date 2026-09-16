extends SceneTree
## Native readback is intentionally confined to this correctness test.
const Powder = preload("res://scripts/presentation/powder_surface.gd")
const Tracks = preload("res://scripts/presentation/snow_tracks.gd")
const Clouds = preload("res://scripts/presentation/cloud_lighting.gd")
const Graphics = preload("res://scripts/presentation/graphics_quality.gd")
var surface
var tracks
var finished_readback = false
var bytes: PackedByteArray
var failures = []
var checks = 0
func _initialize() -> void: call_deferred("run")
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
	for scenario in 12:
		if scenario in [0,5]: tracks.reset()
		if scenario==8: tracks.apply_quality(Graphics.preset(0))
		if scenario==9: tracks.apply_quality(Graphics.preset(2))
		# Include wraparound, crossing strokes, capacity changes and zero-depth
		# unsupported footprints. All expected maps use the original full upload.
		for i in (tracks.capacity+3 if scenario==4 else 7):
			var index = (scenario*7+i)%tracks.capacity
			var p = Vector3(sin(i*.71)*9,0,cos(i*.37)*9)
			tracks.transforms[index] = Transform3D(Basis(Vector3.UP,i*.11),p)
			tracks.corner_history[index] = Color(0,0,0,0)
			tracks.appearance_history[index] = Color(.04,.75,.2,1)
			tracks._upload(index)
		var footprints = PackedFloat32Array([-.2,0,-.2,1.5,.24,0.0 if scenario==6 else .05,.5,1,.2,0,.2,1.5,.24,0.0 if scenario==6 else .06,.7,-1])
		var updates = tracks.take_gpu_updates()
		updates.append({"offset":tracks.capacity*32,"bytes":footprints.to_byte_array()})
		var center = Vector2(4,4) if scenario in [3,7] else Vector2.ZERO
		var partial = await render_and_read(updates,center)
		var full = tracks.gpu_stamps.duplicate(); full.append_array(footprints)
		var expected = await render_and_read([{"offset":0,"bytes":full.to_byte_array()}],center)
		checks+=1
		if partial!=expected: failures.append("Native powder map differs in scenario %d" % scenario)
	# One forward stroke must raise the lip on the same world side as snow
	# ejection/ribbons. Byte-equal upload paths alone cannot catch a mirrored lip.
	tracks.reset()
	var sided = PackedFloat32Array([0,-2,0,2,.48,.12,0,1,0,0,0,0,0,0,0,0])
	var sided_updates = tracks.take_gpu_updates()
	sided_updates.append({"offset":tracks.capacity*32,"bytes":sided.to_byte_array()})
	var sided_bytes = await render_and_read(sided_updates,Vector2.ZERO)
	var map = Image.create_from_data(surface.IMPRINT_RESOLUTION,surface.IMPRINT_RESOLUTION,false,Image.FORMAT_RGH,sided_bytes)
	var right_lip = map.get_pixel(130,128).r
	var left_lip = map.get_pixel(125,128).r
	checks+=1
	if right_lip<=left_lip or right_lip<=0: failures.append("Raised powder lip opposes the requested world-space snow throw")
	print("POWDER_UPLOAD ",checks," GPU checks (12 byte-exact uploads and world-side lip); failures=",failures)
	DirAccess.make_dir_recursive_absolute("res://artifacts/fps_optimization")
	preload("res://tests/test_report.gd").write("res://artifacts/fps_optimization/powder_upload_checks.json",JSON.stringify({"checks":checks,"failures":failures},"\t"))
	if "--profile-uploads" in OS.get_cmdline_user_args(): await profile_uploads()
	surface.queue_free(); tracks.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
func render_and_read(updates: Array, center: Vector2) -> PackedByteArray:
	finished_readback = false
	RenderingServer.call_on_render_thread(read_on_render_thread.bind(updates,center,tracks.capacity+2))
	while not finished_readback: await process_frame
	return bytes
func read_on_render_thread(updates: Array, center: Vector2, count: int) -> void:
	surface._render_update(updates,center,count)
	var result: PackedByteArray = surface.rd.texture_get_data(surface.surface_rid,0)
	call_deferred("receive_readback",result)
func receive_readback(result: PackedByteArray) -> void:
	bytes = result
	finished_readback = true

func profile_uploads() -> void:
	# Alternate paths on one device to separate upload overhead from gameplay
	# and background drift. Both execute the same three reconstruction passes.
	Engine.max_fps = 0; root.size = Vector2i(640,360)
	tracks.reset()
	var footprints = PackedFloat32Array([-.2,0,-.2,1.5,.24,.05,.5,1,.2,0,.2,1.5,.24,.06,.7,-1])
	var rows = []
	for partial in [false,true,true,false,false,true]:
		var samples = PackedFloat64Array()
		var previous = 0
		for frame in 1320:
			var updates = []
			if partial:
				updates = tracks.take_gpu_updates(frame==0)
				# Measured descents modify history on roughly one frame in six.
				if frame%6==0: updates.append({"offset":0,"bytes":tracks.gpu_stamps.slice(0,16).to_byte_array()})
				updates.append({"offset":tracks.capacity*32,"bytes":footprints.to_byte_array()})
			else:
				var full = tracks.gpu_stamps.duplicate(); full.append_array(footprints)
				updates.append({"offset":0,"bytes":full.to_byte_array()})
			RenderingServer.call_on_render_thread(surface._render_update.bind(updates,Vector2.ZERO,tracks.capacity+2))
			await process_frame
			var now = Time.get_ticks_usec()
			if frame>=120 and previous>0: samples.append((now-previous)/1000.0)
			previous = now
		var row = preload("res://scripts/diagnostics/frame_costs.gd").stats(samples)
		row.partial = partial; rows.append(row)
		print("POWDER_SUBMISSION ",JSON.stringify(row))
	preload("res://tests/test_report.gd").write("res://artifacts/fps_optimization/powder_submission.json",JSON.stringify({"scope":"Isolated native reconstruction and upload frame intervals; same GPU and alternating order. No full-descent FPS claim.","rows":rows},"\t"))
