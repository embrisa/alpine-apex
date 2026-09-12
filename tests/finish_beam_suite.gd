extends SceneTree
## Geometry/instance/lifecycle contracts; native readability is a separate test.
const Beams = preload("res://scripts/presentation/race_beams.gd")
const Baseline = preload("res://tests/fixtures/finish_beam_800m/race_beams.gd")
var failures: Array[String] = []
var checks = 0

class Slope:
	extends RefCounted
	func sample(x: float, z: float) -> Dictionary:
		return {"height":20.0+x*0.1-z*0.2}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)

func run() -> void:
	var parent = Node3D.new()
	root.add_child(parent)
	parent.position = Vector3(15,10,-30)
	parent.rotation.y = 0.8
	var field = Slope.new()
	var center = Vector3(0,20,0)
	var start = Beams.new(); parent.add_child(start); start.build(center,false,field)
	var finish = Beams.new(); parent.add_child(finish); finish.build(center,true,field)
	var old = Baseline.new(); parent.add_child(old); old.build(center,false,field)
	var start_mesh: CylinderMesh = start.get_node("CentralSkyBeam").mesh
	var finish_mesh: CylinderMesh = finish.get_node("CentralSkyBeam").mesh
	var old_mesh: CylinderMesh = old.get_node("CentralSkyBeam").mesh
	check(start_mesh.height==old_mesh.height and start_mesh.rings==old_mesh.rings and start_mesh.top_radius==old_mesh.top_radius,"Start retains 808 m geometry, 31 rings and 6 m radius")
	check(start.material.get_shader_parameter("beam_color")==old.material.get_shader_parameter("beam_color") and start.material.get_shader_parameter("brightness")==old.material.get_shader_parameter("brightness"),"Start retains color and brightness")
	check(start_mesh!=finish_mesh,"Start and finish never share mutable geometry")
	check(finish_mesh.height==2008.0 and finish_mesh.rings==79,"Finish geometry reaches 2 km with 80 vertical segments")
	for item in [start,finish]:
		var beam: MeshInstance3D = item.get_node("CentralSkyBeam")
		var bounds: AABB = beam.mesh.get_aabb()
		var bottom = beam.global_transform*bounds.position
		var top = beam.global_transform*(bounds.position+bounds.size)
		check(is_equal_approx(bottom.y,center.y-8.0) and is_equal_approx(top.y,center.y+item.applied_style.height_m),"World anchor and actual culling bounds agree for "+str(item.applied_style.height_m))
		check(is_equal_approx(item.material.get_shader_parameter("height_above_anchor_m"),item.applied_style.height_m) and item.material.get_shader_parameter("top_fade_start_m")==item.applied_style.fade_start_m,"Shader height and top fade agree with geometry")
		check(beam.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and beam.gi_mode==GeometryInstance3D.GI_MODE_DISABLED and beam.visibility_range_end==0.0,"Beacon stays outside prop LOD, shadow and GI paths")
		var base: MeshInstance3D = item.get_node("RotatingSnowHalo")
		var vertices: PackedVector3Array = base.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var seated = true
		for vertex in vertices:
			var point: Vector3 = base.global_transform*vertex
			seated = seated and absf(point.y-field.sample(point.x,point.z).height-0.12)<0.0001
		check(seated,"Snow halo remains seated on sloping support")
	var nav = Beams.new(); parent.add_child(nav)
	var style = Beams.visual_style(false)
	style.merge({"height_m":1200.0,"fade_start_m":900.0,"color":Color.CYAN,"base_enabled":false},true)
	nav.build_styled(center,style,null)
	style.height_m = 300.0
	check(nav.applied_style.height_m==1200.0 and nav.get_child_count()==1 and nav.base_material==null,"Navigation accepts independent explicit style without race halo")
	nav.update_effect(0.5,true,false)
	check(nav.visual_time==0.5,"Halo-free marker animates")
	nav.update_effect(0.5,false,false)
	check(nav.visual_time==0.5,"Pause freezes visual clock")
	nav.update_effect(0.5,true,true)
	check(nav.visual_time==0.5 and nav.material.get_shader_parameter("vfx_strength")==0.0,"Reduced Motion freezes motion without removing steady shaft")
	nav.update_effect(0.5,true,false)
	check(nav.visual_time==1.0 and nav.material.get_shader_parameter("vfx_strength")==1.0,"Motion resumes safely without a halo")
	finish.build(center,true,field)
	check(finish.get_child_count()==2 and start_mesh.height==808.0 and nav.applied_style.height_m==1200.0,"Rebuild replaces children without changing other beacons")
	check(finish_mesh.height==2008.0,"Previously created finish geometry remains unchanged after rebuilding")
	parent.queue_free()
	await process_frame
	check(get_nodes_in_group("race_beam_vfx").is_empty(),"Freeing marker owner removes all VFX registrations")
	print("FINISH_BEAM_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"geometry and presentation contracts; no visual or performance acceptance"}))
	quit(0 if failures.is_empty() else 1)
