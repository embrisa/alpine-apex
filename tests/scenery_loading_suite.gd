extends SceneTree
## Compare yielded uploads with the same geometry built synchronously.
const Contacts = preload("res://scripts/presentation/asset_snow_contacts.gd")
const Surface = preload("res://scripts/world/heightfield_surface.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var checks = 0
var failures: Array = []
var checkpoints: Array = []
var staged

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func checkpoint(_message: String, _progress: float) -> void:
	checkpoints.append([staged.patches.size(),staged.chunks.size()])
	await process_frame

func run() -> void:
	var field = Surface.new()
	field.X_MIN=0; field.Z_MIN=-16; field.NX=265; field.NZ=9
	field.heights.resize(field.NX*field.NZ)
	var immediate = Contacts.new()
	staged = Contacts.new()
	root.add_child(immediate); root.add_child(staged)
	for i in 16:
		var anchor = Vector3(i*64+2,0,0)
		for target in [immediate,staged]: target.add_contact(field,anchor,Vector2.ONE,.3,.3)
	var material = StandardMaterial3D.new()
	immediate.finish(material,Quality.preset(0))
	await staged.finish(material,Quality.preset(0),checkpoint)
	check(checkpoints==[[8,8],[16,0]],"Yield every eight uploads after releasing their construction arrays")
	check(staged.contact_count==16 and staged.patches.size()==16,"Staged loading retains every contact patch")
	for i in 16:
		var a = immediate.patches[i]; var b = staged.patches[i]
		check(a.position==b.position and a.mesh.surface_get_arrays(0)==b.mesh.surface_get_arrays(0),"Staged patch %d preserves vertices, normals, indices and placement" % i)
	check(staged.chunks.is_empty(),"No temporary contact arrays remain after upload")
	immediate.queue_free(); staged.queue_free()
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://artifacts/geology_v11")
	FileAccess.open("res://artifacts/geology_v11/scenery_loading.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
