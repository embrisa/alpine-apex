extends "res://scripts/world/generators/alpine_face_v13.gd"
## V14 keeps v13 geology/ecology, using a separate stream for local snow shapes.
## Footprints are broad enough for the shared 4 m support triangles.
const SNOW_CELL = 128.0
var snow_forms: Array[Dictionary] = []
var snow_grid: Dictionary = {}
var cover_noise = FastNoiseLite.new()

func _init(massif, face_index: int, face_heading: float) -> void:
	super(massif,face_index,face_heading)
	# The new localized banks replace the old broad additive powder deposits.
	powder_deposits.clear()
	cover_noise.seed = seed_value+0x6A14
	cover_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cover_noise.frequency = .035
	cover_noise.fractal_octaves = 2
	var rng = RandomNumberGenerator.new(); rng.seed = seed_value+0x5140F7
	for i in 228:
		var kind = 0 if i<96 else (1 if i<196 else 2)
		var z = rng.randf_range(440,2500)
		var p = Vector2(rng.randf_range(-.49,.49)*z,z)
		var radius: Vector2; var amplitude: float
		if kind==0:
			radius = Vector2(rng.randf_range(28,54),rng.randf_range(40,75))
			amplitude = rng.randf_range(.10,.25)
		elif kind==1:
			radius = Vector2(rng.randf_range(12,24),rng.randf_range(12,24))
			amplitude = rng.randf_range(.20,.45)
		else:
			var bowl: Dictionary = bowls[i%bowls.size()]
			p = bowl.position+Vector2(rng.randf_range(-.78,.78)*bowl.radius.x,rng.randf_range(-.7,.8)*bowl.radius.y)
			radius = Vector2(rng.randf_range(20,50),rng.randf_range(20,50))
			amplitude = rng.randf_range(.30,.85)
		var form = {"kind":kind,"position":p,"radius":radius,"height":amplitude,"angle":wind_angle+rng.randf_range(-1.1,1.1),"phase":rng.randf_range(-PI,PI),"wavelength":rng.randf_range(32,64)}
		var id = snow_forms.size(); snow_forms.append(form)
		var extent: float = maxf(radius.x,radius.y)
		for iz in range(floori((p.y-extent)/SNOW_CELL),floori((p.y+extent)/SNOW_CELL)+1):
			for ix in range(floori((p.x-extent)/SNOW_CELL),floori((p.x+extent)/SNOW_CELL)+1):
				var key = Vector2i(ix,iz)
				if not snow_grid.has(key): snow_grid[key] = []
				snow_grid[key].append(id)

func snow_relief_at(x: float,z: float) -> float:
	# Continuous, non-repeating wind relief across the whole snowy face, also
	# between trees and outside the sparse landmark banks. These are real grid
	# heights, with 15-50 m features the support triangles can resolve gently.
	var wind = Vector2(x,z).rotated(wind_angle)
	var rolling = cover_noise.get_noise_2d(x,z)
	var waves = cover_noise.get_noise_2d(wind.x*.45+319,wind.y*1.6-217)
	var value = .12+rolling*.30+waves*.14
	for id in snow_grid.get(Vector2i(floori(x/SNOW_CELL),floori(z/SNOW_CELL)),[]):
		var form: Dictionary = snow_forms[id]
		var metres: Vector2 = (Vector2(x,z)-form.position).rotated(form.angle)
		var q: Vector2 = metres/form.radius
		if q.length_squared()>=1: continue
		# C2 compact envelope: zero height/slope/curvature at the patch edge.
		var envelope = pow(1.0-q.length_squared(),3)
		var shape: float = sin(metres.y*TAU/form.wavelength+form.phase) if form.kind==0 else 1.0
		value += form.height*envelope*shape
	return clampf(value,-.18,.85)

func snow_relief_weight(x: float,z: float) -> float:
	var n = render_normal(x,z)
	# Use input-grid geometry; never the output of this sculpt pass. Protect
	# shallow outlets, summit, exposed rock and existing drop approaches.
	return smoothstep(220,380,z)*(1-smoothstep(2530,2780,z))*smoothstep(.025,.12,Vector2(n.x,n.z).length())*smoothstep(.52,.73,n.y)*(1-smoothstep(.25,.50,exposure_at(x,z).r))*(1-protected_drop_weight(x,z))

func protected_drop_weight(x: float,z: float) -> float:
	var drop: Dictionary = landforms[4]
	var q = Vector2((x-drop.position.x)/45.0,(z-drop.position.y)/120.0)
	return 1-smoothstep(.65,1.0,q.length())
