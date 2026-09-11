extends RefCounted
## The retained descent area and its authored scenery opening. Grid ownership
## keeps the 4 m support triangles exact; the 32 m join is stitched at 4 m.
const REVISION = 1
const CELL_M = 32.0
const SHAPE = Vector4(3032.0,42.0,24.0,18.0)
const JOIN_MARGIN_M = 24.0
const BOUNDS = Rect2(-3072,-3072,6144,6144)

static func enabled(field) -> bool:
	return field.has_method("is_summit_mountain") and field.is_summit_mountain() and field.GENERATOR_VERSION==15

static func radius(p: Vector2) -> float:
	var angle = atan2(p.x,p.y)
	return SHAPE.x+SHAPE.y*sin(angle*3.0)+SHAPE.z*sin(angle*5.0)+SHAPE.w*sin(angle*2.0)

static func signed_distance(p: Vector2) -> float:
	return p.length()-radius(p)

static func edge_distance(p: Vector2) -> float:
	# Conservatively outside the furthest corner of a retained 32 m cell.
	return maxf(0.0,signed_distance(p)-JOIN_MARGIN_M)

static func owns_cell(p: Vector2) -> bool:
	var center = (p/CELL_M).floor()*CELL_M+Vector2.ONE*CELL_M*.5
	return BOUNDS.has_point(center) and signed_distance(center)<=0.0

static func on_edge(p: Vector2) -> bool:
	var first = owns_cell(p-Vector2.ONE*.1)
	return first!=owns_cell(p+Vector2.ONE*.1) or first!=owns_cell(p+Vector2(.1,-.1)) or first!=owns_cell(p+Vector2(-.1,.1))

static func edge_segment(a: Vector2, b: Vector2) -> bool:
	var midpoint = (a+b)*.5
	var side = (b-a).orthogonal().normalized()*.1
	return owns_cell(midpoint+side)!=owns_cell(midpoint-side)
