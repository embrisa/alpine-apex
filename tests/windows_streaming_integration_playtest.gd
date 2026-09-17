extends SceneTree
## Production local cells and atomic macro-texture publication on Windows.
const Costs=preload("res://scripts/diagnostics/frame_costs.gd")
var game
var camera: Camera3D
var output="res://artifacts/windows_integration_20260917/streaming"
var captures=true
var images=[]
var rows=[]
var failures=[]
var costs=Costs.new()
var macro_id=""
var max_grass_cells=0
var max_gravel_cells=0
var fixture="perf-mixed"

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); printerr("WINDOWS_STREAMING_FAIL ",label)
func shot(label: String) -> void:
	if not captures: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label)
	images.append(label)
func aim(p: Vector3,target: Vector3) -> void:
	camera.position=p; camera.look_at(target)
func settle(count: int=90) -> void:
	for i in count:
		await process_frame
		max_grass_cells=maxi(max_grass_cells,game.world.grass.cells.size())
		max_gravel_cells=maxi(max_gravel_cells,game.world.minerals.gravel.cells.size())
		check_channels()
func check_channels() -> void:
	if macro_id.is_empty(): return
	var minerals=game.world.minerals
	var tier="high" if minerals.high_macros.has(macro_id) else "balanced"
	for channel in minerals.MACRO_CHANNELS:
		var texture=minerals.materials[macro_id].get_shader_parameter(channel+"_map")
		check(texture!=null and texture.resource_path==minerals.rows[macro_id].textures[tier][channel],"atomic "+tier+" "+channel)
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	assert(RenderingServer.get_current_rendering_driver_name()=="d3d12")
	for arg in OS.get_cmdline_user_args():
		if arg=="--no-captures": captures=false
		if arg.begins_with("--output="): output="res://"+arg.get_slice("=",1)
		if arg.begins_with("--map="): fixture=arg.get_slice("=",1)
	assert(fixture in ["perf-mixed","perf-gravel"])
	DirAccess.make_dir_recursive_absolute(output); Engine.max_fps=60
	set_meta("test_map_fixture",fixture)
	game=load("res://main.tscn").instantiate(); game.automated=true; root.add_child(game); current_scene=game
	while not game.initialized or (game.loading and game.loading.busy): await process_frame
	game.set_physics_process(false); game.set_process(false); game.active=false
	game.preferences_enabled=false; game.session.eligible=false
	game.effects.muted=true; game.set_audio_muted(true); game.hud.hide(); game.skier.hide()
	game.set_graphics_preset(7)
	game.display_settings.fps_limit=60; game.display_settings.frame_generation=false
	game.display_settings.apply_display(root,Vector2i(1920,1080)); Engine.max_fps=60
	game.weather.set_preset("clear"); game.weather.set_time_of_day("day"); game.world.update_weather(game.weather.state,0,true)
	camera=Camera3D.new(); game.add_child(camera); camera.fov=65; camera.far=2500; camera.make_current()
	var field=game.field; var grass=game.world.grass; var minerals=game.world.minerals
	var gravel=minerals.gravel
	grass.frame_costs=costs; minerals.frame_costs=costs; gravel.frame_costs=costs
	if game.world.scenery.density_forest: game.world.scenery.density_forest.frame_costs=costs
	var immutable=var_to_bytes([field.heights,field.obstacles,field.geology.placements])
	var start=Vector3(38 if fixture=="perf-mixed" else 6,0,140); start.y=field.sample(start.x,start.z).height+.75
	aim(start,start+Vector3(0,-1.3,4)); await settle(90)
	costs.reset(); costs.enabled=not captures
	# Cross normal 16/8 m grass/gravel cells on the authored mixed map.
	for frame in 360:
		var p=Vector3(38 if fixture=="perf-mixed" else 6,0,140+float(frame)*.25); p.y=field.sample(p.x,p.z).height+.75
		aim(p,p+Vector3(0,-1.3,4))
		await settle(1)
		if frame in [90,179,269,359]:
			rows.append({"frame":frame,"camera":str(p),"grass":grass.population(),"gravel":gravel.population()})
			await shot("cells_%03d" % frame)
	check(grass.population()>0,"nonzero grass in fixture")
	if fixture=="perf-gravel": check(gravel.population().dense+gravel.population().sparse>0,"nonzero rendered gravel")
	# The mixed fixture has two actual macro boulders with a shared material.
	check(not minerals.macro_bounds.is_empty(),"macro texture fixture exists")
	macro_id=minerals.macro_bounds.keys()[0]
	var box: AABB=minerals.macro_bounds[macro_id][0]
	# First move beyond both instances, then cross the 280/420 m hysteresis.
	for distance in [500.0,290.0,250.0,300.0,390.0,430.0]:
		var p=Vector3(box.get_center().x,box.end.y+5,box.position.z-distance)
		p.y=maxf(p.y,field.sample(p.x,p.z).height+8)
		aim(p,box.get_center()); await settle(90)
		var expected=distance in [250.0,300.0,390.0]
		check(minerals.high_macros.has(macro_id)==expected,"macro tier at "+str(distance))
		rows.append({"macro_distance_z":distance,"tier":"high" if minerals.high_macros.has(macro_id) else "balanced","pending":minerals.pending_macros.size(),"loads":minerals.macro_loads.size()})
		if distance in [290.0,250.0,390.0,430.0]: await shot("macro_%d" % distance)
	check(max_grass_cells<=grass.MAX_CELLS,"bounded grass resident cells")
	check(max_gravel_cells<=gravel.MAX_CELLS,"bounded gravel resident cells")
	check(immutable==var_to_bytes([field.heights,field.obstacles,field.geology.placements]),"physical data unchanged")
	var report={"engine":Engine.get_version_info().string,"backend":RenderingServer.get_current_rendering_driver_name(),"fixture":field.fixture_descriptor(),"images":images,"rows":rows,"failures":failures,"max_grass_cells":max_grass_cells,"max_gravel_cells":max_gravel_cells,"display":game.display_settings.report(root,Vector2i(1920,1080)),"captured":captures,"scope":"Local production streaming CPU scopes; capped stationary/moving camera; not whole-mountain FPS","costs":costs.report()}
	preload("res://tests/test_report.gd").write(output+"/report.json",JSON.stringify(report,"\t"))
	game.queue_free(); await process_frame
	print("WINDOWS_STREAMING_INTEGRATION_DONE ",output," failures=",failures.size()); quit(0 if failures.is_empty() else 1)
