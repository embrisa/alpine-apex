extends SceneTree
const Dynamics = preload("res://scripts/core/tree_dynamics.gd")
const Motion = preload("res://scripts/presentation/tree_motion.gd")
var checks = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS: " if ok else "FAIL: ",label)
func _initialize() -> void:
	var spring = Dynamics.new()
	spring.impulse(0,Vector3(2,1,0))
	var start_energy = spring.energy()
	var bounded = true
	var peak = 0.0
	for i in 1200:
		spring.step(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
		peak = maxf(peak,spring.angles[0].length())
		bounded = bounded and spring.angles[0].is_finite() and spring.angles[0].length()<=Dynamics.MAX_ANGLE+.00001
	check(peak>.1 and bounded,"Branch impulse produces bounded finite elastic deflection")
	check(spring.energy()<start_energy*.00001,"Unforced spring dissipates energy and returns to rest")
	var branch = [{"center":[2,1,0],"radius":.5,"pivot_y":1}]
	var swept = Dynamics.new(branch)
	swept.step(Vector3(2,1,-2),Vector3(2,1,2),Vector3(0,0,120))
	check(swept.impacts==1,"Swept contact catches a branch crossed between samples")
	var old_angle = swept.angles[0]
	swept.step(Vector3(100,100,100),Vector3(101,100,100),Vector3.ZERO)
	check(swept.touching[0]==0 and swept.angles[0]!=old_angle,"Outside canopy clears contact and keeps a moving spring integrating")
	var large_actor = Dynamics.new(branch)
	large_actor.step(Vector3(2,1,2),Vector3(2,1,2),Vector3(0,0,1),3.0)
	check(large_actor.impacts==1,"Canopy rejection includes the supplied actor radius")
	check_material_publication()
	var poses: Array = []
	for fps in [30,60,144,240]:
		var motion = Motion.new()
		motion.definitions = {"1":{"branches":branch}}
		motion.add_tree(Transform3D.IDENTITY,1)
		var schedule_peak = 0.0
		for frame in fps*2:
			motion.update(Vector3(2,.05,float(frame+1)/fps*4-4),Vector3(0,0,4),1.0/fps,true)
			schedule_peak = maxf(schedule_peak,motion.angles[0].length())
		check(schedule_peak>.02,"Scheduled contact actually bends the branch at %d FPS" % fps)
		poses.append(motion.angles)
		check(motion.tick_count==240,"Tree dynamics stays at 120 Hz with %d FPS" % fps)
		var before = motion.angles.duplicate()
		motion.update(Vector3(2,0,4),Vector3.ZERO,5,false)
		check(before==motion.angles,"Pause freezes canopy springs at %d FPS" % fps)
		motion.reset()
		check(motion.slots==[null,null,null,null] and motion.angles[0]==Vector4.ZERO,"Restart clears contacts at %d FPS" % fps)
	var error = 0.0
	for result in poses:
		for i in result.size(): error=maxf(error,result[i].distance_to(poses[0][i]))
	check(error<.012,"Cross-frame-rate canopy response agrees within 0.012 radians")
	print("TREE_DYNAMICS_RESULT checks=",checks," failures=",failures.size()," schedule_error_rad=",error)
	quit(0 if failures.is_empty() else 1)

func contact_material() -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = "shader_type spatial; uniform vec4 contact_anchors[4]; uniform vec4 contact_angles[48]; uniform bool contact_active = false;"
	var material = ShaderMaterial.new()
	material.shader = shader
	return material

func check_material_publication() -> void:
	var library = {"named_materials":{"FC_Tree":contact_material()}}
	var motion = Motion.new(library,"")
	motion.reset()
	var material: ShaderMaterial = library.named_materials.FC_Tree
	check(material.get_shader_parameter("contact_angles")==motion.angles,"Initial rest state reaches material")
	motion.anchors[0] = Vector4(1,2,3,1)
	motion.angles[0] = Vector4(.1,.2,0,0)
	motion._upload()
	check(material.get_shader_parameter("contact_anchors")==motion.anchors and material.get_shader_parameter("contact_angles")==motion.angles and material.get_shader_parameter("contact_active")==true,"Changed anchors and bend reach material")
	motion.angles[0] = Vector4(.2,.1,0,0)
	check(motion.uploaded_angles[0]!=motion.angles[0],"Later packed-array writes preserve previous publication")
	motion._upload()
	var late = contact_material()
	library.named_materials.FC_Tree_Mid = late
	motion._upload()
	check(late.get_shader_parameter("contact_angles")==motion.angles and late.get_shader_parameter("contact_anchors")==motion.anchors and late.get_shader_parameter("contact_active")==true,"Late material receives current moving state")
	var replacement = contact_material()
	library.named_materials.FC_Tree = replacement
	motion._upload()
	check(replacement.get_shader_parameter("contact_angles")==motion.angles,"Replaced material receives unchanged current state")
	motion.reset()
	check(replacement.get_shader_parameter("contact_active")==false and replacement.get_shader_parameter("contact_angles")==motion.angles,"Reset clears previously moving material")
	library.named_materials.clear()
	motion._upload()
	check(motion.uploaded_materials.is_empty(),"Removed materials are released from publication receipt")
