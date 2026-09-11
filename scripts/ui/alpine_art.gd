extends TextureRect
## Shared photographic art direction. Only the current photograph is retained.
const PHOTO_SHADER = preload("res://assets/images/alpine_photo.gdshader")
const LOGO_PATH = "res://assets/images/branding/alpine_apex_ice.svg"
const COMPACT_LOGO_PATH = "res://assets/images/branding/alpine_apex_compact.svg"
const ICE = Color("a5dced")
const WHITE = Color("edf4f8")
const MUTED = Color("aec1ce")
const PHOTOS = [
	{"file":"p8.jpg", "caption":"HOLD YOUR EDGE", "aspect":1.5, "focus":Vector2(0.5,0.42)},
	{"file":"p6.jpg", "caption":"CHASE THE POWDER", "aspect":4.0/3.0, "focus":Vector2(0.5,0.42)},
	{"file":"p1.jpg", "caption":"FIND YOUR FALL LINE", "aspect":1.5, "focus":Vector2(0.5,0.60)},
	{"file":"p5.jpg", "caption":"TAKE THE QUIET LINE", "aspect":2448.0/3265.0, "framed":true, "exposure":0.96},
	{"file":"p3.jpg", "caption":"MAKE ROOM TO FLY", "aspect":1.25, "framed":true, "exposure":0.97},
	{"file":"p9.jpg", "caption":"A MOMENT ABOVE IT ALL", "aspect":2023.0/3596.0, "framed":true},
	{"file":"p4.jpg", "caption":"LEAVE YOUR SIGNATURE", "aspect":0.8, "framed":true, "exposure":0.92},
	{"file":"p7.jpg", "caption":"THE MOUNTAIN IS CALLING", "aspect":2400.0/1602.0, "focus":Vector2(0.5,0.58), "saturation":0.46},
	{"file":"p2.jpg", "caption":"FOLLOW THE FEELING", "aspect":1080.0/1441.0, "framed":true, "saturation":0.46}
]
# Source-image coordinates keep the light attached to the moving photograph.
# Strength/rays are deliberately softer in shade; p4 keeps its monochrome light.
const LIGHTS = [
	{"position":Vector2(0.48,-0.06), "tint":Color("ffe2af"), "strength":0.72, "rays":0.65},
	{"position":Vector2(0.38,-0.08), "tint":Color("ffe6bc"), "strength":0.62, "rays":0.50},
	{"position":Vector2(0.96,-0.08), "tint":Color("ffe1ac"), "strength":0.76, "rays":0.65},
	{"position":Vector2(0.70,0.02), "tint":Color("f1f0e9"), "strength":0.17, "rays":0.0},
	{"position":Vector2(0.18,0.02), "tint":Color("ffe9c7"), "strength":0.34, "rays":0.18},
	{"position":Vector2(0.97,-0.04), "tint":Color("ffe3b6"), "strength":0.72, "rays":0.55},
	{"position":Vector2(0.78,-0.20), "tint":Color.WHITE, "strength":0.16, "rays":0.0},
	{"position":Vector2(0.42,-0.15), "tint":Color("ffebcc"), "strength":0.36, "rays":0.20},
	{"position":Vector2(0.20,-0.08), "tint":Color("ffe5bc"), "strength":0.48, "rays":0.30}
]
var photo_index: int = -1
var loading_mode: bool = false
var loading_reduced_motion: bool = false
var visual_time: float = 0.0
const DRIFT_SECONDS = 24.0
var photo_rng = RandomNumberGenerator.new()
var photo_bag: Array[int] = []
var fullscreen_pool: bool = false
var last_photo_index: int = -1

static func interface_font() -> SystemFont:
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Inter", "Avenir Next", "Segoe UI", "DejaVu Sans"])
	return font

func _init() -> void:
	photo_rng.randomize() # Private randomness never consumes skiing/generation RNG.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material = ShaderMaterial.new()
	material.shader = PHOTO_SHADER

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_resize_art)
	_resize_art()

func _resize_art() -> void:
	material.set_shader_parameter("viewport_aspect", size.x / maxf(size.y, 1.0))

func show_photo(index: int) -> void:
	index = posmod(index, PHOTOS.size())
	if photo_index == index and texture: return
	photo_index = index
	last_photo_index = index
	photo_bag.erase(index)
	var photo: Dictionary = PHOTOS[index]
	texture = load("res://assets/images/prepared/" + photo.file)
	material.set_shader_parameter("source_aspect",photo.aspect)
	material.set_shader_parameter("focal_point",photo.get("focus",Vector2(0.5,0.5)))
	material.set_shader_parameter("framed",photo.get("framed",false))
	material.set_shader_parameter("exposure",photo.get("exposure",1.0))
	material.set_shader_parameter("saturation",photo.get("saturation",0.60))
	var light: Dictionary = LIGHTS[index]
	material.set_shader_parameter("light_position",light.position)
	material.set_shader_parameter("light_tint",light.tint)
	material.set_shader_parameter("light_strength",light.strength)
	material.set_shader_parameter("ray_strength",light.rays)
	_resize_art()

func set_loading_mode(enabled: bool, motion_reduced: bool = false) -> void:
	set_atmosphere(enabled,motion_reduced)

func set_atmosphere(enabled: bool, motion_reduced: bool = false) -> void:
	loading_mode = enabled
	loading_reduced_motion = motion_reduced
	material.set_shader_parameter("loading_atmosphere",enabled)
	material.set_shader_parameter("animate_loading",enabled and not motion_reduced)
	material.set_shader_parameter("visual_time",0.0 if motion_reduced else visual_time)

func set_visual_time(seconds: float) -> void:
	visual_time = fposmod(maxf(seconds,0.0),DRIFT_SECONDS)
	material.set_shader_parameter("visual_time",0.0 if loading_reduced_motion else visual_time)

func advance_loading(delta: float) -> bool:
	return advance_animation(delta)

func advance_animation(delta: float) -> bool:
	if loading_mode and not loading_reduced_motion:
		var next_time = visual_time + clampf(delta,0.0,0.05)
		set_visual_time(next_time)
		return next_time >= DRIFT_SECONDS
	return false

func next_photo(fullscreen_only: bool = false) -> int:
	if fullscreen_pool != fullscreen_only:
		photo_bag.clear()
		fullscreen_pool = fullscreen_only
	if photo_bag.is_empty():
		for index in PHOTOS.size():
			if not fullscreen_only or not PHOTOS[index].get("framed",false): photo_bag.append(index)
	var choices = photo_bag.filter(func(index): return index != last_photo_index)
	if choices.is_empty(): choices = photo_bag.duplicate()
	var selected: int = choices[photo_rng.randi_range(0,choices.size()-1)]
	photo_bag.erase(selected)
	return selected

func release_photo() -> void:
	texture = null
	photo_index = -1
	set_visual_time(0.0)
	set_loading_mode(false)

static func logo(dimensions: Vector2, compact: bool = false) -> TextureRect:
	var rect = TextureRect.new()
	rect.name = "AlpineApexLogo"
	rect.texture = load(COMPACT_LOGO_PATH if compact else LOGO_PATH)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = dimensions
	rect.size = dimensions
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return rect
