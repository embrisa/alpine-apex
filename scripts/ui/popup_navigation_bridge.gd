extends Node
## Native/embedded dialogs own a Viewport, so receive their input within it.
var navigation: WeakRef
func _input(event: InputEvent) -> void:
	var router = navigation.get_ref() if navigation else null
	if router and router.route(event): get_viewport().set_input_as_handled()
