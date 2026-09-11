extends Node3D
## Sparse scenery, shared with normal skiing and Jolt. Quality changes only LOD.
const Layout=preload("res://scripts/world/flavor_layout.gd")
const Props=preload("res://scripts/world/prop_collision_surface.gd")
var layout=Layout.new()
var surface
var props: Array=[]
var lighting
var profile
var contact_snow
var discovered_sites: Dictionary={}

func build(field, assets, quality, terrain_material: Material) -> void:
	lighting=assets.lighting; profile=quality
	surface=Props.new(field)
	layout=Layout.for_field(field)
	contact_snow=preload("res://scripts/presentation/asset_snow_contacts.gd").new()
	add_child(contact_snow)
	for placed in layout.placements:
		var prop=load("res://assets/graphics/flavor_v1/scenes/"+placed.asset_id+".tscn").instantiate()
		prop.position=placed.position; prop.rotation.y=placed.yaw
		prop.lighting=lighting; add_child(prop)
		prop.add_foundations(placed.foundations)
		prop.bind_surface(surface); prop.apply_quality(profile.level); props.append(prop)
		var size: Array=prop.record.dimensions_m
		contact_snow.add_contact(field,placed.position,Vector2(size[0],size[2])*.5,placed.yaw,field.snow_depth_at(placed.position.x,placed.position.z))
	# Match the terrain's exposure mask too, so drifts have no pale circular rim.
	if not props.is_empty(): contact_snow.finish(terrain_material,profile)

func apply_quality(quality) -> void:
	profile=quality
	for prop in props: prop.apply_quality(quality.level)
	if contact_snow: contact_snow.apply_quality(quality)

func discover_near(position: Vector3) -> String:
	for placed in layout.placements:
		if discovered_sites.has(placed.site): continue
		if position.distance_squared_to(placed.position)<22.*22.:
			discovered_sites[placed.site]=true
			return Layout.catalog()[placed.asset_id].label
	return ""
