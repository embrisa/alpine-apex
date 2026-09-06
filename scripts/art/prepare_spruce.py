"""Create three botanical derivatives, authored LODs and shared texture bindings."""
import bpy, bmesh, json, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'art_source/meshy/spruce.glb'))
source=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.context.view_layer.objects.active=source
bpy.ops.object.select_all(action='DESELECT');source.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# Imported UV/normal seams split vertices. Weld before reduction so branches
# remain continuous instead of collapsing into disconnected triangular shards.
bm=bmesh.new();bm.from_mesh(source.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.to_mesh(source.data);bm.free()
bottom=min(v.co.z for v in source.data.vertices)
height=max(v.co.z for v in source.data.vertices)-bottom
for v in source.data.vertices:v.co=(v.co-Vector((0,0,bottom)))*(10.5/height)
base=[v.co for v in source.data.vertices if v.co.z<.5]
center=Vector(((min(v.x for v in base)+max(v.x for v in base))*.5,(min(v.y for v in base)+max(v.y for v in base))*.5,0))
for v in source.data.vertices:v.co-=center
radius=max(Vector((v.co.x,v.co.y)).length for v in source.data.vertices if v.co.z<.5)
for v in source.data.vertices:
 strength=max(0,1-v.co.z/1.8)
 factor=1+(.44/radius-1)*strength
 v.co.x*=factor;v.co.y*=factor
for p in source.data.polygons:p.use_smooth=True
source.name='Spruce_Source'
source.data.materials[0].name='SprucePBR_Source'
source.hide_render=True;source.hide_set(True)
placeholder=bpy.data.materials.new('Spruce.Runtime');placeholder.use_nodes=True
stats=[];exports=[]
for variant in range(1,4):
 for lod,target in enumerate([18000,6500,1800]):
  obj=bpy.data.objects.new(f'Spruce_{variant}_LOD{lod}',source.data.copy());bpy.context.collection.objects.link(obj)
  for v in obj.data.vertices:
   z=max(0,min(1,v.co.z/10.5));angle=(variant-1)*.65+math.sin(z*8+variant)*.12*z
   x,y=v.co.x,v.co.y
   # Keep the trunk footprint; variation is concentrated in the upper crown.
   spread=1+(variant-2)*.09*z
   v.co.x=(x*math.cos(angle)-y*math.sin(angle))*spread
   v.co.y=(x*math.sin(angle)+y*math.cos(angle))*(2-spread)
  bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
  obj.data.calc_loop_triangles()
  dec=obj.modifiers.new('Authored foliage LOD','DECIMATE');dec.ratio=target/len(obj.data.loop_triangles)
  bpy.ops.object.modifier_apply(modifier=dec.name)
  low=min(v.co.z for v in obj.data.vertices);high=max(v.co.z for v in obj.data.vertices)
  for v in obj.data.vertices:v.co.z=(v.co.z-low)*10.5/(high-low)
  obj.data.calc_loop_triangles()
  mats=list(obj.data.materials);obj.data.materials.clear();obj.data.materials.append(placeholder)
  path=ROOT/f'assets/graphics/models/spruce_{variant}_lod{lod}.glb'
  bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False)
  obj.data.materials.clear()
  for m in mats:obj.data.materials.append(m)
  stats.append(dict(name=obj.name,triangles=len(obj.data.loop_triangles),dimensions=list(obj.dimensions)))
  exports.append(path)
  obj.hide_render=lod!=0;obj.location.x=(variant-2)*7
source.hide_render=True
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/blender/spruce_library.blend'))
for path,stat in zip(exports,stats):
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(path))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 assert len(meshes)==1
 obj=meshes[0];obj.data.calc_loop_triangles()
 assert len(obj.data.loop_triangles)==stat['triangles']
 assert abs(obj.dimensions.z-10.5)<.08
 assert obj.data.materials[0].name.startswith('Spruce.Runtime')
 stat['roundtrip_verified']=True
(ROOT/'art_source/blender/spruce_qa.json').write_text(json.dumps(stats,indent=2))
print('SPRUCE_LIBRARY',json.dumps(stats))
