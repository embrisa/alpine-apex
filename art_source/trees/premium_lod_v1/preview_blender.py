"""Small authoring contact sheet; native Godot review remains authoritative."""
from pathlib import Path
import bpy
from mathutils import Vector

pack=Path(__file__).resolve().parent
root=pack.parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.render.threads_mode='FIXED'
scene.render.threads=6
scene.render.resolution_x=1600
scene.render.resolution_y=900
scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Alpine ambient')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.46,.55,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for i,family in enumerate(('spruce','fir','pine')):
    name=f'forest_{family}_02_lod0'
    with bpy.data.libraries.load(str(pack/'blends'/f'forest_{family}_02.blend'),link=False) as (source,data):
        data.objects=[name]
    obj=data.objects[0]
    scene.collection.objects.link(obj)
    obj.hide_render=False
    obj.hide_set(False)
    obj.location.x=(i-1)*9
bpy.ops.mesh.primitive_plane_add(size=200)
floor=bpy.context.object
mat=bpy.data.materials.new('Snow ground')
mat.diffuse_color=(.69,.77,.82,1)
floor.data.materials.append(mat)
bpy.ops.object.light_add(type='SUN',location=(5,-8,15))
sun=bpy.context.object
sun.rotation_euler=(.5,-.6,-.5)
sun.data.energy=2.2
sun.data.angle=.10
bpy.ops.object.camera_add(location=(15,-45,16))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,5.0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=34
scene.camera=camera
out=root/'artifacts/premium_tree_review/pilot_blender.png'
scene.render.filepath=str(out)
bpy.ops.render.render(write_still=True)
print('PREMIUM_AUTHORING_PREVIEW',out,flush=True)
