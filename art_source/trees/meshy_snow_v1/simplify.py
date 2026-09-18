"""Build a distance mesh from the exact detailed tree, preserving its materials.

Blender 5.2, run through an Exclusive guard. Imported UVs are per-corner and stay
on the mesh when coincident positions are joined; there are no runtime branch
tags yet. Godot assigns those after this authoring step.
"""
import json
from pathlib import Path
import bmesh
import bpy

ROOT = Path(__file__).resolve().parent
SPECIES = {'spruce': 6000, 'fir': 6000, 'stone_pine': 5000, 'winter_birch_v2': 3500}
report = []
for species, target in SPECIES.items():
    source = ROOT / species / ('tree_detail.glb' if species != 'winter_birch_v2' else 'tree.glb')
    if not source.exists():
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert len(objects) == 1, 'Review multi-part source before reduction'
    obj = objects[0]
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    base_z = min(v.co.z for v in obj.data.vertices)
    top_z = max(v.co.z for v in obj.data.vertices)
    bm = bmesh.new(); bm.from_mesh(obj.data)
    # Imported hard normal/UV seams duplicate positions. Join topology while
    # retaining the per-corner UV layer, then rebuild the smooth tangent frame.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
    # More than two faces sharing an edge prevent Blender's collapse from
    # reaching its budget. Split those fans without moving positions or UVs.
    split_edges = [e for e in bm.edges if len(e.link_faces) > 2]
    split_count = len(split_edges)
    bmesh.ops.split_edges(bm, edges=split_edges)
    bm.to_mesh(obj.data); bm.free()
    obj.data.update()
    obj.data.validate(clean_customdata=False)
    modifier = obj.modifiers.new('Distance simplification', 'DECIMATE')
    modifier.decimate_type = 'COLLAPSE'
    modifier.ratio = min(1.0, target / before)
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    # Collapse can create duplicate/degenerate faces; clean before export so
    # the saved count describes the actual imported mesh.
    repaired = obj.data.validate(clean_customdata=False)
    obj.data.update()
    reduced_base = min(v.co.z for v in obj.data.vertices)
    reduced_top = max(v.co.z for v in obj.data.vertices)
    height_scale = (top_z-base_z)/(reduced_top-reduced_base)
    for vertex in obj.data.vertices:
        vertex.co.z = base_z+(vertex.co.z-reduced_base)*height_scale
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    after = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    output = ROOT / species / 'tree_local_mid.glb'
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB',
        use_selection=True, export_texcoords=True, export_normals=True,
        export_tangents=True, export_materials='EXPORT', export_animations=False)
    report.append({'species': species, 'source': source.name, 'output': output.name,
        'target_triangles': target, 'source_triangles': before, 'triangles': after,
        'split_nonmanifold_edges': split_count, 'collapse_cleanup': repaired,
        'height_scale_to_preserve_root_and_tip': height_scale,
        'method': 'UV-preserving topology join, split nonmanifold fans, local collapse, smooth normals'})
    print('SNOW_LOCAL_LOD', report[-1])
(ROOT / 'local_lods.json').write_text(json.dumps(report, indent=2) + '\n')
