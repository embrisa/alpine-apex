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
const DISCOVERY_RADIUS_M=22.0
## Last full scan position and how far the rider can travel before any
## undiscovered site could enter the discovery radius (negative forces a scan).
var scan_origin: Vector3=Vector3.ZERO
var scan_clearance: float=-1.0

func build(field, assets, quality, terrain_material: Material) -> void:
	lighting=assets.lighting; profile=quality
	scan_clearance=-1.0
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
	# Triangle inequality: until the rider has moved the clearance measured at
	# the last full scan, no undiscovered site can be inside the radius, so the
	# result is exactly the original per-frame scan without touching placements.
	if scan_clearance>=0.0 and position.distance_squared_to(scan_origin)<scan_clearance*scan_clearance: return ""
	scan_origin=position
	var nearest: float=INF
	for placed in layout.placements:
		if discovered_sites.has(placed.site): continue
		var distance_squared: float=position.distance_squared_to(placed.position)
		if distance_squared<DISCOVERY_RADIUS_M*DISCOVERY_RADIUS_M:
			discovered_sites[placed.site]=true
			scan_clearance=-1.0 # A neighbouring site may announce next frame.
			return Layout.catalog()[placed.asset_id].label
		nearest=minf(nearest,sqrt(distance_squared))
	scan_clearance=nearest-DISCOVERY_RADIUS_M # INF once every site is discovered.
	return ""
