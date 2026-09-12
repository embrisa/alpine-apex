"""Original, standalone blade meshes. Writes only the prepared grass package.

Use scripts/prepare_foliage_assets.ps1; no game import, terrain or shader changes.
The existing rock-generator image is recorded as an inspected reference, not
copied or embedded. All geometry is generated here from the editable recipes.
"""
import argparse
import hashlib
import json
import math
import random
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art_source/foliage/grass_v1'
PIVOT_SPAN = 1.0


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def linear(color):
    return tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in color)


def mix(a, b, t):
    return tuple(x * (1 - t) + y * t for x, y in zip(a, b))


def blade_recipes(recipe):
    rng = random.Random(recipe['seed'])
    result = []
    for index in range(recipe['blades']):
        angle = index * 2.399963229728653 + rng.uniform(-.25, .25)
        radius = recipe['radius'] * math.sqrt(rng.random())
        h = recipe['height'] * rng.uniform(.52, 1.04)
        result.append(dict(index=index, angle=angle, root=Vector((math.cos(angle)*radius, math.sin(angle)*radius, 0)),
                           height=h, width=recipe['width']*rng.uniform(.55, 1.18),
                           bend=recipe['bend']*rng.uniform(.55, 1.3), twist=rng.uniform(-.6, .6),
                           tip=rng.uniform(.02, .14), phase=rng.random(), snow=rng.random(),
                           tint=rng.random()))
    # Keep the tallest blades in every LOD; order the others deterministically.
    tallest = max(result, key=lambda b: b['height'])
    result.remove(tallest)
    return [tallest] + result


def cross_section(blade, t, snow=False, finish='green'):
    a = blade['angle']
    direction = Vector((math.cos(a), math.sin(a), 0))
    side = Vector((-math.sin(a), math.cos(a), 0))
    h = blade['height']
    bend = blade['bend']
    center = blade['root'] + direction*h*bend*t*t
    center += side * math.sin(t*math.pi)*h*.07*blade['twist']
    center.z = h*(t - blade['tip']*t**5)
    angle = blade['twist'] * t
    across = side * math.cos(angle) + direction * math.sin(angle)
    normal = (Vector((0, 0, 1))*2*bend*t-direction).normalized()
    width = blade['width'] * (.36 + .64*math.sin(math.pi*t*.85)) * max(0.0, 1-t)**.60
    if snow:
        width *= .76 + .09*math.sin(t*33+blade['phase']*8)
        center += normal * (.00065 if finish == 'dusted' else .00125)
    ridge = width * (.19 if not snow else .27)
    return [center-across*width*.5, center+normal*ridge, center+across*width*.5]


