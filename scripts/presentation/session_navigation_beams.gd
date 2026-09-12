extends Node3D
## Personal presentation lifetime is independent of RaceWorkshop.markers.
const Beam = preload("res://scripts/presentation/race_beams.gd")
const COLOR = Color("bb9dff")
var model
var surface
var beams: Dictionary = {}

static func style() -> Dictionary:
	var result = Beam.visual_style(false)
	result.merge({"height_m":1600.0,"fade_start_m":1250.0,"radius_m":3.5,
		"color":COLOR,"brightness":1.0,"base_enabled":false},true)
	return result

func build(state, support_surface) -> void:
	model = state
	surface = support_surface
	model.changed.connect(sync)
	sync()

func sync() -> void:
	visible = model.shown
	var retained: Dictionary = {}
	for entry in model.points():
		retained[entry.id] = true
		if not beams.has(entry.id):
			var beam = Beam.new()
			beam.name = "NavigationPoint%d" % entry.id
			add_child(beam)
			beam.build_styled(entry.position,style(),surface)
			beam.set_meta("navigation_anchor",entry.position)
			beams[entry.id] = beam
		elif beams[entry.id].get_meta("navigation_anchor") != entry.position:
			beams[entry.id].build_styled(entry.position,style(),surface)
			beams[entry.id].set_meta("navigation_anchor",entry.position)
	for id in beams.keys():
		if not retained.has(id):
			var beam = beams[id]
			remove_child(beam)
			beam.queue_free()
			beams.erase(id)
