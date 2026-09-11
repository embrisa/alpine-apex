extends RefCounted
## Layout coordinates describe travel inside the safe area, independent of racing.
const Store = preload("res://scripts/ui/preference_store.gd")
const PATH = "user://hud_layout_v1.cfg"
var widgets: Dictionary = {}
var values: Dictionary = {}
var global_visible = true
var safe_area = .025
var timed = false
var menu_visible = true
var preview = false

func register(id: String, label: String, node: Control, dimensions: Vector2, position: Vector2, enabled: bool = true, race_only: bool = false) -> void:
	widgets[id] = {"label":label,"node":node,"size":dimensions,"race_only":race_only,"default":{"position":position,"scale":1.0,"opacity":1.0,"visible":enabled}}
	values[id] = widgets[id].default.duplicate(true)

func snapshot() -> Dictionary:
	return values.duplicate(true)

func restore(data: Dictionary) -> void:
	for id in widgets:
		values[id] = widgets[id].default.duplicate(true)
		var entry = data.get(id,{})
		if not entry is Dictionary: continue
		for key in ["scale","opacity"]:
			var value = entry.get(key,values[id][key])
			if (value is float or value is int) and is_finite(float(value)): values[id][key] = clampf(float(value),.5 if key=="scale" else 0.0,2.0 if key=="scale" else 1.0)
		if entry.get("visible") is bool: values[id].visible = entry.visible
		if entry.get("position") is Vector2 and entry.position.is_finite(): values[id].position = entry.position.clamp(Vector2.ZERO,Vector2.ONE)

func reset_widget(id: String) -> void:
	values[id] = widgets[id].default.duplicate(true)

func apply(size: Vector2) -> void:
	var margin = size*safe_area
	var available = (size-margin*2).max(Vector2.ONE)
	for id in widgets:
		var widget: Dictionary = widgets[id]
		var node: Control = widget.node
		var entry: Dictionary = values[id]
		var scale_value = minf(entry.scale,minf(available.x/widget.size.x,available.y/widget.size.y))
		node.scale = Vector2.ONE*scale_value
		node.size = widget.size
		node.position = margin+(available-widget.size*scale_value)*entry.position
		node.modulate.a = entry.opacity
		node.visible = entry.visible and (preview or global_visible and not menu_visible) and (timed or not widget.race_only) and (preview or not widget.has("transient") or widget.transient.visible)

func move_pixel(id: String, pixel: Vector2, size: Vector2, snap: bool) -> void:
	var widget: Dictionary = widgets[id]
	var margin = size*safe_area
	var travel = (size-margin*2-widget.size*widget.node.scale).max(Vector2.ONE)
	var target = pixel.snapped(Vector2(8,8)) if snap else pixel
	values[id].position = ((target-margin)/travel).clamp(Vector2.ZERO,Vector2.ONE)

func load_preferences(path: String = PATH) -> void:
	restore(Store.read_values(path,1))

func save_preferences(path: String = PATH) -> Error:
	return Store.write_values(path,1,snapshot())
