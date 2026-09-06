extends RefCounted
## Node-independent 4 m triangle surface shared by the lab and generated mountains.
const CELL = 4.0
var X_MIN: float = -384.0
var Z_MIN: float = -192.0
var NX: int = 193
var NZ: int = 513
const SPATIAL_CELL = 48.0
var seed_value: int = 849205174
var heights: PackedFloat32Array
var obstacles: Array = []
var obstacle_grid: Dictionary = {}
var noise = FastNoiseLite.new()

var finish_z: float = 1740.0

func bounds() -> Rect2:
	return Rect2(X_MIN,Z_MIN,(NX-1)*CELL,(NZ-1)*CELL)

func ski_bounds() -> Rect2:
	return Rect2(X_MIN+9,Z_MIN+22,(NX-1)*CELL-18,(NZ-1)*CELL-58)

var boundary_message: String = "OUT OF TEST AREA"

func vertex(ix: int, iz: int) -> Vector3:
	return Vector3(X_MIN + ix * CELL, heights[iz * NX + ix], Z_MIN + iz * CELL)

func sample(x: float, z: float) -> Dictionary:
	var gx = clampf((x - X_MIN) / CELL, 0.0, NX - 1.001)
	var gz = clampf((z - Z_MIN) / CELL, 0.0, NZ - 1.001)
	var ix = int(gx)
	var iz = int(gz)
	var u = gx - ix
	var v = gz - iz
	var h00 = heights[iz * NX + ix]
	var h10 = heights[iz * NX + ix + 1]
	var h01 = heights[(iz + 1) * NX + ix]
	var h11 = heights[(iz + 1) * NX + ix + 1]
	var h: float
	var dx: float
	var dz: float
	# Exact barycentric height on the same diagonal as the rendered triangles.
	if u + v <= 1.0:
		dx = (h10 - h00) / CELL
		dz = (h01 - h00) / CELL
		h = h00 + u * (h10 - h00) + v * (h01 - h00)
	else:
		dx = (h11 - h01) / CELL
		dz = (h11 - h10) / CELL
		h = h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)
	return {"height": h, "normal": Vector3(-dx, 1.0, -dz).normalized()}

func contact_normal(x: float, z: float) -> Vector3:
	# A four-metre support stencil filters the 4 m mesh's normal discontinuities.
	# This is a coarse-grid suspension approximation, not a rigid four-metre ski.
	# Height collision remains exact; this supplies distributed ski support.
	var dx: float = sample(x + 2.0,z).height - sample(x - 2.0,z).height
	var dz: float = sample(x,z + 2.0).height - sample(x,z - 2.0).height
	return Vector3(-dx,4.0,-dz).normalized()

func sweep_obstacle(from: Vector3, to: Vector3) -> String:
	if not ski_bounds().has_point(Vector2(to.x,to.z)):
		return boundary_message
	var a = Vector2(from.x, from.z)
	var b = Vector2(to.x, to.z)
	var delta = b - a
	var denom = maxf(delta.length_squared(), 0.000001)
	var checked: Dictionary = {}
	for gz in range(floori((minf(a.y, b.y) - 0.4) / SPATIAL_CELL), floori((maxf(a.y, b.y) + 0.4) / SPATIAL_CELL) + 1):
		for gx in range(floori((minf(a.x, b.x) - 0.4) / SPATIAL_CELL), floori((maxf(a.x, b.x) + 0.4) / SPATIAL_CELL) + 1):
			for idx in obstacle_grid.get(Vector2i(gx, gz), []):
				if checked.has(idx):
					continue
				checked[idx] = true
				var ob = obstacles[idx]
				var p: Vector3 = ob.position
				var t = clampf((Vector2(p.x, p.z) - a).dot(delta) / denom, 0.0, 1.0)
				var nearest = a + delta * t
				if nearest.distance_squared_to(Vector2(p.x, p.z)) < pow(ob.radius + 0.35, 2.0):
					var h = lerpf(from.y, to.y, t)
					if h < p.y + ob.height and h + 1.6 > p.y:
						return "TREE IMPACT" if ob.tree else "ROCK IMPACT"
	return ""

func add_obstacle(obstacle: Dictionary) -> void:
	var idx = obstacles.size()
	obstacles.append(obstacle)
	var p: Vector3 = obstacle.position
	var radius: float = obstacle.radius
	for gz in range(floori((p.z-radius)/SPATIAL_CELL),floori((p.z+radius)/SPATIAL_CELL)+1):
		for gx in range(floori((p.x-radius)/SPATIAL_CELL),floori((p.x+radius)/SPATIAL_CELL)+1):
			var key = Vector2i(gx,gz)
			if not obstacle_grid.has(key): obstacle_grid[key] = []
			obstacle_grid[key].append(idx)

func spawn_heading() -> float:
	return 0.0

func is_summit_mountain() -> bool: return false

func reached_base(position: Vector3) -> bool:
	return position.z>=finish_z

func descent_progress(position: Vector3) -> float:
	return clampf((position.z-25)/(finish_z-25)*100,0,100)
