extends "res://tests/massif_playtest.gd"
## Same physical pilot and settings; only decorative meshes/materials differ.
var baseline_fixture
func descent() -> void:
	if "--offmap-baseline" in OS.get_cmdline_user_args():
		baseline_fixture = preload("res://tests/offmap_fixture.gd").new()
		baseline_fixture.build(game.world)
		baseline_fixture.select(game.world,true)
		# Retire enhanced meshes before warmup. Record loading separately: this
		# test adapter constructs both versions, but only v1 remains in the descent.
		game.world.assets.surface_materials.erase(game.world.backdrop.material)
		game.world.cloud_lighting.materials.erase(game.world.backdrop.material)
		game.world.backdrop.queue_free(); game.world.wilderness.queue_free()
		game.world.backdrop = baseline_fixture.apron
		game.world.wilderness = baseline_fixture.panorama
		await process_frame
	await super.descent()
	if baseline_fixture: baseline_fixture.dispose()
