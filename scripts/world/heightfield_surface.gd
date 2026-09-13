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
var material_image: Image

func nearby_obstacle_indices(center: Vector3, radius: float) -> Array:
	# The same frozen grid used by continuous skiing sweeps. Return unique,
	# sorted IDs so preparation order does not depend on overlapping grid cells.
	var found: Dictionary = {}
	for z in range(floori((center.z-radius)/SPATIAL_CELL),floori((center.z+radius)/SPATIAL_CELL)+1):
		for x in range(floori((center.x-radius)/SPATIAL_CELL),floori((center.x+radius)/SPATIAL_CELL)+1):
			for id in obstacle_grid.get(Vector2i(x,z),[]):
				var p: Vector3=obstacles[id].position
				if Vector2(center.x-p.x,center.z-p.z).length_squared()<=radius*radius: found[id]=true
	var ids=found.keys()
	ids.sort()
	return ids

func _rock_vertex(ix: int, iz: int) -> float:
	# Quantize before interpolation, exactly as the shared R8 render texture.
	var dx = heights[iz*NX+mini(ix+1,NX-1)]-heights[iz*NX+maxi(ix-1,0)]
	var dz = heights[mini(iz+1,NZ-1)*NX+ix]-heights[maxi(iz-1,0)*NX+ix]
	var up = 8.0/sqrt(dx*dx+dz*dz+64.0)
	var rock = 1.0-smoothstep(.66,.90,up)
	var field = self
	if "exposure_image" in field and field.exposure_image != null:
		var pixel = Vector2i(roundi((X_MIN+ix*CELL-field.MASK_ORIGIN.x)/CELL),roundi((Z_MIN+iz*CELL-field.MASK_ORIGIN.y)/CELL))
		if pixel.x>=0 and pixel.y>=0 and pixel.x<field.exposure_image.get_width() and pixel.y<field.exposure_image.get_height():
			var feature: Color = field.exposure_image.get_pixelv(pixel)
			rock = lerpf(rock,feature.r,feature.a)
	return roundf(clampf(rock,0,1)*255.0)/255.0

func build_material_map() -> void:
	if material_image != null: return
	var bytes = PackedByteArray()
	bytes.resize(NX*NZ)
	for z in NZ:
		for x in NX: bytes[z*NX+x] = roundi(_rock_vertex(x,z)*255.0)
	material_image = Image.create_from_data(NX,NZ,false,Image.FORMAT_R8,bytes)

func rock_fraction_at(x: float, z: float) -> float:
	if heights.size()!=NX*NZ: return 0.0 # Analytic test adapters have no baked grid.
	var p = ((Vector2(x,z)-Vector2(X_MIN,Z_MIN))/CELL).clamp(Vector2.ZERO,Vector2(NX-1.001,NZ-1.001))
	var ix = int(p.x)
	var iz = int(p.y)
	var a = material_image.get_pixel(ix,iz).r if material_image else _rock_vertex(ix,iz)
	var b = material_image.get_pixel(ix+1,iz).r if material_image else _rock_vertex(ix+1,iz)
	var c = material_image.get_pixel(ix,iz+1).r if material_image else _rock_vertex(ix,iz+1)
	var d = material_image.get_pixel(ix+1,iz+1).r if material_image else _rock_vertex(ix+1,iz+1)
	return lerpf(lerpf(a,b,p.x-ix),lerpf(c,d,p.x-ix),p.y-iz)

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

# Exact script identity opts into the baked triangle query. Derived adapters
# retain virtual sample dispatch, even when they also carry a populated grid.
var _height_query_script: Script

func _init() -> void:
	_height_query_script = load("res://scripts/world/heightfield_surface.gd")

func sample_height(x: float, z: float) -> float:
	if get_script() != _height_query_script: return sample(x,z).height
	var gx = clampf((x - X_MIN) / CELL, 0.0, NX - 1.001)
	var gz = clampf((z - Z_MIN) / CELL, 0.0, NZ - 1.001)
	var ix = int(gx)
	var iz = int(gz)
	var u = gx - ix
	var v = gz - iz
	var h00 = heights[iz * NX + ix]
	var h10 = heights[iz * NX + ix + 1]
	var h01 = heights[(iz + 1) * NX + ix]
	if u + v <= 1.0:
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	var h11 = heights[(iz + 1) * NX + ix + 1]
	return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)

