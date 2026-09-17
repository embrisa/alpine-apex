extends SceneTree
const Wilderness = preload("res://scripts/world/alpine_wilderness.gd")
const Quality = preload("res://scripts/presentation/graphics_quality.gd")
var world
var checks=0
var failures: Array=[]
var stages=0
var replace_during_checkpoint=false
var disable_shadow_during_checkpoint=false
class Job:
	extends RefCounted
	var cancelled=false
	func is_cancelled() -> bool: return cancelled
class Field:
	extends RefCounted
	var job=Job.new()
	func bounds() -> Rect2: return Rect2(-3072,-3072,6144,6144)
	func sample(_x: float,_z: float) -> Dictionary: return {"height":2400.0}
class Mountain:
	extends RefCounted
	var seed_value=849205174
	const ORIGIN=Vector2(-4096,-4096)
	const EXTENT=8192.0
	func sample_height(p: Vector2) -> float: return 2400.0+p.x*.01
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
	print("PASS: " if value else "FAIL: ",label)
func quality(level: int, snow: bool = false, shadows: int = 0):
	var q=Quality.preset(level); q.offmap_prop_density=0.0; q.offmap_snow_detail=snow; q.offmap_shadow_quality=shadows; return q
func checkpoint(_label: String,_percent: float) -> void:
	stages+=1
	if replace_during_checkpoint and stages==2:
		replace_during_checkpoint=false
		await world.apply_quality(quality(2,true,2))
	if disable_shadow_during_checkpoint and stages==2:
		disable_shadow_during_checkpoint=false
		await world.apply_quality(quality(0,false,0))
	await process_frame
func run() -> void:
	var field=Field.new()
	world=Wilderness.new(); root.add_child(world)
	# Inject a real baked terrain resource with empty prop batches to keep
	# cancellation ordering independent of asset upload throughput.
	world.data.asset=load(Wilderness.Data.DEFAULT_ASSET).duplicate()
	var levels: Array[Dictionary]=[]
	for source in world.data.asset.levels:
		var preset: Dictionary=source.duplicate()
		preset.groups=[]; preset.apron_count=0
		levels.append(preset)
	world.data.asset.levels=levels
	await world.build(field,Mountain.new(),quality(0,true,1))
	check(world.horizon.payload.geometry_tier==0 and world.horizon.quality==1,"New scenery loads only the requested shadow tier")
	check(world.material.get_shader_parameter("offmap_snow_detail")==true,"New scenery initializes the effective snow override")
	var old_root=world.terrain_root
	var old_triangles: int=world.triangles
	world.apron_material=ShaderMaterial.new()
	world.apron_material.shader=preload("res://assets/graphics/alpine_apron.gdshader")
	for detail in [true,false,true]:
		await world.apply_quality(quality(0,detail))
		check(world.terrain_root==old_root and world.triangles==old_triangles,"Same-tier snow override leaves resident geometry intact")
		check(world.material.get_shader_parameter("offmap_snow_detail")==detail and world.apron_material.get_shader_parameter("offmap_snow_detail")==detail,"Resident ridges and late-bound apron receive the same snow override")
	for shadow in [1,2,0]:
		await world.apply_quality(quality(0,false,shadow))
		check(world.terrain_root==old_root,"Shadow-only change retains resident geometry")
		check(world.material.get_shader_parameter("offmap_horizon_enabled")==bool(shadow) and world.apron_material.get_shader_parameter("offmap_horizon_enabled")==bool(shadow),"Resident ridges and late apron share the current shadow override")
	field.job.cancelled=true
	await world.apply_quality(quality(1,false,2),checkpoint)
	check(world.terrain_root==old_root and world.level==0 and world.triangles==old_triangles,"Cancelled quality build retains complete active geometry")
	check(world.get_child_count()==1 and world.source_arrays.is_empty(),"Cancelled staging and triangle inputs are released")
	check(world.horizon.tier==0 and world.horizon.payload.geometry_tier==0,"Cancelled build retains an atlas matching the active geometry")
	field.job.cancelled=false
	await world.apply_quality(quality(1),checkpoint)
	check(world.level==1,"A cancelled requested preset can be retried")
	stages=0; replace_during_checkpoint=true
	await world.apply_quality(quality(0),checkpoint)
	check(world.level==2 and world.get_child_count()==1 and world.ridge_nodes().size()==24,"Newest quality request wins during staged construction")
	check(world.material.get_shader_parameter("offmap_snow_detail")==true and world.apron_material.get_shader_parameter("offmap_snow_detail")==true,"Replacement scenery retains the newest snow override")
	check(world.horizon.tier==2 and world.horizon.payload.geometry_tier==2 and world.horizon.quality==2,"Replacement scenery selects the newest geometry and shadow combination")
	for ridge in world.ridge_nodes():
		check(ridge.material_override==world.material,"Replacement ridge owns the current shared material")
	await world.apply_quality(quality(2))
	check(not world.material.get_shader_parameter("offmap_snow_detail") and not world.apron_material.get_shader_parameter("offmap_snow_detail"),"Same-tier reset disables both material consumers")
	stages=0; disable_shadow_during_checkpoint=true
	await world.apply_quality(quality(0,true,2),checkpoint)
	check(world.level==0 and world.shadow_quality==0 and world.horizon.payload==null,"A same-tier Off request during staging stays Off after publication")
	var reference=weakref(world.props)
	world.queue_free(); await process_frame; await process_frame
	check(reference.get_ref()==null,"World destruction frees its background prop owner")
	print("OFFMAP_LIFECYCLE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
