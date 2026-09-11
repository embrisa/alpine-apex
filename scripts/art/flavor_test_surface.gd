extends "res://scripts/world/heightfield_surface.gd"
## Explicit 4 m test fixture, independent of mountain generation and records.
func _init() -> void:
	X_MIN=-80; Z_MIN=-40; NX=41; NZ=81; finish_z=210
	heights.resize(NX*NZ)
	for z in NZ:
		for x in NX: heights[z*NX+x]=-(Z_MIN+z*CELL)*.16

func snow_depth_at(_x: float,_z: float) -> float:
	return .04
