extends RefCounted
## Reversible, process-local forest representation. Does not write production assets.
const PREP="res://artifacts/meshy_snow_20260918/prepared"
const SPECIES={"spruce":"spruce","fir":"fir","pine":"stone_pine","birch":"winter_birch_v2","golden":"winter_birch_v2","maple":"winter_birch_v2"}
var assets
var forest
var scenery
var source={}
var original={}
var replacement={}
var inventory=[]
var active=false
func setup(world):
	assets=world.assets;scenery=world.scenery;forest=scenery.density_forest
	for species in SPECIES.values():
		if source.has(species):continue
		var lods=[]
		for lod in 2:
			var mesh:Mesh=load(PREP+"/"+species+"_"+str(lod)+".res")
			var source_mat:StandardMaterial3D=mesh.surface_get_material(0)
			var mat=ShaderMaterial.new();mat.shader=load(PREP+"/pc_forest_tree_snow_"+str(lod)+".gdshader")
			mat.resource_name="MeshySnow_"+species+"_"+str(lod);mat.render_priority=-20 if lod==0 else -10
			mat.set_shader_parameter("mesh_albedo",load(PREP+"/"+species+"_albedo.res"))
			mat.set_shader_parameter("mesh_roughness",load(PREP+"/"+species+"_roughness.res"))
			mat.set_shader_parameter("roughness_channel",source_mat.roughness_texture_channel)
			if lod==0:mat.set_shader_parameter("mesh_normal",load(PREP+"/"+species+"_normal.res"))
			assets.wind_receivers.append(mat);assets.sight_receivers.append(mat);assets.lighting.register(mat)
			lods.append({"mesh":mesh,"mat":mat,"image":source_mat.albedo_texture.get_image()})
			if lods[-1].image.is_compressed():assert(lods[-1].image.decompress()==OK)
		var far=ShaderMaterial.new();far.shader=load("res://assets/graphics/pc_tree_impostor.gdshader");far.render_priority=-5
		far.resource_name="FC_Impostor_MeshySnow_"+species
		far.set_shader_parameter("albedo_texture",load(PREP+"/"+species+"_atlas.res"));far.set_shader_parameter("card_crop",.64)
		far.set_shader_parameter("pc_detail_residency",forest.residency_texture)
		assets.sight_receivers.append(far);assets.lighting.register(far)
		source[species]={"lods":lods,"far":far}
	for id in assets.tree_ids():
		var record:Dictionary=assets.tree_record(id)
		if not SPECIES.has(record.family):continue
		var species:String=SPECIES[record.family];var box=assets.mesh(id+"_lod0").get_aabb()
		var srcbox=source[species].lods[0].mesh.get_aabb()
		# Keep exact original height/root and fit the existing crown envelope.
		var scale_m=Vector3(box.size.x/srcbox.size.x,box.size.y/12.0,box.size.z/srcbox.size.z)
		for lod in 3:
			var key=id+"_lod"+str(lod);original[key]=assets.mesh(key)
			var mesh:Mesh=detail(id,record,species,lod,scale_m,box.position.y) if lod<2 else card(species,scale_m,box.position.y)
			mesh.set_meta("forest_asset",id);replacement[key]=mesh
			inventory.append({"asset":id,"species":species,"lod":lod,"original_triangles":original[key].surface_get_array_index_len(0)/3,"candidate_triangles":mesh.surface_get_array_index_len(0)/3,"original_vertices":original[key].surface_get_array_len(0),"candidate_vertices":mesh.surface_get_array_len(0)})
