extends SceneTree
## Current production gameplay views of reviewed actions and rapid turns. Never ranked.
const DT = 1.0/120.0
const Definition = preload("res://scripts/world/mountain_definition.gd")
var game
var output = ""
var rows: Array = []
var label: Label
var side_camera: Camera3D
var scenarios = ["carve_left","carve_right","prepare_takeoff","landing"]

func _initialize(): call_deferred("run")

func source_manifest() -> Dictionary:
	var hashes = {}
	for path in ["scripts/core/air_rotation.gd","scripts/core/ski_simulation.gd","scripts/core/rider_body.gd","scripts/core/rider_input.gd","scripts/core/ski_tuning.gd","config/ski_default.tres","scripts/presentation/skier_animation.gd","scripts/presentation/skier_full_motion.gd","scripts/presentation/action_posture.gd","scripts/presentation/downhill_posture.gd","scripts/presentation/skier_anatomy.gd","scripts/presentation/skier_visual.gd","scripts/presentation/skier_pose_writer.gd","assets/animation/steep_ski_motion.res","assets/graphics/models/skier_v7.glb","tests/action_animation_playtest.gd"]:
		hashes[path] = FileAccess.get_sha256("res://"+path)
	return hashes

func run():
	if DisplayServer.get_name()=="headless": quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--scenarios="):
			scenarios=Array(arg.trim_prefix("--scenarios=").split(","))
	for scenario in scenarios:
		if scenario not in ["carve_left","carve_right","carve_reversal","carve_taps","prepare_takeoff","landing"]:
			printerr("Unknown gameplay scenario: ",scenario); quit(2); return
	if not output.is_empty() and not output.begins_with("res://") and not output.is_absolute_path(): output="res://"+output
	if output.is_empty() or FileAccess.file_exists(output+"/results.json"):
		printerr("Pass a new --output directory for this action capture"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources = source_manifest()
	var field = Definition.generate(849205174,14)
	set_meta("mountain_to_load",{"definition":Definition.from_field(field,"Animation review validation"),"field":field})
	game = load("res://main.tscn").instantiate(); game.automated = true
	root.add_child(game); current_scene = game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.start_run(false); game.summit_ready=false; game.session.eligible=false; game.active=false
	game.effects.muted=true; game.effects.reset_haptics(); game.hud.hide(); game.hud.hide_menu()
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day")
	game.display_settings.display_mode="windowed"; game.display_settings.upscaler="native"
	game.display_settings.render_scale=1.0; game.display_settings.fps_limit=120
	game.display_settings.apply_display(root,Vector2i(1280,720)); game.display_settings.apply_viewport(root)
	var overlay=CanvasLayer.new(); root.add_child(overlay)
	label=Label.new(); overlay.add_child(label); label.position=Vector2(18,14)
	label.add_theme_font_size_override("font_size",21); label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2)
	side_camera=Camera3D.new(); game.add_child(side_camera); side_camera.fov=55
	for i in 60: await process_frame
	await capture_actions(field)
	var after=source_manifest(); var changed=[]
	for path in sources:
		if sources[path]!=after[path]: changed.append(path)
	var pixels=root.get_texture().get_image().get_size()
	var report={"model":game.sim.MODEL_VERSION,"engine":Engine.get_version_info(),"seed":849205174,"generator":14,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum,"pixels":[pixels.x,pixels.y],"record_eligible":game.session.eligible,"sources":sources,"sources_after":after,"stable_sources":changed.is_empty(),"changed_sources":changed,"cases":rows,"fps":30,"capture_overhead_included":true}
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ACTION_GAMEPLAY_CAPTURE ",output," cases=",rows.size()," stable=",changed.is_empty())
	game.effects.stop_audio(); game.queue_free(); await process_frame
	quit(0 if changed.is_empty() else 1)

