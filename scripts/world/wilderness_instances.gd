extends RefCounted
## Reuse authored transforms; adapt only baked triangle anchors on the join.
const TREE_IDS = ["forest_spruce_03", "forest_fir_02", "forest_pine_03"]
const ROCK_IDS = ["pc_rock_boulder_1", "rock_boulder_2", "rock_gneiss_1"]
const NEAR_TILE_M = 256.0
var groups: Array[Dictionary] = []
var counts: Dictionary
var fingerprint = ""
var build_ms = 0.0
var ready = false
var seating_error_m = 0.0
var adapted_instances = 0
func build(preset: Dictionary, apron: Array, job = null) -> void:
	var started=Time.get_ticks_usec()
	groups.clear(); ready=false; adapted_instances=0
	assert(apron.size()==preset.apron_count,"Authored anchors require matching apron topology")
	counts=preset.counts.duplicate(); seating_error_m=preset.seating_error_m
	var context=HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	for source in preset.groups:
		if job and job.is_cancelled(): return
		var group: Dictionary={"kind":source.kind,"asset":source.asset,"buffer":source.buffer.duplicate()}
		var buffer: PackedFloat32Array=group.buffer
		var anchors: PackedFloat32Array=source.anchors
		for i in buffer.size()/16:
			var anchor=i*6; var source_index=int(anchors[anchor])
			if source_index>=apron.size(): continue
			var vertices: PackedVector3Array=apron[source_index][Mesh.ARRAY_VERTEX]
			var a=vertices[int(anchors[anchor+1])]; var b=vertices[int(anchors[anchor+2])]; var c=vertices[int(anchors[anchor+3])]
			var v=anchors[anchor+4]; var w=anchors[anchor+5]
			var height=a.y*(1.0-v-w)+b.y*v+c.y*w
			var offset=i*16
			if absf(buffer[offset+7]-height)>.02: adapted_instances+=1
			buffer[offset+7]=height
			if source.kind=="rock":
				var normal=(b-a).cross(c-a).normalized()
				if normal.y<0.0: normal=-normal
				var old=Basis(Vector3(buffer[offset],buffer[offset+4],buffer[offset+8]),Vector3(buffer[offset+1],buffer[offset+5],buffer[offset+9]),Vector3(buffer[offset+2],buffer[offset+6],buffer[offset+10]))
				var up=Vector3.UP.lerp(normal,.7).normalized()
				var right=Vector3(old.x.x,0,old.x.z).slide(up).normalized()
				var basis=Basis(right,up,right.cross(up)).scaled(Vector3(old.x.length(),old.y.length(),old.z.length()))
				buffer[offset]=basis.x.x; buffer[offset+4]=basis.x.y; buffer[offset+8]=basis.x.z
				buffer[offset+1]=basis.y.x; buffer[offset+5]=basis.y.y; buffer[offset+9]=basis.y.z
				buffer[offset+2]=basis.z.x; buffer[offset+6]=basis.z.y; buffer[offset+10]=basis.z.z
		group.buffer=buffer
		if group.kind=="near": _partition_near(group)
		else: groups.append(group)
		context.update(buffer.to_byte_array())
	fingerprint=context.finish().hex_encode()
	ready=true; build_ms=(Time.get_ticks_usec()-started)/1000.0

func _partition_near(group: Dictionary) -> void:
	# The authored kilometre tiles work for cards and rocks. Detailed conifers
	# need tighter culling: otherwise whole groves run their vertex shaders even
	# when every trunk is beyond the per-instance fade. Preserve every baked pose.
	var tiles: Dictionary={}
	var buffer: PackedFloat32Array=group.buffer
	for i in buffer.size()/16:
		var offset=i*16
		var cell=Vector2i((Vector2(buffer[offset+3],buffer[offset+11])/NEAR_TILE_M).floor())
		var values: PackedFloat32Array=tiles.get(cell,PackedFloat32Array())
		values.append_array(buffer.slice(offset,offset+16)); tiles[cell]=values
	for values in tiles.values(): groups.append({"kind":"near","asset":group.asset,"buffer":values})