func detail(id:String,record:Dictionary,species:String,lod:int,scale_m:Vector3,bottom:float)->Mesh:
	var data:Dictionary=source[species].lods[lod];var a:Array=data.mesh.surface_get_arrays(0).duplicate(true)
	var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var n:PackedVector3Array=a[Mesh.ARRAY_NORMAL];var t:PackedFloat32Array=a[Mesh.ARRAY_TANGENT];var uv:PackedVector2Array=a[Mesh.ARRAY_TEX_UV]
	var tags=PackedVector2Array();tags.resize(v.size());var colors=PackedColorArray();colors.resize(v.size())
	for i in v.size():
		v[i]=v[i]*scale_m+Vector3(0,bottom,0);n[i]=(n[i]/scale_m).normalized()
		var tangent=(Vector3(t[i*4],t[i*4+1],t[i*4+2])*scale_m).normalized();t[i*4]=tangent.x;t[i*4+1]=tangent.y;t[i*4+2]=tangent.z
		var im:Image=data.image;var px=im.get_pixel(clampi(int(uv[i].x*im.get_width()),0,im.get_width()-1),clampi(int(uv[i].y*im.get_height()),0,im.get_height()-1))
		var snow=minf(px.r,minf(px.g,px.b))>.55 and maxf(px.r,maxf(px.g,px.b))-minf(px.r,minf(px.g,px.b))<.20
		var wood=not snow and (Vector2(v[i].x,v[i].z).length()<.12*record.height_m/6.0 or px.r>px.g*1.08)
		colors[i]=Color(1,1,1,1.0 if snow else (0.0 if wood else .55))
		var best=INF;var branch=0
		for j in record.branches.size():
			var c=record.branches[j].center;var d=v[i].distance_squared_to(Vector3(c[0],c[1],c[2]))
			if d<best:best=d;branch=j
		tags[i]=Vector2(float(branch)/16,float(record.branches[branch].pivot_y)/32)
	a[Mesh.ARRAY_VERTEX]=v;a[Mesh.ARRAY_NORMAL]=n;a[Mesh.ARRAY_TANGENT]=t;a[Mesh.ARRAY_COLOR]=colors;a[Mesh.ARRAY_TEX_UV2]=tags
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);mesh.surface_set_material(0,data.mat);return mesh
func card(species:String,scale_m:Vector3,bottom:float)->Mesh:
	# Atlas covers a 13.8 m square around the normalized 12 m source.
	var width=13.8*maxf(scale_m.x,scale_m.z);var height=13.8*scale_m.y;var center=6*scale_m.y+bottom
	var a=[];a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-width*.5,center-height*.5,0),Vector3(width*.5,center-height*.5,0),Vector3(width*.5,center+height*.5,0),Vector3(-width*.5,center+height*.5,0)])
	a[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD])
	a[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
	a[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,0,3,2])
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);mesh.surface_set_material(0,source[species].far);return mesh
func select(candidate:bool):
	var selected=replacement if candidate else original
	var shadows={}
	for node in scenery.batches:
		if is_instance_valid(node) and int(node.get_meta("art_lod",-1))==5:shadows[node.multimesh.get_rid()]=true
	for key in selected:
		assets.meshes[key]=selected[key];forest.prepared_meshes[key.replace("_lod",":")]=selected[key]
	for node in scenery.batches:
		if not is_instance_valid(node) or not node.has_meta("art_lod"):continue
		var lod=int(node.get_meta("art_lod"));var id=str(node.multimesh.mesh.get_meta("forest_asset",""));var key=id+"_lod"+str(lod)
		if not selected.has(key):continue
		# Original bare birches share their middle MultiMesh with the shadow
		# proxy. Detach the visible resource before changing its mesh.
		if shadows.has(node.multimesh.get_rid()):node.multimesh=node.multimesh.duplicate()
		node.multimesh.mesh=selected[key]
	# Prepared caches are indexed by Mesh. The active MultiMeshes can be rekeyed
	# without reconstructing transforms or changing the residency algorithm.
	for region in forest.regions.values():
		for id in region:
			var group:Dictionary=region[id]
			var prepared=[group.prepared]
			for child in group.detail_groups:prepared.append(child.prepared)
			for p in prepared:
				var updated={}
				for mm in p.multimeshes.values():updated[mm.mesh]=mm
				p.multimeshes=updated
	active=candidate
