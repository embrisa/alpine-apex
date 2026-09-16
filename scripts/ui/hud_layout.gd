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
## State the last apply() laid out; per-frame callers skip identical states.
var applied_state: Array = []
var transient_nodes: Array = []

func register(id: String, label: String, node: Control, dimensions: Vector2, position: Vector2, enabled: bool = true, race_only: bool = false) -> void:
	widgets[id] = {"label":label,"node":node,"size":dimensions,"race_only":race_only,"default":{"position":position,"scale":1.0,"opacity":1.0,"visible":enabled}}
	values[id] = widgets[id].default.duplicate(true)

func snapshot() -> Dictionary:
	return values.duplicate(true)

func restore(data: Dictionary) -> void:
	applied_state = []
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
	applied_state = []
	values[id] = widgets[id].default.duplicate(true)

func instruments_visible() -> bool:
	return preview or (global_visible and not menu_visible)

func layout_state(size: Vector2) -> Array:
	transient_nodes.clear()
	var state: Array = [size,safe_area,timed,menu_visible,global_visible,preview]
	for id in widgets:
		var widget: Dictionary = widgets[id]
		if widget.has("transient"):
			transient_nodes.append(widget.transient)
			state.append(widget.transient.visible)
	return state

## Riding frames call this; widgets only move on resize, preference, menu,
## race-mode or transient-label changes, so identical states keep the retained
## transforms and skip every setter. Field-wise comparison allocates nothing.
func apply_if_changed(size: Vector2) -> void:
	if applied_state.size()==6+transient_nodes.size() and applied_state[0]==size and applied_state[1]==safe_area and applied_state[2]==timed and applied_state[3]==menu_visible and applied_state[4]==global_visible and applied_state[5]==preview:
		var same = true
		for i in transient_nodes.size():
			if applied_state[6+i]!=transient_nodes[i].visible: same = false
		if same: return
	apply(size)

func apply(size: Vector2) -> void:
	applied_state = layout_state(size)
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
	applied_state = []
	var widget: Dictionary = widgets[id]
	var margin = size*safe_area
	var travel = (size-margin*2-widget.size*widget.node.scale).max(Vector2.ONE)
	var target = pixel.snapped(Vector2(8,8)) if snap else pixel
	values[id].position = ((target-margin)/travel).clamp(Vector2.ZERO,Vector2.ONE)

func load_preferences(path: String = PATH) -> void:
	restore(Store.read_values(path,1))

func save_preferences(path: String = PATH) -> Error:
	return Store.write_values(path,1,snapshot())
