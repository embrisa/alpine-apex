extends SceneTree
## Lightweight launch: the editor without loading or baking a mountain.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps = 120
	var workshop = preload("res://scripts/workshop/motion_workshop.gd").new()
	workshop.standalone = true
	root.title = "Alpine Apex · Animation Workshop"
	root.size = Vector2i(1440,900)
	root.add_child(workshop)
	workshop.closed.connect(func(): quit())
