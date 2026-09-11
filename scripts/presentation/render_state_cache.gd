extends RefCounted
## Exact value comparisons, scoped to a world/asset owner. No rate limiting.
var values: Dictionary = {}
var submitted = 0
var skipped = 0
func clear() -> void: values.clear()
func changed(receiver: Object, key: StringName, value: Variant) -> bool:
	if not values.has(receiver): values[receiver] = {}
	var previous: Dictionary = values[receiver]
	if previous.has(key) and previous[key]==value:
		skipped+=1
		return false
	previous[key] = value
	submitted+=1
	return true
func assign(receiver: Object, key: StringName, value: Variant) -> void:
	if changed(receiver,key,value): receiver.set(key,value)
func shader(receiver: ShaderMaterial, key: StringName, value: Variant) -> void:
	if changed(receiver,key,value): receiver.set_shader_parameter(key,value)
