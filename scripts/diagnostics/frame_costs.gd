extends RefCounted
## Opt-in CPU scopes; no formatting or disk I/O inside measured frames.
var enabled = false
var samples: Dictionary = {}
var events: Array = []
func begin() -> int: return Time.get_ticks_usec() if enabled else 0
func end(name: StringName, started: int) -> void:
	if not enabled: return
	if not samples.has(name): samples[name] = PackedFloat64Array()
	# Bound diagnostics to 200k observations per scope (~28 minutes at 120 Hz).
	if samples[name].size()<200000: samples[name].append(float(Time.get_ticks_usec()-started))
	if (String(name).begins_with("stream_") or name==&"collision_preparation") and events.size()<20000:
		events.append([name,Engine.get_process_frames(),started,Time.get_ticks_usec()])
func reset() -> void:
	samples.clear(); events.clear()
static func stats(values) -> Dictionary:
	if values.is_empty(): return {"count":0}
	var ordered = values.duplicate(); ordered.sort()
	var sum = 0.0
	for value in ordered: sum+=value
	return {"count":ordered.size(),"mean":sum/ordered.size(),"p95":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],"p99":ordered[mini(ordered.size()-1,int(ordered.size()*.99))],"max":ordered[-1]}
func report() -> Dictionary:
	var result = {}
	for name in samples: result[name] = stats(samples[name])
	return result
