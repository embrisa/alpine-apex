extends SceneTree
## Native atlas/mapping transaction checks. All readback stays in this fixture.
const Powder = preload("res://scripts/presentation/powder_surface.gd")
const Field = preload("res://scripts/world/heightfield_surface.gd")
var powder
var failures: Array[String] = []
var checks = 0
var received = false
var result: Dictionary = {}
var output = "res://artifacts/local_snow_boundary/checks"

class SnowField extends "res://scripts/world/heightfield_surface.gd":
	func snow_depth_at(x: float,z: float) -> float: return .21+.02*sin(x*.2+z*.1)
	func render_normal(x: float,z: float) -> Vector3:
		var ix = clampi(roundi((x-X_MIN)/4),0,NX-1)
		var iz = clampi(roundi((z-Z_MIN)/4),0,NZ-1)
		return Vector3(heights[iz*NX+maxi(ix-1,0)]-heights[iz*NX+mini(ix+1,NX-1)],8,
			heights[maxi(iz-1,0)*NX+ix]-heights[mini(iz+1,NZ-1)*NX+ix]).normalized()

class WorldData extends RefCounted:
	var surface

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var field = SnowField.new()
	field.X_MIN = -32; field.Z_MIN = -32; field.NX = 17; field.NZ = 17
	field.heights.resize(field.NX*field.NZ)
	for z in field.NZ:
		for x in field.NX: field.heights[z*field.NX+x] = sin(x*.71)*.7+cos(z*.53)*1.1
	powder = Powder.new(); root.add_child(powder)
	powder.world = WorldData.new(); powder.world.surface = field
	var enclosed = true
	var continuous = true
	for step in 801:
		var p = Vector2(-4.0+step*.01,-2.0+step*.01)
		var center = Powder.storage_center(p)
		enclosed = enclosed and (p-center).abs().x+Powder.COVER_RADIUS_M<16.0 and (p-center).abs().y+Powder.COVER_RADIUS_M<16.0
		continuous = continuous and absf(Powder.influence(Vector2(12,0),p)-Powder.influence(Vector2(12,0),p+Vector2.ONE*.0001))<.0001
	check(enclosed,"Round ownership stays inside mesh/atlas at all threshold/corner crossings")
	check(continuous,"Visual relief influence remains continuous through storage thresholds")
	check(Powder.influence(Vector2(7.9,0),Vector2.ZERO)==1.0 and Powder.influence(Vector2(13,0),Vector2.ZERO)==0.0,"Nearby relief retained and zero-relief collar present")
	var first_support = powder._support_bytes(Vector2.ZERO)
	var shifted_support = powder._support_bytes(Vector2(4,4))
	var support_exact = true
	for z in range(1,9):
		for x in range(1,9):
			support_exact = support_exact and first_support.slice((z*9+x)*16,(z*9+x+1)*16)==shifted_support.slice(((z-1)*9+x-1)*16,((z-1)*9+x)*16)
	check(support_exact,"Support normals and loose depth are byte-identical at fixed world knots after diagonal recenter")
	if DisplayServer.get_name()=="headless":
		finish("CPU mapping only; native atlas checks NOT RUN")
		return
	Engine.max_fps = 120
	powder.patch = MeshInstance3D.new(); powder.patch.mesh = PlaneMesh.new(); powder.add_child(powder.patch)
	var receiver = ShaderMaterial.new()
	receiver.shader = Shader.new()
	receiver.shader.code = "shader_type spatial; uniform bool powder_patch_enabled=false; uniform vec2 powder_center; uniform vec2 powder_visual_center;"
	powder.patch.material_override = receiver
	RenderingServer.call_on_render_thread(powder._render_setup)
	var deadline = Time.get_ticks_msec()+10000
	while not powder.available and Time.get_ticks_msec()<deadline: await process_frame
	if not powder.available:
		check(false,"Native RenderingDevice initialized"); finish("native"); return
	# Diagonal, crossing and boundary-near strokes plus an unsupported zero slot.
	var data = PackedFloat32Array([-10,-10,10,10,.48,.09,.3,1,-10,7,10,7,.60,.1,.7,-1,0,-10,0,10,.30,.06,.1,1,0,0,0,0,0,0,0,0])
	var updates = [{"offset":0,"bytes":data.to_byte_array()}]
	var reference: Image
	var centers = [Vector2.ZERO,Vector2(4,0),Vector2(0,4),Vector2(4,4),Vector2(-4,-4),Vector2.ZERO]
	for center in centers:
		var visual: Vector2 = center+Vector2(1.999,-1.999)
		var support = powder._support_bytes(center)
		var snapshot = await present_and_read(updates,support,center,visual,receiver)
		if snapshot.is_empty(): break
		var map = Image.create_from_data(256,256,false,Image.FORMAT_RGH,snapshot.atlas)
		check(snapshot.support==support,"GPU support bytes match the committed center "+str(center))
		check(snapshot.center==center and snapshot.visual==visual and snapshot.enabled,"GPU material mapping and enabled mask publish with atlas "+str(center))
		if reference==null: reference = map
		else:
			var exact = true
			# Fixed-world 16 m square has >=4 m filter margin in every atlas.
			for y in range(64,192):
				for x in range(64,192):
					exact = exact and map.get_pixel(x-int(center.x*8),y-int(center.y*8))==reference.get_pixel(x,y)
			check(exact,"World-fixed cuts/lips remain byte-exact through X/Z/diagonal/reversal "+str(center))
	# Disable then teleport/rebuild/re-enable through the same publication path.
	var disable_materials: Array[RID] = [receiver.get_rid()]
	RenderingServer.call_on_render_thread(powder._render_visibility.bind(powder.patch.get_instance(),disable_materials,false))
	var relocated = await present_and_read(updates,powder._support_bytes(Vector2(16,16)),Vector2(16,16),Vector2(16,16),receiver)
	check(not relocated.is_empty() and relocated.center==Vector2(16,16),"Reset/teleport reopens only the newly reconstructed mapping")
	# Receiver membership may change without either centre moving. New ghost
	# histories must receive the current mapping in that very transaction.
	var ghost_receiver = ShaderMaterial.new(); ghost_receiver.shader = receiver.shader
	var same = await present_and_read(updates,PackedByteArray(),Vector2(16,16),Vector2(16,16),receiver,[ghost_receiver])
	check(same.receivers[1].center==Vector2(16,16) and same.receivers[1].visual==Vector2(16,16) and same.receivers[1].enabled,"New ghost receiver gets complete unchanged mapping")
	RenderingServer.call_on_render_thread(powder._render_visibility.bind(powder.patch.get_instance(),disable_materials,false))
	var reopened = await present_and_read(updates,PackedByteArray(),Vector2(16,16),Vector2(16,16),receiver)
	check(reopened.enabled,"Unchanged mapping reopens after disabling and receiver removal")
	var moved_visual = await present_and_read(updates,PackedByteArray(),Vector2(16,16),Vector2(17,16),receiver)
	check(moved_visual.center==Vector2(16,16) and moved_visual.visual==Vector2(17,16) and moved_visual.atlas==reopened.atlas,"Visual centre moves independently without changing retained relief")
	var fresh_strokes = PackedFloat32Array([12,12,20,20,.48,.12,.3,1,12,19,20,19,.60,.1,.7,-1,16,12,16,20,.30,.06,.1,1,0,0,0,0,0,0,0,0])
	var fresh = await present_and_read([{"offset":0,"bytes":fresh_strokes.to_byte_array()}],PackedByteArray(),Vector2(16,16),Vector2(17,16),receiver)
	check(fresh.atlas!=moved_visual.atlas and fresh.enabled,"Fresh strokes reconstruct even when both centres and enabled state are unchanged")
	finish("native transaction and byte-exact atlas continuity; shader visuals require playtest")

