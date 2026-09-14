extends RefCounted
const DIRECTORY = "res://assets/images/startup/"
const MANIFEST = DIRECTORY+"manifest.json"

static func catalog() -> Array:
	if not FileAccess.file_exists(MANIFEST): return []
	var value = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return value.get("photos",[]) if value is Dictionary else []

static func choose(entries: Array, rng: RandomNumberGenerator) -> int:
	var available: Array[int] = []
	for i in entries.size():
		if ResourceLoader.exists(DIRECTORY+str(entries[i].get("file",""))): available.append(i)
	return available[rng.randi_range(0,available.size()-1)] if not available.is_empty() else -1

static func background(texture: Texture2D, focus: Vector2) -> TextureRect:
	var rect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader_path = "res://assets/images/branding/startup_atmosphere.gdshader"
	if ResourceLoader.exists(shader_path):
		var shader = load(shader_path) as Shader
		if shader:
			var material = ShaderMaterial.new(); material.shader = shader
			material.set_shader_parameter("use_photo",true)
			material.set_shader_parameter("source_aspect",float(texture.get_width())/texture.get_height())
			material.set_shader_parameter("focal_point",focus)
			rect.material = material; rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.resized.connect(func(): material.set_shader_parameter("viewport_aspect",rect.size.x/maxf(1.0,rect.size.y)))
	else: rect.modulate = Color(.55,.62,.70)
	return rect
