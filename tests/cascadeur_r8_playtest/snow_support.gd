extends RefCounted
## Trial-only pressure-dependent support within the existing loose-snow layer.
## The solver advances this once per tick; every height/normal query is pure.
const TerrainMaterial=preload("res://scripts/core/terrain_material.gd")
const Bank=preload("res://scripts/core/snow_crush_contact.gd")
const MAX_SINK_M=.12
const SINK_RATE_M_S=.30
const RELEASE_RATE_M_S=.22
var max_sink_m=MAX_SINK_M
var penetration_scale=1.0
var bank=Bank.new()
var ski_ref:WeakRef
var tick_dt=1.0/120.0
var trial_enabled=true
var pressure_m=0.0
var pressure_rate_m_s=0.0
var effective_pressure_m=0.0
var effective_vertical_m=0.0
var effective_rate_m_s=0.0
var amount_m:float:
	get:return bank.amount_m+effective_pressure_m
var vertical_m:float:
	get:return bank.vertical_m+effective_vertical_m
var rate_m_s:float:
	get:return bank.rate_m_s+maxf(effective_rate_m_s,0.0)
var yielding:bool:
	get:return bank.yielding
var enabled:bool:
	get:return bank.enabled or pressure_m>0.0
var initialized:bool:
	get:return bank.initialized or pressure_m>0.0
var origin:Vector3:
	get:return bank.origin
var normal:Vector3:
	get:return bank.normal

func _init(ski) -> void:
	ski_ref=weakref(ski)

func reset() -> void:
	bank.reset();pressure_m=0.0;pressure_rate_m_s=0.0
	effective_pressure_m=0.0;effective_vertical_m=0.0;effective_rate_m_s=0.0

func capacity(surface,x:float,z:float) -> float:
	if not surface.has_method("snow_depth_at") or TerrainMaterial.at(surface,x,z)==TerrainMaterial.Kind.ROCK:return 0.0
	var depth:float=maxf(0.0,surface.snow_depth_at(x,z))
	return minf(max_sink_m,depth)*smoothstep(.025,.12,depth)

func begin_tick(surface,point:Vector3,speed:Vector3,supported:bool,tuning) -> void:
	bank.begin_tick(surface,point,speed,supported,tuning)
	if not supported:
		pressure_m=0.0;pressure_rate_m_s=0.0;return
	var allowed=capacity(surface,point.x,point.z)
	if allowed<=0.0:
		pressure_m=0.0;pressure_rate_m_s=0.0;return
	var ski=ski_ref.get_ref()
	# Reuse completed load-dependent penetration (including speed planing).
	# No input-steer target, joint pose, or future normal force drives this layer.
	var goal=minf(allowed,maxf(0.0,ski.penetration)*penetration_scale) if trial_enabled else 0.0
	var old=pressure_m
	pressure_m=move_toward(pressure_m,goal,tick_dt*(SINK_RATE_M_S if goal>pressure_m else RELEASE_RATE_M_S))
	pressure_m=minf(pressure_m,allowed)
	pressure_rate_m_s=(pressure_m-old)/maxf(tick_dt,.0001)

func sample(surface,x:float,z:float) -> Dictionary:
	var result:Dictionary=bank.sample(surface,x,z)
	if pressure_m<=0.0:return result
	# Bank crushing and pressure sinking spend the SAME available snow depth.
	var available=maxf(0.0,capacity(surface,x,z)-float(result.crush_m))
	var sink=minf(pressure_m,available)
	var vertical=sink/maxf(result.normal.y,.05)
	result.height-=vertical
	result.crush_m+=sink;result.crush_vertical_m+=vertical
	return result

func height_at(surface,x:float,z:float) -> float:
	if pressure_m<=0.0:return bank.height_at(surface,x,z)
	return sample(surface,x,z).height

func contact_normal_at(surface,x:float,z:float) -> Vector3:
	return bank.contact_normal_at(surface,x,z)

func complete_tick(surface,point:Vector3,dt:float,supported:bool) -> void:
	bank.complete_tick(surface,point,dt,supported)
	if not supported:
		reset();return
	var result=sample(surface,point.x,point.z)
	var old=effective_pressure_m
	effective_pressure_m=maxf(0.0,result.crush_m-bank.amount_m)
	effective_vertical_m=maxf(0.0,result.crush_vertical_m-bank.vertical_m)
	effective_rate_m_s=(effective_pressure_m-old)/maxf(dt,.0001)
