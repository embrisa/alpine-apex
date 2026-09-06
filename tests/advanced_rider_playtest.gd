extends SceneTree
var game
var output = "res://artifacts/advanced_rider/visual"
func _initialize(): call_deferred("run")
func capture(id):
 for i in range(4): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+id+".png")
func run():
 if DisplayServer.get_name()=="headless": quit(1); return
 DirAccess.make_dir_recursive_absolute(output+"/crash_frames")
 DirAccess.make_dir_recursive_absolute(output+"/ski_frames")
 root.size = Vector2i(1280,900)
 game = load("res://main.tscn").instantiate()
 game.automated = true
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.set_physics_process(false)
 game.start_speed_lab(120)
 game.hud.root.visible = false
 game.hud.toast_label.visible = false
 game.effects.visible = false
 game.weather_effects.visible = false
 game.sim.reset(Vector3(0,game.field.sample(0,500).height,500))
 game.sim.prime_contacts(game.field)
 game.sim.effective_tuck = 1.0
 game.sim.body.pelvis_height = .72
 for i in range(240): game.sim.body._pose(game.sim,1.0/120.0)
 game.sim.body.previous_joints = game.sim.body.joints.duplicate()
 game.sim.body.previous_rotations = game.sim.body.rotations.duplicate()
 game.skier.pose(game.sim)
 var center = game.skier.to_global(Vector3(0,.85,0))
 game.camera.global_position = center+game.skier.basis*Vector3(2.4,.40,0)
 game.camera.look_at(center)
 await capture("tuck_side")
 var hand = game.skier.pose_probe("left_hand")
 game.camera.global_position = hand+game.skier.basis*Vector3(.32,.27,.44)
 game.camera.look_at(hand)
 await capture("grip_close")
 var head = game.skier.pose_probe("head")
 game.camera.global_position = head+game.skier.basis*Vector3(.18,.14,.60)
 game.camera.look_at(head)
 await capture("materials_default")
 game.skier.appearance.change("Lens","tint",Color(.2,.6,1),false)
 game.skier.appearance.change("Helmet","tint",Color(.7,.25,.1),false)
 game.skier.appearance.change("Clothing","tint",Color(.3,.8,1),false)
 await capture("materials_changed")
 game.skier.appearance.reset(false)
 game.hud.root.visible = true
 game.hud.show_menu("paused")
 game.hud.weather_panel.visible = true
 game.hud.menu.visible = false
 var scroll = game.hud.weather_panel.get_child(0)
 scroll.scroll_vertical = 500
 await capture("material_controls")
 game.hud.root.visible = false
 await physics_motion()
 game.sim.reset(Vector3(0,game.field.sample(0,500).height+2.0,500))
 game.sim.prime_contacts(game.field)
 game.sim.grounded = false
 game.sim.velocity = Vector3(0,-3,150.0/3.6).slide(game.sim.surface_normal)
 game.sim.body.roll_velocity = .8
 game.sim.crash("PLAYTEST")
 game.crash_collision.prepare(game.sim.position)
 game.skier.ragdoll.start(game.sim)
 process_frame.connect(_crash_camera)
 var min_clearance = INF
 var max_velocity = 0.0
 for frame in range(180):
  for tick in range(4): await physics_frame
  game.skier.ragdoll.update_equipment()
  var focus = game.skier.ragdoll.focus()
  game.crash_collision.prepare(focus)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output+"/crash_frames/%04d.png"%frame)
  for id in game.skier.ragdoll.bodies:
   var body = game.skier.ragdoll.bodies[id]
   min_clearance = minf(min_clearance,body.global_position.y-game.field.sample(body.global_position.x,body.global_position.z).height)
   max_velocity = maxf(max_velocity,body.linear_velocity.length())
  if frame in [0,14,44,89,179]: await capture("crash_%03d"%frame)
 print("ADVANCED_VISUAL ",JSON.stringify({"unranked":not game.session.eligible,"min_clearance_m":min_clearance,"max_body_speed_ms":max_velocity}))
 game.queue_free()
 await process_frame
 quit()

func _crash_camera():
 if not is_instance_valid(game) or not game.skier.ragdoll.running: return
 game.skier.ragdoll.update_equipment()
 var focus = game.skier.ragdoll.focus()
 game.camera.global_position = focus+Vector3(3.0,2.0,-3.5)
 game.camera.global_position.y = maxf(game.camera.global_position.y,game.field.sample(game.camera.global_position.x,game.camera.global_position.z).height+1.2)
 game.camera.look_at(focus)

func physics_motion():
 game.sim.reset(Vector3(0,game.field.sample(0,500).height,500))
 game.sim.prime_contacts(game.field)
 game.sim.velocity = Vector3.BACK.slide(game.sim.surface_normal).normalized()*100.0/3.6
 var intent = RiderInput.new()
 for frame in range(240):
  var t = frame/30.0
  for tick in range(4):
   intent.steer = .22*sin(t*1.4)
   intent.tuck = .5+.5*cos(t*1.1)
   intent.jump = frame==130 and tick==0
   game.sim.step(1.0/120.0,intent,game.field)
  game.skier.pose(game.sim)
  var center = game.skier.to_global(Vector3(0,.80,0))
  game.camera.global_position = center+game.skier.basis*Vector3(2.0,.8,3.1)
  game.camera.look_at(center)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output+"/ski_frames/%04d.png"%frame)
  if frame in [45,100,145,200]: await capture("ski_%03d"%frame)
  if game.sim.crashed: print("MOTION_CRASH ",frame," ",game.sim.crash_reason); break
