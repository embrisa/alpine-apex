extends RefCounted
## JSON wire clock: exactly 16 lowercase hex digits of an IEEE754 binary64,
## little-endian. No decimal parser or numeric JSON fallback. Domain bounds are
## checked by the archive/replay; null is distinct from the valid -1 sentinel.

static func encode(seconds: float) -> String:
	if not is_finite(seconds): return ""
	var bytes = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0,seconds)
	return bytes.hex_encode()

static func decode(stored: Variant) -> Variant:
	# Check shape before hex decoding; at most eight bytes can be allocated.
	if not stored is String or stored.length()!=16: return null
	for digit in stored:
		if digit not in "0123456789abcdef": return null
	var seconds = stored.hex_decode().decode_double(0)
	return seconds if is_finite(seconds) else null

static func encode_array(times: Array) -> Array:
	var stored: Array = []
	for time in times: stored.append(encode(time))
	return stored

static func decode_array(stored: Variant, count: int) -> Variant:
	# Internal callers request exactly two crash endpoints or three splits.
	if count not in [2,3] or not stored is Array or stored.size()!=count: return null
	var times: Array = []
	for value in stored:
		var time = decode(value)
		if time==null: return null
		times.append(time)
	return times
