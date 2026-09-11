extends SceneTree
const Router = preload("res://scripts/core/input_router.gd")
const Sim = preload("res://scripts/core/ski_simulation.gd")
const Carving = preload("res://tests/arcade_carving_suite.gd")
const DT = 1.0/120.0
var checks = 0
var failures: Array = []
var router

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)

static func axis(id: int, value: float) -> void:
	var event = InputEventJoypadMotion.new()
	event.axis = id; event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

static func button(id: int, pressed: bool) -> void:
	var event = InputEventJoypadButton.new()
	event.button_index = id; event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func drive(sim, field, ticks: int) -> void:
	for tick in ticks: sim.step(DT,router.sample(sim.grounded),field)

func run() -> void:
	router = Router.new()
	axis(JOY_AXIS_LEFT_Y,-.05)
	check(router.sample().tuck==0.0,"Forward stick noise inside the deadzone is silent")
	check(router.sample(false).air_pitch==0.0,"Stick flips share the stick deadzone")
	axis(JOY_AXIS_LEFT_Y,-.6)
	check(router.sample().tuck>0.0 and router.sample().tuck<1.0,"Forward stick retains analog tuck")
	axis(JOY_AXIS_LEFT_Y,-1.0)
	check(router.sample().tuck==1.0 and not router.sample().jump_held,"Full forward requests tuck without jump")
	check(router.sample().air_tilt==0.0 and router.sample().air_pitch==0.0,"Grounded forward stick requests tuck without rotation")
	var field = Carving.CarvePlane.new()
	var sim = Sim.new()
	sim.reset(Vector3.ZERO); sim.prime_contacts(field)
	sim.velocity = sim.support_basis().z*90.0/3.6
	drive(sim,field,120)
	check(sim.effective_tuck>.95,"Forward stick enters deep tuck")
	axis(JOY_AXIS_LEFT_X,.2)
	drive(sim,field,60)
	check(sim.effective_tuck>.99 and router.sample().steer>0.0,"Small stick corrections retain tuck and steering")
	axis(JOY_AXIS_LEFT_X,.7071); axis(JOY_AXIS_LEFT_Y,-.7071)
	var diagonal = router.sample()
	check(diagonal.steer>.6 and diagonal.tuck>.6 and diagonal.steer==Input.get_axis("steer_left","steer_right"),"Diagonal stick preserves independent steering and tuck strength")
	drive(sim,field,54)
	check(sim.effective_tuck<.04,"Sustained diagonal steering opens tuck by 450 ms")
	axis(JOY_AXIS_LEFT_X,0.0); axis(JOY_AXIS_LEFT_Y,-1.0)
	drive(sim,field,120)
	check(sim.effective_tuck>.95,"Returning the stick forward automatically resumes tuck")
	axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	drive(sim,field,12)
	check(router.sample().brake==1.0 and sim.effective_tuck<.31,"L2 braking opens tuck promptly")
	axis(JOY_AXIS_TRIGGER_LEFT,0.0); axis(JOY_AXIS_LEFT_Y,1.0)
	check(router.sample().tuck==0.0 and router.sample().brake==0.0,"Backward stick does not request tuck or change the brake mapping")
	check(router.sample().air_tilt==0.0 and router.sample().air_pitch==0.0,"Grounded backward stick does not request air rotation")
	axis(JOY_AXIS_LEFT_Y,-1.0); button(JOY_BUTTON_LEFT_SHOULDER,true)
	check(router.sample().tuck==0.0 and router.sample().air_pitch==1.0,"L1 owns forward stick for flips without tuck")
	check(router.sample().air_tilt==0.0,"L1 excludes ordinary pitch from the same stick")
	var key = InputEventKey.new(); key.physical_keycode = KEY_W; key.pressed = true
	Input.parse_input_event(key); Input.flush_buffered_events()
	check(router.sample().tuck==1.0,"Keyboard tuck remains available with the trick modifier")
	key = key.duplicate(); key.pressed = false; Input.parse_input_event(key); Input.flush_buffered_events()
	button(JOY_BUTTON_LEFT_SHOULDER,false); axis(JOY_AXIS_LEFT_Y,0.0)
	await process_frame; await process_frame
	axis(JOY_AXIS_TRIGGER_RIGHT,.7)
	check(router.sample().jump_held and not router.sample().jump and router.sample().tuck==0.0,"R2 prepares a jump and never requests tuck")
	await process_frame; await process_frame
	check(router.sample().jump_held and not router.sample().jump,"Holding R2 does not auto-repeat")
	axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	check(router.sample().jump and not router.sample().jump_held,"Releasing R2 requests one hop")
	await process_frame; await process_frame
	check(not router.sample().jump,"R2 release is a transient intent")
	button(JOY_BUTTON_A,true)
	check(Input.is_action_pressed("begin_run") and not router.sample().jump_held,"Cross/A confirms or drops in without preparing a hop")
	button(JOY_BUTTON_A,false)
	check(not router.sample().jump,"Releasing Cross/A cannot hop")
	stick_flips()
	DirAccess.make_dir_recursive_absolute("res://artifacts/controller_input_v1")
	var result = {"checks":checks,"failures":failures}
	FileAccess.open("res://artifacts/controller_input_v1/input.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CONTROLLER_INPUT_RESULTS ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func stick_flips() -> void:
	var field = Carving.CarvePlane.new()
	for backward in [false,true]:
		for direction in [-1.0,1.0]:
			axis(JOY_AXIS_LEFT_X,0.0); axis(JOY_AXIS_LEFT_Y,-direction)
			router.sample(true)
			var sim = Sim.new(); sim.reset(Vector3(0,500,0)); sim.prime_contacts(field)
			sim.velocity = Vector3(0,0,25); sim._begin_flight(Basis.IDENTITY)
			sim.facing_backward = backward; sim.facing_pose.capture(sim,true)
			drive(sim,field,60)
			check(sim.air_control.integrated_pitch==0 and not sim.air_control.flip_flight,"Stick held through takeoff preserves attitude in either direction/facing")
			axis(JOY_AXIS_LEFT_Y,0.0); drive(sim,field,1)
			axis(JOY_AXIS_LEFT_Y,-.6*direction)
			var analog = router.sample(false)
			check(analog.air_pitch*direction>.5 and analog.air_pitch*direction<.6 and analog.air_tilt==0,"Centered airborne stick requests proportional flips without L1")
			axis(JOY_AXIS_LEFT_Y,-direction); drive(sim,field,210)
			check(absf(sim.air_control.integrated_pitch)>TAU and sim.air_control.flip_flight,"Stick alone completes a flip with the physical trick pose selected")
			check(signf(sim.air_control.integrated_pitch)==direction*(-1.0 if backward else 1.0),"Direct stick flip follows rider-facing direction")
			axis(JOY_AXIS_LEFT_Y,0.0); drive(sim,field,12)
			check(sim.air_control.angular_velocity.length()<.00001,"Centering stick stops the direct flip")
			router.sample(true); axis(JOY_AXIS_LEFT_Y,-direction)
			check(router.sample(false).air_pitch==0,"Landing requires a new airborne center before another stick flip")
	axis(JOY_AXIS_LEFT_Y,0.0); router.sample(false)
	Input.action_press("air_tilt_forward")
	check(router.sample(false).air_tilt==1 and router.sample(false).air_pitch==0,"Keyboard limited pitch remains separate from stick flips")
	Input.action_release("air_tilt_forward")
	axis(JOY_AXIS_LEFT_Y,-1.0); Input.action_press("flip_backward")
	check(router.sample(false).air_pitch==-1.0,"Dedicated keyboard flip takes priority over opposite stick input")
	Input.action_release("flip_backward")
	axis(JOY_AXIS_LEFT_Y,0.0); router.cancel_air_input()
