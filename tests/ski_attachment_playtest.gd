extends SceneTree
## Real engine tick/render cadence, including stopped simulation with live rendering.
var game
var elapsed = 0.0
var frame = 0
var measured_frames = 0
var captured = 0
var previous_ski: Array = []
var max_gap = 0.0
var max_moving_gap = 0.0
var max_paused_step = 0.0
var mode = "baseline" if "--baseline" in OS.get_cmdline_user_args() else "fixed"
var recording = "--recording" in OS.get_cmdline_user_args()
var output: String
var ready = false
func _initialize(): call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless": quit(1); return
 output = "res://artifacts/ski_attachment/"+mode+("_recording" if recording else "")
 DirAccess.make_dir_recursive_absolute(output+"/frames")
 root.size = Vector2i(1280,900)
 game = load("res://main.tscn").instantiate()
 game.automated = true
 if mode=="baseline": game.set_script(load("res://artifacts/ski_attachment/baseline/main.gd"))
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.set_physics_process(false)
 game.start_speed_lab(180)
 game.hud.root.visible = false
 game.hud.toast_label.visible = false
 game.effects.visible = false
 game.weather_effects.visible = false
 game.skier.skeleton.skeleton_updated.connect(_measure_skeleton)
 game.camera.close_view = false
 game.sim.reset(Vector3(0,game.field.sample(0,500).height,500))
 game.sim.prime_contacts(game.field)
 game.previous_position = game.sim.position
 game.sim.velocity = Vector3.BACK.slide(game.sim.surface_normal).normalized()*180/3.6
 game.session.eligible = false
 physics_frame.connect(_tick)
 process_frame.connect(_draw)
 RenderingServer.frame_post_draw.connect(_capture)
 ready = true
func _tick():
 if not ready: return
 var dt = 1.0/Engine.physics_ticks_per_second
 elapsed += dt
 var next_active = elapsed<3.0 or elapsed>5.0
 if next_active and not game.active: game.resume()
 game.active = next_active
 if not game.active: return
 game.previous_position = game.sim.position
 game.intent.steer = .06*sin(elapsed*1.4) if elapsed>2 else 0.0
 game.intent.tuck = 1.0
 game.intent.jump = false
 game.sim.step(dt,game.intent,game.field)
 if game.sim.crashed:
  printerr("UNEXPECTED_CRASH ",elapsed," ",game.sim.crash_reason)
  ready = false
  quit(1)
func _draw():
 if not ready: return
 game._process(1.0/120)
 var center = game.skier.to_global(Vector3(0,.72,0))
 game.camera.global_position = center+game.skier.basis*Vector3(2.3,.70,2.5)
 game.camera.look_at(center)
 if not game.active and previous_ski.size()==2:
  for i in range(2): max_paused_step = maxf(max_paused_step,previous_ski[i].distance_to(game.skier.skis[i].global_position))
 previous_ski = [game.skier.skis[0].global_position,game.skier.skis[1].global_position] if not game.active else []
 measured_frames += 1
func _measure_skeleton():
 if not ready: return
 for i in range(2):
  var id = "RightFoot" if i==0 else "LeftFoot"
  var foot = game.skier.skeleton.global_transform*game.skier.skeleton.get_bone_global_pose(game.skier.bone_ids[id])
  var boot = game.skier.skis[i].global_transform*Vector3(0,.095+game.sim.Body.REST[id].y,-.15)
  max_gap = maxf(max_gap,foot.origin.distance_to(boot))
  if game.active: max_moving_gap = maxf(max_moving_gap,foot.origin.distance_to(boot))
func _capture():
 if not ready: return
 frame += 1
 if (not recording and frame%4==0) or (recording and frame in [90,180,300]):
  root.get_texture().get_image().save_png(output+"/frames/%04d.png"%captured)
  captured += 1
 if elapsed>=7.0:
  ready = false
  var result = {"rendered_frames":measured_frames,"captured_frames":captured,"max_rendered_ankle_gap_m":max_gap,"max_moving_gap_m":max_moving_gap,"max_paused_ski_step_m":max_paused_step,"speed_kmh":game.sim.velocity.length()*3.6,"unranked":not game.session.eligible}
  FileAccess.open(output+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  ")+"\n")
  print("SKI_ATTACHMENT_VISUAL ",JSON.stringify(result))
  game.queue_free()
  quit()
