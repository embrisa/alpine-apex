extends RefCounted
## Two reusable per-ski response samples. No Nodes, RNG or writes to physics.
const Condition = preload("res://scripts/presentation/snow_condition.gd")
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

func sample(sim, ski, surface = null) -> void:
	contact_position = ski.position
	contact_forward = ski.forward
	turn_work = 0.0
	contact_width_m = .30
	supported = sim.grounded and not sim.crashed and ski.grounded and ski.load_n>1.0
	var speed: float = sim.velocity.length()
	var rock: bool = ski.material_kind==TerrainMaterial.Kind.ROCK
	snow_contact = supported and not rock
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

func report() -> Dictionary:
	return {"supported":supported,"snow_contact":snow_contact,"sparks":sparks,"condition":condition,"slip":slip,"pressure_bodyweights":pressure,
		"disturbance":disturbance,"powder":powder,"grains":grains,"mist":mist,
		"width_m":width_m,"contact_width_m":contact_width_m,"turn_work":turn_work,"depth_m":depth_m,"ejection_m_s":ejection_m_s,"throw_side":throw_side}
