extends RefCounted
## Stable run identity is textual; ten contrasting colors supplement it.
const COLORS = [Color("f04a48"),Color("ff9a36"),Color("eadc39"),Color("91db42"),Color("25c981"),Color("24c5c5"),Color("54a7f6"),Color("7374ee"),Color("b960ef"),Color("f269b0"),Color("a3e8f5"),Color("f2bdaf"),Color("36687a"),Color("7e4a62"),Color("828538"),Color("8d98a8")]

static func assignment(runs: Array, player: Color) -> Dictionary:
	var identities: Array = []
	for row in runs: identities.append(row.id)
	identities.sort()
	var result = {}
	var used: Array[Color] = [player]
	for id in identities:
		var best = COLORS[0]
		var best_distance = -1.0
		for color in COLORS:
			var distance = INF
			for other in used: distance = minf(distance,_distance(color,other))
			if distance>best_distance: best_distance = distance; best = color
		result[id] = best; used.append(best)
	return result

static func _distance(a: Color, b: Color) -> float:
	# Perceptual-ish opponent axes, balancing hue and brightness for ten entries.
	var va = Vector3(.3*a.r+.59*a.g+.11*a.b,a.r-a.g,a.b-(a.r+a.g)*.5)
	var vb = Vector3(.3*b.r+.59*b.g+.11*b.b,b.r-b.g,b.b-(b.r+b.g)*.5)
	return va.distance_to(vb)

static func player_color(visual) -> Color:
	var tint: Color = visual.appearance.values.Clothing.tint
	# White default multiplies the blue/red production atlas. Use an atlas
	# sample cached by the field once rather than assuming a white outfit.
	return tint
