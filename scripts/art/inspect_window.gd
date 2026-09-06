extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(2560,1440)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	print("IMAGE_PIXELS ",root.get_texture().get_image().get_size())
	print("WINDOW_INFO ",root.size," texture=",root.get_texture().get_size()," screen scale=",DisplayServer.screen_get_scale()," content factor=",root.content_scale_factor," stretch=",root.content_scale_mode," content size=",root.content_scale_size," 3d scale=",root.scaling_3d_scale)
	var ratio = root.get_texture().get_size()/Vector2(root.size)
	root.size = Vector2i(Vector2(2560,1440)/ratio)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	print("ADJUSTED_IMAGE_PIXELS ",root.get_texture().get_image().get_size())
	print("WINDOW_ADJUSTED ",root.size," texture=",root.get_texture().get_size()," ratio=",ratio)
	quit()
