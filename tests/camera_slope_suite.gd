extends SceneTree
const Camera = preload("res://scripts/presentation/chase_camera.gd")
const Simulation = preload("res://scripts/core/ski_simulation.gd")
var checks = 0
var failures = []
var camera
var sim = Simulation.new()
var field = Surface.new()
class Surface extends RefCounted:
	var gradient = Vector2.ZERO
	var bumps = false
	func sample(x: float, z: float) -> Dictionary:
		return {"height":gradient.dot(Vector2(x,z)) + (0.3*sin(z*PI)*exp(-z*z/16.0) if bumps else 0.0)}
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func pitch() -> float:
	return rad_to_deg(asin(clampf(-camera.global_basis.z.y,-1,1)))
func step(seconds: float, hz: int = 120) -> void:
	for i in roundi(seconds*hz): camera.update_camera(sim,field,sim.position,1.0/hz)
func reset(slope: float = 0.0, close: bool = false, preset: String = "Connected", kmh: float = 0.0) -> void:
	field.gradient = Vector2(0,tan(deg_to_rad(slope)))
	field.bumps = false
	sim.reset(Vector3.ZERO,0)
	sim.velocity = Vector3(0,field.gradient.y,1).normalized()*kmh/3.6
	camera.settings.reset()
	camera.settings.apply_preset("first_person" if close else "chase",preset)
	camera.close_view = close
	camera.effects_enabled = false
	camera.reset()
	camera.update_camera(sim,field,sim.position,0)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	camera = Camera.new(); root.add_child(camera)
	for preset in camera.CameraSettings.BUILT_INS:
		for close in [false,true]:
			for slope in [-50,-30,-20,0,15,30,45]:
				for kmh in [0,120,200]:
					reset(slope,close,preset,kmh)
					camera.effects_enabled = true
					camera.reset(); camera.update_camera(sim,field,sim.position,0)
					var values = camera.settings.profile("first_person" if close else "chase")
					var label = "%s / %s / %d deg / %d kmh" % [preset,close,slope,kmh]
					check(absf(pitch()-clampf(values.rest_tilt+(slope if close else maxf(slope,-15))+15,-80,80))<.01,"Directional slope aim: "+label)
					var ahead = Vector3(0,field.sample(0,20).height+.1,20)
					check(not camera.is_position_behind(ahead) and root.get_visible_rect().has_point(camera.unproject_position(ahead)),"20m forward terrain is visible: "+label)
					if not close:
						for height in [0.05,0.8,1.65]:
							var point = Vector3.UP*height
							check(not camera.is_position_behind(point) and root.get_visible_rect().has_point(camera.unproject_position(point)),"Rider stays visible at height %.2f: %s" % [height,label])
						var tail = Vector3(0,field.sample(0,-1).height+.05,-1)
						check(not camera.is_position_behind(tail) and root.get_visible_rect().has_point(camera.unproject_position(tail)),"Ski tails stay visible: "+label)
					check(camera.position.y>=field.sample(camera.position.x,camera.position.z).height+(0.799 if close else .999),"Slope framing retains clearance: "+label)
	for hz in [30,60,120,240]:
		reset(-15)
		field.gradient.y = tan(deg_to_rad(30))
		step(.5,hz)
		var expected = -45+45*(1-exp(-.5/.35))
		check(absf(pitch()-expected)<.002,"Slope transition is frame-rate independent at %d Hz" % hz)
		var takeoff = pitch()
		sim.grounded = false
		field.gradient.y = tan(deg_to_rad(-40))
		for i in hz:
			sim.position.y += 2.0/hz
			camera.update_camera(sim,field,sim.position,1.0/hz)
		check(absf(pitch()-takeoff)<.001,"Jump holds terrain aim at %d Hz" % hz)
		sim.grounded = true
		camera.update_camera(sim,field,sim.position,1.0/hz)
		check(absf(pitch()-takeoff)<6,"Landing resumes smoothly at %d Hz" % hz)
	reset(30)
	camera.settings.update_profile("chase",{"slope_follow":0})
	step(1)
	check(absf(pitch()+45)<.001,"Slope following can be disabled")
	camera.settings.update_profile("chase",{"slope_follow":50})
	step(1)
	check(absf(pitch()+22.5)<.001,"Slope strength applies independently of V")
	reset(30,true)
	camera.add_mouse_look(Vector2(0,-100))
	step(1.0/120)
	check(absf(pitch()-30)<.01,"Manual vertical look applies after uphill aim")
	reset(30)
	sim.heading = PI/2; sim.velocity = Vector3.ZERO; camera.reset()
	step(1)
	check(absf(pitch()+30)<.01,"Traversing a slope uses cross-slope grade")
	sim.heading = PI; camera.reset(); step(1)
	check(absf(pitch()+45)<.01,"Reversing direction follows the downhill grade")
	reset()
	field.bumps = true; sim.position.y = 5
	step(1)
	check(absf(pitch()+30)<.01,"Nearby bumps do not steer pitch")
	var state = [sim.position,sim.velocity,sim.ticks,sim.heading,sim.grounded]
	camera.reset(); camera.update_camera(sim,field,sim.position,0,false,false,false,200)
	check(state==[sim.position,sim.velocity,sim.ticks,sim.heading,sim.grounded],"Slope preview preserves simulation state")
	check(absf(pitch()+30)<.01,"Preview shares the slope evaluator")
	print("CAMERA_SLOPE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	camera.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
