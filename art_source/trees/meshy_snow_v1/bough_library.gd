extends "res://art_source/trees/meshy_snow_v1/library.gd"
## Preserve whole-bough pivots instead of assigning nearby branches per vertex.
func detail(id:String,record:Dictionary,species:String,lod:int,scale_m:Vector3,bottom:float)->Mesh:
	var data:Dictionary=source[species].lods[lod]
	if not data.mesh.has_meta("authored_boughs"):
		return super.detail(id,record,species,lod,scale_m,bottom)
	var a:Array=data.mesh.surface_get_arrays(0).duplicate(true)
	var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var n:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	var t:PackedFloat32Array=a[Mesh.ARRAY_TANGENT];var tags:PackedVector2Array=a[Mesh.ARRAY_TEX_UV2]
	assert(tags.size()==v.size())
	var centers={};var mapped={}
	for i in v.size():
		v[i]=v[i]*scale_m+Vector3(0,bottom,0)
	# Both LODs map contacts from the same detailed bough centers. Simplification
	# changes vertex distribution and must not pick a different physical spring.
	var reference:Array=source[species].lods[0].mesh.surface_get_arrays(0)
	var rv:PackedVector3Array=reference[Mesh.ARRAY_VERTEX];var rt:PackedVector2Array=reference[Mesh.ARRAY_TEX_UV2]
	for i in rv.size():
		if not centers.has(rt[i]):centers[rt[i]]={"sum":Vector3.ZERO,"count":0}
		centers[rt[i]].sum+=rv[i]*scale_m+Vector3(0,bottom,0);centers[rt[i]].count+=1
	for tag in centers:
		var center:Vector3=centers[tag].sum/centers[tag].count
		var best=INF;var branch=0
		for j in record.branches.size():
			var c=record.branches[j].center;var d=center.distance_squared_to(Vector3(c[0],c[1],c[2]))
			if d<best:best=d;branch=j
		mapped[tag]=Vector2(float(branch)/16.0,(tag.y*32.0*scale_m.y+bottom)/32.0)
	for i in v.size():
		n[i]=(n[i]/scale_m).normalized()
		var tangent=(Vector3(t[i*4],t[i*4+1],t[i*4+2])*scale_m).normalized()
		t[i*4]=tangent.x;t[i*4+1]=tangent.y;t[i*4+2]=tangent.z
		tags[i]=mapped[tags[i]]
	a[Mesh.ARRAY_VERTEX]=v;a[Mesh.ARRAY_NORMAL]=n;a[Mesh.ARRAY_TANGENT]=t;a[Mesh.ARRAY_TEX_UV2]=tags
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	mesh.surface_set_material(0,data.mat);return mesh
