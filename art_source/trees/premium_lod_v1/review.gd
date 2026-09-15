extends SceneTree
## Finite, capped, isolated source-asset review. Never loads the game or imports
## production resources. Invocation: --assets=ABS_PACK --output=ABS_DIR --bake
## --sample chooses one spruce/fir/pine and a compact initial visual pass.
## --bake-only emits atlas and validation receipts without running visual review.

const VIEW_SIZE := Vector2i(1600, 1000)
const TILE_SIZE := 512
const VIEW_COUNT := 8
const NEAR_DISTANCE := 12.0
const FAR_DISTANCE := 64.0
const FEATHER := 5.0
const MOTION_FRAME_COUNT := 90
const MOTION_CAPTURE_STRIDE := 3
const MOTION_SOURCE_FPS := 60.0
const GEOMETRY_CODE := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool textured = false;
uniform bool normal_textured = false;
uniform float normal_strength = 1.0;
uniform float alpha_cutoff = .5;
uniform vec4 crown_bounds = vec4(0.0,5.0,0.0,5.0);
uniform bool fade_enabled = false;
uniform int tier = 0;
varying float coverage;
float threshold(vec2 p) { return fract(52.9829189*fract(dot(floor(p),vec2(.06711056,.00583715)))); }
void vertex() {
 vec3 crown=(MODEL_MATRIX*vec4(crown_bounds.xyz,1.0)).xyz;
 float scale=max(length(MODEL_MATRIX[0].xyz),max(length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz)));
 float d=max(0.0,distance(MAIN_CAM_INV_VIEW_MATRIX[3].xyz,crown)-crown_bounds.w*scale);
 float near_part=smoothstep(7.0,17.0,d), far_part=smoothstep(59.0,69.0,d);
 coverage=fade_enabled ? (tier==0 ? 1.0-near_part : near_part*(1.0-far_part)) : 1.0;
}
void fragment() {
 float cut=threshold(FRAGCOORD.xy);
 if(tier==1) cut=1.0-cut;
 if(coverage<cut) discard;
 vec4 tex=textured ? texture(albedo_texture,UV) : vec4(1.0);
 if(tex.a<alpha_cutoff) discard;
 ALBEDO=COLOR.rgb*base_color.rgb*tex.rgb;
 if(normal_textured) { NORMAL_MAP=texture(normal_texture,UV).rgb; NORMAL_MAP_DEPTH=normal_strength; }
 ROUGHNESS=.91;
 SPECULAR=.14;
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
"""
const BAKE_NORMAL_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool textured = false;
uniform bool normal_textured = false;
uniform float normal_strength = 1.0;
uniform float alpha_cutoff = .5;
uniform bool canopy_mode = false;
uniform float canopy_value = 1.0;
varying vec3 object_normal;
varying vec3 object_tangent;
varying vec3 object_binormal;
vec3 from_srgb(vec3 c) { return mix(pow((c+vec3(.055))/1.055,vec3(2.4)),c/12.92,step(c,vec3(.04045))); }
void vertex() {
 object_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 object_tangent=normalize(MODEL_NORMAL_MATRIX*TANGENT);
 object_binormal=normalize(MODEL_NORMAL_MATRIX*BINORMAL);
}
void fragment() {
 if(textured && texture(albedo_texture,UV).a<alpha_cutoff) discard;
 vec3 n=normalize(object_normal);
 if(normal_textured) {
  vec3 mapped=texture(normal_texture,UV).rgb*2.0-1.0;
  mapped.xy*=normal_strength;
  n=normalize(object_tangent*mapped.x+object_binormal*mapped.y+n*mapped.z);
 }
 if(!FRONT_FACING) n=-n;
 vec3 encoded=canopy_mode ? vec3(canopy_value) : n*.5+.5;
 ALBEDO=OUTPUT_IS_SRGB ? encoded : from_srgb(encoded);
}
"""
const BAKE_COLOR_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool textured = false;
uniform float alpha_cutoff = .5;
void fragment() {
 vec4 tex=textured ? texture(albedo_texture,UV) : vec4(1.0);
 if(tex.a<alpha_cutoff) discard;
 ALBEDO=COLOR.rgb*base_color.rgb*tex.rgb;
}
"""

var asset_root := ""
var output := ""
var bake := false
var bake_only := false
var sample := false
var catalog: Dictionary = {}
var records: Array = []
var stage: Node3D
var display: Node3D
var camera: Camera3D
var environment: Environment
var floor_mesh: MeshInstance3D
var sun: DirectionalLight3D
var hud: CanvasLayer
var heading: Label
var subtitle: Label
var footer: Label
var templates: Dictionary = {}
var bounds_cache: Dictionary = {}
var material_cache: Dictionary = {}
var texture_cache: Dictionary = {}
var captures: Array = []
var motion_sequences: Array = []
var baked: Array = []
var failures: Array[String] = []
var checks := 0
var geometry_shader: Shader
var far_shader: Shader
var normal_shader: Shader
var color_shader: Shader
var started_ms := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("PREMIUM_TREE_FAIL ", label)

func model_record(record: Dictionary, lod: int) -> Dictionary:
	for model: Dictionary in record.models:
		if int(model.get("lod", -1)) == lod: return model
	return record.models[lod]

func model_path(model: Dictionary) -> String:
	return asset_root.path_join(str(model.get("path", "models/" + str(model.get("file", "")))))

func mesh_nodes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node as MeshInstance3D)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		result.append(child as MeshInstance3D)
	return result

func load_model(record: Dictionary, lod: int) -> Node3D:
	var model := model_record(record, lod)
	var path := model_path(model)
	if templates.has(path): return templates[path].duplicate() as Node3D
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	check(error == OK, "GLB load " + path.get_file())
	if error != OK: return Node3D.new()
	var node := document.generate_scene(state) as Node3D
	check(node != null, "Generated scene " + path.get_file())
	if node == null: return Node3D.new()
	var triangles := 0
	var surface_count := 0
	for child in mesh_nodes(node):
		triangles += child.mesh.get_faces().size() / 3
		surface_count += child.mesh.get_surface_count()
		for surface in child.mesh.get_surface_count():
			var arrays := child.mesh.surface_get_arrays(surface)
			var mat := child.mesh.surface_get_material(surface) as StandardMaterial3D
			check(mat != null, "Portable material " + path.get_file())
			if mat != null:
				mat.vertex_color_use_as_albedo = true
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mat.roughness = .91
				mat.metallic_specular = .14
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				for property in ["albedo_texture", "normal_texture"]:
					var source_texture: Texture2D = mat.get(property)
					if source_texture != null:
						var pixels := source_texture.get_image()
						pixels.generate_mipmaps(property == "normal_texture")
						mat.set(property, ImageTexture.create_from_image(pixels))
				if lod < 2:
					var opaque_or_cutout := mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED or (mat.resource_name.contains("Foliage") and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
					check(opaque_or_cutout, "Opaque or foliage-cutout detailed material " + path.get_file())
			check(arrays[Mesh.ARRAY_TEX_UV] != null and not arrays[Mesh.ARRAY_TEX_UV].is_empty(), "UV0 " + path.get_file())
			if lod < 2:
				check(arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty(), "Vertex colors " + path.get_file())
				check(arrays[Mesh.ARRAY_TEX_UV2] != null and not arrays[Mesh.ARRAY_TEX_UV2].is_empty(), "Branch UV1 " + path.get_file())
	check(triangles == int(model.triangles), "Manifest triangles " + path.get_file())
	if model.has("surfaces"): check(surface_count == int(model.surfaces), "Manifest surfaces " + path.get_file())
	check(node.find_children("*", "CollisionObject3D", true, false).is_empty(), "No physics " + path.get_file())
	if model.has("sha256") and not str(model.sha256).is_empty():
		check(FileAccess.get_sha256(path) == str(model.sha256), "Model hash " + path.get_file())
	templates[path] = node.duplicate()
	return node

func merged_bounds(node: Node3D) -> AABB:
	var found := false
	var result := AABB()
	for child in mesh_nodes(node):
		var transform := child.transform
		var parent_node := child.get_parent()
		while parent_node != null and parent_node != node:
			if parent_node is Node3D: transform = (parent_node as Node3D).transform * transform
			parent_node = parent_node.get_parent()
		var transformed: AABB = transform * child.mesh.get_aabb()
		result = result.merge(transformed) if found else transformed
		found = true
	return result

func crown_bounds(record: Dictionary) -> Vector4:
	if bounds_cache.has(record.id): return bounds_cache[record.id]
	var node := load_model(record, 0)
	var box := merged_bounds(node)
	node.free()
	var center := box.get_center()
	var radius := box.size.length() * .5
	var result := Vector4(center.x, center.y, center.z, radius)
	bounds_cache[record.id] = result
	return result

func atlas_texture(record: Dictionary, role: String) -> Texture2D:
	var path := asset_root.path_join("impostors/" + str(record.id) + "_" + role + ".png")
	if texture_cache.has(path): return texture_cache[path]
	var pixels := Image.load_from_file(path)
	check(pixels != null and not pixels.is_empty(), "Atlas load " + path.get_file())
	if pixels == null or pixels.is_empty(): return null
	check(pixels.get_size() == Vector2i(TILE_SIZE * VIEW_COUNT, TILE_SIZE), "Atlas dimensions " + path.get_file())
	# Normal RGB is an encoded object-space vector with associated coverage;
	# renormalizing mip pixels here would corrupt alpha-edge reconstruction.
	pixels.generate_mipmaps(false)
	var texture := ImageTexture.create_from_image(pixels)
	texture_cache[path] = texture
	return texture

func set_materials(node: Node3D, record: Dictionary, lod: int, fading: bool) -> void:
	for child in mesh_nodes(node):
		for surface in child.mesh.get_surface_count():
			var original := child.mesh.surface_get_material(surface) as StandardMaterial3D
			var key := str(record.id) + ":" + str(lod) + ":" + str(surface) + ":" + str(original.resource_name if original != null else "none") + ":" + str(fading)
			if not material_cache.has(key):
				var mat := ShaderMaterial.new()
				mat.shader = far_shader if lod == 2 else geometry_shader
				mat.set_shader_parameter("crown_bounds", crown_bounds(record))
				mat.set_shader_parameter("fade_enabled", fading)
				if lod == 2:
					mat.set_shader_parameter("color_atlas", atlas_texture(record, "color"))
					mat.set_shader_parameter("normal_atlas", atlas_texture(record, "normal"))
					mat.set_shader_parameter("canopy_atlas", atlas_texture(record, "canopy"))
				else:
					mat.set_shader_parameter("tier", lod)
					mat.set_shader_parameter("base_color", original.albedo_color if original != null else Color.WHITE)
					if original != null: configure_texture_parameters(mat, original)
				material_cache[key] = mat
			child.set_surface_override_material(surface, material_cache[key])

func clear_display() -> void:
	if display != null: display.free()
	display = Node3D.new()
	stage.add_child(display)
	floor_mesh.rotation.x = 0.0
	floor_mesh.visible = true
	sun.rotation_degrees = Vector3(-37, -28, 0)
	environment.fog_enabled = false

func add_tree(record: Dictionary, position: Vector3, lod: int, yaw: float = 0.0, fading: bool = false, scale_value: float = 1.0) -> Node3D:
	var node := load_model(record, lod)
	display.add_child(node)
	node.position = position
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale_value
	set_materials(node, record, lod, fading)
	return node

func add_adaptive_tree(record: Dictionary, position: Vector3, yaw: float = 0.0, scale_value: float = 1.0) -> Dictionary:
	var crown := crown_bounds(record)
	var center := position + Vector3(crown.x, crown.y, crown.z).rotated(Vector3.UP, yaw) * scale_value
	var distance_m := maxf(0.0, camera.position.distance_to(center) - crown.w * scale_value)
	var tiers: Array = []
	if distance_m < NEAR_DISTANCE + FEATHER: tiers.append(0)
	if distance_m > NEAR_DISTANCE - FEATHER and distance_m < FAR_DISTANCE + FEATHER: tiers.append(1)
	if distance_m > FAR_DISTANCE - FEATHER: tiers.append(2)
	for tier: int in tiers: add_tree(record, position, tier, yaw, true, scale_value)
	return {"id": record.id, "crown_distance_m": distance_m, "tiers": tiers}

func caption(title: String, detail: String) -> void:
	heading.text = title
	subtitle.text = detail
	footer.text = "ALPINE APEX  /  PREMIUM TREE SOURCE REVIEW     |     ISOLATED ASSETS • NO RUNTIME INTEGRATION • NO FPS CLAIM"

func capture(name: String, details: Dictionary = {}) -> Image:
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	var path := output.path_join(name + ".png")
	check(pixels.save_png(path) == OK, "Capture saved " + name)
	var entry := {"name": name, "file": name + ".png", "path": path, "label": heading.text, "title": heading.text, "subtitle": subtitle.text,
		"camera_position": [camera.position.x, camera.position.y, camera.position.z],
		"camera_rotation_degrees": [camera.rotation_degrees.x, camera.rotation_degrees.y, camera.rotation_degrees.z],
		"projection": "orthographic" if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else "perspective",
		"orthographic_size_m": camera.size, "fov_degrees": camera.fov, "details": details}
	captures.append(entry)
	print("PREMIUM_TREE_CAPTURE ", name)
	return pixels

func configure_texture_parameters(mat: ShaderMaterial, source: StandardMaterial3D) -> void:
	mat.set_shader_parameter("textured", source.albedo_texture != null)
	mat.set_shader_parameter("normal_textured", source.normal_enabled and source.normal_texture != null)
	mat.set_shader_parameter("normal_strength", source.normal_scale)
	mat.set_shader_parameter("alpha_cutoff", source.alpha_scissor_threshold if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else .001)
	if source.albedo_texture != null: mat.set_shader_parameter("albedo_texture", source.albedo_texture)
	if source.normal_texture != null: mat.set_shader_parameter("normal_texture", source.normal_texture)

func set_bake_materials(node: Node3D, role: String) -> void:
	for child in mesh_nodes(node):
		for surface in child.mesh.get_surface_count():
			var source := child.mesh.surface_get_material(surface) as StandardMaterial3D
			if role == "normal" or role == "canopy":
				var normal := ShaderMaterial.new()
				normal.shader = normal_shader
				configure_texture_parameters(normal, source)
				normal.set_shader_parameter("canopy_mode", role == "canopy")
				var canopy := source.resource_name.contains("Foliage") or source.resource_name.contains("Snow")
				normal.set_shader_parameter("canopy_value", 1.0 if canopy else 0.0)
				child.set_surface_override_material(surface, normal)
			else:
				var mat := ShaderMaterial.new()
				mat.shader = color_shader
				configure_texture_parameters(mat, source)
				mat.set_shader_parameter("base_color", source.albedo_color)
				child.set_surface_override_material(surface, mat)

func bake_atlases() -> void:
	clear_display()
	floor_mesh.visible = false
	hud.visible = false
	root.size = Vector2i(TILE_SIZE, TILE_SIZE)
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.transparent_bg = true
	environment.background_mode = Environment.BG_CLEAR_COLOR
	var old_clear := RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	DirAccess.make_dir_recursive_absolute(asset_root.path_join("impostors"))
	for record: Dictionary in records:
		var node := load_model(record, 0)
		display.add_child(node)
		var box := merged_bounds(node)
		var framing: Dictionary = record.get("impostor", {})
		var span: float = float(framing.get("ortho_scale", maxf(box.size.y, maxf(box.size.x, box.size.z)) * 1.12))
		var center_y: float = float(framing.get("center_z", box.get_center().y))
		camera.size = span
		camera.near = .05
		camera.far = 1000.0
		var files: Dictionary = {}
		for role: String in ["color", "normal", "canopy"]:
			set_bake_materials(node, role)
			var atlas := Image.create(TILE_SIZE * VIEW_COUNT, TILE_SIZE, false, Image.FORMAT_RGBA8)
			atlas.fill(Color(0, 0, 0, 0))
			for view in VIEW_COUNT:
				var angle := float(view) * TAU / float(VIEW_COUNT)
				camera.position = Vector3(sin(angle) * span * 3.0, center_y, cos(angle) * span * 3.0)
				camera.look_at(Vector3(0, center_y, 0))
				for frame in 2: await process_frame
				await RenderingServer.frame_post_draw
				var pixels := root.get_texture().get_image()
				pixels.convert(Image.FORMAT_RGBA8)
				check(pixels.get_size() == Vector2i(TILE_SIZE, TILE_SIZE), "Bake viewport dimensions")
				check(pixels.get_pixel(0, 0).a < .01, "Transparent bake background")
				var used := pixels.get_used_rect()
				check(used.size.x > 2 and used.size.y > 8, "Nonempty bake silhouette " + str(record.id) + " " + role)
				check(used.position.x > 0 and used.position.y > 0 and used.end.x < TILE_SIZE and used.end.y < TILE_SIZE, "Unclipped bake framing " + str(record.id) + " " + role)
				atlas.blit_rect(pixels, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(view * TILE_SIZE, 0))
			var relative := "impostors/" + str(record.id) + "_" + role + ".png"
			check(atlas.save_png(asset_root.path_join(relative)) == OK, "Bake saved " + relative)
			files[role] = {"path": relative, "sha256": FileAccess.get_sha256(asset_root.path_join(relative))}
		baked.append({"id": record.id, "source_model_sha256": FileAccess.get_sha256(model_path(model_record(record, 0))),
			"views": VIEW_COUNT, "tile_size": TILE_SIZE, "ortho_scale": span, "center_z": center_y,
			"yaw_degrees": [0, 45, 90, 135, 180, 225, 270, 315], "files": files,
			"normal_space": "Godot object XYZ, Y up; encode normal * 0.5 + 0.5",
			"color_lighting": "unlit portable material albedo times vertex color",
			"canopy": "white foliage and snow, black wood; silhouette alpha",
			"edge_encoding": "binary alpha with zero RGB background; shader unassociates filtered RGB by coverage",
			"integrated": false})
		print("PREMIUM_TREE_BAKED ", record.id)
		node.free()
	write_json(output.path_join("bake_manifest.json"), {"sample": sample, "assets": baked})
	root.transparent_bg = false
	root.size = VIEW_SIZE
	root.msaa_3d = Viewport.MSAA_4X
	RenderingServer.set_default_clear_color(old_clear)
	environment.background_mode = Environment.BG_COLOR
	floor_mesh.visible = true
	hud.visible = true

func family_review(family: String, family_records: Array) -> void:
	for lod in 3:
		clear_display()
		var tallest := 1.0
		var width := 0.0
		for record: Dictionary in family_records:
			tallest = maxf(tallest, float(record.get("height_m", 10.0)))
			width = maxf(width, float(record.impostor.ortho_scale) * .8)
		var spacing := maxf(8.0, width)
		for i in family_records.size():
			var record: Dictionary = family_records[i]
			add_tree(record, Vector3((i - (family_records.size() - 1) * .5) * spacing, 0, 0), lod, .20)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(tallest * 1.45, family_records.size() * spacing / 1.6)
		camera.position = Vector3(0, tallest * .66, tallest * 3)
		camera.look_at(Vector3(0, tallest * .46, 0))
		var crown_label := "branch silhouette"
		if family in ["spruce", "fir", "pine"]: crown_label = "curved needle sprays"
		elif family == "golden": crown_label = "folded rounded leaves"
		elif family == "maple": crown_label = "folded lobed leaves"
		var tier_name: String = ["NEAR • " + crown_label, "MID • reduced " + crown_label, "FAR • relit eight-view card"][lod]
		caption(family.to_upper() + "  /  " + tier_name, "Matched orthographic camera and asset seeds • forced tier " + str(lod) + " • " + str(family_records.size()) + " source variants")
		await capture(family + "_lod" + str(lod), {"family": family, "lod": lod, "ids": family_records.map(func(r): return r.id)})

func hero_record() -> Dictionary:
	for record: Dictionary in records:
		if record.id == "forest_spruce_02": return record
	for record: Dictionary in records:
		if record.family == "spruce": return record
	return records[0]

func close_review() -> void:
	clear_display()
	var record := hero_record()
	add_tree(record, Vector3.ZERO, 0, .2)
	var height := float(record.get("height_m", 10.0))
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45
	camera.position = Vector3(height * .27, height * .28, height * .52)
	camera.look_at(Vector3(0, height * .36, 0))
	caption("BESIDE THE SKIER  /  " + str(record.id).to_upper(), "Textured volumetric sprays • branch layering, trunk clearance and snow volume • perspective camera")
	await capture("close_branch_detail", {"id": record.id, "lod": 0})

func forest_record(rng: RandomNumberGenerator) -> Dictionary:
	# Evergreen alpine stand with restrained deciduous accents and deadwood.
	var weights := {"spruce": .32, "fir": .24, "pine": .20, "birch": .06, "golden": .07, "maple": .04, "dead": .04, "broken": .03}
	var pick := rng.randf()
	var selected := "spruce"
	for family: String in weights:
		pick -= float(weights[family])
		if pick <= 0:
			selected = family
			break
	var candidates: Array = records.filter(func(r): return r.family == selected)
	if candidates.is_empty(): candidates = records
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func stand_review(kind: String) -> void:
	clear_display()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 54
	var count := 288
	var focus := Vector3(0, 12, -65)
	if kind == "forest_depth": camera.position = Vector3(2, 3.4, 15)
	elif kind == "far_slope":
		camera.position = Vector3(0, 40, 78)
		focus = Vector3(0, 12, -55)
		camera.fov = 34
	elif kind == "high_elevation":
		camera.position = Vector3(35, 120, 40)
		focus = Vector3(0, 8, -60)
	else:
		camera.position = Vector3(-18, 8, 26)
		sun.rotation_degrees = Vector3(-19, 158, 0)
	camera.look_at(focus)
	floor_mesh.rotation.x = .055
	var rng := RandomNumberGenerator.new()
	rng.seed = 9152026
	var placements: Array = []
	var tier_counts := [0, 0, 0]
	for i in count:
		var column := i % 18
		var row := i / 18
		var x := (column - 8.5) * 7.1 + rng.randf_range(-2.8, 2.8)
		var z := -float(row) * 9.0 + rng.randf_range(-3.5, 3.5)
		# Small winding glade exposes layers and prevents a solid front wall.
		if absf(x - sin(z * .042) * 6.0) < 3.8: x += 6.0 * (1.0 if x >= 0 else -1.0)
		var y := -z * tan(.055)
		var record: Dictionary = forest_record(rng)
		var placed := add_adaptive_tree(record, Vector3(x, y, z), rng.randf_range(0, TAU), rng.randf_range(.86, 1.18))
		for tier: int in placed.tiers: tier_counts[tier] += 1
		placements.append(placed)
	var descriptions := {"forest_depth": "Skier-height glade and layered stand", "far_slope": "Distant forest volume and species rhythm", "high_elevation": "Elevated camera stress • axial-card limitation remains visible", "backlit": "Low side/back sun • object-space normals respond to light"}
	caption(str(descriptions[kind]).to_upper(), str(count) + " trees • 12 / 64 m crown-distance thresholds • ±5 m complementary dither • tiers " + str(tier_counts))
	await capture(kind, {"tree_count": count, "tier_instance_counts": tier_counts, "placements": placements,
		"slope_radians": .055, "seed": 9152026, "uses_runtime_lod_thresholds": true,
		"performance_acceptance": false, "axial_impostor_elevation_limitation": kind == "high_elevation"})

func transition_review() -> void:
	var record := hero_record()
	var crown := crown_bounds(record)
	var center := Vector3(crown.x, crown.y, crown.z)
	for boundary in [NEAR_DISTANCE, FAR_DISTANCE]:
		var small_images: Array[Image] = []
		for offset in [-6.0, -2.5, 0.0, 2.5, 6.0]:
			clear_display()
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 38.0 if boundary == NEAR_DISTANCE else 12.0
			camera.position = center + Vector3(0, 0, crown.w + boundary + offset)
			camera.look_at(center)
			var placed := add_adaptive_tree(record, Vector3.ZERO)
			var label := "near_mid" if boundary == NEAR_DISTANCE else "mid_far"
			caption(label.to_upper().replace("_", " → ") + "  /  " + str(boundary + offset) + " M", "Continuous world-distance sequence • ±5 m production feather • " + ("38° field of view" if boundary == NEAR_DISTANCE else "12° telephoto silhouette stress; distances remain unchanged"))
			var pixels: Image = await capture("transition_" + label + "_" + str(boundary + offset).replace(".", "p"), placed)
			pixels.convert(Image.FORMAT_RGBA8)
			pixels.resize(480, 300, Image.INTERPOLATE_LANCZOS)
			small_images.append(pixels)
		var strip := Image.create(2400, 300, false, Image.FORMAT_RGBA8)
		for i in small_images.size(): strip.blit_rect(small_images[i], Rect2i(0, 0, 480, 300), Vector2i(i * 480, 0))
		var strip_name := "transition_near_mid_strip.png" if boundary == NEAR_DISTANCE else "transition_mid_far_strip.png"
		check(strip.save_png(output.path_join(strip_name)) == OK, "Transition strip")
		captures.append({"name": strip_name.get_basename(), "file": strip_name, "path": output.path_join(strip_name), "label": "Transition sequence at " + str(boundary) + " m", "details": {"kind": "distance_sequence_contact_strip", "boundary_m": boundary}})
		# Forced adjacent tiers at an exactly matched boundary camera make the
		# silhouette/colour hand-off reviewable separately from the dither.
		for lod in ([0, 1] if boundary == NEAR_DISTANCE else [1, 2]):
			clear_display()
			camera.position = center + Vector3(0, 0, crown.w + boundary)
			camera.look_at(center)
			add_tree(record, Vector3.ZERO, lod)
			caption("MATCHED HAND-OFF  /  " + str(boundary) + " M  /  FORCED TIER " + str(lod), "Exact same camera, source seed and lighting across each adjacent-tier pair")
			await capture("handoff_" + str(int(boundary)) + "m_lod" + str(lod), {"boundary_m": boundary, "forced_lod": lod, "id": record.id})

func transition_motion_review() -> void:
	var record := hero_record()
	var crown := crown_bounds(record)
	var center := Vector3(crown.x, crown.y, crown.z)
	for boundary in [NEAR_DISTANCE, FAR_DISTANCE]:
		clear_display()
		var band := "near_mid" if boundary == NEAR_DISTANCE else "mid_far"
		var relative_directory := "motion_" + band
		DirAccess.make_dir_recursive_absolute(output.path_join(relative_directory))
		var tiers: Array = [0, 1] if boundary == NEAR_DISTANCE else [1, 2]
		for lod: int in tiers: add_tree(record, Vector3.ZERO, lod, 0.0, true)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		var distance_start: float = boundary + 7.0
		var distance_end: float = boundary - 7.0
		# Fixed field of view throughout each approach. Include the entire crown
		# at the closest endpoint so a changing crop cannot conceal a hand-off.
		var span := float(record.impostor.ortho_scale)
		var fitting_fov := rad_to_deg(2.0 * atan(span * .65 / (crown.w + distance_end)))
		camera.fov = maxf(38.0 if boundary == NEAR_DISTANCE else 12.0, fitting_fov)
		camera.position = center + Vector3(0, 0, crown.w + distance_start)
		camera.look_at(center)
		for warmup_frame in 4: await process_frame
		var frames: Array = []
		var saved_count := 0
		for frame_index in MOTION_FRAME_COUNT:
			var fraction := float(frame_index) / float(MOTION_FRAME_COUNT - 1)
			var distance_m := lerpf(distance_start, distance_end, fraction)
			camera.position = center + Vector3(0, 0, crown.w + distance_m)
			camera.look_at(center)
			var incoming_weight := smoothstep(boundary - FEATHER, boundary + FEATHER, distance_m)
			caption(band.to_upper().replace("_", " → ") + "  /  APPROACH  /  %.2f M" % distance_m,
				"Frame %03d / 089 • %.1f° fixed field of view • textured sprays and complementary ±5 m dither" % [frame_index, camera.fov])
			await process_frame
			await RenderingServer.frame_post_draw
			var relative_file := ""
			if frame_index % MOTION_CAPTURE_STRIDE == 0:
				relative_file = relative_directory + "/frame_%03d.jpg" % frame_index
				var pixels := root.get_texture().get_image()
				check(pixels.save_jpg(output.path_join(relative_file), .94) == OK, "Motion frame " + band + " " + str(frame_index))
				saved_count += 1
			frames.append({"frame_index": frame_index, "source_time_seconds": float(frame_index) / MOTION_SOURCE_FPS,
				"file": relative_file, "captured": not relative_file.is_empty(), "band": band,
				"crown_distance_m": distance_m, "boundary_m": boundary, "feather_half_width_m": FEATHER,
				"tier_weights": {str(tiers[0]): 1.0 - incoming_weight, str(tiers[1]): incoming_weight},
				"camera_position": [camera.position.x, camera.position.y, camera.position.z],
				"camera_target": [center.x, center.y, center.z],
				"camera_rotation_degrees": [camera.rotation_degrees.x, camera.rotation_degrees.y, camera.rotation_degrees.z],
				"projection": "perspective", "fov_degrees": camera.fov})
		check(frames.size() == MOTION_FRAME_COUNT and saved_count == 30, "Complete finite motion sequence " + band)
		var sequence := {"band": band, "label": band.replace("_", " → ") + " chronological approach",
			"asset_id": record.id, "family": record.family, "boundary_m": boundary,
			"directory": relative_directory, "manifest_file": relative_directory + "/manifest.json",
			"frame_count": MOTION_FRAME_COUNT, "captured_frame_count": saved_count,
			"capture_stride": MOTION_CAPTURE_STRIDE, "source_fps": MOTION_SOURCE_FPS,
			"playback_fps": MOTION_SOURCE_FPS / MOTION_CAPTURE_STRIDE,
			"distance_start_m": distance_start, "distance_end_m": distance_end,
			"fov_degrees": camera.fov, "direction": "approach", "frames": frames,
			"timing_meaning": "90 authored chronological camera states at nominal 60 Hz; every third state saved. Image writing is not real-time or performance evidence.",
			"scope": "isolated presentation shader transition; no skiing simulation or controller inputs"}
		write_json(output.path_join(relative_directory + "/manifest.json"), sequence)
		motion_sequences.append(sequence)
		print("PREMIUM_TREE_MOTION ", band, " frames=90 captures=30")
	write_json(output.path_join("motion_manifest.json"), {"sequences": motion_sequences,
		"source_manifest_sha256": FileAccess.get_sha256(asset_root.path_join("manifest.json")),
		"review_source_sha256": FileAccess.get_sha256(asset_root.path_join("review.gd"))})

func far_angle_review() -> void:
	var record := hero_record()
	var crown := crown_bounds(record)
	var center := Vector3(crown.x, crown.y, crown.z)
	var radius := crown.w + FAR_DISTANCE
	clear_display()
	add_tree(record, Vector3.ZERO, 2)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = maxf(12.0, rad_to_deg(2.0 * atan(float(record.impostor.ortho_scale) * .70 / radius)))
	for azimuth in [0.0, 22.5, 45.0, 67.5, 90.0]:
		var angle := deg_to_rad(azimuth)
		camera.position = center + Vector3(sin(angle), 0.0, cos(angle)) * radius
		camera.look_at(center)
		caption("FAR AZIMUTH  /  %.1f°  /  FORCED TIER 2" % azimuth,
			"Matched radius, fixed field of view and sun • baked view boundaries plus halfway blends • 64 m crown distance")
		await capture("far_azimuth_" + str(azimuth).replace(".", "p"), {"kind": "far_azimuth_stress", "id": record.id,
			"family": record.family, "lod": 2, "azimuth_degrees": azimuth, "elevation_degrees": 0.0,
			"crown_distance_m": FAR_DISTANCE, "atlas_blend_fraction": fmod(azimuth / 45.0, 1.0)})
	for elevation in [22.0, 45.0]:
		var angle := deg_to_rad(elevation)
		camera.position = center + Vector3(0.0, sin(angle), cos(angle)) * radius
		camera.look_at(center)
		caption("FAR ELEVATION STRESS  /  %.0f°  /  FORCED TIER 2" % elevation,
			"Same crown distance and fixed field of view • vertical card foreshortening exposed for review")
		await capture("far_elevation_" + str(int(elevation)), {"kind": "far_elevation_stress", "id": record.id,
			"family": record.family, "lod": 2, "azimuth_degrees": 0.0, "elevation_degrees": elevation,
			"crown_distance_m": FAR_DISTANCE, "axial_impostor_elevation_limitation": true})

func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check(false, "Write " + path)
		return
	file.store_string(JSON.stringify(value, "\t") + "\n")

func setup_stage() -> void:
	Engine.max_fps = 60
	root.size = VIEW_SIZE
	root.title = "Alpine Apex premium tree assets — isolated source review"
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.39, .51, .64)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.78, .86, 1.0)
	environment.ambient_light_energy = .60
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = environment
	stage.add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-37, -28, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, .93, .84)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 130
	stage.add_child(sun)
	floor_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8000, 8000)
	floor_mesh.mesh = plane
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(.69, .77, .84)
	snow.roughness = .92
	floor_mesh.material_override = snow
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.near = .05
	camera.far = 1000
	stage.add_child(camera)
	camera.make_current()
	hud = CanvasLayer.new()
	root.add_child(hud)
	heading = Label.new()
	heading.position = Vector2(38, 25)
	heading.add_theme_font_size_override("font_size", 30)
	subtitle = Label.new()
	subtitle.position = Vector2(40, 70)
	subtitle.add_theme_font_size_override("font_size", 19)
	footer = Label.new()
	footer.position = Vector2(40, VIEW_SIZE.y - 42)
	footer.add_theme_font_size_override("font_size", 15)
	for label: Label in [heading, subtitle, footer]:
		label.add_theme_color_override("font_color", Color(.96, .98, 1))
		label.add_theme_color_override("font_shadow_color", Color(0, .025, .04, .95))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
		hud.add_child(label)
	geometry_shader = Shader.new()
	geometry_shader.code = GEOMETRY_CODE
	normal_shader = Shader.new()
	normal_shader.code = BAKE_NORMAL_CODE
	color_shader = Shader.new()
	color_shader.code = BAKE_COLOR_CODE
	far_shader = Shader.new()
	far_shader.code = FileAccess.get_file_as_string(asset_root.path_join("far.gdshader"))
	clear_display()

func run() -> void:
	started_ms = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var arg := args[i]
		if arg.begins_with("--assets="): asset_root = arg.trim_prefix("--assets=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg == "--assets" and i + 1 < args.size(): asset_root = args[i + 1]
		elif arg == "--output" and i + 1 < args.size(): output = args[i + 1]
		elif arg == "--bake": bake = true
		elif arg == "--bake-only":
			bake_only = true
			bake = true
		elif arg == "--sample": sample = true
	if asset_root.is_empty() or output.is_empty():
		printerr("Requires --assets=absolute-pack --output=absolute-output [--bake] [--bake-only] [--sample]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(asset_root.path_join("manifest.json")))
	if not parsed is Dictionary or not parsed.has("assets"):
		printerr("Invalid or missing pack manifest")
		quit(2)
		return
	catalog = parsed
	records = catalog.assets.duplicate()
	if sample:
		records.clear()
		for family in ["spruce", "fir", "pine"]:
			for record: Dictionary in catalog.assets:
				if record.family == family:
					records.append(record)
					break
	check(not records.is_empty(), "Review records selected")
	if records.is_empty():
		quit(2)
		return
	setup_stage()
	for record: Dictionary in records:
		for lod in 3:
			var node := load_model(record, lod)
			node.free()
	if bake: await bake_atlases()
	if not bake_only:
		var families: Dictionary = {}
		for record: Dictionary in records:
			if not families.has(record.family): families[record.family] = []
			families[record.family].append(record)
		for family: String in families:
			await family_review(family, families[family])
		await close_review()
		if not sample:
			for kind: String in ["forest_depth", "far_slope", "high_elevation", "backlit"]: await stand_review(kind)
			await transition_review()
			await transition_motion_review()
			await far_angle_review()
	var manifest_hash := FileAccess.get_sha256(asset_root.path_join("manifest.json"))
	if not bake_only:
		write_json(output.path_join("capture_manifest.json"), {"source_manifest_sha256": manifest_hash, "captures": captures,
			"motion_sequences": motion_sequences, "motion_manifest_file": "motion_manifest.json" if not motion_sequences.is_empty() else "",
			"sample": sample, "near_distance_m": NEAR_DISTANCE, "far_distance_m": FAR_DISTANCE,
			"feather_half_width_m": FEATHER, "crown_distance": "distance to shared near-model bounds sphere surface",
			"scope": "isolated asset and shader prototype; production loading, batching, placement, physics and tier policy unchanged"})
	var report := {"checks": checks, "failures": failures, "capture_count": captures.size(), "baked_assets": baked.size(),
		"motion_sequence_count": motion_sequences.size(), "motion_frame_count": motion_sequences.size() * MOTION_FRAME_COUNT,
		"motion_capture_count": motion_sequences.size() * 30,
		"sample": sample, "bake_only": bake_only, "asset_count": records.size(), "source_manifest_sha256": manifest_hash,
		"review_source_sha256": FileAccess.get_sha256(asset_root.path_join("review.gd")),
		"far_shader_sha256": FileAccess.get_sha256(asset_root.path_join("far.gdshader")),
		"renderer": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info(),
		"elapsed_ms": Time.get_ticks_msec() - started_ms, "fps_cap": Engine.max_fps,
		"no_game_session": true, "no_personal_bests": true, "runtime_integrated": false,
		"rendered_acceptance": "atlases baked; visual review not run" if bake_only else "images emitted; human visual inspection still required",
		"performance_acceptance": false, "human_controller_acceptance": false,
		"known_limits": ["Far tier remains a vertical axial billboard and must be assessed in the high-elevation stress view.",
			"Source-asset preview uses individual instances, not production MultiMesh batching; elapsed time is not FPS evidence."]}
	write_json(output.path_join("native_validation.json"), report)
	if bake_only: write_json(output.path_join("native_bake_validation.json"), report)
	print("PREMIUM_TREE_NATIVE_RESULTS ", JSON.stringify(report))
	for template: Node3D in templates.values(): template.free()
	quit(0 if failures.is_empty() else 1)
