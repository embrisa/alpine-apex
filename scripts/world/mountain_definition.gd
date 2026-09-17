extends RefCounted
## Compact, data-only recipe. Unsupported versions fail instead of silently
## changing a saved mountain. Name is metadata, never part of terrain identity.
const CurrentTerrain = preload("res://scripts/world/generators/alpine_massif_v17.gd")
const CURRENT_VERSION = 18
const DEFAULT_SEED = CurrentTerrain.DEFAULT_SEED
const Cache = preload("res://scripts/world/mountain_cache_v17.gd")
const Settings = preload("res://scripts/world/generation_settings.gd")
const Scenery = preload("res://scripts/world/mountain_data.gd")
const SCHEMA = 2
const MAX_BYTES = 4096
const MAX_SEED = 2147483647
var title: String = "Untitled mountain"
var generator_version: int = CURRENT_VERSION
var seed_value: int = 849205174
var height_checksum: String = ""
var obstacle_checksum: String = ""
var generation_settings: Dictionary = Settings.preset()

static func from_field(field, mountain_name: String = ""):
	var result = load("res://scripts/world/mountain_definition.gd").new()
	result.seed_value = field.seed_value
	result.generator_version = field.GENERATOR_VERSION
	result.title = mountain_name.strip_edges() if not mountain_name.strip_edges().is_empty() else "Mountain %d" % field.seed_value
	result.height_checksum = field.height_checksum
	result.obstacle_checksum = field.obstacle_checksum
	if "generation_settings" in field: result.generation_settings = field.generation_settings.duplicate()
	return result

static func parse_seed(value: String) -> Dictionary:
	var parts = value.strip_edges().trim_prefix("Mountain Seed:").strip_edges().split(" / v")
	var trimmed = parts[0].strip_edges()
	if not trimmed.is_valid_int() or trimmed.length()>10 or int(trimmed)<0 or int(trimmed)>MAX_SEED:
		return {"error":"Enter a whole seed from 0 to 2147483647."}
	var version = CURRENT_VERSION
	if parts.size()>1:
		if parts.size()!=2 or parts[1]!=str(CURRENT_VERSION): return {"error":"That mountain seed uses an unsupported generator version."}
	return {"seed":int(trimmed),"version":version,"error":""}

static func generate(seed_number: int, version: int = CURRENT_VERSION, settings: Dictionary = {}, job = null):
	if not preload("res://scripts/diagnostics/test_world_policy.gd").require_full("Mountain generation/restoration"): return null
	if seed_number<0 or seed_number>MAX_SEED: return null
	if version==CURRENT_VERSION: return Cache.generate(seed_number,settings,job)
	# Explicit comparison fixtures are loaded only when requested.
	if version==14 and settings.is_empty() and job==null: return load("res://scripts/world/mountain_cache_v14.gd").generate(seed_number)
	if version==13 and settings.is_empty() and job==null: return load("res://scripts/world/mountain_cache_v13.gd").generate(seed_number)
	return null

func seed_text() -> String:
	return "Mountain Seed: %d / v%d" % [seed_value,generator_version]

func to_reference() -> Dictionary:
	return {"generator":CurrentTerrain.GENERATOR_ID,"version":generator_version,
		"seed":seed_value,"scenery_seed":seed_value,"scenery_version":Scenery.GENERATOR_VERSION,
		"settings":generation_settings.duplicate(),"engine":Engine.get_version_info().string,"height_sha256":height_checksum,"obstacle_sha256":obstacle_checksum}

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
	if not value is Dictionary or value.size()!=9: return "The mountain reference is incomplete."
	for key in ["generator","version","seed","scenery_seed","scenery_version","engine","height_sha256","obstacle_sha256","settings"]:
		if not value.has(key): return "The mountain reference is incomplete."
	if value.generator!=CurrentTerrain.GENERATOR_ID or value.version!=CURRENT_VERSION or value.scenery_version!=Scenery.GENERATOR_VERSION or value.engine!=Engine.get_version_info().string:
		return "This mountain requires a different generator or Godot version."
	var settings_error = Settings.error(value.settings)
	if not settings_error.is_empty(): return settings_error
	for key in ["seed","scenery_seed"]:
		var seed = value[key]
		if not (seed is int or seed is float) or not is_finite(float(seed)) or seed!=floor(float(seed)) or seed<0 or seed>MAX_SEED:
			return "Mountain seeds must be whole numbers from 0 to 2147483647."
	if value.seed!=value.scenery_seed: return "This mountain's scenery seed does not match."
	for key in ["height_sha256","obstacle_sha256"]:
		if not value[key] is String or value[key].length()!=64: return "Missing or invalid mountain checksum."
		for i in 64:
			if not value[key].substr(i,1) in "0123456789abcdef": return "Invalid mountain checksum."
	return ""

static func decode(text_value: String) -> Dictionary:
	if text_value.to_utf8_buffer().size()>MAX_BYTES: return {"error":"Mountain files must be smaller than 4 KB."}
	var parser = JSON.new()
	if parser.parse(text_value)!=OK: return {"error":"Choose a complete Alpine Apex .apexmountain file."}
	var data = parser.data
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
	result.generation_settings = Settings.canonical(data.mountain.settings)
	return {"mountain":result,"error":""}

func reconstruct(job = null) -> Dictionary:
	var field = generate(seed_value,generator_version,generation_settings,job)
	if field==null: return {"error":"Mountain loading cancelled." if job and job.is_cancelled() else "Unsupported or invalid mountain recipe."}
	if field.height_checksum!=height_checksum or field.obstacle_checksum!=obstacle_checksum:
		return {"error":"Reconstructed terrain differs from this file. The mountain was not loaded."}
	return {"field":field,"error":""}
