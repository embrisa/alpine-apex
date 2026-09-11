extends SceneTree
## Exercise the real Jolt builder for every offline piece, without a renderer.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var catalog=preload("res://scripts/world/mineral_catalog.gd").new()
	var count=0
	for id in catalog.records:
		var row: Dictionary=catalog.records[id]
		var body=StaticBody3D.new()
		root.add_child(body)
		for i in row.hull_points.size():
			body.name="%s_piece_%d" % [id,i]
			var shape=ConvexPolygonShape3D.new()
			shape.points=row.hull_points[i]
			var child=CollisionShape3D.new()
			child.shape=shape
			body.add_child(child)
			child.free()
			count+=1
		body.free()
		# Validate the compound used by crash_collision as well as isolated pieces.
		var compound=StaticBody3D.new()
		compound.name=id+"_compound"
		var owner=compound.create_shape_owner(compound)
		for points in row.hull_points:
			var shape=ConvexPolygonShape3D.new()
			shape.points=points
			compound.shape_owner_add_shape(owner,shape)
		root.add_child(compound)
		await physics_frame
		compound.free()
		print("JOLT_ASSET ",id," ",row.hull_points.size())
		await process_frame
	FileAccess.open("res://artifacts/geology_v11/jolt.json",FileAccess.WRITE).store_string(JSON.stringify({"assets":catalog.records.size(),"pieces":count,"catalog_sha256":catalog.fingerprint,"backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"requires_clean_engine_log":true},"\t"))
	print("GEOLOGY_JOLT ",count," pieces; inspect engine errors as well as exit code")
	quit()
