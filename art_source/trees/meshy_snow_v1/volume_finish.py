"""Rebuild fine branch detail as rounded volumes before the final reduction.

Blender 5.2, Exclusive guard. Pass -- SOURCE OUTPUT after Blender arguments.
Only a new authoring output is written; source and runtime files are untouched.
"""
import json
import argparse
import sys
from pathlib import Path
import bpy

parser=argparse.ArgumentParser()
parser.add_argument('source',type=Path)
parser.add_argument('output',type=Path)
parser.add_argument('--triangles',type=int,default=40000)
parser.add_argument('--voxels-per-height',type=float,default=120)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
source,output=args.source.resolve(),args.output.resolve()
assert args.triangles>0 and args.voxels_per_height>0
assert source != output
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
height = max(v.co.z for v in obj.data.vertices)-min(v.co.z for v in obj.data.vertices)
before = sum(len(p.vertices)-2 for p in obj.data.polygons)
remesh = obj.modifiers.new('Merge fine needles into branch volumes', 'REMESH')
remesh.mode = 'VOXEL'
remesh.voxel_size = height / args.voxels_per_height
remesh.use_smooth_shade = True
bpy.ops.object.modifier_apply(modifier=remesh.name)
smooth = obj.modifiers.new('Round rebuilt snow surfaces', 'SMOOTH')
smooth.factor = .55
smooth.iterations = 3
bpy.ops.object.modifier_apply(modifier=smooth.name)
reconstructed = sum(len(p.vertices)-2 for p in obj.data.polygons)
decimate = obj.modifiers.new('Close detail budget', 'DECIMATE')
decimate.ratio = min(1,args.triangles/reconstructed)
decimate.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=decimate.name)
finish = obj.modifiers.new('Round collapsed needle tips', 'SMOOTH')
finish.factor = .25
finish.iterations = 2
bpy.ops.object.modifier_apply(modifier=finish.name)
repaired = obj.data.validate(clean_customdata=False)
obj.data.update()
for polygon in obj.data.polygons: polygon.use_smooth = True
after = sum(len(p.vertices)-2 for p in obj.data.polygons)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,
    export_normals=True,export_materials='EXPORT',export_animations=False)
report=dict(source=str(source),output=str(output),source_triangles=before,
    reconstructed_triangles=reconstructed,triangles=after,
    target_triangles=args.triangles,voxels_per_height=args.voxels_per_height,
    voxel_size_at_12m=12/args.voxels_per_height,normal_smoothing=True,cleanup_repaired=repaired,production_acceptance=False)
output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n')
print('VOLUME_FINISH',json.dumps(report),flush=True)
