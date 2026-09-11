extends RefCounted
## Presentation response, separate from loose-layer depth and physical friction.
## A surface may implement snow_condition_at(x,z) -> ID. Existing mountains
## derive powder/packed from their authoritative loose depth; no new generation.
enum Kind { POWDER, DEEP_POWDER, PACKED, WIND_PACKED, ICE, GROOMED }
const PROFILES = [
	# loose yield, clump yield, mist yield, compression, crystal density
	Vector4(1.0,1.0,1.0,1.0), Vector4(1.2,1.1,1.2,1.0),
	Vector4(.12,.7,.08,.25), Vector4(.35,.9,.24,.45),
	Vector4(.015,.55,0.0,.06), Vector4(.20,.65,.12,.30)
]
const CRYSTALS = [1.0,.85,.65,.55,.25,.55]

static func at(surface, position: Vector3, depth_m: float) -> int:
	if surface != null and surface.has_method("snow_condition_at"):
		return clampi(int(surface.snow_condition_at(position.x,position.z)),0,5)
	return Kind.PACKED if depth_m<.012 else (Kind.DEEP_POWDER if depth_m>.18 else Kind.POWDER)
