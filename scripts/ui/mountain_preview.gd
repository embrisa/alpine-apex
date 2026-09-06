extends Control
## Survey of the authoritative triangles, with slope tint and collidable flora.
var terrain
var texture: ImageTexture
var font: Font

func set_terrain(field) -> void:
	terrain = field
	# A bounded survey texture keeps preview time independent of physical area.
	var dimensions = Vector2i(mini(field.NX,385),mini(field.NZ,513))
	var image = Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_RGB8)
	var area: Rect2 = field.bounds()
	for z in dimensions.y:
		for x in dimensions.x:
			var p = area.position+Vector2(float(x)/(dimensions.x-1),float(z)/(dimensions.y-1))*area.size
			var n: Vector3 = field.contact_normal(p.x,p.y)
			var slope = rad_to_deg(acos(clampf(n.y,0,1)))
			var color = Color("d9e6e7").lerp(Color("e2ae70"),smoothstep(27,43,slope))
			color = color.lerp(Color("6d666c"),smoothstep(43,65,slope))
			if field.has_method("exposure_at"):
				var exposure: Color = field.exposure_at(p.x,p.y)
				color = color.lerp(Color("535762") if exposure.r>.4 else Color("eaf4f5"),exposure.a)
			var shade = .67+maxf(0,n.dot(Vector3(-.5,1,-.4).normalized()))*.33
			if fposmod(field.sample(p.x,p.y).height,50)<2.0: shade *= .78
			image.set_pixel(x,z,color*shade)
	for ob in field.obstacles:
		var uv = (Vector2(ob.position.x,ob.position.z)-area.position)/area.size
		var x = clampi(roundi(uv.x*(dimensions.x-1)),0,dimensions.x-1)
		var z = clampi(roundi(uv.y*(dimensions.y-1)),0,dimensions.y-1)
		image.set_pixel(x,z,Color("456c62") if ob.tree else Color("535762"))
	texture = ImageTexture.create_from_image(image)
	queue_redraw()

func _draw() -> void:
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	if not texture or not terrain: return
	var ratio = terrain.bounds().size.x/terrain.bounds().size.y
	var height_value = minf(size.y-65,maxf(100,size.x-265)/ratio)
	var width_value = height_value*ratio
	var rect = Rect2(Vector2(maxf(24,(size.x-width_value-280)*.5),20),Vector2(width_value,height_value))
	draw_texture_rect(texture,rect,false)
	draw_rect(rect,Color("789395"),false,1)
	var label_x = rect.end.x+22
	for i in terrain.features.size():
		var feature = terrain.features[i]
		var p = rect.position+(feature.position-Vector2(terrain.X_MIN,terrain.Z_MIN))/terrain.bounds().size*rect.size
		var label_y = 42+i*(height_value-40)/maxi(1,terrain.features.size())
		draw_circle(p,4,Color("c2e76b"))
		draw_line(p,Vector2(label_x-7,label_y-4),Color(.76,.9,.6,.4),1,true)
		if font: draw_string(font,Vector2(label_x,label_y),feature.name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("eef4f1"))
	if font: draw_string(font,Vector2(rect.position.x,size.y-7),("N ↑   SUMMIT → ALL FACES   /   50 m CONTOURS" if terrain.is_summit_mountain() else "SUMMIT ↓ LOWER BASIN    /    50 m CONTOURS"),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("9eb4bf"))

func _background() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("102832")
	style.set_corner_radius_all(12)
	return style
