extends RefCounted
## Capture provenance is separate from the physical mountain identity.
static func sources() -> Dictionary:
	var result: Dictionary={}
	for relative in [
		"assets/graphics/mineral_world.gdshader",
		"assets/graphics/mineral_grass.gdshader",
		"assets/graphics/alpine_surface_fragment.gdshaderinc",
		"assets/graphics/alpine_surface_uniforms.gdshaderinc",
		"assets/cloud_light.gdshaderinc",
		"scripts/presentation/mineral_scenery.gd",
		"scripts/presentation/alpine_assets.gd",
		"scripts/presentation/asset_snow_contacts.gd",
		"scripts/presentation/graphics_quality.gd",
		"scripts/presentation/chase_camera.gd",
		"scripts/world/alpine_scenery.gd",
		"scripts/world/alpine_world.gd",
		"scripts/world/wilderness_data.gd",
		"scripts/world/alpine_backdrop.gd",
		"scripts/world/alpine_wilderness.gd",
		"assets/graphics/alpine_apron.gdshader",
		"assets/graphics/alpine_wilderness.gdshader",
		"assets/graphics/offmap_surface.gdshaderinc",
	]:
		result[relative]=FileAccess.get_sha256("res://"+relative)
	return result
