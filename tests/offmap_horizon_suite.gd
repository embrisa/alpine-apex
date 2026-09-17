extends SceneTree
## Authored payload integrity, light direction and seed-independent exclusion.
const Horizon=preload("res://scripts/world/wilderness_horizon.gd")
const Data=preload("res://scripts/world/wilderness_data.gd")
const Quality=preload("res://scripts/presentation/graphics_quality.gd")
var checks=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var source=load(Data.DEFAULT_ASSET)
	var controller=Horizon.new()
	var material=ShaderMaterial.new(); material.shader=load("res://assets/graphics/alpine_wilderness.gdshader")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(Horizon.DIRECTORY+"manifest.json"))
	check(manifest.schema==1 and manifest.variants.size()==6,"Manifest enumerates both qualities for all geometry tiers")
	for tier in 3:
		for quality in [1,2]:
			controller.select(quality,tier,source); controller.bind(material)
			var payload=controller.payload
			check(payload!=null and payload.valid_for(source,tier,quality),"Reloaded tier %d quality %d has complete CPU image layers" % [tier,quality])
			check(controller.texture!=null and material.get_shader_parameter("offmap_horizon_enabled")==true,"Valid companion uploads and enables material")
			check(payload.payload_bytes()==[0,524288,4194304][quality],"Quality has its bounded resident payload")
			var image: Image=payload.layers[0]
			var finite=true; var bounded=true
			for y in range(0,payload.size,4):
				for x in range(0,payload.size,4):
					var angle=image.get_pixel(x,y)
					for channel in 4:
						finite=finite and is_finite(angle[channel]); bounded=bounded and angle[channel]>=0.0 and angle[channel]<PI/2
			check(finite and bounded,"Persisted horizon samples are finite obstruction angles")
			for direction in [Vector3(1,.2,0),Vector3(-.2,.7,1),Vector3(0,.001,-1)]:
				controller.set_light(direction)
				var daylight=[controller.bins,controller.blend,controller.elevation]
				controller.set_light(-direction)
				check(daylight==[controller.bins,controller.blend,controller.elevation],"Opposite moon hemisphere selects the same active-light bearing")
			var copy=payload.duplicate()
			copy.payload_version+=1
			check(not copy.valid_for(source,tier,quality),"Unknown payload version is rejected")
			copy.payload_version=payload.payload_version; copy.geometry_tier=(tier+1)%3
			check(not copy.valid_for(source,tier,quality),"Atlas cannot be used with another geometry tier")
			var empty_layers: Array[Image]=[]
			copy.geometry_tier=tier; copy.layers=empty_layers
			check(not copy.valid_for(source,tier,quality),"Missing image bytes are rejected, including headless empty texture saves")
	controller.set_light(Vector3(NAN,0,0))
	check(is_finite(controller.elevation) and controller.bins.is_finite(),"Invalid light direction has a finite non-shadowing fallback")
	var texture_ref=weakref(controller.texture)
	controller.select(0,2,source); controller.bind(material)
	check(controller.payload==null and controller.texture==null and material.get_shader_parameter("offmap_horizon")==null and texture_ref.get_ref()==null,"Off unbinds and releases optional atlas residency")
	check(not material.get_shader_parameter("offmap_horizon_enabled"),"Off disables shader evaluation")
	var inactive_bins=controller.bins
	controller.set_light(Vector3(1,.1,0))
	check(controller.bins==inactive_bins and controller.sun_direction==Vector3(1,.1,0),"Off caches new light direction without evaluating angles")
	controller.select(1,2,source)
	check(controller.bins.x==1 and controller.bins.y==0,"Re-enabling uses the latest cached direction at the selected quality")
	controller.select(0,2,source)
	# Maximum irregular footprint + join + connector delta is strictly inside
	# exclusion for every seed; no reference-seed terrain enters the bake.
	var max_variable=Data.Footprint.SHAPE.x+absf(Data.Footprint.SHAPE.y)+absf(Data.Footprint.SHAPE.z)+absf(Data.Footprint.SHAPE.w)+Data.Footprint.JOIN_MARGIN_M+640.0
	check(max_variable<Horizon.Asset.EXCLUDED_RADIUS_M,"Conservative exclusion contains every variable connector orientation")
	var outside=true
	for a in 360:
		var p=Vector2(sin(deg_to_rad(a)),cos(deg_to_rad(a)))*Horizon.Asset.EXCLUDED_RADIUS_M
		outside=outside and Data.Footprint.edge_distance(p)>=640.0
	check(outside,"All 360 sampled bearings begin outside the deformed apron")
	check(FileAccess.get_file_as_string("res://export_presets.cfg").contains('export_filter="all_resources"'),"Companion resources are included by the production export policy")
	print("OFFMAP_HORIZON_RESULTS ",JSON.stringify({"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
