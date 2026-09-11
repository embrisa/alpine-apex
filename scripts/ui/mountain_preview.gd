extends Control
const Obstacles = preload("res://scripts/world/obstacle_access.gd")
const AlpineTheme = preload("res://scripts/ui/alpine_theme.gd")
var background: StyleBox = AlpineTheme.box(Color("102832"),AlpineTheme.EDGE,0,AlpineTheme.PANEL_CUT)
## Survey of the authoritative triangles, with slope tint and collidable flora.
var terrain
var texture: ImageTexture
var font: Font

func set_terrain(field) -> void:
	apply_image(field,build_image(field))

func apply_image(field, image: Image) -> void:
	if image==null: return
	terrain = field
	texture = ImageTexture.create_from_image(image)
	queue_redraw()

static func build_image(field, job = null) -> Image:
	# A bounded survey texture keeps preview time independent of physical area.
	var dimensions = Vector2i(mini(field.NX,385),mini(field.NZ,513))
	if job: job.set_total(dimensions.y+ceili(float(Obstacles.count(field))/1024)+ceili(float(field.geology.placements.size())/128) if "geology" in field else dimensions.y+ceili(float(Obstacles.count(field))/1024))
	var image = Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8)
	var area: Rect2 = field.bounds()
	for z in dimensions.y:
		if job and job.is_cancelled(): return null
		for x in dimensions.x:
			var p = area.position+Vector2(float(x)/(dimensions.x-1),float(z)/(dimensions.y-1))*area.size
			if preload("res://scripts/world/mountain_footprint.gd").enabled(field) and not preload("res://scripts/world/mountain_footprint.gd").owns_cell(p): continue
			var n: Vector3 = field.contact_normal(p.x,p.y)
			var slope = rad_to_deg(acos(clampf(n.y,0,1)))
			var color = Color("d9e6e7").lerp(Color("e2ae70"),smoothstep(27,43,slope))
			color = color.lerp(Color("6d666c"),smoothstep(43,65,slope))
			if field.has_method("exposure_at"):
				var exposure = Color(0,0,0,1)
				if not "geology" in field: exposure = field.exposure_at(p.x,p.y)
				if "geology" in field:
					var pixel=(p-field.MASK_ORIGIN)/4.0
					exposure=field.exposure_image.get_pixel(clampi(roundi(pixel.x),0,field.NX-1),clampi(roundi(pixel.y),0,field.NZ-1))
				color = color.lerp(Color("535762") if exposure.r>.4 else Color("eaf4f5"),exposure.a)
				color = color.lerp(Color("87bbc9"),exposure.g)
			var shade = .67+maxf(0,n.dot(Vector3(-.5,1,-.4).normalized()))*.33
			if fposmod(field.height_at(p.x,p.y) if field.has_method("height_at") else field.sample(p.x,p.y).height,50)<2.0: shade *= .78
			color*=shade; color.a=1.0
			image.set_pixel(x,z,color)
		if job: job.advance()
	for id in Obstacles.count(field):
		if id%1024==0 and job:
			if job.is_cancelled(): return null
			job.advance()
		var position_value = Obstacles.position(field,id)
		var uv = (Vector2(position_value.x,position_value.z)-area.position)/area.size
		var x = clampi(roundi(uv.x*(dimensions.x-1)),0,dimensions.x-1)
		var z = clampi(roundi(uv.y*(dimensions.y-1)),0,dimensions.y-1)
		image.set_pixel(x,z,Color("456c62"))
	if "geology" in field:
		for id in field.geology.placements.size():
			if id%128==0 and job:
				if job.is_cancelled(): return null
				job.advance()
			var placed: Dictionary = field.geology.placements[id]
			var row: Dictionary=field.geology.catalog.records[placed.asset]
			if row.category=="small": continue
			var box: AABB=placed.pose*row.aabb
			var begin=(Vector2(box.position.x,box.position.z)-area.position)/area.size*Vector2(dimensions-Vector2i.ONE)
			var end=(Vector2(box.end.x,box.end.z)-area.position)/area.size*Vector2(dimensions-Vector2i.ONE)
			var rect=Rect2i(Vector2i(begin.floor()),Vector2i((end-begin).ceil()).max(Vector2i.ONE))
			image.fill_rect(rect.intersection(Rect2i(Vector2i.ZERO,dimensions)),Color("6babbf") if placed.ice else Color("5a626a"))
	return image

func _draw() -> void:
	draw_style_box(background,Rect2(Vector2.ZERO,size))
	if not texture or not terrain: return
	var ratio = terrain.bounds().size.x/terrain.bounds().size.y
	var height_value = minf(size.y-65,maxf(100,size.x-265)/ratio)
	var width_value = height_value*ratio
	var rect = Rect2(Vector2(maxf(24,(size.x-width_value-280)*.5),20),Vector2(width_value,height_value))
	draw_texture_rect(texture,rect,false)
	draw_rect(rect,Color("789395"),false,1)
	var label_x = rect.end.x+22
	var legend: Array = terrain.features
	if terrain.has_method("environment_weight"):
		# One readable label per face; the complete feature list still belongs to
		# terrain data and the survey, not a stack of overlapping legend text.
		legend = [{"name":"Summit · choose any direction","position":Vector2.ZERO}]
		for face in terrain.faces:
			var compass = ["South","South-east","East","North-east","North","North-west","West","South-west"][posmod(roundi(face.heading/(PI/4)),8)]
			legend.append({"name":"Face %d · %s" % [face.index+1,compass],"position":face.to_world(Vector2(0,1400))})
	for i in legend.size():
		var feature = legend[i]
		var p = rect.position+(feature.position-Vector2(terrain.X_MIN,terrain.Z_MIN))/terrain.bounds().size*rect.size
		var label_y = 42+i*(height_value-40)/maxi(1,legend.size())
		draw_circle(p,4,Color("c2e76b"))
		draw_line(p,Vector2(label_x-7,label_y-4),Color(.76,.9,.6,.4),1,true)
		if font: draw_string(font,Vector2(label_x,label_y),feature.name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("eef4f1"))
	if font: draw_string(font,Vector2(rect.position.x,size.y-7),("N ↑   SUMMIT → ALL FACES   /   50 m CONTOURS" if terrain.is_summit_mountain() else "SUMMIT ↓ LOWER BASIN    /    50 m CONTOURS"),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("9eb4bf"))

func _background() -> StyleBox:
	return background
