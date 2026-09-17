extends RefCounted
## Two reusable per-ski response samples. No Nodes, RNG or writes to physics.
const Condition = preload("res://scripts/presentation/snow_condition.gd")
# Bound applies only to the V15 analytic snow implementation below.
const TrackMountain = preload("res://scripts/world/generators/alpine_massif_v17.gd")
const TrackTreeSnow = preload("res://scripts/world/generators/tree_snow_v15.gd")
static var bounded_track_queries = true
static var audit_certificates = false
static var certified_queries = 0
const TerrainMaterial = preload("res://scripts/core/terrain_material.gd")
var supported = false
var slip = 0.0
var pressure = 0.0
var disturbance = 0.0
var powder = 0.0
var grains = 0.0
var mist = 0.0
var width_m = .22
var depth_m = 0.0
var ejection_m_s = 0.0
var throw_side = 0.0
var throw_world = Vector3.ZERO
var condition = 0
var crystal_density = 1.0
var snow_contact = false
var sparks = 0.0
var turn_work = 0.0
var contact_width_m = .30
var contact_position = Vector3.ZERO
var contact_forward = Vector3.BACK
# Track-only continuation never grants physical support, spray or sparks.
const TRACK_PHYSICAL_REACH_M = .12
const TRACK_VISUAL_REACH_M = .24
const TRACK_SEPARATION_SPEED_M_S = 1.0
const COSMETIC_DEPTH_M = .012
var track_contact = false
var cosmetic_track = false
var track_depth_m = 0.0
var track_clearance_m = INF
var track_reason = "unsupported"
var track_probe = ""
var track_rejection: Dictionary = {}

func sample(sim, ski, surface = null) -> void:
	track_contact = false
	cosmetic_track = false
	track_depth_m = 0.0
	track_clearance_m = INF
	track_reason = "unsupported"
	track_probe = ""
	track_rejection = {}
	contact_position = ski.position
	contact_forward = ski.forward
	turn_work = 0.0
	contact_width_m = .30
	supported = sim.grounded and not sim.crashed and ski.grounded and ski.load_n>1.0
	var speed: float = sim.velocity.length()
	var rock: bool = ski.material_kind==TerrainMaterial.Kind.ROCK
	snow_contact = supported and not rock
	track_contact = snow_contact
	track_reason = "supported" if snow_contact else ("rock" if rock else "unsupported")
	sparks = smoothstep(.5,8.0,speed)*clampf(ski.load_n/maxf(sim.tuning.rider_mass*9.81*.5,1.0),0.0,1.0) if supported and rock else 0.0
	if rock:
		powder = 0.0
		grains = 0.0
		mist = 0.0
		depth_m = 0.0
		pressure = 0.0
		disturbance = 0.0
		ejection_m_s = 0.0
		crystal_density = 0.0
		return
	slip = clampf(absf(sin(ski.slip_angle)),0.0,1.0)
	pressure = clampf(ski.load_n/maxf(sim.tuning.rider_mass*9.81*.5,1.0),0.0,3.5) if supported else 0.0
	condition = Condition.at(surface,ski.position,ski.snow_depth)
	var profile: Vector4 = Condition.PROFILES[condition]
	crystal_density = Condition.CRYSTALS[condition]
	var depth: float = clampf(ski.snow_depth,0.0,.35)
	var penetration: float = clampf(ski.penetration,0.0,depth)
	var edge: float = clampf(absf(sin(ski.edge_angle)),0.0,1.0)
	var load_response = 1.0-exp(-pressure)
	var lateral_m_s = speed*slip
	var skid_work = 1.0-exp(-lateral_m_s/7.0)
	var grip: float = clampf(ski.grip_n/maxf(ski.load_n,1.0),0.0,1.6)
	var carve_work = edge*grip*(1.0-exp(-speed/18.0))
	# Loaded clean carving displaces snow even when lateral slip stays tiny.
	turn_work = clampf(carve_work*load_response*1.65,0.0,1.0)
	var compression: float = ski.compression_m if "compression_m" in ski else 0.0
	var compression_work = clampf(compression/maxf(depth,.01),0.0,1.0)*load_response
	var crush_work = smoothstep(.01,.12,ski.crush_m)*smoothstep(.02,1.0,ski.crush_rate_m_s)*load_response if supported else 0.0
	# Saturating contact work: speed alone contributes only a tiny base cut.
	var contact_work = load_response*(skid_work*.95+carve_work*.85)+compression_work*.22
	disturbance = clampf(contact_work+crush_work*.85,0.0,1.0)
	var loose = sqrt(depth/.18)*profile.x
	var moving = smoothstep(.5,5.0,speed)*float(supported)
	# An embedded ski moves snow even in a clean, low-slip turn. Keep a small
	# visible trail tied to actual penetration instead of requiring a skid.
	var base_plough = .10*load_response*smoothstep(.025,.16,depth)*smoothstep(.005,.035,penetration)
	powder = clampf(moving*loose*(.018*load_response+base_plough+disturbance),0.0,1.0)
	grains = clampf(moving*profile.y*(.025*load_response+base_plough+disturbance*.85),0.0,1.0)
	mist = clampf(powder*profile.z*smoothstep(.10,.65,disturbance),0.0,1.0)
	# Swept ski footprint: sideways travel exposes ski length, not just width.
	contact_width_m = .30+turn_work*.20
	width_m = .28+slip*1.45*load_response+turn_work*.20
	depth_m = minf(depth,penetration*(.85+disturbance*.65+turn_work*.30)+edge*.020*load_response)*profile.w
	ejection_m_s = moving*(.7+9.5*sqrt(disturbance)*sqrt(clampf(depth/.16,.04,1.5)))
	# Snow follows lateral displacement (opposite the snow reaction on the ski).
	# In a clean carve, the loaded edge determines the side. Never bilateral jets.
	throw_side = signf(ski.slip_angle) if lateral_m_s>.35 else -signf(ski.edge_angle)
	if is_zero_approx(throw_side): throw_side = ski.side
	throw_world = ski.normal.cross(ski.forward).normalized()*throw_side
	track_depth_m = depth_m if snow_contact else 0.0

