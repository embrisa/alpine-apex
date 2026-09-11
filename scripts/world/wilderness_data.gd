extends RefCounted
## Read-only authored background plus the small map-dependent apron connection.
const VERSION = 3
const OUTER_RADIUS_M = 18000.0
const SECTORS = 8
const EDGE_SEGMENTS = 1024
const COLLAR_M = 192.0
const DEFAULT_ASSET = "res://assets/graphics/scenery/alpine_valleys_01.res"
const GRID = 259
const Footprint = preload("res://scripts/world/mountain_footprint.gd")
var asset
var seed_value: int
var origin = Vector2(-4096,-4096)
var apron_center = Vector2.ZERO
var apron_half = 4096.0
var physical_bounds: Rect2
var valley_height: float
var snowline: float
var mountain
var height_cache: Dictionary = {}
var sample_cache: Dictionary = {}
var asset_read_ms = 0.0
func configure(source, field) -> void:
	mountain=source; physical_bounds=field.bounds(); clear_cache()
	var started=Time.get_ticks_usec()
	if not asset: asset=load(DEFAULT_ASSET)
	assert(asset!=null and asset.presentation_version==VERSION and asset.levels.size()==3,"Missing or incompatible authored background asset")
	assert(asset.metadata.get("footprint_revision")==Footprint.REVISION,"Rebake the background for the current mountain footprint")
	assert(physical_bounds==asset.metadata.bounds,"The background connector requires the standard mountain bounds")
	asset_read_ms=(Time.get_ticks_usec()-started)/1000.0
	seed_value=asset.metadata.seed
	valley_height=asset.metadata.valley_height; snowline=asset.metadata.snowline
func clear_cache() -> void:
	height_cache.clear(); sample_cache.clear()
func edge_point(index: int) -> Vector2:
	var i=posmod(index,EDGE_SEGMENTS); var t=float(i%256)*32.0
	match i/256:
		0: return origin+Vector2(t,0)
		1: return origin+Vector2(apron_half*2,t)
		2: return origin+Vector2(apron_half*2-t,apron_half*2)
		_: return origin+Vector2(0,apron_half*2-t)
func _grid(p: Vector2) -> Vector3:
	var g=((p-origin)/32.0+Vector2.ONE).clamp(Vector2.ZERO,Vector2.ONE*(GRID-1.001))
	return Vector3(int(g.y)*GRID+int(g.x),g.x-floorf(g.x),g.y-floorf(g.y))
func _sample(values, p: Vector2):
	var g=_grid(p); var i=int(g.x)
	return lerp(lerp(values[i],values[i+1],g.y),lerp(values[i+GRID],values[i+GRID+1],g.y),g.z)
func _delta(p: Vector2) -> float:
	var distance_m=Footprint.edge_distance(p)
	var weight=1.0-smoothstep(COLLAR_M,640.0,distance_m)
	if weight<=0.0: return 0.0
	return (mountain.sample_height(p)-float(_sample(asset.apron_reference,p)))*weight
func blend_at(p: Vector2) -> float:
	return _sample(asset.apron_blends,p)
func height_at(p: Vector2) -> float:
	if Footprint.edge_distance(p)<=COLLAR_M: return mountain.sample_height(p)
	var key=Vector2i((p*1000.0).round())
	if not height_cache.has(key): height_cache[key]=float(_sample(asset.apron_heights,p))+_delta(p)
	return height_cache[key]
func normal_at(p: Vector2) -> Vector3:
	var n: Vector3=_sample(asset.apron_normals,p)
	var gradient=Vector3(n.x/maxf(n.y,.001)*64.0,64.0,n.z/maxf(n.y,.001)*64.0)
	gradient.x+=_delta(p-Vector2(32,0))-_delta(p+Vector2(32,0))
	gradient.z+=_delta(p-Vector2(0,32))-_delta(p+Vector2(0,32))
	return gradient.normalized()
func sample_at(p: Vector2) -> Dictionary:
	var key=Vector2i((p*1000.0).round())
	if not sample_cache.has(key):
		sample_cache[key]={"height":height_at(p),"normal":normal_at(p),"mask":_sample(asset.apron_masks,p),"blend":blend_at(p)}
	return sample_cache[key]
