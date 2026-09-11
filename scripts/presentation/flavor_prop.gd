@tool
extends Node3D
## Drag the matching .tscn into a scene. Static colliders work in Godot/Jolt.
## For the independent skier, bind_surface(PropCollisionSurface) once placed.
@export var asset_id: String = ""
@export_range(0.0,1.0) var snow_amount: float = .7
var collision_surface
var shader_materials: Array[ShaderMaterial] = []
var record: Dictionary
var lighting
var quality_level=2

func _ready() -> void:
	if asset_id.is_empty(): return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/graphics/flavor_v1/manifest.json"))
	for candidate in manifest.assets:
		if candidate.id==asset_id: record=candidate; break
	if record.is_empty(): push_error("Unknown flavor asset: "+asset_id); return
	_build()

func _build() -> void:
	for lod in 3:
		var model = load("res://"+record.models[lod].path).instantiate()
		model.name="Detail%d" % lod
		add_child(model)
		_materials(model,lod)
	var body=StaticBody3D.new(); body.name="SolidParts"; body.collision_layer=9; body.collision_mask=16
	add_child(body)
	for box in record.colliders:
		var collider=CollisionShape3D.new(); collider.shape=BoxShape3D.new()
		collider.shape.size=_vector(box.size); collider.position=_vector(box.center)
		body.add_child(collider)
	set_snow(snow_amount)

func _materials(node: Node, lod: int) -> void:
	if node is MeshInstance3D:
		node.visibility_range_begin=[0.0,45.0,120.0][lod]
		node.visibility_range_end=[45.0,120.0,450.0][lod]
		# All colliders remain active regardless of graphics detail.
		for i in node.mesh.get_surface_count():
			var original=node.get_active_material(i)
			if not original is StandardMaterial3D: continue
			var mat=ShaderMaterial.new(); mat.shader=preload("res://assets/graphics/flavor_v1/flavor_snow.gdshader")
			mat.set_shader_parameter("base_color",original.albedo_color)
			mat.set_shader_parameter("roughness_value",original.roughness)
			mat.set_shader_parameter("metallic_value",original.metallic)
			mat.set_shader_parameter("asset_height",float(record.dimensions_m[1]))
			if original.albedo_texture:
				mat.set_shader_parameter("albedo_tex",original.albedo_texture)
				mat.set_shader_parameter("has_albedo",true)
			if original.normal_enabled and original.normal_texture:
				mat.set_shader_parameter("normal_tex",original.normal_texture)
				mat.set_shader_parameter("normal_strength",original.normal_scale)
			if original.roughness_texture:
				mat.set_shader_parameter("roughness_tex",original.roughness_texture)
				mat.set_shader_parameter("has_roughness",true)
				mat.set_shader_parameter("roughness_channel",original.roughness_texture_channel)
			if original.metallic_texture:
				mat.set_shader_parameter("metallic_tex",original.metallic_texture)
				mat.set_shader_parameter("has_metallic",true)
				mat.set_shader_parameter("metallic_channel",original.metallic_texture_channel)
			# Use identical external textures at every distance detail level.
			for shared in record.get("materials",[]):
				if shared.name!=original.resource_name: continue
				if shared.albedo: mat.set_shader_parameter("albedo_tex",load(shared.albedo))
				if shared.normal: mat.set_shader_parameter("normal_tex",load(shared.normal))
				if shared.orm:
					mat.set_shader_parameter("roughness_tex",load(shared.orm))
					mat.set_shader_parameter("metallic_tex",load(shared.orm))
			node.set_surface_override_material(i,mat); shader_materials.append(mat)
			if lighting: lighting.register(mat)
	for child in node.get_children(): _materials(child,lod)

func set_snow(amount: float) -> void:
	snow_amount=clampf(amount,0,1)
	for mat in shader_materials: mat.set_shader_parameter("snow_amount",snow_amount)

func set_detail(level: int = -1) -> void:
	# -1 restores distance detail; 0..2 lets the gallery inspect each export.
	for lod in 3:
		var node=get_node_or_null("Detail%d" % lod)
		if node:
			node.visible=level<0 or level==lod
			_detail_ranges(node,lod,level<0)

func apply_quality(level: int) -> void:
	quality_level=clampi(level,0,2)
	set_detail(-1)

func _detail_ranges(node: Node,lod: int,automatic: bool) -> void:
	if node is GeometryInstance3D:
		var ranges=[[25.,75.,450.],[35.,100.,450.],[45.,120.,450.]][quality_level]
		node.visibility_range_begin=([0.0,ranges[0],ranges[1]][lod]) if automatic else 0.0
		node.visibility_range_end=ranges[lod] if automatic else 0.0
	for child in node.get_children(): _detail_ranges(child,lod,automatic)

func add_foundations(boxes: Array) -> void:
	var material=ShaderMaterial.new()
	material.shader=preload("res://assets/graphics/flavor_v1/flavor_foundation.gdshader")
	material.set_shader_parameter("rock_albedo",preload("res://assets/graphics/textures/rock_albedo.jpg"))
	if not boxes.is_empty():
		shader_materials.append(material)
		if lighting: lighting.register(material)
	for box in boxes:
		record.colliders.append(box)
		var visual=MeshInstance3D.new(); visual.mesh=BoxMesh.new(); visual.mesh.size=_vector(box.size)
		visual.position=_vector(box.center); add_child(visual)
		visual.material_override=material; visual.visibility_range_end=450.0
		var collider=CollisionShape3D.new(); collider.shape=BoxShape3D.new()
		collider.shape.size=_vector(box.size); collider.position=_vector(box.center); get_node("SolidParts").add_child(collider)
	sync_collision()

func set_collision_enabled(enabled: bool) -> void:
	get_node("SolidParts").collision_layer=9 if enabled else 0
	if not enabled: unbind_surface()

func bind_surface(surface) -> void:
	unbind_surface()
	collision_surface=surface
	sync_collision()

func sync_collision() -> void:
	# Call explicitly after moving a bound prop. No per-frame Node queries.
	if collision_surface==null or record.is_empty(): return
	var boxes: Array=[]
	for box in record.colliders:
		boxes.append({"transform":global_transform*Transform3D(Basis.IDENTITY,_vector(box.center)),
			"size":_vector(box.size),"reason":("GATE IMPACT" if record.family=="gates" else "PROP IMPACT")})
	collision_surface.register_props(get_instance_id(),boxes)

func unbind_surface() -> void:
	if collision_surface!=null:
		collision_surface.unregister_props(get_instance_id())
		collision_surface=null

func _exit_tree() -> void:
	unbind_surface()
	if lighting:
		for mat in shader_materials: lighting.materials.erase(mat)

static func _vector(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])
