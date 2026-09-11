extends RefCounted
## Correctness readbacks ONLY, outside every steady-state timing interval.
const Powder = preload("res://scripts/presentation/powder_surface.gd")
var read_ready = false
var read_result: Dictionary = {}

func run(suite) -> void:
	var game = suite.game
	game.active = false
	game.set_physics_process(false)
	# Stop the ordinary producer while this fixture owns its history and buffer.
	game.set_process(false)
	var surface = game.effects.powder_surface
	var tracks = game.effects.snow_tracks
	suite.case_name = "native_powder"
	if not suite.check(surface!=null and surface.available,"native powder compute initialized"):
		game.set_process(true); return
	var baseline_buffer = surface.buffer_rid
	var baseline_texture = surface.surface_rid
	# Includes the review's capacity/anchor transition order plus preset 9.
	for preset in [7,8,9,10,7,1,7,10]:
		if not suite.alive(): break
		game.set_graphics_preset(preset)
		if preset<8: continue
		suite.case_name = "native_powder_%02d" % preset
		print("INTERFACE_PERFORMANCE_BEGIN ",suite.case_name," max-history full/partial/repeat readback")
		tracks.reset()
		# Fill EVERY slot with finite supported nonzero stamps, including >4096.
		for index in tracks.capacity:
			write_stamp(tracks,index)
		var live = PackedFloat32Array([-.22,-1,-.22,1,.24,.05,.5,1,.22,-1,.22,1,.24,.06,.7,-1]).to_byte_array()
		var initial: Array = tracks.take_gpu_updates(true)
		initial.append({"offset":tracks.capacity*32,"bytes":live})
		var count: int = tracks.capacity+2
		if not suite.check(Powder.valid_submission(initial,count),"all history plus two live slots fit allocation"): break
		var first: Dictionary = await render_read(suite,surface,initial,count)
		if not suite.alive(): break
		# Real producer dirty spans straddling the ring's last/first slots.
		for index in [tracks.capacity-2,tracks.capacity-1,0,1]: write_stamp(tracks,index,.025)
		var wrapped: Array = tracks.take_gpu_updates()
		suite.check(wrapped.size()==2,"ring wrap produces two bounded dirty spans")
		wrapped.append({"offset":tracks.capacity*32,"bytes":live})
		if not suite.check(Powder.valid_submission(wrapped,count),"wrapped submission fits current dispatch range"): break
		var partial: Dictionary = await render_read(suite,surface,wrapped,count)
		if not suite.alive(): break
		var expected: PackedByteArray = tracks.gpu_stamps.to_byte_array()
		expected.append_array(live)
		var full: Dictionary = await render_read(suite,surface,[{"offset":0,"bytes":expected}],count)
		if not suite.alive(): break
		var repeated: Dictionary = await render_read(suite,surface,[{"offset":0,"bytes":expected}],count)
		if not suite.alive(): break
		suite.check(partial.buffer==expected and full.buffer==expected,"actual native buffer matches every history/live byte")
		suite.check(partial.texture==full.texture and full.texture==repeated.texture,"partial/full/repeat GPU relief byte-stable")
		var extrema = image_extrema(full.texture)
		suite.check(extrema.valid and extrema.max_abs>0,"native relief has positive finite signal")
		suite.check(surface.buffer_rid==baseline_buffer and surface.surface_rid==baseline_texture,"native buffer and atlas allocation stable across presets")
		suite.check(surface.budget().contact_buffer_bytes==Powder.BUFFER_BYTES,"native allocation retains bounded maximum capacity")
		suite.rows.append({"case":suite.case_name,"preset":preset,"capacity":tracks.capacity,"dispatch_count":count,
			"dispatches_completed":4,"buffer_bytes":Powder.BUFFER_BYTES,"uploaded_buffer_bytes":expected.size(),
			"partial_full_equal":partial.texture==full.texture,"repeat_equal":full.texture==repeated.texture,
			"first_read_bytes":first.texture.size(),"extrema":extrema,"native_allocation_stable":surface.buffer_rid==baseline_buffer,
			"budget":surface.budget(),"outside_measurement":true,"synthetic_history":true})
		suite.write_report()
		print("INTERFACE_PERFORMANCE_RESULT ",suite.case_name," capacity=",tracks.capacity," finite=",extrema.valid)
	tracks.reset()
	surface.last_revision = -1
	game.set_graphics_preset(7)
	game.set_process(true)

func write_stamp(tracks, index: int, extra: float = 0.0) -> void:
	var x = float(index%64)*.20-6.4
	var z = float((index/64)%64)*.20-6.4
	tracks.transforms[index] = Transform3D(Basis.IDENTITY,Vector3(x,0,z))
	tracks.corner_history[index] = Color(0,0,0,0)
	tracks.appearance_history[index] = Color(.04+extra,.75,.2,1)
	tracks._upload(index)

func render_read(suite, surface, updates: Array, count: int) -> Dictionary:
	read_ready = false
	RenderingServer.call_on_render_thread(read_on_render_thread.bind(surface,updates,count))
	var deadline = Time.get_ticks_msec()+5000
	while not read_ready and suite.alive():
		if Time.get_ticks_msec()>deadline:
			suite.check(false,"powder native readback exceeded five seconds"); break
		await suite.process_frame
	return read_result

func read_on_render_thread(surface, updates: Array, count: int) -> void:
	surface._render_update(updates,Vector2.ZERO,count)
	var result = {"buffer":surface.rd.buffer_get_data(surface.buffer_rid,0,count*32),
		"texture":surface.rd.texture_get_data(surface.surface_rid,0)}
	call_deferred("receive",result)

func receive(result: Dictionary) -> void:
	read_result = result
	read_ready = true

func image_extrema(bytes: PackedByteArray) -> Dictionary:
	if bytes.size()!=Powder.IMPRINT_RESOLUTION*Powder.IMPRINT_RESOLUTION*4: return {"valid":false,"max_abs":0.0}
	var image = Image.create_from_data(Powder.IMPRINT_RESOLUTION,Powder.IMPRINT_RESOLUTION,false,Image.FORMAT_RGH,bytes)
	var maximum = 0.0
	for y in image.get_height():
		for x in image.get_width():
			var value = image.get_pixel(x,y)
			if not is_finite(value.r) or not is_finite(value.g): return {"valid":false,"max_abs":maximum}
			maximum = maxf(maximum,maxf(absf(value.r),absf(value.g)))
	return {"valid":true,"max_abs":maximum}
