"""Normalize and reduce Meshy whole-tree sources, preserving UVs and root frames.

Blender 5.2 under Exclusive guard. -- SOURCE OUTPUT [--near N --mid N]
Raw source is never overwritten. Both LODs share one normalized source frame.
"""
import argparse
import json
import sys
from pathlib import Path
import bmesh
import bpy
from mathutils import Matrix, Vector

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--near', type=int, default=24000)
parser.add_argument('--mid', type=int, default=4500)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
args.output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(args.source.resolve()))
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert len(objects) == 1, 'Review multipart source before packaging'
source = objects[0]
source.data.transform(source.matrix_world)
source.parent = None
source.matrix_world = Matrix.Identity(4)
# Full-topology Meshy foliage can contain millions of micro triangles. Reduce
# once in Blender before Python-side frame/LOD work; preserve its source UVs.
source_count=sum(len(p.vertices)-2 for p in source.data.polygons)
if source_count>300000:
    print('SEASONAL_DENSE_SOURCE',source_count,flush=True)
    bpy.context.view_layer.objects.active=source
    preliminary=source.modifiers.new('Authoring working mesh','DECIMATE')
    preliminary.ratio=300000/source_count;preliminary.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=preliminary.name)
    print('SEASONAL_WORKING_MESH',sum(len(p.vertices)-2 for p in source.data.polygons),flush=True)
coords = [v.co.copy() for v in source.data.vertices]
bottom = min(v.z for v in coords)
height = max(v.z for v in coords) - bottom
roots = [v for v in coords if v.z < bottom + height * .015]
center = sum(roots, Vector()) / len(roots)
frame = Vector((center.x, center.y, bottom))
for vertex in source.data.vertices:
    vertex.co = (vertex.co - frame) * (12 / height)
source.data.update()
report = {'source': str(args.source), 'frame': {'origin': list(frame), 'height': height}, 'lods': []}
for lod, target in enumerate([args.near, args.mid]):
    bpy.ops.object.select_all(action='DESELECT')
    obj = source.copy(); obj.data = source.data.copy()
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj; obj.select_set(True)
    before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    bm = bmesh.new(); bm.from_mesh(obj.data)
    # Full foliage contains intentional overlapping leaf surfaces. Welding and
    # splitting these first strands many tiny components that cannot collapse.
    if source_count <= 300000:
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.000001)
        bmesh.ops.split_edges(bm, edges=[e for e in bm.edges if len(e.link_faces) > 2])
    bm.to_mesh(obj.data); bm.free()
    modifier = obj.modifiers.new('Bounded distance mesh', 'DECIMATE')
    modifier.ratio = min(1, target / before); modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.validate(clean_customdata=False)
    for polygon in obj.data.polygons: polygon.use_smooth = True
    # Whole-tree materials retain Meshy bark instead of the legacy bark override.
    # Contact tags are bound offline to the physical catalogue at packaging.
    output = args.output / ('tree_lod%d.glb' % lod)
    bpy.ops.export_scene.gltf(filepath=str(output.resolve()), export_format='GLB',
        use_selection=True, export_texcoords=True, export_normals=True,
        export_tangents=True, export_materials='EXPORT', export_animations=False)
    report['lods'].append({'lod': lod, 'triangles': sum(len(p.vertices)-2 for p in obj.data.polygons),
        'target': target, 'path': str(output), 'bounds': [list(min(v.co[i] for v in obj.data.vertices) for i in range(3)),
        list(max(v.co[i] for v in obj.data.vertices) for i in range(3))]})
    bpy.data.objects.remove(obj, do_unlink=True)
(args.output / 'prepare.json').write_text(json.dumps(report, indent=2) + '\n')
print('SEASONAL_WHOLE_READY', json.dumps(report), flush=True)
