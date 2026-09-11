extends "res://tests/planted_snow_playtest.gd"
## Rendered current-build smoke using the retained input fixtures. Collisions
## remain in the report; these are not user skiing or full-descent acceptance.
func source_hashes() -> Dictionary:
	output = "res://artifacts/snow_control_fix/"+("clear_" if "--clear-fixtures" in OS.get_cmdline_user_args() else "")+("timing" if benchmark else "visual")
	if "--visibility" in OS.get_cmdline_user_args(): output = "res://artifacts/snow_control_fix/visibility"
	DirAccess.make_dir_recursive_absolute(output)
	var hashes = super.source_hashes()
	hashes["tests/thick_snow_playtest.gd"] = FileAccess.get_sha256("res://tests/thick_snow_playtest.gd")
	hashes["scripts/presentation/speed_effects.gd"] = FileAccess.get_sha256("res://scripts/presentation/speed_effects.gd")
	hashes["scripts/presentation/skier_visual.gd"] = FileAccess.get_sha256("res://scripts/presentation/skier_visual.gd")
	return hashes

func ride(fixture: Dictionary) -> void:
	if "--clear-fixtures" in OS.get_cmdline_user_args():
		fixture = clear_fixture(fixture)
		if fixture.is_empty(): return
	await super.ride(fixture)
	rows[-1].starting_fixture = fixture
	if benchmark: return
	var current_row: Dictionary = rows[-1]
	current_row.effects = []
	for response in game.effects.responses: current_row.effects.append(response.report())
	current_row.spray_emitters = game.effects.sprays.filter(func(s): return s.emitting).size()
	if game.effects.snow_tracks.written<20: failures.append(fixture.name+": missing contact track history")
	# Actual production chase view, after the same skiing and current animation.
	game.camera.make_current()
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output+"/"+fixture.name+"_chase.jpg",.95)
	if not fixture.name.begins_with("face_5_band_0"): return
	# Freeze this single contact history and inspect all three quality presets.
	game.active = false
	for spray in game.effects.sprays: spray.speed_scale = 0.0
	var p: Vector3 = game.sim.position
	var f: Vector3 = game.sim.ski_forward
	var across: Vector3 = game.sim.surface_normal.cross(f)
	observer.position = p-f*9+across*3+Vector3.UP*3
	observer.position.y = maxf(observer.position.y,field.sample(observer.position.x,observer.position.z).height+1.3)
	observer.look_at(p-f*3); observer.make_current()
	for level in [0,1,2]:
		game.set_graphics_quality(level)
		if level==2: game.effects.powder_surface.update_surface(game.sim,p,game.effects.responses)
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(output+"/tracks_quality_%d.jpg"%level,.95)
	game.active = true

func clear_fixture(original: Dictionary) -> Dictionary:
	# New-terrain visual smoke, not an old/new performance comparison. Select
	# uninterrupted snow travel from a fixed local grid, retaining the original
	# blocked-fixture captures separately. Timing uses the same deterministic
	# search and reports the exact selected start/input with its measurements.
	var origin = Vector3(original.origin[0],0,original.origin[2])
	var n: Vector3 = field.contact_normal(origin.x,origin.z)
	var downhill = Vector3(n.x,0,n.z).normalized()
	var across = Vector3.UP.cross(downhill)
	var attempts = 0
	for along in [-80.0,-40.0,0.0,40.0,80.0]:
		for side in [0.0,-24.0,24.0,-48.0,48.0,-80.0,80.0]:
			var p = origin+downhill*along+across*side
			if field.rock_fraction_at(p.x,p.z)>=.2: continue
			var normal: Vector3 = field.contact_normal(p.x,p.z)
			if normal.y<.72: continue
			var candidate = {"name":original.name+"_clear","origin":[p.x,field.sample(p.x,p.z).height,p.z],"heading":atan2(normal.x,normal.z),"kmh":90.0,"seconds":6.0,"input":"ripple","steer":.28}
			var trial = Probe.measure(SkiSimulation,field,candidate)
			attempts += 1
			# Short natural releases and speed lost in turns are valid skiing.
			# Reject sustained rock contact or a stop, not every small bump.
			if trial.crash.is_empty() and trial.airtime_s<.75 and trial.rock_s<.25 and trial.exit_kmh>40:
				candidate.selection_attempts = attempts
				print("CLEAR_SNOW_FIXTURE ",JSON.stringify(candidate))
				return candidate
	failures.append("No uninterrupted snow run near "+original.name+" after "+str(attempts)+" candidates")
	return {}
