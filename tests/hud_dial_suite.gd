extends SceneTree
const Hud = preload("res://scripts/ui/hud.gd")
# Frozen pre-optimization paint sequence: verifies native output and ordering.
class Reference extends Control:
    var speed = 0.0
    var tint = Color.WHITE
    var total_us = 0
    var draws = 0
    func _draw() -> void:
        var stamp = Time.get_ticks_usec()
        var center = size * 0.5
        var radius = size.x * 0.46
        var start = deg_to_rad(140.0)
        var sweep = deg_to_rad(260.0)
        draw_arc(center,radius,start,start+sweep,80,Color(1,1,1,.25),2.0,true)
        draw_arc(center,radius,start,start+sweep*clampf(speed/200.0,0,1),80,tint,3.0,true)
        for threshold in [60,90,120,150,165,200]:
            var direction = Vector2.from_angle(start+sweep*threshold/200.0)
            draw_line(center+direction*(radius-6),center+direction*radius,Color(1,1,1,.5),1.0,true)
        total_us += Time.get_ticks_usec()-stamp
        draws += 1
var failures: Array = []
var cases: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
    if DisplayServer.get_name()=="headless": push_error("Native renderer required"); quit(2); return
    var output = "res://artifacts/hud_dial"
    DirAccess.make_dir_recursive_absolute(output)
    var views: Array[SubViewport] = []
    var controls: Array[Control] = [Reference.new(),Hud.SpeedDial.new()]
    for control in controls:
        var view = SubViewport.new()
        view.size = Vector2i(512,512); view.transparent_bg = true
        view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(view); view.add_child(control); views.append(view)
        control.position = Vector2(32,32)
    var index = 0
    for extent in [Vector2(90,90),Vector2(180,180),Vector2(300,230)]:
        for speed in [0.0,42.5,60.0,90.0,120.0,150.0,165.0,170.0,200.0,240.0,-10.0]:
            for control in controls:
                control.size = extent; control.speed = speed
                control.tint = Color("efa773") if speed>=165 else Color("f4f0e8")
                control.queue_redraw()
            await process_frame; await process_frame; await RenderingServer.frame_post_draw
            var a = views[0].get_texture().get_image()
            var b = views[1].get_texture().get_image()
            var same = a.get_data()==b.get_data()
            cases.append({"size":[extent.x,extent.y],"speed":speed,"byte_identical":same})
            if not same:
                failures.append("Native dial differs at %s / %s" % [extent,speed])
                a.save_png(output+"/reference_%d.png"%index); b.save_png(output+"/candidate_%d.png"%index)
            if extent==Vector2(180,180) and speed==170.0:
                a.save_png(output+"/reference.png"); b.save_png(output+"/candidate.png")
            index += 1
    # A changed speed/tint must invalidate its arc without caller queue_redraw.
    for control in controls:
        control.speed = 73.125; control.tint = Color("85d5ca")
    controls[0].queue_redraw()
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    var reactive_equal = views[0].get_texture().get_image().get_data()==views[1].get_texture().get_image().get_data()
    if not reactive_equal: failures.append("Speed/tint setter failed to redraw")
    # Resizing and hide/show must retain the static layers and inherited opacity.
    for control in controls: control.hide(); control.size = Vector2(240,240); control.modulate.a = .6
    await process_frame
    for control in controls: control.show()
    controls[0].queue_redraw()
    await process_frame; await process_frame; await RenderingServer.frame_post_draw
    var lifecycle_equal = views[0].get_texture().get_image().get_data()==views[1].get_texture().get_image().get_data()
    if not lifecycle_equal: failures.append("Resize/show/opacity output differs")
    var counts = {"arc":0,"static":0}
    controls[1].draw.connect(func(): counts.arc += 1)
    for layer in controls[1].get_children(): layer.draw.connect(func(): counts.static += 1)
    for step in 8:
        controls[1].speed += 1.0
        await process_frame; await process_frame
    var retained = counts.arc==8 and counts.static==0
    if not retained: failures.append("Speed changes rebuilt static drawing commands")
    counts.arc = 0
    controls[1].speed = controls[1].speed; controls[1].tint = controls[1].tint
    await process_frame; await process_frame
    var unchanged_retained = counts.arc==0 and counts.static==0
    if not unchanged_retained: failures.append("Unchanged dial values triggered a redraw")
    var report = {"retained_static_layers":retained,"unchanged_retained":unchanged_retained,"cases":cases,"setter_equal":reactive_equal,"lifecycle_equal":lifecycle_equal,"failures":failures}
    preload("res://tests/test_report.gd").write(output+"/results.json",JSON.stringify(report,"\t"))
    print("HUD_DIAL_RESULT cases=",cases.size()," failures=",JSON.stringify(failures))
    for view in views: view.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