class GrassMesh:
    def __init__(self):
        self.vertices, self.faces, self.colors, self.uv, self.pivots = [], [], [], [], []
        self.base_triangles, self.snow_triangles = 0, 0

    def ribbon(self, blade, segments, finish, snow=False):
        start = 0.0
        if snow:
            start = (.43 + blade['phase']*.28) if finish == 'dusted' else (.13 + blade['phase']*.15)
        ring_ids = []
        ts = [start+(1-start)*i/segments for i in range(segments+1)]
        for i, t in enumerate(ts):
            points = cross_section(blade, t, snow, finish)
            if i == segments:
                points = [points[1]]
            ids = []
            for column, point in enumerate(points):
                if snow:
                    rgb = mix((.67, .74, .76), (.94, .965, .97), .53 + .40*t)
                    rgb = tuple(c*(.96 if column == 0 else 1.0) for c in rgb)
                else:
                    green = mix((.32, .48, .11), (.49, .63, .23), blade['tint'])
                    rgb = mix((.29, .28, .12), green, min(1, t*5))
                    rgb = mix(rgb, (.61, .64, .29), max(0, (t-.72)*1.6)*blade['phase'])
                    rgb = tuple(c*(1.05 if column == 1 else .94) for c in rgb)
                    if finish != 'green':
                        rgb = mix(rgb, (.48, .53, .32), .28 if finish == 'snow' else .12)
                        # Frost wraps coated blades so reverse views retain the
                        # snowy finish; raised upper strips still carry relief.
                        if blade['snow'] < (.55 if finish == 'dusted' else .94):
                            frost = min(1,max(0,(t-(.43 if finish == 'dusted' else .12))/.28))
                            rgb = mix(rgb,(.78,.84,.85),frost*(.33 if finish == 'dusted' else .88))
                ids.append(len(self.vertices))
                self.vertices.append(tuple(point))
                self.colors.append((*linear(rgb), 1.0))
                # glTF flips Blender V: exported UV0.y is root-to-tip t.
                self.uv.append((.5 if i == segments else column*.5, 1-t))
                self.pivots.append((blade['root'].x/PIVOT_SPAN+.5, .5-blade['root'].y/PIVOT_SPAN))
            ring_ids.append(ids)
        count = 0
        for i in range(segments):
            a, b = ring_ids[i], ring_ids[i+1]
            for column in range(2):
                if len(b) == 1:
                    self.faces.append((a[column], b[0], a[column+1]))
                    count += 1
                else:
                    self.faces.extend([(a[column], b[column], b[column+1]), (a[column], b[column+1], a[column+1])])
                    count += 2
        if snow:
            self.snow_triangles += count
        else:
            self.base_triangles += count

    def object(self, name, material):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        colors = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
        uv = mesh.uv_layers.new(name='BladeCoordinates')
        pivot = mesh.uv_layers.new(name='RootPivot')
        for face in mesh.polygons:
            face.use_smooth = True
            for li in face.loop_indices:
                vi = mesh.loops[li].vertex_index
                colors.data[li].color = self.colors[vi]
                uv.data[li].uv = self.uv[vi]
                pivot.data[li].uv = self.pivots[vi]
        mesh.materials.append(material)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj['asset_role'] = 'grass_only'
        obj['pivot_span_m'] = PIVOT_SPAN
        obj['base_triangles'] = self.base_triangles
        obj['snow_triangles'] = self.snow_triangles
        return obj


def material():
    result = bpy.data.materials.new('PreparedGrass_VertexPBR')
    result.use_nodes = True
    result.use_backface_culling = False
    bsdf = result.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = .86
    bsdf.inputs['Specular IOR Level'].default_value = .22
    colors = result.node_tree.nodes.new('ShaderNodeVertexColor')
    colors.layer_name = 'Color'
    result.node_tree.links.new(colors.outputs['Color'], bsdf.inputs['Base Color'])
    return result


