extends GridContainer
## Related settings use two columns only when controls retain a comfortable width.
func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation",32)
	add_theme_constant_override("v_separation",22)
	resized.connect(_fit)
	_fit()
func _fit() -> void:
	columns = 2 if size.x>=1050 else 1
