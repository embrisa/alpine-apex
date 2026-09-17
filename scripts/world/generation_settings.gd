extends RefCounted
## Physical recipe settings. Values are factors, canonical to one hundredth.
const KEYS = ["tree_population","mineral_density","snow_feature_density","landform_complexity","tree_spacing"]
const PRESETS = ["Light","Standard","Rich","Extreme","Custom"]
const MULTIPLIERS = [.5,1.0,2.0,5.0]
const TREE_BASELINE = 170000
const MINERAL_BASELINE = 16022

static func preset(index: int = 1) -> Dictionary:
	var factor: float = MULTIPLIERS[clampi(index,0,3)]
	return {"tree_population":factor,"mineral_density":factor,"snow_feature_density":factor,"landform_complexity":factor,"tree_spacing":1.0}

static func canonical(value: Dictionary = {}) -> Dictionary:
	if value.is_empty(): return preset()
	if not error(value).is_empty(): return {}
	var result: Dictionary = {}
	for key in KEYS: result[key] = roundf(float(value[key])*100.0)/100.0
	return result

static func error(value: Variant) -> String:
	if not value is Dictionary or value.size()!=KEYS.size(): return "The generation settings are incomplete."
	for key in KEYS:
		var v = value.get(key)
		if not (v is float or v is int) or not is_finite(float(v)):
			return "Generation settings must be finite numbers."
		if v<.5 or v>(2.0 if key=="tree_spacing" else 5.0): return "Generation settings are outside the supported range."
		if absf(v*100-roundf(v*100))>.000001: return "Generation settings use increments of 0.01."
	return ""

static func preset_index(value: Dictionary) -> int:
	for i in 4:
		if canonical(value)==preset(i): return i
	return 4

static func identity(value: Dictionary) -> String:
	return JSON.stringify(canonical(value),"",true,true).sha256_text()

static func targets(value: Dictionary) -> Dictionary:
	return {"trees":roundi(TREE_BASELINE*value.tree_population),"minerals":roundi(MINERAL_BASELINE*value.mineral_density),"snow_features":6*(roundi(96*value.snow_feature_density)+roundi(100*value.snow_feature_density)+roundi(32*value.snow_feature_density))}

static func stream(seed_number: int, stage: int, candidate: int) -> int:
	# A bounded integer mix avoids signed-overflow/platform arithmetic differences.
	var v = ((seed_number & 0x7fffffff) ^ (stage*104729) ^ (candidate & 0x7fffffff)) & 0x7fffffff
	v = ((v ^ (v >> 16))*1103515245+12345) & 0x7fffffff
	return (v ^ (v >> 13)) & 0x7fffffff