func resolve_track_contact(sim, ski, surface) -> void:
	# Call after substituting final rendered equipment position/orientation.
	# A supported ski already projects its mark onto the shared snow surface;
	# changing only its cosmetic elevation cannot revoke that support.
	if snow_contact or surface==null: return
	if not sim.contacts_initialized or not sim.grounded or sim.crashed:
		track_reason = "rider_inactive"
		return
	if ski.material_kind==TerrainMaterial.Kind.ROCK: return
	var confirmed_grounded: bool = ski.grounded
	if not confirmed_grounded:
		# An unsupported ski still needs the original conservative carving proof.
		# Root extension/normal velocity are departure guards only on this path.
		var other = sim.skis[1] if ski==sim.skis[0] else sim.skis[0]
		if not other.grounded or other.load_n<=1.0 or other.material_kind==TerrainMaterial.Kind.ROCK:
			track_reason = "no_other_support"
			return
		if sim.velocity.length()<2.0 or absf(other.edge_angle)<.08 or other.grip_n/maxf(other.load_n,1.0)<.05:
			track_reason = "not_carving"
			return
		if ski.clearance_m>TRACK_PHYSICAL_REACH_M or ski.normal_speed_ms>TRACK_SEPARATION_SPEED_M_S:
			track_reason = "physical_separation"
			return
	if not surface.has_method("snow_depth_at"):
		track_reason = "no_snow_depth"
		return
	if confirmed_grounded:
		# Completed support is independent of load sharing, edge and root/leg
		# extension. Certify the actual ski centre against its local loose layer.
		track_probe = "physical_center"
		if _track_snow_at(surface,ski.position,TRACK_PHYSICAL_REACH_M,.04)<=0.0: return
	# Distributed support normals and the rigid final pose can intersect snow
	# across a 4 m triangle change. A certified grounded centre permits the
	# existing 24 cm presentation envelope at the footprint (also below the
	# loose layer); it never bypasses local rock, void, depth or reach checks.
	# Unsupported fallback keeps its original 12 cm reach / 4 cm burial margin.
	var physical_reach = TRACK_VISUAL_REACH_M if confirmed_grounded else TRACK_PHYSICAL_REACH_M
	var burial_margin = TRACK_VISUAL_REACH_M if confirmed_grounded else .04
	track_probe = "physical_footprint"
	var physical_depth = _near_snow_depth(surface,ski.position,ski.forward,sim.tuning.ski_length,physical_reach,burial_margin)
	if physical_depth<=0.0: return
	track_probe = "rendered_footprint"
	var rendered_depth = _near_snow_depth(surface,contact_position,contact_forward,sim.tuning.ski_length,TRACK_VISUAL_REACH_M,burial_margin)
	if rendered_depth<=0.0: return
	var loose_depth = minf(physical_depth,rendered_depth)
	var track_condition = Condition.at(surface,contact_position,loose_depth)
	track_depth_m = minf(loose_depth,COSMETIC_DEPTH_M)*Condition.PROFILES[track_condition].w
	track_contact = track_depth_m>0.0
	cosmetic_track = track_contact
	track_reason = "grounded_snow" if confirmed_grounded else "near_surface_carve"
	# Small, neutral scratch: no full-load widening, lips or lateral throw.
	width_m = .28
	contact_width_m = .30
	throw_world = Vector3.ZERO
	crystal_density = Condition.CRYSTALS[track_condition]

