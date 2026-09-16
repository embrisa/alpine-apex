extends SceneTree
## Rendered, labelled equipment/contact audition. Scripted objects, not skiing.
const Sfx = preload("res://scripts/presentation/procedural_sfx.gd")
const Events = preload("res://scripts/presentation/riding_audio_events.gd")
const OUT = "res://artifacts/natural_audio/rendered"
var shots: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(OUT)
	# Record the bus before its output gain; keep automatic fixture playback quiet.
	AudioServer.set_bus_volume_db(0,-80)
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	var scene = Node3D.new();root.add_child(scene)
	var environment = WorldEnvironment.new();environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.23,.30,.38)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.72,.82,1)
	environment.environment.ambient_light_energy = .9
	scene.add_child(environment)
	var light = DirectionalLight3D.new();light.rotation_degrees = Vector3(-55,-25,0);light.light_energy = 1.8;scene.add_child(light)
	var floor_mesh = MeshInstance3D.new();var plane = PlaneMesh.new();plane.size = Vector2(20,20);floor_mesh.mesh = plane
	var mat = StandardMaterial3D.new();mat.albedo_color = Color(.6,.68,.77);mat.roughness = .9;floor_mesh.material_override = mat;floor_mesh.position.y = -.25;scene.add_child(floor_mesh)
	var visual = preload("res://scripts/presentation/skier_visual.gd").new();visual.preview_only = true;scene.add_child(visual)
	visual.character.visible = false;visual.animation_enabled = false
	var camera = Camera3D.new();scene.add_child(camera);camera.fov = 45;camera.position = Vector3(1.35,1.65,2.25);camera.look_at(Vector3(0,.65,0));camera.make_current()
	var label = Label.new();label.position = Vector2(32,24);label.add_theme_font_size_override("font_size",28);root.add_child(label)
	var detail = Label.new();detail.position = Vector2(32,650);detail.add_theme_font_size_override("font_size",19);root.add_child(detail)
	detail.add_theme_color_override("font_color",Color(.08,.14,.20))
	detail.text = "Procedural audio • scripted equipment fixture • no race or personal settings"
	var sfx = Sfx.new();scene.add_child(sfx);sfx.bind_equipment_source(visual)
	var wind = preload("res://scripts/presentation/procedural_wind.gd").new();scene.add_child(wind)
	var original = AudioStreamPlayer.new();scene.add_child(original);wind.setup(original);wind.volume = 0
	var sim = preload("res://scripts/core/ski_simulation.gd").new();sim.reset(Vector3.ZERO)
	var record = AudioEffectRecord.new();record.format = AudioStreamWAV.FORMAT_16_BITS
	var index = AudioServer.get_bus_effect_count(0);AudioServer.add_bus_effect(0,record)
	for i in 8: await process_frame
	record.set_recording_active(true)
	var began = Time.get_ticks_usec()/1000000.0
	var chapter_counts: Array = []
	var capture_at = 0.0
	for chapter in 6:
		var titles = ["Carbon shafts · dry contact ticks","Metal pole tips · short clinks","Equipment · mixed knock","Bindings · restrained rattle","Rock hit · knock and grit","Tree hit · thud and bark texture"]
		label.text = titles[chapter]
		sfx.reset()
		var count_before: int = sfx.equipment_events_submitted
		var touch_before: int = sfx.equipment_contacts.event_count
		var elapsed = 0.0
		var next_hit = .4
		while elapsed<2.4:
			await process_frame
			var dt = root.get_process_delta_time();elapsed += dt
			for i in 2: visual.skis[i].transform = Transform3D(Basis.IDENTITY,Vector3(-.35+i*.7,0,0))
			visual.poles[0].global_transform = Transform3D(Basis(Quaternion(Vector3.DOWN,Vector3.RIGHT)),Vector3(-.59,1,0))
			var height = 1.30-minf(elapsed,.65)*.8 if elapsed<1.25 else .78+(elapsed-1.25)*.8
			visual.poles[1].global_transform = Transform3D(Basis(Quaternion(Vector3.DOWN,Vector3.BACK)),Vector3(0 if chapter==0 else .59,height,-.59 if chapter==0 else -1.18))
			if chapter>=2:
				visual.poles[1].position.y = 1.4
			sfx.advance(sim,null,null,camera,wind,null,dt,true,false,false,false)
			if chapter>=2 and elapsed>=next_hit:
				next_hit += 1.1
				if chapter<4: sfx._submit(Events._equipment(Events.EquipmentProfile.MIXED_KNOCK if chapter==2 else Events.EquipmentProfile.BINDING_RATTLE,8,0,.8))
				else: sfx._submit(Events._event(Events.Kind.IMPACT,Events.AudioMaterial.ROCK if chapter==4 else Events.AudioMaterial.WOOD,8,0,.6))
			var now = Time.get_ticks_usec()/1000000.0-began
			if now>=capture_at:
				capture_at = now+.10
				await RenderingServer.frame_post_draw
				var file = "frame_%04d.jpg" % shots.size()
				root.get_texture().get_image().save_jpg(OUT+"/"+file,.9)
				shots.append({"file":file,"time":now,"chapter":chapter})
		chapter_counts.append({"chapter":titles[chapter],"equipment_submitted":sfx.equipment_events_submitted-count_before,"geometric_contacts":sfx.equipment_contacts.event_count-touch_before})
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"/chapter_%d.png" % chapter)
		detail.text = "Procedural audio • contact events: %d • scripted fixture" % sfx.equipment_events_submitted
	sfx.silence();await create_timer(.3).timeout
	record.set_recording_active(false)
	var wav = record.get_recording();wav.save_to_wav(OUT+"/equipment_impacts.wav")
	AudioServer.remove_bus_effect(0,index)
	var report = {"chapters":chapter_counts,"native":sfx.diagnostics(),"mix_rate":wav.mix_rate,"frames":shots,"scope":"Scripted equipment geometry for shafts/tips; direct event auditions for mixed knocks, rattles, rock/tree hits","pixels":[root.size.x,root.size.y],"unranked":true}
	preload("res://tests/test_report.gd").write(OUT+"/report.json",JSON.stringify(report,"\t"))
	var passed: bool = chapter_counts[0].geometric_contacts>=2 and chapter_counts[1].geometric_contacts>=2
	print("NATURAL_AUDIO_RENDER_RESULT contacts_pass=",passed," chapters=",JSON.stringify(chapter_counts))
	sfx.stop_audio();wind.stop_audio();await create_timer(.2).timeout
	scene.queue_free();label.queue_free();detail.queue_free();await process_frame
	quit(0 if passed else 1)
