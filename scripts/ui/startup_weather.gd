extends ColorRect
## One optional canvas pass. No world weather, particles, cameras or solver state.
const SHADER_PATH = "res://assets/images/branding/startup_snow.gdshader"
var motion_enabled: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.TRANSPARENT
	if ResourceLoader.exists(SHADER_PATH):
		var shader = load(SHADER_PATH) as Shader
		if shader:
			var effect = ShaderMaterial.new(); effect.shader = shader; material = effect
	resized.connect(_resize)
	_resize()

func _resize() -> void:
	if material: material.set_shader_parameter("aspect",size.x/maxf(1.0,size.y))

func update_visual(seconds: float, enabled: bool) -> void:
	motion_enabled = enabled
	visible = enabled and material!=null
	if visible: material.set_shader_parameter("seconds",seconds)
