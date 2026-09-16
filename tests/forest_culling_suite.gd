extends SceneTree
## Packed production groups must retain the same coverage support as direct
## fixture groups. Empty transforms does not mean there are no uploaded trees.
const Forest = preload("res://scripts/presentation/density_forest.gd")
const Scenery = preload("res://scripts/world/alpine_scenery.gd")
const Assets = preload("res://scripts/presentation/alpine_assets.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var checks = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func run() -> void:
	var host = Scenery.new(); root.add_child(host)
	host.quality=Quality.numbered(7); host.dense_woodlands=true
	host.assets=Assets.new(preload("res://scripts/presentation/cloud_lighting.gd").new(),host.quality)
	var forest=Forest.new(); host.add_child(forest); forest.set_process(false); forest.host=host
	var rng=RandomNumberGenerator.new(); rng.seed=2026091601
	for asset in ["forest_spruce_01","forest_fir_01","forest_dead_01"]:
		var record=host.assets.tree_record(asset)
		var poses=[]
		for i in 6:
			poses.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-.2,.2),rng.randf()*TAU,rng.randf_range(-.2,.2))).scaled(Vector3(rng.randf_range(.5,1.5),rng.randf_range(.5,1.5),rng.randf_range(.5,1.5))),Vector3(rng.randf_range(-32,0),rng.randf_range(-8,8),rng.randf_range(32,64))))
		var prepared=Scenery.prepare_tree_batch(poses,30,host.assets.tree_render_bounds(asset))
		var direct={"transforms":poses,"height_m":30,"prepared":prepared}
		var packed={"transforms":[],"height_m":30,"prepared":prepared}
		var support=forest._coverage_padding(packed,record)
		check(is_equal_approx(support,forest._coverage_padding(direct,record)),asset+": packed/direct support")
		check(support>.05,asset+": nonempty upload must have nonempty support")
		packed.coverage_padding=support
		var children=forest._detail_groups(packed,asset)
		var members=[]
		for child in children:
			var values:PackedFloat32Array=child.prepared.buffer
			for offset in range(0,values.size(),12): members.append(values.slice(offset,offset+12))
		var source_values:PackedFloat32Array=prepared.buffer
		for offset in range(0,source_values.size(),12):
			var member=members.find(source_values.slice(offset,offset+12))
			check(member>=0,asset+": subdivision preserves uploaded transform")
			if member>=0: members.remove_at(member)
		check(members.is_empty(),asset+": subdivision adds no instances")
		var center:Vector3=prepared.bounds.get_center()
		var radius=float(record.get("crown_radius",0))
		var c:Array=record.get("crown_center",[0,0,0])
		for end in [12.0,64.0]:
			for i in 12:
				var direction=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
				var camera=center+direction*(end+5+support+.001)
				for pose:Transform3D in poses:
					var scale_m=maxf(pose.basis.x.length(),maxf(pose.basis.y.length(),pose.basis.z.length()))
					var detail=maxf(0,camera.distance_to(pose*Vector3(c[0],c[1],c[2]))-radius*scale_m) if radius>0 else camera.distance_to(pose.origin)
					check(detail>end+5,asset+": rejected batch has zero individual coverage")
		var bare=record.duplicate(); bare.crown_radius=0
		var anchor_support=forest._coverage_padding(packed,bare)
		for pose:Transform3D in poses: check(center.distance_to(pose.origin)<anchor_support,asset+": bare anchor enclosed")
	print("FOREST_CULLING_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
