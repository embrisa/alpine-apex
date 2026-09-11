extends RefCounted
## Same renderer/world/camera, both HUD instances resident; visible layout differs.
static func run(suite) -> void:
 var path = "res://artifacts/interface_overhaul/baseline/hud.gd"
 if not suite.check(FileAccess.file_exists(path),"captured pre-overhaul HUD is available"): return
 var game = suite.game
 var current = game.hud
 var old = load(path).new()
 game.add_child(old)
 old.feedback.persist = false; old.feedback.enabled = false; old.feedback.muted = true
 old.feedback.reduced_motion = true
 old.set_mountain(game.current_mountain)
 old.sync_display(game.display_settings)
 old.sync_weather(game.weather)
 old.graphics_quality.select(game.graphics.level)
 suite.manifest.matched_hud_source_sha256 = FileAccess.get_sha256(path)
 cpu_comparison(suite,old,current)
 var cameras: Dictionary = {}
 for workload in ["menu","settings_scroll","settings_transition","riding_hud","moving_forest_hud"]:
  for side in ["before","after"]:
   if not suite.alive(): break
   suite.case_name = "matched_"+workload+"_"+side
   print("INTERFACE_PERFORMANCE_BEGIN ",suite.case_name)
   var moving = workload=="moving_forest_hud"
   suite.prepare_site("forest" if moving else "summit",false)
   current.feedback.reduced_motion = true
   game.camera.effects_enabled = false
   game.effects.muted = true
   current.feedback.muted = true
   current.show_menu("paused"); old.show_menu("paused")
   if workload.begins_with("settings"):
    current.open_settings(); old.open_settings()
    current.settings_tabs.current_tab = 2
    old.settings_tabs.current_tab = 3
    for hud in [current,old]:
     for group in hud.camera_options.groups.values(): group.button.button_pressed = true
   elif workload.ends_with("hud"):
    current.hide_menu(); old.hide_menu()
   current.root.modulate.a = 0.0 if side=="before" else 1.0
   old.root.modulate.a = 1.0 if side=="before" else 0.0
   var action = func(index: int):
    old.update_hud(game.sim,game.session,game.intent,"fixture",8.333,0.0,1.0/120.0,false,game.weather.state.label+" · "+game.weather.state.time_label)
    for hud in [current,old]:
     if workload=="settings_scroll":
      var scroll: ScrollContainer = hud.settings_tabs.get_current_tab_control()
      var bar = scroll.get_v_scroll_bar()
      scroll.scroll_vertical = roundi(maxf(0,bar.max_value-bar.page)*(.5-.5*cos(index*TAU/120.0)))
     elif workload=="settings_transition" and index%20==0:
      # Equivalent Camera/Controls/Audio page activity with respective old indices.
      var indices = [2,3,4] if hud==current else [3,6,7]
      hud.settings_tabs.current_tab = indices[posmod(index/20,3)]
   for i in 120:
    action.call(i)
    await suite.process_frame
   var camera = game.presentation_camera.global_transform
   if cameras.has(workload):
    var reference: Transform3D = cameras[workload]
    suite.check(reference.origin.distance_to(camera.origin)<.02 and reference.basis.is_equal_approx(camera.basis),"paired UI uses the same camera")
   else: cameras[workload] = camera
   if moving:
    suite.route_site = "forest"
    suite.segment_serial = 0
    game.active = true
    game.set_physics_process(true)
   var row = await suite.sample(30 if moving else 0,0 if moving else 240,moving,action)
   game.active = false
   game.set_physics_process(false)
   row.workload = workload
   row.side = side
   row.camera_transform = str(camera)
   row.warmup_frames = 120
   row.scope = "Same world and initial view; moving_forest_hud follows identical 120 Hz input for at least 30 seconds; other pairs stay stationary; both HUDs resident and updated in both samples; visible pre-overhaul/current layout. Both include the common update cost of both resident HUDs; CPU update calls are measured separately."
   suite.rows.append(row)
   suite.write_report()
   if suite.take_captures and suite.alive(): await suite.capture(suite.case_name)
 current.root.modulate.a = 1.0
 old.queue_free()
 await suite.process_frame

static func cpu_comparison(suite, old, current) -> void:
 # Isolate the changed update call separately from shared scene and draw cost.
 var timings = {"before":PackedFloat64Array(),"after":PackedFloat64Array()}
 var game = suite.game
 for i in 550:
  for side in (["before","after"] if i%2==0 else ["after","before"]):
   var hud = old if side=="before" else current
   var started = Time.get_ticks_usec()
   hud.update_hud(game.sim,game.session,game.intent,"fixture",8.333,0.0,0.0,false,game.weather.state.label+" · "+game.weather.state.time_label)
   var elapsed = Time.get_ticks_usec()-started
   if i>=50: timings[side].append(float(elapsed))
 suite.rows.append({"case":"paired_hud_update_cpu","before_us":suite.Costs.stats(timings.before),"after_us":suite.Costs.stats(timings.after),"warmup_calls":50,"samples_per_side":500,"scope":"Alternating isolated update_hud calls on the same state; excludes draw/scene work, outside FPS samples."})
 suite.write_report()
