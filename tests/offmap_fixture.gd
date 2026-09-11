extends RefCounted
## Frozen v1 renderer for complete apron+panorama comparisons on current physics.
const Apron = preload("res://tests/fixtures/offmap_v1/alpine_backdrop.gd")
const Panorama = preload("res://tests/fixtures/offmap_v1/alpine_wilderness.gd")
var apron
var panorama
var source_world

func build(world) -> void:
	source_world = world
	apron = Apron.new(); panorama = Panorama.new()
	world.add_child(apron); world.add_child(panorama)
	apron.build(world.surface,world.assets,world.mountain)
	panorama.build(world.surface,world.mountain,world.quality)
	if world.last_weather_state: panorama.update_weather(world.last_weather_state)
	world.get_tree().process_frame.connect(update_weather)

func update_weather() -> void:
	if is_instance_valid(source_world) and source_world.last_weather_state:
		panorama.update_weather(source_world.last_weather_state)

func select(world, baseline: bool) -> void:
	apron.visible = baseline; panorama.visible = baseline
	world.backdrop.visible = not baseline; world.wilderness.visible = not baseline
	if world.last_weather_state: panorama.update_weather(world.last_weather_state)

func dispose() -> void:
	if is_instance_valid(source_world): source_world.get_tree().process_frame.disconnect(update_weather)
	apron.queue_free(); panorama.queue_free()