func present_and_read(updates: Array, support: PackedByteArray, center: Vector2, visual: Vector2, receiver: ShaderMaterial, extras: Array = []) -> Dictionary:
	received = false
	var materials: Array[RID] = [receiver.get_rid()]
	for extra in extras: materials.append(extra.get_rid())
	RenderingServer.call_on_render_thread(read_render.bind(updates,support,center,visual,materials))
	var deadline = Time.get_ticks_msec()+10000
	while not received and Time.get_ticks_msec()<deadline: await process_frame
	if not received: check(false,"Readback completed within 10 seconds"); return {}
	return result

func read_render(updates: Array, support: PackedByteArray, center: Vector2, visual: Vector2, materials: Array[RID]) -> void:
	var receiver = materials[0]
	powder._render_present(updates,support,center,visual,0,4,true,powder.patch.get_instance(),materials)
	var snapshot = {"atlas":powder.rd.texture_get_data(powder.surface_rid,0),"support":powder.rd.texture_get_data(powder.support_rid,0),
		"center":RenderingServer.material_get_param(receiver,&"powder_center"),"visual":RenderingServer.material_get_param(receiver,&"powder_visual_center"),
		"enabled":RenderingServer.material_get_param(receiver,&"powder_patch_enabled")}
	snapshot.receivers = []
	for item in materials:
		snapshot.receivers.append({"center":RenderingServer.material_get_param(item,&"powder_center"),"visual":RenderingServer.material_get_param(item,&"powder_visual_center"),"enabled":RenderingServer.material_get_param(item,&"powder_patch_enabled")})
	call_deferred("receive",snapshot)

func receive(snapshot: Dictionary) -> void:
	result = snapshot; received = true

func finish(scope: String) -> void:
	preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify({"checks":checks,"failures":failures,"scope":scope},"\t"))
	print("LOCAL_SNOW_BOUNDARY_CHECKS ",checks," failures=",failures," scope=",scope)
	powder.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
