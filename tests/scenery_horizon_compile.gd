extends SceneTree
## Native shader compilation without preparing the full mountain.
var shaders: Array=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	assert(DisplayServer.get_name()!="headless","Use the native renderer")
	for script in ["scenery_horizon_playtest","scenery_horizon_cost"]:
		assert(load("res://tests/%s.gd" % script).can_instantiate())
	for name in ["alpine_wilderness","alpine_apron","offmap_tree","offmap_prop","alpine_surface"]:
		var path="res://assets/graphics/%s.gdshader" % name
		assert(ResourceLoader.exists(path))
		var shader: Shader=load(path)
		shaders.append(shader); shader.get_shader_uniform_list()
	for i in 4: await process_frame
	print("HORIZON_NATIVE_COMPILE_READY"); quit()
