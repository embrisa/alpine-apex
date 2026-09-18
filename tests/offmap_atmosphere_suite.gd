extends SceneTree
const Fog = preload("res://scripts/world/wilderness_atmosphere.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var failures: Array = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func run() -> void:
	var state = preload("res://scripts/presentation/weather_state.gd").new()
	state.fog_color=Color("b4c9da"); state.fog_density=.000065; state.sun_color=Color("ffe1bb"); state.sun_energy=1.9
	var material = ShaderMaterial.new(); material.shader=preload("res://assets/graphics/offmap_prop.gdshader")
	Fog.configure(material,{"physical_bounds":Rect2(-3072,-3072,6144,6144),"valley_height":1600.0})
	check(material.get_shader_parameter("offmap_footprint")==preload("res://scripts/world/mountain_footprint.gd").SHAPE,"Background fog and tree fades share the authored footprint coefficients")
	Fog.apply(material,state)
	var clear: float = material.get_shader_parameter("offmap_valley_density")
	check(is_equal_approx(material.get_shader_parameter("offmap_depth_density"),preload("res://scripts/presentation/alpine_atmosphere.gd").depth_fog(state).density),"Background and playable atmosphere share depth density")
	state.cloud_coverage=1.0; Fog.apply(material,state)
	check(material.get_shader_parameter("offmap_valley_density")>clear,"Overcast weather strengthens the distant valley layer")
	state.enabled=false; Fog.apply(material,state)
	check(material.get_shader_parameter("offmap_valley_density")==0.0,"Weather Off disables the added valley layer")
	check(state.fog_density==.000065 and state.fog_color==Color("b4c9da"),"Applying backdrop atmosphere never changes shared weather")
	state.enabled=true; state.sun_direction=Vector3.DOWN; state.sun_energy=0; state.fog_color=Color("142334"); Fog.apply(material,state)
	var night: Vector3 = material.get_shader_parameter("offmap_fog_color")
	check(night.length()<.1 and material.get_shader_parameter("offmap_fog_scatter")==0.0,"Night fog follows dark weather colors without daytime scattering")
	for level in 3:
		var q = Quality.preset(level)
		check(q.offmap_prop_density==[.3,.6,1.0][level] and q.offmap_tree_distance_m==[3000.0,4500.0,6000.0][level],"Preset %d has independent backdrop density and range" % level)
	var shader = FileAccess.get_file_as_string("res://assets/graphics/alpine_surface_fragment.gdshaderinc")
	check(shader.find("#ifdef ALPINE_OFFMAP\n FOG=")>=0,"Playable terrain does not compile the background fog output")
	print("OFFMAP_ATMOSPHERE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
