@tool
extends EditorPlugin
var exporter
func _enter_tree() -> void:
	exporter = preload("res://addons/generation_export/receipt.gd").new()
	add_export_plugin(exporter)
func _exit_tree() -> void:
	if exporter: remove_export_plugin(exporter)