func contact_normal(x: float, z: float) -> Vector3:
	# A four-metre support stencil filters the 4 m mesh's normal discontinuities.
	# This is a coarse-grid suspension approximation, not a rigid four-metre ski.
	# Height collision remains exact; this supplies distributed ski support.
	var dx: float = sample_height(x + 2.0,z) - sample_height(x - 2.0,z)
	var dz: float = sample_height(x,z + 2.0) - sample_height(x,z - 2.0)
	return Vector3(-dx,4.0,-dz).normalized()

func sweep_obstacle(from: Vector3, to: Vector3) -> String:
	return sweep_obstacle_contact(from,to).get("reason","")

func sweep_obstacle_contact(from: Vector3, to: Vector3) -> Dictionary:
	return sweep_filtered_obstacle_contact(from,to,true,true)

func sweep_filtered_obstacle_contact(from: Vector3, to: Vector3, trees: bool, rocks: bool) -> Dictionary:
	# Earliest intersection of the swept rider with each cylindrical envelope.
	# The vertical interval includes the rider's 1.6 m height. Geometry and
	# obstacle indexing remain the same; callers can now measure closing speed.
	if not ski_bounds().has_point(Vector2(to.x,to.z)):
		return {"reason":boundary_message,"boundary":true}
	var a = Vector2(from.x,from.z)
	var b = Vector2(to.x,to.z)
	var delta = b-a
	var length_squared = delta.length_squared()
	var dy = to.y-from.y
	var checked: Dictionary = {}
	var closest: Dictionary = {}
	var earliest = INF
	for gz in range(floori((minf(a.y,b.y)-.4)/SPATIAL_CELL),floori((maxf(a.y,b.y)+.4)/SPATIAL_CELL)+1):
		for gx in range(floori((minf(a.x,b.x)-.4)/SPATIAL_CELL),floori((maxf(a.x,b.x)+.4)/SPATIAL_CELL)+1):
			for idx in obstacle_grid.get(Vector2i(gx,gz),[]):
				if checked.has(idx): continue
				checked[idx] = true
				var ob = obstacles[idx]
				if (ob.tree and not trees) or (not ob.tree and not rocks): continue
				var center: Vector3 = ob.position
				var offset = a-Vector2(center.x,center.z)
				var radius: float = ob.radius+.35
				var c = offset.length_squared()-radius*radius
				var enter = 0.0
				var leave = 1.0
				if length_squared<.000001:
					if c>=0.0: continue
				else:
					var along = offset.dot(delta)
					var discriminant = along*along-length_squared*c
					if discriminant<=0.0: continue
					enter = maxf(0.0,(-along-sqrt(discriminant))/length_squared)
					leave = minf(1.0,(-along+sqrt(discriminant))/length_squared)
				var vertical_enter = 0.0
				var vertical_leave = 1.0
				if absf(dy)<.000001:
					if from.y>=center.y+ob.height or from.y+1.6<=center.y: continue
				else:
					var first: float = (center.y-1.6-from.y)/dy
					var second: float = (center.y+ob.height-from.y)/dy
					vertical_enter = maxf(0.0,minf(first,second))
					vertical_leave = minf(1.0,maxf(first,second))
				var fraction = maxf(enter,vertical_enter)
				if fraction>minf(leave,vertical_leave) or fraction>=earliest: continue
				var point = from.lerp(to,fraction)
				var normal = Vector3(point.x-center.x,0.0,point.z-center.z).normalized()
				if vertical_enter>enter: normal = Vector3.DOWN if dy>0 else Vector3.UP
				if normal.length_squared()<.5: normal = -(to-from).normalized() if from!=to else Vector3.RIGHT
				earliest = fraction
				closest = {"reason":"TREE IMPACT" if ob.tree else "ROCK IMPACT","id":idx,"fraction":fraction,"position":point,"normal":normal,"boundary":false}
	return closest

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
