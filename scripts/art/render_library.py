"""Render the editable Blender library using its full authoring materials."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art_source/blender/alpine_library.blend'))
for obj in bpy.context.scene.objects:obj.hide_render=True
with bpy.data.libraries.load(str(ROOT/'art_source/blender/spruce_library.blend')) as (source,target):
    target.objects=[n for n in source.objects if n.endswith('_LOD0')]
for obj in target.objects:
    bpy.context.collection.objects.link(obj)
    obj.hide_render=False
for i in range(3):
    obj=bpy.data.objects[f'Spruce_{i+1}_LOD0'];obj.hide_render=False;obj.location=(i*7-7,2,0)
    obj=bpy.data.objects[f'Boulder{i+1}'];obj.hide_render=False;obj.location=(i*4-4,-3,0)
bpy.ops.mesh.primitive_plane_add(size=200)
ground=bpy.context.object;ground.name='QA Ground'
mat=bpy.data.materials.new('QA Snow');mat.diffuse_color=(.73,.79,.86,1);ground.data.materials.append(mat)
world=bpy.data.worlds.new('QA sky');world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Color'].default_value=(.30,.43,.65,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6;bpy.context.scene.world=world
data=bpy.data.lights.new('Sun','SUN');data.energy=2.0;sun=bpy.data.objects.new('Sun',data);bpy.context.collection.objects.link(sun);sun.rotation_euler=(.5,-.6,-.6);sun.data.angle=.08
data=bpy.data.cameras.new('Camera');camera=bpy.data.objects.new('Camera',data);bpy.context.collection.objects.link(camera)
camera.location=(17,-33,17);camera.rotation_euler=(Vector((0,0,4))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=27
scene=bpy.context.scene;scene.camera=camera;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1500;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.filepath=str(ROOT/'artifacts/graphics_blender_library.png');bpy.ops.render.render(write_still=True)
