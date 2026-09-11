extends RefCounted
## Explicit test-only v2 baseline. Same v15 world, weather, camera and physics.
const Apron = preload("res://tests/fixtures/offmap_v2/alpine_backdrop.gd")
const Panorama = preload("res://tests/fixtures/offmap_v2/alpine_wilderness.gd")
var apron
var panorama
var source_world

func build(world, checkpoint: Callable = Callable()) -> void:
	source_world = world
	apron = Apron.new(); panorama = Panorama.new()
	world.add_child(apron); world.add_child(panorama)
	panorama.prepare(world.surface,world.mountain)
	await apron.build(world.surface,world.assets,world.mountain,panorama.data,checkpoint)
	panorama.apron_material = apron.material
	await panorama.apply_quality(world.quality,checkpoint)
	select(world,false)
	world.get_tree().process_frame.connect(update_weather)

func update_weather() -> void:
	if is_instance_valid(source_world) and source_world.last_weather_state:
		panorama.update_weather(source_world.last_weather_state)

func select(world, baseline: bool) -> void:
	apron.visible = baseline; panorama.visible = baseline
	world.backdrop.visible = not baseline; world.wilderness.visible = not baseline
	update_weather()

func dispose() -> void:
	if is_instance_valid(source_world): source_world.get_tree().process_frame.disconnect(update_weather)
	apron.queue_free(); panorama.queue_free()
