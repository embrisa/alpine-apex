extends "res://scripts/world/generators/alpine_massif_v14.gd"
## Frozen v14 control: same operations/order, with non-cumulative timings.
func _init(seed_number: int = DEFAULT_SEED) -> void:
	var begin = Time.get_ticks_usec()
	super(seed_number,false)
	_timed("terrain_shaping",func(): heights = _parallel_rows(_landform_rows))
	_timed("geology_foundations",func(): geology.prepare(self))
	_timed("snow_shaping",func(): _sculpt_snow(); _accumulate_powder())
	_timed("geology_placement_collision",func(): geology.finish(self))
	_timed("tree_candidates_placement",func(): _scatter(); _scatter_open_slopes())
	_timed("exposure",func():
		exposure_image = Image.create_from_data(NX,NZ,false,Image.FORMAT_RGBA8,_parallel_rows(_exposure_rows,true))
		geology.paint_exposure(self))
	_timed("tree_filtering_material",_open_woodland_connections)
	_timed("tree_snow_seating_exposure",func(): TreeSnow.apply(self))
	_timed("hashing",_refresh_identity)
	generation_ms = (Time.get_ticks_usec()-begin)/1000.0

func _timed(stage: String, work: Callable) -> void:
	var begin = Time.get_ticks_usec()
	work.call()
	generation_stages[stage+"_ms"] = (Time.get_ticks_usec()-begin)/1000.0
	print("V14_PROFILE_STAGE ",stage," ",generation_stages[stage+"_ms"])
