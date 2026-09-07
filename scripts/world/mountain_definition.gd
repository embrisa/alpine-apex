extends RefCounted
## Compact, data-only recipe. Unsupported versions fail instead of silently
## changing a saved mountain. Name is metadata, never part of terrain identity.
const Terrain = preload("res://scripts/world/generated_mountain.gd")
const LegacyTerrain = preload("res://scripts/world/generators/drainage_v1.gd")
const TerrainV2 = preload("res://scripts/world/generators/drainage_v2.gd")
const TerrainV3 = preload("res://scripts/world/generators/drainage_v3.gd")
const ShowcaseV5 = preload("res://scripts/world/generators/technical_showcase_v5.gd")
const ShowcaseV6 = preload("res://scripts/world/generators/technical_showcase_v6.gd")
const Showcase = preload("res://scripts/world/generators/technical_showcase_v7.gd")
const Scenery = preload("res://scripts/world/mountain_data.gd")
const SCHEMA = 1
const MAX_BYTES = 4096
const MAX_SEED = 2147483647
var title: String = "Untitled mountain"
var generator_version: int = Terrain.GENERATOR_VERSION
var seed_value: int = 849205174
var height_checksum: String = ""
var obstacle_checksum: String = ""

static func from_field(field, mountain_name: String = ""):
	var result = load("res://scripts/world/mountain_definition.gd").new()
	result.seed_value = field.seed_value
	result.generator_version = field.GENERATOR_VERSION
	result.title = mountain_name.strip_edges() if not mountain_name.strip_edges().is_empty() else "Mountain %d" % field.seed_value
	result.height_checksum = field.height_checksum
	result.obstacle_checksum = field.obstacle_checksum
	return result

static func parse_seed(value: String) -> Dictionary:
	var parts = value.strip_edges().trim_prefix("Mountain Seed:").strip_edges().split(" / v")
	var trimmed = parts[0].strip_edges()
	if not trimmed.is_valid_int() or trimmed.length()>10 or int(trimmed)<0 or int(trimmed)>MAX_SEED:
		return {"error":"Enter a whole seed from 0 to 2147483647."}
	var version = Terrain.GENERATOR_VERSION
	if parts.size()>1:
		if parts.size()!=2 or not parts[1] in ["1","2","3","4","5","6","7"]:
			return {"error":"That mountain seed uses an unsupported generator version."}
		version = int(parts[1])
	if version in [5,6,7] and int(trimmed)!=Showcase.SHOWCASE_SEED:
		return {"error":"Technical Showcase supports only seed 849205174."}
	return {"seed":int(trimmed),"version":version,"error":""}

static func generate(seed_number: int, version: int = Terrain.GENERATOR_VERSION):
	match version:
		1: return LegacyTerrain.new(seed_number)
		2: return TerrainV2.new(seed_number)
		3: return TerrainV3.new(seed_number)
		4: return Terrain.new(seed_number)
		5:
			if seed_number==Showcase.SHOWCASE_SEED: return ShowcaseV5.new(seed_number)
		6:
			if seed_number==Showcase.SHOWCASE_SEED: return ShowcaseV6.new(seed_number)
		7:
			if seed_number==Showcase.SHOWCASE_SEED: return Showcase.new(seed_number)
	return null

func seed_text() -> String:
	return "Mountain Seed: %d / v%d" % [seed_value,generator_version]

func to_reference() -> Dictionary:
	return {"generator":Terrain.GENERATOR_ID,"version":generator_version,
		"seed":seed_value,"scenery_seed":seed_value,"scenery_version":Scenery.GENERATOR_VERSION,
		"engine":Engine.get_version_info().string,"height_sha256":height_checksum,"obstacle_sha256":obstacle_checksum}

func identity() -> String:
	return JSON.stringify(to_reference(),"",true,true).sha256_text()

func share_text() -> String:
	return JSON.stringify({"format":"alpine-apex-mountain","schema":SCHEMA,"name":title,"mountain":to_reference()},"\t",true,true)

static func name_error(value: String) -> String:
	if value.strip_edges().is_empty() or value.length()>60: return "Name your mountain using 1–60 characters."
	for i in value.length():
		if value.unicode_at(i)<32 or value.unicode_at(i)==127: return "Mountain names cannot contain control characters."
	return ""

static func reference_error(value: Variant) -> String:
	if not value is Dictionary or value.size()!=8: return "The mountain reference is incomplete."
	for key in ["generator","version","seed","scenery_seed","scenery_version","engine","height_sha256","obstacle_sha256"]:
		if not value.has(key): return "The mountain reference is incomplete."
	if value.generator!=Terrain.GENERATOR_ID or (not (value.version is int or value.version is float) or (value.version!=1 and value.version!=2 and value.version!=3 and value.version!=4 and value.version!=5 and value.version!=6 and value.version!=7)) or value.scenery_version!=Scenery.GENERATOR_VERSION or value.engine!=Engine.get_version_info().string:
		return "This mountain requires a different generator or Godot version."
	for key in ["seed","scenery_seed"]:
		var seed = value[key]
		if not (seed is int or seed is float) or not is_finite(float(seed)) or seed!=floor(float(seed)) or seed<0 or seed>MAX_SEED:
			return "Mountain seeds must be whole numbers from 0 to 2147483647."
	if value.version in [5,6,7] and value.seed!=Showcase.SHOWCASE_SEED:
		return "Technical Showcase supports only seed 849205174."
	if value.seed!=value.scenery_seed: return "This mountain's scenery seed does not match."
	for key in ["height_sha256","obstacle_sha256"]:
		if not value[key] is String or value[key].length()!=64: return "Missing or invalid mountain checksum."
		for i in 64:
			if not value[key].substr(i,1) in "0123456789abcdef": return "Invalid mountain checksum."
	return ""

static func decode(text_value: String) -> Dictionary:
	if text_value.to_utf8_buffer().size()>MAX_BYTES: return {"error":"Mountain files must be smaller than 4 KB."}
	var data = JSON.parse_string(text_value)
	if not data is Dictionary or data.size()!=4 or data.get("format")!="alpine-apex-mountain" or data.get("schema")!=SCHEMA or not data.get("name") is String:
		return {"error":"Choose a complete Alpine Apex .apexmountain file."}
	var error = name_error(data.name)
	if error.is_empty(): error = reference_error(data.get("mountain"))
	if not error.is_empty(): return {"error":error}
	var result = load("res://scripts/world/mountain_definition.gd").new()
	result.title = data.name.strip_edges()
	result.seed_value = int(data.mountain.seed)
	result.generator_version = int(data.mountain.version)
	result.height_checksum = data.mountain.height_sha256
	result.obstacle_checksum = data.mountain.obstacle_sha256
	return {"mountain":result,"error":""}

func reconstruct() -> Dictionary:
	var field = generate(seed_value,generator_version)
	if field==null: return {"error":"Unsupported mountain generator version."}
	if field.height_checksum!=height_checksum or field.obstacle_checksum!=obstacle_checksum:
		return {"error":"Reconstructed terrain differs from this file. The mountain was not loaded."}
	return {"field":field,"error":""}
