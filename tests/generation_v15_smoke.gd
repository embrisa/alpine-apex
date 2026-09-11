extends SceneTree
const Terrain = preload("res://scripts/world/generators/alpine_massif_v15.gd")
const Cache = preload("res://scripts/world/mountain_cache_v15.gd")
const Prep = preload("res://scripts/world/mountain_preparation.gd")
const Estimates = preload("res://scripts/world/generation_estimates.gd")
func _initialize() -> void:
	var main_script = load("res://scripts/main.gd")
	if main_script==null: quit(3); return
	var settings = preload("res://scripts/world/generation_settings.gd").preset()
	var field = Terrain.new(849205174,false,settings,null,true)
	print("V15_PARSE ",field.GENERATOR_VERSION," key=",Cache.cache_key(849205174))
	var buffer = PackedFloat32Array(); buffer.resize(12)
	var pose = Transform3D(Basis(Vector3.UP,.4),Vector3(1,2,3))
	preload("res://scripts/presentation/forest_placement.gd").put_pose(buffer,0,pose)
	print("V15_PACKED_POSE ",buffer)
	if buffer[3]!=1 or buffer[7]!=2 or buffer[11]!=3: quit(2); return
	print("V15_ESTIMATE ",Estimates.label(Estimates.estimate(849205174,settings)))
	quit()
