"""Small background-only GLB inspection renders; does not save source scenes."""
import argparse
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector

p=argparse.ArgumentParser()
p.add_argument('--source',required=True)
p.add_argument('--output',required=True)
p.add_argument('--body',action='store_true')
p.add_argument('--textured',action='store_true')
p.add_argument('--flat-normal',action='store_true')
args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
source_path=Path(args.source).resolve()
output_path=Path(args.output).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source_path))
if args.flat_normal:
    for mat in bpy.data.materials:
        if mat.name.startswith('SkierV7Gloves') and mat.node_tree:
            for node in mat.node_tree.nodes:
                if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=0
scene=bpy.context.scene
arm=next((o for o in scene.objects if o.type=='ARMATURE'),None)
shapes={b.custom_shape for b in arm.pose.bones if b.custom_shape} if arm else set()
meshes=[o for o in scene.objects if o.type=='MESH' and o not in shapes]
for o in shapes:o.hide_render=True
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
low=Vector(tuple(min(v[i] for v in points) for i in range(3)))
high=Vector(tuple(max(v[i] for v in points) for i in range(3)))
print('HAND_INSPECTION',json.dumps({'bounds':[list(low),list(high)],'meshes':[(o.name,len(o.data.polygons)) for o in meshes]}))
scene.render.engine='BLENDER_EEVEE' if args.textured else 'BLENDER_WORKBENCH'
shade=scene.display.shading
shade.light='STUDIO';shade.color_type='SINGLE';shade.single_color=(.45,.48,.52)
shade.show_shadows=True;shade.show_cavity=True;shade.cavity_type='BOTH';shade.background_type='WORLD'
scene.world=bpy.data.worlds.new('InspectionWorld');scene.world.color=(.08,.08,.08)
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.18,.18,1)
scene.view_settings.view_transform='AgX'
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
camera=bpy.data.objects.new('InspectionCamera',bpy.data.cameras.new('InspectionCamera'));scene.collection.objects.link(camera);scene.camera=camera
camera.data.type='ORTHO';camera.data.clip_start=.001
out=output_path;out.mkdir(parents=True,exist_ok=True)
if args.body:
    centers={side:arm.matrix_world@arm.data.bones[side+'Hand'].head_local+Vector((.048 if side=='Left' else -.048,-.008,.005)) for side in ['Left','Right']}
    scale=.245
    views={'back':(.18,-.32,.20),'palm':(.18,.30,-.12),'side':(.30,.015,.01)}
else:
    centers={'raw':(high+low)*.5};scale=max(high-low)*1.25
    views={'front':(0,-1,0),'back':(0,1,0),'right':(1,0,0),'left':(-1,0,0),'top':(0,0,1),'angle':(1,-1,.6)}
lights=[]
for i,power in enumerate([400,220,300]):
    data=bpy.data.lights.new('InspectionArea'+str(i),'AREA');data.energy=power;data.shape='DISK';data.size=2
    light=bpy.data.objects.new(data.name,data);scene.collection.objects.link(light);lights.append(light)
for side,center in centers.items():
    camera.data.ortho_scale=scale
    for i,light in enumerate(lights):
        light.location=center+Vector([(1,-2,2),(-2,-1,.5),(0,2,1)][i]);light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    for label,offset in views.items():
        direction=Vector(offset)
        if side=='Right':direction.x=-direction.x
        camera.location=center+direction.normalized()*max(1,scale*3)
        camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/(side+'_'+label+'.png'))
        bpy.ops.render.render(write_still=True)