def build(rebuild=False):
    manifest_path = OUT/'manifest.json'
    if manifest_path.exists():
        if not rebuild:
            raise RuntimeError('Package exists; use --rebuild for unchanged generated outputs.')
        old = json.loads(manifest_path.read_text())
        # Never overwrite hand-edited source/exports merely because a rebuild was requested.
        for row in old['files']:
            path = OUT/row['path']
            if not path.exists() or sha(path) != row['sha256']:
                raise RuntimeError('Preserve edited/missing asset before rebuilding: '+str(path))
    recipes = json.loads((OUT/'recipes.json').read_text())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1
    mat = material()
    models = OUT/'models'
    models.mkdir(parents=True, exist_ok=True)
    records, files = [], []
    for shape in recipes['shapes']:
        blades = blade_recipes(shape)
        for finish in recipes['finishes']:
            asset_id = shape['id']+'_'+finish
            record = {'id':asset_id, 'shape':shape['id'], 'finish':finish, 'seed':shape['seed'], 'models':[]}
            for lod in recipes['lods']:
                geom = GrassMesh()
                chosen = blades[::lod['stride']]
                coated = 0
                for blade in chosen:
                    geom.ribbon(blade, lod['segments'], finish)
                    if finish != 'green' and blade['snow'] < (.55 if finish == 'dusted' else .94):
                        geom.ribbon(blade, lod['segments'], finish, snow=True)
                        coated += 1
                name = asset_id+'_lod'+str(lod['level'])
                obj = geom.object(name, mat)
                obj['shape'] = shape['id']; obj['finish'] = finish; obj['lod'] = lod['level']
                obj['blade_count'] = len(chosen)
                obj['coated_blades'] = coated
                bpy.ops.object.select_all(action='DESELECT')
                obj.select_set(True)
                bpy.context.view_layer.objects.active = obj
                path = models/(name+'.glb')
                bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                                         export_animations=False, export_yup=True, export_extras=True,
                                         export_vertex_color='NAME', export_vertex_color_name='Color',
                                         export_all_vertex_colors=False)
                obj.data.calc_loop_triangles()
                bpy.context.view_layer.update()
                row = {'file':path.name, 'lod':lod['level'], 'sha256':sha(path), 'bytes':path.stat().st_size,
                       'triangles':len(obj.data.loop_triangles), 'blades':len(chosen), 'coated_blades':coated,
                       'base_triangles':geom.base_triangles, 'snow_triangles':geom.snow_triangles,
                       'surfaces':1, 'dimensions_blender_xyz_m':list(obj.dimensions),
                       'dimensions_godot_xyz_m':[obj.dimensions.x,obj.dimensions.z,obj.dimensions.y]}
                record['models'].append(row)
                files.append({'path':'models/'+path.name, 'sha256':row['sha256'], 'bytes':row['bytes']})
                obj.hide_set(lod['level'] != 0 or finish != 'green')
                obj.hide_render = lod['level'] != 0 or finish != 'green'
                # Source library is arranged for editing; export meshes have identity transforms.
                index = recipes['shapes'].index(shape)
                obj.location = Vector(((index%3)*.85, (index//3)*.95, 0))
            records.append(record)
            print('GRASS_PREPARED', asset_id, [m['triangles'] for m in record['models']], flush=True)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.scene['package_status'] = 'prepared_only_not_integrated'
    bpy.context.scene['instructions'] = 'Six base clumps. Green LOD0 visible; unhide matching finish/LOD for editing. Models exported at origin.'
    source = OUT/'grass_library.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
    files.append({'path':source.name, 'sha256':sha(source), 'bytes':source.stat().st_size})
    reference_paths = ['art_source/blender/rock_generator.blend', 'assets/graphics/geology_v11/textures/grass.png']
    manifest = {'schema':1, 'status':'prepared_only_not_integrated', 'geometry_origin':'Original procedural curved blades from recipes.json; no vendor geometry or textures embedded',
                'authoring_blender':bpy.app.version_string, 'builder_sha256':sha(Path(__file__)),
                'recipe_sha256':sha(OUT/'recipes.json'), 'units':'metres', 'export_axes':'Y up, Blender Z up',
                'material':'One opaque double-sided vertex-colored PBR surface; no external textures',
                'vertex_contract':{'COLOR_0':'linear appearance RGB; alpha 1', 'TEXCOORD_0':'x across blade, y root-to-tip bend weight',
                                   'TEXCOORD_1':'root pivot: x=(u-.5)*span; z=-(v-.5)*span; y=0', 'pivot_span_m':PIVOT_SPAN},
                'inspected_references_not_embedded':[{'path':p,'sha256':sha(ROOT/p)} for p in reference_paths],
                'rock_geometry':False, 'collision':False, 'wind_or_skier_runtime_implemented':False,
                'assets':records, 'files':files, 'total_payload_bytes':sum(row['bytes'] for row in files)}
    manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
    print('GRASS_PACKAGE_COMPLETE',len(records),'variants',sum(len(r['models']) for r in records),'GLBs',manifest['total_payload_bytes'],'bytes',flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--rebuild', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    build(args.rebuild)
