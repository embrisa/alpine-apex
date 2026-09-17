extends RefCounted
## Owns only the selected optional atlas. No terrain queries, ray marching or baking.
const Asset = preload("res://scripts/world/wilderness_horizon_asset.gd")
const DIRECTORY = "res://assets/graphics/scenery/horizons/"
var payload
var texture: Texture2DArray
var quality = 0
var tier = -1
var load_ms = 0.0
var sun_direction = Vector3.UP
var bins = Vector4.ZERO
var blend = 0.0
var elevation = PI/2.0

func select(requested_quality: int, geometry_tier: int, source) -> void:
	requested_quality=clampi(requested_quality,0,2)
	if quality==requested_quality and tier==geometry_tier: return
	quality=requested_quality; tier=geometry_tier; payload=null; texture=null; load_ms=0.0
	if quality==0 or tier<0: return
	var started=Time.get_ticks_usec()
	var path=DIRECTORY+"%s_t%d_q%d.res" % [source.asset_id,tier,quality]
	if ResourceLoader.exists(path): payload=load(path)
	if not payload is Asset or not payload.valid_for(source,tier,quality):
		payload=null
		push_error("Missing or incompatible distant mountain horizons; explicitly rebake "+path)
	else:
		texture=Texture2DArray.new()
		if texture.create_from_images(payload.layers)!=OK:
			payload=null; texture=null
			push_error("Could not upload distant mountain horizons: "+path)
	load_ms=(Time.get_ticks_usec()-started)/1000.0
	set_light(sun_direction)

func set_light(direction: Vector3) -> void:
	sun_direction=direction
	if not payload: return # Off keeps the latest direction without trigonometry.
	# World lighting uses opposite sun/moon hemispheres; ambient remains untouched.
	var active=direction.normalized() if direction.is_finite() and direction.length_squared()>.001 else Vector3.UP
	if active.y<0: active=-active
	var count: int=payload.directions if payload else 32
	var bearing=fposmod(atan2(active.x,active.z),TAU)*count/TAU
	var a=int(floor(bearing)); var b=(a+1)%count
	bins=Vector4(a/4,a%4,b/4,b%4)
	blend=fposmod(bearing,1.0); elevation=asin(clampf(active.y,0.0,1.0))

func bind(material: ShaderMaterial) -> void:
	material.set_shader_parameter("offmap_horizon_enabled",payload!=null)
	material.set_shader_parameter("offmap_horizon",texture)
	material.set_shader_parameter("offmap_horizon_bins",bins)
	material.set_shader_parameter("offmap_horizon_blend",blend)
	material.set_shader_parameter("offmap_light_elevation",elevation)

func report() -> Dictionary:
	return {"quality":quality,"geometry_tier":tier,"resident":payload!=null,"payload_bytes":payload.payload_bytes() if payload else 0,"load_ms":load_ms,"path":payload.resource_path if payload else ""}