func _near_snow_depth(surface, center: Vector3, forward: Vector3, ski_length: float, reach: float, burial_margin: float) -> float:
	var across = Vector3.UP.cross(forward).normalized()
	if not center.is_finite() or not forward.is_finite() or across.length_squared()<.5:
		return _reject_track("invalid_pose",center)
	var depth = .35
	for longitudinal in [-ski_length*.5,0.0,ski_length*.5+.12]:
		for lateral in [-.15,0.0,.15]:
			var point: Vector3 = center+forward*longitudinal+across*lateral
			var local_depth = _track_snow_at(surface,point,reach,burial_margin)
			if local_depth<=0.0: return 0.0
			depth = minf(depth,local_depth)
	return depth

func _track_snow_at(surface, point: Vector3, reach: float, burial_margin: float) -> float:
	if not point.is_finite(): return _reject_track("invalid_pose",point)
	# Heightfield sampling clamps outside its domain. Never turn that clamp into
	# a cosmetic bridge over the world edge, even with stale grounded evidence.
	if surface.has_method("bounds") and not surface.bounds().has_point(Vector2(point.x,point.z)):
		return _reject_track("footprint_void",point)
	if TerrainMaterial.at(surface,point.x,point.z)==TerrainMaterial.Kind.ROCK:
		return _reject_track("footprint_rock",point)
	var sample_value: Dictionary = surface.sample(point.x,point.z)
	var height: float = sample_value.get("height",NAN)
	var normal: Vector3 = sample_value.get("normal",Vector3.ZERO)
	# V15's clamped cover gives >=.19 m before the separately sampled tree term;
	# the alternative powder term is >=.24 m and its blend weight is in [0,1].
	# A 1 mm conservative allowance keeps this proof clear of roundoff. Only a
	# safely accepted deep-powder point can bypass the analytic regional query.
	# Every ambiguous/rejected point still reads its exact depth and diagnostics.
	if bounded_track_queries and surface.get_script()==TrackMountain and is_finite(height) and normal.is_finite() and normal.y>.05:
		var lower = minf(.35,.189+minf(.06,TrackTreeSnow.sample_delta(surface,surface.tree_snow_height,point.x,point.z)*.12))
		var certified_clearance = (point.y-height)*normal.y
		if is_finite(lower) and lower>.18 and certified_clearance<=reach and certified_clearance>=-lower-burial_margin:
			track_clearance_m = certified_clearance if not is_finite(track_clearance_m) else maxf(track_clearance_m,certified_clearance)
			if audit_certificates: certified_queries+=1
			# Both exact and bounded depths select DEEP_POWDER and exceed the
			# 12 mm cosmetic cut cap. These private probes serve only that cut.
			return lower
	var loose: float = surface.snow_depth_at(point.x,point.z)
	if not is_finite(height) or not normal.is_finite() or normal.y<=.05 or not is_finite(loose):
		return _reject_track("footprint_void",point)
	var local_depth = clampf(loose,0.0,.35)
	var clearance = (point.y-height)*normal.y
	track_clearance_m = clearance if not is_finite(track_clearance_m) else maxf(track_clearance_m,clearance)
	if local_depth<=0.0: return _reject_track("no_loose_snow",point,clearance,local_depth,reach,burial_margin)
	if clearance>reach: return _reject_track("footprint_reach",point,clearance,local_depth,reach,burial_margin)
	if clearance < -local_depth-burial_margin:
		return _reject_track("footprint_buried",point,clearance,local_depth,reach,burial_margin)
	return local_depth

func _reject_track(reason: String, point: Vector3, clearance: float = INF, loose_depth: float = 0.0, reach: float = 0.0, burial_margin: float = 0.0) -> float:
	track_reason = reason
	# Allocated only on rejection. Preserve the first rejecting point/pass; a
	# combined maximum cannot distinguish burial from physical/visual reach.
	track_rejection = {"probe":track_probe,"point":[point.x,point.y,point.z],"clearance_m":clearance,
		"loose_depth_m":loose_depth,"maximum_m":reach,"minimum_m":-loose_depth-burial_margin}
	return 0.0

func report() -> Dictionary:
	return {"supported":supported,"snow_contact":snow_contact,"track_contact":track_contact,"cosmetic_track":cosmetic_track,
		"track_depth_m":track_depth_m,"track_clearance_m":track_clearance_m,"track_reason":track_reason,"track_rejection":track_rejection,
		"sparks":sparks,"condition":condition,"slip":slip,"pressure_bodyweights":pressure,
		"disturbance":disturbance,"powder":powder,"grains":grains,"mist":mist,
		"width_m":width_m,"contact_width_m":contact_width_m,"turn_work":turn_work,"depth_m":depth_m,"ejection_m_s":ejection_m_s,"throw_side":throw_side}
