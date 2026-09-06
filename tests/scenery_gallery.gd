extends SceneTree
## Inspect imported family silhouettes with the actual game materials and light.
var game
var stage: Node3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	root.size = Vector2i(1600,1000)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.start_speed_lab(120.0)
	game.active = false
	game.effects.hide()
	game.weather_effects.hide()
	game.skier.hide()
	game.hud.hide()
	game.world.scenery.hide()
	game.weather.set_preset("clear")
	game.weather.set_time_of_day("day")
	game.world.update_weather(game.weather.state,0.0,false)
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 38.0
	stage = Node3D.new()
	root.add_child(stage)
	stage.position = Vector3(0,3000,300)
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(180,180)
	ground.mesh = plane
	ground.material_override = game.world.assets.terrain_material()
	stage.add_child(ground)
	var family_row = Node3D.new()
	stage.add_child(family_row)
	var pages = [["spruce_1","fir_1","pine_1","scots_pine_1","wind_pine_1"],
		["larch_1","birch_1","rowan_1","snag_1","split_snag_1","hollow_snag_1"]]
	for page in range(pages.size()):
		for lod in [0,1,2]:
			for child in family_row.get_children(): child.free()
			var ids: Array = pages[page]
			for i in range(ids.size()):
				var object = MeshInstance3D.new()
				object.mesh = game.world.assets.mesh("%s_lod%d" % [ids[i],lod])
				family_row.add_child(object)
				object.position.x = (i-(ids.size()-1)*.5)*7.3
				label(family_row,ids[i],Vector3(object.position.x,.2,-3))
			game.camera.position = stage.position+Vector3(0,12,-40)
			game.camera.look_at(stage.position+Vector3(0,4.8,0))
			await capture("families_%d_lod%d" % [page,lod])
	# Show all four authored crown shapes together, not just one representative.
	game.camera.size = 29.0
	for family in ["pine","birch","split_snag"]:
		for child in family_row.get_children(): child.free()
		for variant in [1,2,3,4]:
			var object = MeshInstance3D.new()
			object.mesh = game.world.assets.mesh("%s_%d_lod0" % [family,variant])
			family_row.add_child(object)
			object.position.x = (variant-2.5)*7
			label(family_row,"%s %d" % [family,variant],Vector3(object.position.x,.2,-3))
		await capture(family+"_variants")
	for child in family_row.get_children(): child.free()
	game.camera.size = 28.0
	var stones = ["rock_granite_1","rock_slate_1","rock_boulder_1","rock_limestone_1","rock_gneiss_1","rock_split_rock_1","rock_outcrop_1"]
	for i in range(stones.size()):
		var object = MeshInstance3D.new()
		object.mesh = game.world.assets.mesh(stones[i])
		family_row.add_child(object)
		object.position = Vector3((i%4-1.5)*6,0,(i/4)*8)
		object.scale = Vector3.ONE*1.3
		label(family_row,stones[i].trim_prefix("rock_"),object.position+Vector3(0,.2,-2.5))
	game.camera.position = stage.position+Vector3(0,20,-28)
	game.camera.look_at(stage.position+Vector3(0,0,3))
	await capture("rock_families")
	game.effects.stop_audio()
	stage.queue_free()
	game.queue_free()
	await process_frame
	quit()

func label(parent: Node3D, text_value: String, at: Vector3) -> void:
	var text_node = Label3D.new()
	text_node.text = text_value.replace("_"," ")
	text_node.font_size = 48
	text_node.pixel_size = .013
	text_node.modulate = Color(.1,.14,.18)
	text_node.outline_size = 0
	text_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(text_node)
	text_node.position = at

func capture(id: String) -> void:
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/scenery_variation/"+id+".png")
