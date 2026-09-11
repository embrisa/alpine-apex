extends Node3D
## Full 120 Hz ski simulation through both gates. No RunSession or record store.
const Sim=preload("res://scripts/core/ski_simulation.gd")
const CollisionSurface=preload("res://scripts/world/prop_collision_surface.gd")
const Surface=preload("res://scripts/art/flavor_test_surface.gd")
var terrain=Surface.new()
var surface=CollisionSurface.new(terrain)
var sim=Sim.new()
var router
var skier
var camera
var status: Label
var paused=false
var autoplay=false
var ticks=0
var gate_crossings=0
var captures: Array=[]

func _ready() -> void:
	get_window().size=Vector2i(1600,1000); get_window().title="Alpine Apex | Gate test course"
	Engine.physics_ticks_per_second=120; Engine.max_fps=120
	get_viewport().msaa_3d=Viewport.MSAA_4X
	autoplay="--capture" in OS.get_cmdline_user_args()
	router=preload("res://scripts/core/input_router.gd").new()
	var env=WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_SKY
	var sky=Sky.new(); sky.sky_material=ProceduralSkyMaterial.new(); env.environment.sky=sky
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(.75,.84,1); env.environment.ambient_light_energy=.65
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC; env.environment.ssao_enabled=true; add_child(env)
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-38,-30,0); sun.light_color=Color(1,.92,.78)
	sun.light_energy=1.7; sun.shadow_enabled=true; add_child(sun)
	_build_terrain()
	_place("start_gate",Vector3(0,0,26))
	_place("finish_gate",Vector3(0,0,108))
	_place("alpine_refuge",Vector3(-11,0,112),PI)
	_place("picnic_table",Vector3(-8,0,102))
	_place("stone_fire_pit",Vector3(-13,0,101))
	_place("marmot_monument",Vector3(9,0,107),PI)
	_place("wet_floor_sign",Vector3(7,0,56),PI)
	_place("giant_rubber_duck",Vector3(-9,0,71),PI)
	skier=preload("res://scripts/presentation/skier_visual.gd").new(); add_child(skier)
	camera=preload("res://scripts/presentation/chase_camera.gd").new(); camera.far=600; add_child(camera)
	var canvas=CanvasLayer.new(); add_child(canvas)
	var panel=PanelContainer.new(); panel.position=Vector2(20,20); canvas.add_child(panel)
	var style=StyleBoxFlat.new(); style.bg_color=Color(.025,.035,.05,.94)
	style.content_margin_left=18; style.content_margin_top=14; style.content_margin_right=18; style.content_margin_bottom=14
	panel.add_theme_stylebox_override("panel",style)
	status=Label.new(); status.add_theme_font_size_override("font_size",22); panel.add_child(status)
	_restart()
	DirAccess.make_dir_recursive_absolute("res://artifacts/flavor_v1/course")
	print("FLAVOR_GATE_COURSE_READY unranked=true physics_hz=120")

func _place(id: String,point: Vector3,yaw: float=0) -> void:
	point.y=terrain.sample(point.x,point.z).height
	var prop=load("res://assets/graphics/flavor_v1/scenes/"+id+".tscn").instantiate()
	add_child(prop); prop.position=point; prop.rotation.y=yaw; prop.bind_surface(surface)

func _build_terrain() -> void:
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in terrain.NZ-1:
		for x in terrain.NX-1:
			# Godot front faces use clockwise winding, as in the main terrain mesh.
			for ij in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var point=terrain.vertex(x+ij.x,z+ij.y); st.set_uv(Vector2(point.x,point.z)*.25); st.add_vertex(point)
	st.generate_normals()
	var mesh=st.commit(); var ground=MeshInstance3D.new(); ground.mesh=mesh
	var mat=StandardMaterial3D.new(); mat.albedo_color=Color(.92,.96,1); mat.roughness=.95
	mat.albedo_texture=load("res://assets/graphics/textures/snow_albedo_high.jpg"); ground.material_override=mat; add_child(ground)
	var body=StaticBody3D.new(); body.collision_layer=8; body.collision_mask=16; add_child(body)
	var shape=CollisionShape3D.new(); shape.shape=mesh.create_trimesh_shape(); body.add_child(shape)

func _restart() -> void:
	router.cancel_air_input()
	if skier.ragdoll.running: skier.ragdoll.stop()
	sim.reset(Vector3.ZERO); sim.prime_contacts(surface); skier.reset_animation(sim)
	ticks=0; gate_crossings=0; captures.clear(); paused=false; camera.reset()

func _physics_process(dt: float) -> void:
	if paused:
		router.cancel_air_input()
		return
	var controls=router.sample(sim.grounded)
	if autoplay:
		controls.steer=0; controls.tuck=1; controls.brake=0; controls.jump=false
	var before=sim.position
	sim.step(dt,controls,surface)
	skier.step_animation(dt,sim,controls,surface)
	for z in [26.,108.]:
		if before.z<z and sim.position.z>=z and absf(sim.position.x)<4.65: gate_crossings+=1
	if sim.crashed and not skier.ragdoll.running: skier.ragdoll.start(sim)
	ticks+=1
	if autoplay:
		for z in [12.,24.,90.,106.,120.]:
			if sim.position.z>=z and z not in captures:
				captures.append(z); call_deferred("capture",int(z))
		if sim.position.z>140 or sim.crashed or ticks>3600:
			set_physics_process(false); call_deferred("finish_capture")
	elif sim.position.z>210: paused=true

func _process(dt: float) -> void:
	if not skier: return
	skier.pose(sim,Engine.get_physics_interpolation_fraction())
	camera.update_camera(sim,surface,sim.position,dt,false,not paused)
	status.text="GATE COURSE  ·  %d / 2 passed  ·  %.0f km/h\nA/D Steer · W Tuck · S Brake · Space Release to hop\nR Restart · C Camera · P Pause · Esc Close%s" % [gate_crossings,sim.speed_kmh(),"\n"+sim.crash_reason if sim.crashed else ""]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R: _restart()
			KEY_C: camera.close_view=not camera.close_view; camera.reset()
			KEY_P: paused=not paused; sim.clear_input_buffer(); sim.reset_pose_history()
			KEY_ESCAPE: get_tree().quit()

func capture(z: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/flavor_v1/course/pass_%03d.png" % z)

func finish_capture() -> void:
	await get_tree().process_frame
	var report={"gate_crossings":gate_crossings,"crashed":sim.crashed,"ticks":ticks,"physics_hz":120,"record_session_created":false,
		"position":[sim.position.x,sim.position.y,sim.position.z],"speed_kmh":sim.speed_kmh(),"actual_pixels":[get_viewport().size.x,get_viewport().size.y]}
	var file=FileAccess.open("res://artifacts/flavor_v1/course/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FLAVOR_GATE_RENDERED ",JSON.stringify(report))
	get_tree().quit(0 if gate_crossings==2 and not sim.crashed else 1)
