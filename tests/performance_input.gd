extends RefCounted
## Benchmark fixture inputs, separate from snapshot ghosts and personal records.
const FIELDS = ["steer","tuck","brake","jump","jump_held","air_pitch","air_yaw","grab","air_tilt"]
static func storage(data: Dictionary) -> Dictionary:
	var result = data.duplicate(true)
	var values = PackedFloat64Array()
	for command in data.commands:
		for value in command: values.append(float(value))
	result.inputs_f64 = Marshalls.raw_to_base64(values.to_byte_array())
	result.heading_f64 = Marshalls.raw_to_base64(PackedFloat64Array([data.heading]).to_byte_array())
	result.erase("commands"); result.erase("heading")
	return result
static func expand(data: Dictionary) -> String:
	# Packed doubles preserve the exact resolved controls and launch heading.
	# JSON's decimal parser can differ by an ULP even with full-precision output.
	if not data.has("inputs_f64"): return "" # In-memory fixtures use arrays.
	if not data.inputs_f64 is String or not data.get("heading_f64") is String: return "Invalid packed inputs"
	var bytes = Marshalls.base64_to_raw(data.inputs_f64)
	var heading = Marshalls.base64_to_raw(data.heading_f64)
	if bytes.is_empty() or bytes.size()%(FIELDS.size()*8)!=0 or heading.size()!=8: return "Invalid packed input length"
	var values = bytes.to_float64_array()
	var commands: Array = []
	for offset in range(0,values.size(),FIELDS.size()):
		var command: Array = []
		for i in FIELDS.size():
			var value = values[offset+i]
			if i in [3,4,7]:
				if value!=0.0 and value!=1.0: return "Invalid packed input flag"
				command.append(value==1.0)
			else: command.append(value)
		commands.append(command)
	data.commands = commands; data.heading = heading.to_float64_array()[0]
	if not is_finite(data.heading): return "Invalid launch heading"
	return ""
static func encode(intent) -> Array:
	return [intent.steer,intent.tuck,intent.brake,intent.jump,intent.jump_held,intent.air_pitch,intent.air_yaw,intent.grab,intent.air_tilt]
static func decode(command: Array) -> RiderInput:
	var intent = RiderInput.new()
	for i in FIELDS.size(): intent.set(FIELDS[i],command[i])
	return intent
static func valid(command) -> bool:
	if not command is Array or command.size()!=FIELDS.size(): return false
	for i in FIELDS.size():
		var value = command[i]
		if i in [3,4,7]:
			if not value is bool: return false
		elif not (value is float or value is int) or not is_finite(float(value)) or value>1.0 or value<(-1.0 if i in [0,5,6,8] else 0.0): return false
	return true
static func state(sim) -> Array:
	return [sim.ticks,sim.position.x,sim.position.y,sim.position.z,sim.velocity.x,sim.velocity.y,sim.velocity.z,sim.heading]
static func matches_state(sim, expected: Array) -> bool:
	if expected.size()!=8: return false
	# Restore the engine's actual Vector3 precision before comparing JSON numbers.
	# Heading is a double; permit only decimal-parser roundoff, not route drift.
	return sim.ticks==int(expected[0]) and sim.position==Vector3(expected[1],expected[2],expected[3]) and sim.velocity==Vector3(expected[4],expected[5],expected[6]) and absf(sim.heading-float(expected[7]))<=1e-12
