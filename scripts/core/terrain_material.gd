extends RefCounted
## Equipment-neutral contact material. Missing contracts retain packed snow.
enum Kind { SNOW, ROCK }
const ROCK_THRESHOLD = 0.5

static func at(surface, x: float, z: float) -> int:
	if surface != null and surface.has_method("rock_fraction_at"):
		return Kind.ROCK if surface.rock_fraction_at(x,z)>=ROCK_THRESHOLD else Kind.SNOW
	return Kind.SNOW
