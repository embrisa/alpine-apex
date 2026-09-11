extends SceneTree
## Frozen physical contracts, plus real-apron non-mutation by the new renderer.
const Definition = preload("res://scripts/world/mountain_definition.gd")
const Apron = preload("res://scripts/world/mountain_data.gd")
const Wilderness = preload("res://scripts/world/alpine_wilderness.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
const FROZEN = [
	["0ed82c22719010fd77995ed3a6f97933ceb631b1b5ee853b5976e3167a14f0a6","c57948415fda4626b30bc3c5e37ca1023bc717657b3b01137e3b419876e301f6"],
	["386b2b1dc89c6df713f057d916bb6081bd8c47943f7b6e6280e131372acf5c93","a8bc9fbc2ec8312c5a69bf7808e162eb7584c647adfb0c3e9452b9113dd8274f"],
	["a63348d8ceefaa1380d04fa6f13b0408a5df5d9e56bf068c7ac5168d559d0eb7","04b32758eaf3f0f43664bc68bea2fc6bd5785726b527749235fb41c88a84e890"],
	["5fae684348b894f276549e57c420b6318d5e508be169348df81431c13060b3c9","547e534a054990f7df0f6ea2f19417c0dca408077a2184b3f384b94dbfe09e3e"],
	["34dd0f8e5b203c07b6b92f5ca94d796abee4bf5bca44352e9e8f695b96f41174","f9fbcf0488d18eddf4790701c4a5e374176dd87e86db7a79cf4b1559fc1810d4"],
	["9acd576cc8bbff5abfe25c76fe32bc9f2629fb77d90aad057d1f2f56d19dc331","b7a4a6ad0d728fc57fe44903233426418ca097487afe3f8befad8a845b24b78f"],
	["9f303aab12a3a3bc97b115b4040013303b04f562c2bb5a2486214602b822b560","afeb8a384c013515344980dc3f913bc24bcfecffb18332ed7ce93f6ad199025a"],
	["ca584843caffef7d97c2eea63ba65ba787ae1745178acffcb59dda04be4b0c65","f65bd968d755e26038d6336bfe410ed142e0e15e773a0142836901edc01f2d8f"],
	["6baaeeba3608c2f47a280e5a86cb5350aed70f40c1a455cb3274e49d3904bc83","58001d00894141a649cb33816e51fb5838c514d6417cd659330d605dd4b49232"],
	["272e3210c85c78684fdd7a07194a0e196460c57620158b4d6263257ee48bccf2","06b79834016e70c68e99da47d526889332ec3f190024c07f06b86ede2b6cecdf"],
	["19470568b1506be5ab9d7fcad9f9f0da9188a02494d623c0ec304aca09a7c216","b9573162d25ddd8af535148ebea708b17d3d9074d40c51c77b3848549fc074a3"]
]
var checks = 0
var failures: Array[String] = []
var fingerprints: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)

func run() -> void:
	for version in range(1,12):
		var field = Definition.generate(849205174,version)
		if version<=FROZEN.size():
			check(field.height_checksum==FROZEN[version-1][0] and field.obstacle_checksum==FROZEN[version-1][1],"V%d frozen terrain and obstacle fingerprints" % version)
		fingerprints.append({"version":version,"height_sha256":field.height_checksum,"obstacle_sha256":field.obstacle_checksum})
		if field.is_summit_mountain():
			var heights = field.heights.duplicate()
			var obstacles = field.obstacles.duplicate(true)
			var apron = Apron.new()
			apron.generate(field,field.seed_value+4187)
			var apron_bytes = apron.height_image.get_data()
			var wilderness = Wilderness.new()
			root.add_child(wilderness)
			wilderness.build(field,apron,Quality.preset(0))
			check(field.heights==heights and field.obstacles==obstacles and apron.height_image.get_data()==apron_bytes,"V%d backdrop leaves physical arrays and the actual apron unchanged" % version)
			wilderness.queue_free()
			await process_frame
	var report = {"checks":checks,"failures":failures,"fingerprints":fingerprints}
	DirAccess.make_dir_recursive_absolute("res://artifacts/wilderness")
	FileAccess.open("res://artifacts/wilderness/fingerprints.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WILDERNESS_FINGERPRINT_RESULTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
