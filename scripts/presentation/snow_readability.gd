extends RefCounted
## Static presentation data over the final support grid. Never edits the field,
## consumes randomness, or participates in the mountain bake/replay identity.
var image: Image
var texture: ImageTexture
var origin: Vector2
var cell_m: float
var preparation_ms: float = 0.0
var upload_ms: float = 0.0
var builds: int = 0

func prepare(field, job = null) -> void:
	var start = Time.get_ticks_usec()
	origin = Vector2(field.X_MIN,field.Z_MIN)
	cell_m = field.CELL
	image = build_image(field.heights,field.NX,field.NZ,cell_m,job.worker_count if job else 0,job)
	builds += 1
	preparation_ms = (Time.get_ticks_usec()-start)/1000.0

static func build_image(heights: PackedFloat32Array, nx: int, nz: int, spacing_m: float = 4.0, workers: int = 0, context = null) -> Image:
	assert(nx>1 and nz>1 and heights.size()==nx*nz and spacing_m>0.0)
	# The loading worker owns these bounded, immutable row jobs. Each has its own
	# output; fixed row-order joining keeps identical pixels at every worker count.
	var count: int = clampi(workers,1,mini(6,nz)) if workers>0 else (mini(4,maxi(1,OS.get_processor_count()-2)) if nx*nz>65536 else 1)
	var jobs: Array = []
	for worker: int in count:
		var work = _rows.bind(heights,nx,nz,spacing_m,floori(float(nz*worker)/count),floori(float(nz*(worker+1))/count),context)
		var thread = Thread.new()
		if count==1 or thread.start(work)!=OK: jobs.append(work.call())
		else: jobs.append(thread)
	var bytes = PackedByteArray()
	for job in jobs: bytes.append_array(job.wait_to_finish() if job is Thread else job)
	if context and context.is_cancelled(): return null
	var result = Image.create_from_data(nx,nz,false,Image.FORMAT_R8,bytes)
	result.generate_mipmaps()
	return result

static func _rows(heights: PackedFloat32Array, nx: int, nz: int, spacing_m: float, first: int, last: int, context = null) -> PackedByteArray:
	var bytes = PackedByteArray()
	bytes.resize((last-first)*nx)
	# Fixed four-neighbour stencils at 4/12 m on the authoritative 4 m grid.
	# Subtract the centre BEFORE summing: opposite slopes cancel, including at
	# high mountain elevations. Missing boundary pairs contribute no curvature.
	for z: int in range(first,last):
		if context and context.is_cancelled(): return bytes
		var row: int = z*nx
		for x: int in nx:
			var i: int = row+x
			var h: float = heights[i]
			var near_curve: float = 0.0
			var broad_curve: float = 0.0
			if x>0 and x<nx-1: near_curve += (heights[i-1]-h)+(heights[i+1]-h)
			if z>0 and z<nz-1: near_curve += (heights[i-nx]-h)+(heights[i+nx]-h)
			if x>=3 and x<nx-3: broad_curve += (heights[i-3]-h)+(heights[i+3]-h)
			if z>=3 and z<nz-3: broad_curve += (heights[i-3*nx]-h)+(heights[i+3*nx]-h)
			# Dimensionless local hollow depth/radius. The dead zone excludes
			# float32 height quantization; broad slopes never become painted bands.
			var near_weight: float = smoothstep(.002,.040,near_curve/(4.0*spacing_m))
			var broad_weight: float = smoothstep(.002,.040,broad_curve/(12.0*spacing_m))
			bytes[(z-first)*nx+x] = roundi(255.0*(near_weight+broad_weight)*.5)
	return bytes

func bind(material: ShaderMaterial) -> void:
	assert(image!=null)
	if texture==null:
		var start = Time.get_ticks_usec()
		texture = ImageTexture.create_from_image(image)
		upload_ms = (Time.get_ticks_usec()-start)/1000.0
	material.set_shader_parameter("snow_hollows",texture)
	material.set_shader_parameter("snow_hollows_origin",origin)
	material.set_shader_parameter("snow_hollows_size",Vector2(image.get_size()))
	material.set_shader_parameter("snow_hollows_cell_m",cell_m)
	material.set_shader_parameter("snow_hollows_enabled",true)

func report() -> Dictionary:
	return {"builds":builds,"preparation_ms":preparation_ms,"upload_ms":upload_ms,
		"texture_bytes":image.get_data().size() if image else 0,
		"size":[image.get_width(),image.get_height()] if image else [0,0]}