func capture_actions(field):
	var revision = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--revision="): revision=arg.trim_prefix("--revision=")
	assert(not revision.is_empty(),"Pass the reference capture revision")
	if not revision.begins_with("res://") and not revision.is_absolute_path(): revision="res://"+revision
	for scenario in scenarios:
		var captured=JSON.parse_string(FileAccess.get_file_as_string(revision+"/capture/"+scenario+".json"))
		var fixture: Dictionary=captured.fixture
		var p: Array=fixture.origin
		var position=Vector3(p[0],p[1],p[2])
		if scenario=="landing": position.y+=1.2
		game.sim.reset(position,fixture.heading); game.sim.prime_contacts(game.world.ski_surface)
		game.sim.velocity=game.sim.support_basis().z*18.0
		if scenario=="landing":
			game.sim.velocity+=Vector3.DOWN*3.0
			game.sim._begin_flight(game.sim.support_basis())
		game.sim.reset_pose_history()
		game.skier.reset_animation(game.sim); game.camera.reset(); game.effects.reset()
		var trace=[]
		for view in ["chase","side"]: DirAccess.make_dir_recursive_absolute(output+"/"+scenario+"_"+view)
		var count=96 if scenario=="prepare_takeoff" else 90
		if scenario in ["carve_reversal","carve_taps"]: count=120
		for frame_index in count:
			var intent=RiderInput.new()
			for substep in 4:
				var tick=frame_index*4+substep
				var time=tick*DT
				intent=RiderInput.new()
				if scenario.begins_with("carve"):
					intent.steer=(-.55 if scenario=="carve_left" else .55)*smoothstep(.25,.75,time)*(1.0-smoothstep(1.65,2.35,time))
				if scenario=="carve_reversal":
					intent.steer=.55 if time>=.3 and time<1.2 else (-.55 if time>=1.7 and time<2.5 else (.55 if time>=2.5 and time<3.0 else 0.0))
					if time>=1.2 and time<1.7: intent.steer=-.7 if int((time-1.2)/.16)%2==0 else .7
				if scenario=="carve_taps":
					intent.steer=(.8 if int((tick-60)/12)%2==0 else -.8) if tick>=60 and tick<300 else 0.0
				if scenario=="prepare_takeoff":
					intent.tuck=.7 if time<1.1 else 0.0
					intent.jump_held=tick>=48 and tick<132
					intent.jump=tick==132
				game.sim.step(DT,intent,game.world.ski_surface)
				game.skier.step_animation(DT,game.sim,intent,field)
			game.intent=intent; game.session.elapsed=(frame_index+1)/30.0
			game._process(1.0/30.0); game.skier.pose(game.sim,1.0); game.speed_periphery.hide()
			var center: Vector3=game.sim.position+game.sim.support_basis().y*.7
			side_camera.position=center+Basis(Vector3.UP,fixture.heading)*Vector3(4.2,.6,1.0)
			side_camera.look_at(center)
			for view in ["chase","side"]:
				if view=="side": side_camera.make_current()
				else: game.camera.make_current()
				label.text="MODEL %d / %s / %s / %.2f s"%[game.sim.MODEL_VERSION,scenario.to_upper(),view.to_upper(),(frame_index+1)/30.0]
				if scenario.begins_with("carve"):
					label.text+="\nInput %.2f / supported turn %.2f"%[intent.steer,game.skier.animation.full_motion.diagnostics.get("physical_turn",0.0)]
				await process_frame; await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(output+"/"+scenario+"_"+view+"/%04d.jpg"%frame_index,.90)
			trace.append({"frame":frame_index,"tick":game.sim.ticks,"grounded":game.sim.grounded,"phase":game.skier.animation.phase,"position":str(game.sim.position),"input_steer":intent.steer,"physical_turn":game.skier.animation.full_motion.diagnostics.get("physical_turn",0.0)})
			if game.sim.crashed: break
		rows.append({"name":scenario,"trace":trace,"crash":game.sim.crash_reason,"landings":game.skier.animation.landing_events,
			"action_posture_sha256":FileAccess.get_sha256("res://scripts/presentation/action_posture.gd"),"reference_revision":revision})
		print("ACTION_GAMEPLAY_CASE ",scenario," frames=",trace.size()," crash=",game.sim.crash_reason)

