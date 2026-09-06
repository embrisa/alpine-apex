"""Export standalone PBR GLBs alongside the geometry-only Godot batch assets."""
import bpy,json,hashlib,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art_source/reusable';OUT.mkdir(exist_ok=True)
exports=[]
def export(obj,name):
 bpy.ops.object.select_all(action='DESELECT');obj.hide_set(False);obj.select_set(True)
 obj.location=(0,0,0);bpy.context.view_layer.objects.active=obj
 obj.data.calc_loop_triangles();count=len(obj.data.loop_triangles)
 path=OUT/f'{name}.glb'
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False)
 exports.append({'path':str(path.relative_to(ROOT)),'triangles':count})
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art_source/blender/alpine_library.blend'))
for source,name in [('Boulder1','boulder1'),('Boulder2','boulder2'),('Boulder3','boulder3'),('Scrub','scrub_1'),('Scrub.001','scrub_2')]:
 assert source in bpy.data.objects, f'Missing source object: {source}'
 export(bpy.data.objects[source],name)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art_source/blender/spruce_library.blend'))
mat=bpy.data.materials.new('Spruce PBR');mat.use_nodes=True
p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Metallic'].default_value=0
for channel,socket in [('albedo','Base Color'),('normal','Normal'),('roughness','Roughness')]:
 image=bpy.data.images.load(str(ROOT/f'assets/graphics/textures/spruce_model_{channel}.jpg'),check_existing=True)
 if channel!='albedo':image.colorspace_settings.name='Non-Color'
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
 if channel=='normal':
  normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.5
  mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],p.inputs[socket])
 else:mat.node_tree.links.new(tex.outputs['Color'],p.inputs[socket])
for variant in range(1,4):
 for lod in range(2):
  obj=bpy.data.objects[f'Spruce_{variant}_LOD{lod}'];obj.data.materials.clear();obj.data.materials.append(mat)
  export(obj,f'spruce_{variant}_lod{lod}')
for entry in exports:
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(ROOT/entry['path']))
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
 assert len(objects)==1
 obj=objects[0];obj.data.calc_loop_triangles()
 assert len(obj.data.loop_triangles)==entry['triangles']
 assert all(o.type in ['MESH','EMPTY'] for o in bpy.context.scene.objects)
 assert obj.data.materials
 data=(ROOT/entry['path']).read_bytes();length=struct.unpack_from('<I',data,12)[0]
 gltf=json.loads(data[20:20+length]);assert gltf.get('images'), f'Missing embedded textures: {entry["path"]}'
 assert all('bufferView' in image for image in gltf['images'])
 entry['roundtrip_verified']=True;entry['materials']=[m.name for m in obj.data.materials];entry['dimensions_m']=list(obj.dimensions)
 entry['embedded_images']=len(gltf['images']);entry['sha256']=hashlib.sha256(data).hexdigest()
(OUT/'manifest.json').write_text(json.dumps({'units':'metres','up_axis':'Y in GLB, Z in Blender','dimensions_basis':'Blender X/Y/Z after reimport','note':'Standalone PBR. Godot applies additional snow/exposure and foliage-tint shaders. Skier/equipment GLBs in assets/graphics/models are already standalone.','assets':exports},indent=2))
print('REUSABLE_LIBRARY',len(exports),'round-trip verified GLBs')
