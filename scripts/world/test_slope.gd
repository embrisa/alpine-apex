extends "res://scripts/world/heightfield_surface.gd"
## Generator v3 is a deliberately authored laboratory valley, not yet the
## mountain generator. Seed only varies small landforms and scenery.
const GENERATOR_VERSION = 3
const GENERATOR_ID = "laboratory"
func _init(mountain_seed: int = 849205174) -> void:
	seed_value = mountain_seed
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.009
	noise.fractal_octaves = 3
	heights.resize(NX * NZ)
	for z in range(NZ):
		for x in range(NX):
			var wx = X_MIN + x * CELL
			var wz = Z_MIN + z * CELL
			heights[z * NX + x] = _landform(wx, wz)
	_scatter()

func _landform(x: float, z: float) -> float:
	var channel = 14.0 * sin(z * 0.0027)
	var cross = absf(x - channel)
	var shoulder = pow(cross / 115.0, 1.6) * 26.0
	var roughness = lerpf(0.7, 23.0, smoothstep(35.0, 245.0, cross))
	var waves = sin(z * 0.009) * 4.0 + sin(z * 0.019 + x * 0.009) * 1.5
	var training_flat = smoothstep(85.0, 200.0, z)
	# Broad compression and convex transition, followed by an optional sharp
	# right-side lip. The fall-line corridor remains approachable at low speed.
	var roller = 8.0 * exp(-pow((z - 670.0) / 62.0, 2.0))
	var side_drop = 16.0 * exp(-pow((x - 88.0) / 36.0, 2.0)) * tanh((740.0 - z) / 14.0)
	# Integrate a smooth pitch transition: 10° apron, then a 25° race face.
	# Changing gravity would make every slope floaty; the terrain earns speed.
	var ramp_length = 260.0
	var u = clampf((z - 80.0) / ramp_length, 0.0, 1.0)
	var pitch_integral = ramp_length * (u * u * u - 0.5 * u * u * u * u) + maxf(0.0, z - 340.0)
	return 1370.0 - z * 0.18 - 0.28 * pitch_integral + shoulder + (waves + roller + side_drop + noise.get_noise_2d(x, z) * roughness) * training_flat + snow_relief_at(x,z)

func snow_relief_at(x: float, z: float) -> float:
	# Actual heightfield geometry, sampled identically by meshes and ski contact.
	# Wind-built ridges vary mainly across the slope: visible raised/depressed
	# snow without high-frequency down-course curvature launching racing skis.
	var warp = noise.get_noise_2d(x*1.7+513.0,z*0.65-927.0)
	var phase = x*0.29+z*0.035+sin(z*0.014)*0.65+warp*2.0
	var drift = sin(phase)*1.15
	var scallop = sin(x*0.47-z*0.058+warp*3.4)*0.18
	var mounds = noise.get_noise_2d(x*4.0-319.0,z*0.5+811.0)*0.70
	return (drift+scallop+mounds)*smoothstep(45.0,150.0,z)

func spawn_point() -> Vector3:
	return Vector3(0.0, sample(0.0, 25.0).height, 25.0)

func snow_depth_at(x: float, z: float) -> float:
	# A static, seeded loose layer in metres. Broad deposits avoid abrupt drag
	# changes; no weather, render history, or preferred racing line enters it.
	var deposit = clampf(0.5 + noise.get_noise_2d(x + 971.0,z - 327.0) * 0.8,0.0,1.0)
	return 0.035 + deposit * 0.14

func _scatter() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(1450):
		var x = rng.randf_range(-330.0, 330.0)
		var z = rng.randf_range(75.0, 1780.0)
		# A safe starting apron; progressively closer obstacles communicate pace.
		var corridor = lerpf(36.0, 15.0, smoothstep(120.0, 650.0, z))
		if absf(x) < corridor or (z < 450.0 and absf(x) > 240.0):
			continue
		var tree = rng.randf() > 0.14
		var scale_value = rng.randf_range(0.65, 1.65) if tree else rng.randf_range(0.8, 3.3)
		var radius = 0.46 * scale_value if tree else 1.35 * scale_value
		var obstacle = {"position": Vector3(x, sample(x, z).height, z), "radius": radius, "height": 11.0 * scale_value if tree else 2.0 * scale_value, "scale": scale_value, "yaw": rng.randf_range(-PI, PI), "tree": tree}
		var idx = obstacles.size()
		obstacles.append(obstacle)
		# Insert radius-expanded bounds; sweeping the rider queries crossed cells.
		for gz in range(floori((z - radius) / SPATIAL_CELL), floori((z + radius) / SPATIAL_CELL) + 1):
			for gx in range(floori((x - radius) / SPATIAL_CELL), floori((x + radius) / SPATIAL_CELL) + 1):
				var key = Vector2i(gx, gz)
				if not obstacle_grid.has(key):
					obstacle_grid[key] = []
				obstacle_grid[key].append(idx)

