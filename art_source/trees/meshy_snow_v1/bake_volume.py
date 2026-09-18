"""Transfer the aligned Meshy color texture onto a repaired branch mesh.

Blender 5.2, Exclusive guard. -- TEXTURED_SOURCE NEW_GEOMETRY OUTPUT
The material is baked without lighting; output embeds the resulting 2K map.
"""
import json
import math
import sys
from pathlib import Path
import bpy

textured, geometry, output = [Path(p).resolve() for p in sys.argv[sys.argv.index('--')+1:]]
assert output not in (textured,geometry)
bpy.ops.wm.read_factory_settings(use_empty=True)
def load(path):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return next(o for o in set(bpy.data.objects)-before if o.type=='MESH')
source=load(textured);target=load(geometry)
bpy.ops.object.select_all(action='DESELECT')
target.select_set(True);bpy.context.view_layer.objects.active=target
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.004)
bpy.ops.object.mode_set(mode='OBJECT')
material=bpy.data.materials.new('Rounded winter foliage');material.use_nodes=True
target.data.materials.clear();target.data.materials.append(material)
image=bpy.data.images.new('Snow foliage color',width=2048,height=2048,alpha=False)
image.generated_color=(.75,.8,.83,1)
nodes=material.node_tree.nodes
texture=nodes.new('ShaderNodeTexImage');texture.image=image;nodes.active=texture
principled=nodes.get('Principled BSDF');principled.inputs['Roughness'].default_value=.9
principled.inputs['Specular IOR Level'].default_value=.16
height=target.dimensions.z
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1
scene.render.threads_mode='FIXED';scene.render.threads=4
bake=scene.render.bake;bake.use_selected_to_active=True;bake.use_clear=False
bake.use_pass_direct=False;bake.use_pass_indirect=False;bake.use_pass_color=True
bake.cage_extrusion=height*.035;bake.max_ray_distance=height*.09;bake.margin=8
source.select_set(True)
print('BAKE_VOLUME_START',flush=True)
bpy.ops.object.bake(type='DIFFUSE')
material.node_tree.links.new(texture.outputs['Color'],principled.inputs['Base Color'])
image.pack()
bpy.ops.object.select_all(action='DESELECT');target.select_set(True)
bpy.context.view_layer.objects.active=target
output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,
    export_normals=True,export_tangents=True,export_materials='EXPORT',export_animations=False)
report=dict(textured_source=str(textured),geometry=str(geometry),output=str(output),
    texture_size=2048,triangles=sum(len(p.vertices)-2 for p in target.data.polygons),
    method='UV unwrap and diffuse-color-only selected-to-active projection',production_acceptance=False)
output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n')
print('BAKE_VOLUME_DONE',json.dumps(report),flush=True)
