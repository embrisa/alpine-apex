extends "res://tests/performance_descent.gd"
## Same ordinary-input dense-forest route, with one excluded traversal then A/A/B.
var trial=0
func configure_comparison():
	assert(OS.get_environment("ALPINE_VALIDATION_MODE")=="FpsCritical")
	assert(repetitions==4 and trial_seconds==15 and scenario_replay)
	assert(game.forest_appearance.active==1)
func prepare_comparison_trial(index:int):
	trial=index
	for node in game.world.wilderness.props.get_children():
		if node.get_meta("kind","")!="tree":continue
		var mat:ShaderMaterial=node.multimesh.mesh.surface_get_material(0)
		mat.shader=preload("res://assets/graphics/offmap_tree.gdshader") if index==3 else preload("res://tests/fixtures/distant_forest_reference.gdshader")
		if index==3:preload("res://scripts/world/wilderness_props.gd").configure_card(mat,node.multimesh.mesh)
		var base:AABB=node.get_meta("card_filter_base_bound")
		node.multimesh.custom_aabb=base.grow(preload("res://scripts/world/wilderness_props.gd").CARD_FILTER_PADDING_M if index==3 else 0.0)
	game.display_settings.reset_history()
func comparison_metadata()->Dictionary:
	return {"forest_style":"winter","far_coverage":"filtered" if trial==3 else "reference","excluded_route_warmup":trial==0,"background_prop_instances":game.world.wilderness.props.instances}
