extends SceneTree
const MenuCamera = preload("res://scripts/presentation/menu_camera.gd")
var checks = 0
var failures: Array[String] = []
var camera

class Surface extends RefCounted:
	var features: Array = []
	var blocked = false
	var slope = 0.0
	func bounds() -> Rect2: return Rect2(-2000,-2000,4000,4000)
	func ski_bounds() -> Rect2: return bounds().grow(-10)
	func spawn_point() -> Vector3: return Vector3.ZERO
	func sample(_x: float,z: float) -> Dictionary: return {"height":-z*slope}
	func ray_geology(_a: Vector3,_b: Vector3,_radius: float) -> Dictionary:
		return {"fraction":0.12,"normal":Vector3.UP} if blocked else {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures.append(caption)
	print("PASS: " if ok else "FAIL: ",caption)

func advance(seconds: float, hz: int = 120, reduced: bool = false, moving: bool = false) -> void:
	for i in roundi(seconds*hz): camera.update_view(Vector3.ZERO,1.0/hz,reduced,moving)

func run() -> void:
	var field = Surface.new()
	camera = MenuCamera.new()
	root.add_child(camera)
	camera.setup(field)
	check(camera.shots.size()==6,"Archived terrain without features gets six sampled viewpoints")
	var shots = camera.shots.duplicate(true)
	camera.setup(field)
	check(camera.shots==shots,"Repeated setup reuses the current mountain's shot cache")
	camera.select_context("title")
	camera.update_view(Vector3.ZERO,0.0,false)
	check(camera.shot_index==-1 and camera.fov==60.0,"Main menu begins on the player at a fixed cinematic FOV")
	var start: Vector3 = camera.position
	advance(12.0,30)
	var end_30: Vector3 = camera.position
	check(start.distance_to(end_30)>5.0,"Menu camera orbits the stationary player")
	camera.leave(); camera.select_context("title")
	advance(12.0,120)
	check(camera.position.distance_to(end_30)<0.001,"Orbit speed is independent of 30 versus 120 render FPS")
	var phase: float = camera.shot_time
	camera.select_context("title")
	check(camera.shot_time==phase,"Opening another panel in the same context retains the sequence")
	advance(11.9)
	check(camera.shot_index==-1 and camera.fade_alpha==0.0,"The player shot lasts 24 seconds before fading")
	advance(0.3)
	check(camera.shot_index==-1 and camera.fade_alpha>0.4,"Fade covers the old shot before a distant cut")
	advance(0.17)
	check(camera.shot_index==0 and camera.fade_alpha>0.85,"The scenic cut occurs at the dark midpoint")
	advance(0.4)
	check(camera.fade_alpha==0.0 and camera.shot_index==0,"The new scenic shot fades back to the live world")
	var frozen: Transform3D = camera.transform
	advance(60.0,60,true)
	check(camera.transform.is_equal_approx(frozen) and camera.fade_alpha==0.0,"Reduced motion holds the current live scenic frame without cuts")
	camera.select_context("paused")
	camera.update_view(Vector3.ZERO,0.0,false)
	advance(50.0)
	check(camera.shot_index==-1 and camera.fade_alpha==0.0,"Pause stays near the player without scenic cuts")
	camera.select_context("crashed")
	advance(2.0,60,false,true)
	var angle: float = camera.orbit_angle
	var before: Vector3 = camera.position
	camera.update_view(Vector3(5,0,0),1.0/60.0,false,true)
	check(is_equal_approx(angle,camera.orbit_angle) and camera.position.distance_to(before)>4.9,"Moving crashes follow the ragdoll before beginning an orbit")
	camera.update_view(Vector3(5,0,0),1.0/60.0,false,false)
	check(camera.orbit_angle>angle,"A frozen crash begins the player orbit")
	camera.update_view(Vector3(5,0,0),0.0,true,true)
	before = camera.position
	camera.update_view(Vector3(7,0,0),0.02,true,true)
	check(camera.position.distance_to(before)>1.9,"Reduced motion still follows a moving ragdoll")
	field.slope = 1.2
	var safe: Vector3 = camera.safe_position(Vector3(0,1,0),Vector3(0,4,-9))
	check(safe.y>=field.sample(safe.x,safe.z).height+1.0,"Steep slopes cannot bury the menu camera")
	field.slope = 0.0
	field.blocked = true
	safe = camera.safe_position(Vector3(0,1,0),Vector3(0,4,9))
	check(safe.distance_to(Vector3(0,1,0))<3.0,"Geology retracts an obstructed player camera")
	var blocked = Surface.new(); blocked.blocked = true
	camera.setup(blocked)
	check(camera.shots.is_empty(),"Obstructed scenic shots are rejected")
	camera.select_context("title"); advance(50.0)
	check(camera.shot_index==-1 and camera.fade_alpha==0.0,"A mountain with no safe scenic shots keeps the player view")
	camera.setup(field); field.blocked = false
	camera.select_context("title"); camera.fade_alpha = 0.8; camera.fade_time = 0.2
	camera.leave()
	check(camera.context.is_empty() and camera.fade_alpha==0.0 and not camera.pose_ready,"Leaving menus cancels pending fades and view history")
	DirAccess.make_dir_recursive_absolute("res://artifacts/live_menu")
	preload("res://tests/test_report.gd").write("res://artifacts/live_menu/camera_checks.json",JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("MENU_CAMERA_RESULTS ",checks," checks, ",failures.size()," failures")
	camera.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
