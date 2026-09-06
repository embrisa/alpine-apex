extends SceneTree
var game
var output = "res://artifacts/turn_anatomy/fixed"
func _initialize(): call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless": quit(1); return
 if "--before" in OS.get_cmdline_user_args(): output = "res://artifacts/turn_anatomy/baseline"
 DirAccess.make_dir_recursive_absolute(output)
 root.size = Vector2i(1280,900)
 game = load("res://main.tscn").instantiate()
 game.automated = true
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.set_physics_process(false)
 game.start_speed_lab(30)
 game.hud.root.visible = false
 game.hud.toast_label.visible = false
 game.effects.visible = false
 game.weather_effects.visible = false
 game.speed_periphery.visible = false
 for steer in [-1.0,1.0]:
  game.skier.ragdoll.stop()
  game.sim.reset(Vector3(0,game.field.sample(0,500).height,500))
  game.sim.prime_contacts(game.field)
  game.sim.velocity = Vector3.BACK.slide(game.sim.surface_normal).normalized()*30/3.6
  var intent = RiderInput.new()
  for frame in range(120):
   intent.steer = steer if frame<60 else -steer
   for tick in range(2): game.sim.step(1.0/120,intent,game.field)
   game.skier.pose(game.sim)
   var center = game.skier.to_global(Vector3(0,.75,0))
   game.camera.global_position = center+game.skier.basis*Vector3(.5,.55,-2.65)
   game.camera.look_at(center)
   await process_frame
   await RenderingServer.frame_post_draw
   if frame in [29,59,89]: root.get_texture().get_image().save_png(output+"/turn_%s_%s.png"%[int(steer),frame])
   if game.sim.crashed:
    print("TURN_CRASH_HANDOFF ",steer," ",frame," ",game.sim.crash_reason)
    game.crash_collision.prepare(game.sim.position)
    game.skier.ragdoll.start(game.sim)
    print("TURN_RAGDOLL_STARTED ",steer)
    for crash_frame in range(45):
     await process_frame
     game.skier.ragdoll.update_equipment()
     var focus = game.skier.ragdoll.focus()
     game.crash_collision.prepare(focus)
     game.camera.global_position = focus+Vector3(.5,1.1,-2.65)
     game.camera.look_at(focus)
     await RenderingServer.frame_post_draw
    break
 game.queue_free()
 await process_frame
 quit()
