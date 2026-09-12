"""Prepare original leafy ground plants, ferns and low shrubs, outside the game."""
import argparse
import json
import math
from pathlib import Path
import random
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
from prepare_grass_assets import GrassMesh, linear, mix, sha, material

OUT = ROOT/'art_source/foliage/plants_v1'
UP = Vector((0,0,1))


class PlantMesh(GrassMesh):
    def __init__(self, recipe, finish, lod):
        super().__init__()
        self.recipe, self.finish, self.lod = recipe, finish, lod
        self.leaves, self.coated = 0, 0

    def face(self, points, rgb, snow=False):
        first = len(self.vertices)
        for i,p in enumerate(points):
            self.vertices.append(tuple(p))
            color = tuple(min(1,c*(1.035 if i == 0 else .96)) for c in rgb)
            self.colors.append((*linear(color),1))
            self.uv.append((.5,1-min(1,max(0,p.z/self.recipe['height']))))
            self.pivots.append((.5,.5))
        for i in range(1,len(points)-1):
            self.faces.append((first,first+i,first+i+1))
            if snow: self.snow_triangles += 1
            else: self.base_triangles += 1

    def tube(self, points, radius, rgb):
        sides = 5 if self.lod == 0 else 4
        rings = []
        for i,p in enumerate(points):
            tangent = (points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
            side = tangent.cross(UP)
            if side.length < .01: side = Vector((1,0,0))
            side.normalize()
            other = tangent.cross(side).normalized()
            r = radius*(1-.66*i/(len(points)-1))
            rings.append([Vector((v.x,v.y,max(0,v.z))) for v in
                          [p+(side*math.cos(k*math.tau/sides)+other*math.sin(k*math.tau/sides))*r for k in range(sides)]])
        for i in range(len(points)-1):
            for k in range(sides):
                nxt = (k+1)%sides
                self.face([rings[i][k],rings[i+1][k],rings[i+1][nxt],rings[i][nxt]],rgb)

    def leaf(self, root, direction, length, width, index, narrow=False):
        direction = direction.normalized()
        side = direction.cross(UP)
        if side.length < .05: side = Vector((1,0,0))
        side.normalize()
        normal = side.cross(direction).normalized()
        if normal.z < 0: normal = -normal
        rng = random.Random(self.recipe['seed']+index*137)
        tint = rng.random()
        rgb = mix((.20,.35,.115),(.41,.54,.22),tint)
        if narrow: rgb = mix((.20,.40,.14),(.39,.57,.24),tint)
        contour = [(0,0),(.35,.12),(.5,.38),(.40,.68),(.18,.88),(0,1),(-.18,.88),(-.40,.68),(-.5,.38),(-.35,.12)]
        if narrow:
            contour = [(0,0),(.46,.19),(.29,.34),(.47,.48),(.23,.63),(.25,.77),(0,1),(-.25,.77),(-.23,.63),(-.47,.48),(-.29,.34),(-.46,.19)]
        if self.lod == 1: contour = [(0,0),(.46,.25),(.38,.65),(0,1),(-.38,.65),(-.46,.25)]
        if self.lod == 2: contour = [(0,0),(.43,.43),(0,1),(-.43,.43)]
        def surface(coating=False):
            offset = normal*(.0014 if self.finish == 'snow' else .0007) if coating else Vector()
            scale = (.87 if self.finish == 'snow' else .64) if coating else 1
            base_center = root+direction*length*.46+normal*length*.065
            center = base_center+offset
            outline = [root+direction*length*y+side*width*x+normal*length*(.014*math.sin(y*math.pi)) for x,y in contour]
            # Shrink each cap triangle within the exact supporting leaf plane.
            # A separately flattened outline intersects the folded leaf and
            # creates white rings with green holes in the middle.
            points = [base_center+(p-base_center)*scale+offset for p in outline]
            color = (.87,.92,.925) if coating else rgb
            for i,p in enumerate(points):
                self.face([center,p,points[(i+1)%len(points)]],color,coating)
        surface()
        self.leaves += 1
        if self.finish != 'green' and rng.random() < (.50 if self.finish == 'dusted' else .94):
            surface(True)
            self.coated += 1


def geometry(recipe,finish,lod):
    mesh = PlantMesh(recipe,finish,lod)
    rng = random.Random(recipe['seed'])
    height = recipe['height']
    kind = recipe['kind']
    segments = [7,5,3][lod]
    if kind == 'rosette':
        for i in range(recipe['leaves']):
            a = i*2.399963+ rng.uniform(-.13,.13)
            length = height*rng.uniform(.68,1.12)
            if lod == 2 and i%2: continue
            d = Vector((math.cos(a),math.sin(a),rng.uniform(.30,.75))).normalized()
            root = Vector((0,0,0))
            stem_end = d*height*.17
            mesh.tube([root,stem_end],.0017,(.30,.37,.15))
            mesh.leaf(stem_end,d,length,length*.55,i)
    elif kind == 'fern':
        for i in range(recipe['fronds']):
            a = i*2.399963+rng.uniform(-.1,.1)
            h = height*(1 if i == 0 else rng.uniform(.74,.98))
            d = Vector((math.cos(a),math.sin(a),0))
            side = Vector((-math.sin(a),math.cos(a),0))
            def axis(t): return d*h*.72*t*t+UP*h*(t-.16*t**4)
            mesh.tube([axis(j/segments) for j in range(segments+1)],.0017,(.39,.45,.19))
            pairs = recipe['pairs']-[0,2,4][lod]
            for j in range(pairs):
                t = .16+.76*j/max(1,pairs-1)
                leaf_length = h*.24*math.sin(t*math.pi)**.70
                for sign in [-1,1]:
                    direction = side*sign+d*.22+UP*(.12+.1*t)
                    mesh.leaf(axis(t),direction,leaf_length,leaf_length*.30,i*100+j*2+(sign+1)//2,True)
            mesh.leaf(axis(.90),d*.50+UP*.80,h*.14,h*.029,i*100+99,True)
    else:
        count = recipe['branches']
        for i in range(count):
            a = i*2.399963+rng.uniform(-.15,.15)
            h = height*(.95 if i == 0 else rng.uniform(.63,.89))
            d = Vector((math.cos(a),math.sin(a),0))
            def axis(t): return d*h*(.40 if kind == 'shrub' else .26)*t*t+UP*h*t
            wood = (.31,.27,.18) if kind == 'shrub' else (.30,.39,.14)
            mesh.tube([axis(j/segments) for j in range(segments+1)],.0032 if kind == 'shrub' else .0021,wood)
            levels = [5,4,3][lod] if kind == 'shrub' else [4,3,3][lod]
            for j in range(levels):
                t = .28+.61*j/(levels-1)
                for sign in [-1,1]:
                    angle = a+j*1.28+sign*1.13
                    branch_direction = Vector((math.cos(angle),math.sin(angle),.20+.25*t)).normalized()
                    length = height*(.18 if kind == 'shrub' else .34)*(1-.34*t)
                    root = axis(t)
                    stem_end = root+branch_direction*length*.20
                    mesh.tube([root,stem_end],.0011,wood)
                    mesh.leaf(stem_end,branch_direction,length,length*(.53 if kind == 'shrub' else .65),i*100+j*2+(sign+1)//2)
            mesh.leaf(axis(.93),d*.4+UP*.8,height*.12,height*.07,i*100+99)
    return mesh


def build(rebuild):
    manifest_path = OUT/'manifest.json'
    if manifest_path.exists():
        if not rebuild: raise RuntimeError('Package exists; use --rebuild for unchanged generated outputs.')
        for row in json.loads(manifest_path.read_text())['files']:
            if not (OUT/row['path']).exists() or sha(OUT/row['path']) != row['sha256']:
                raise RuntimeError('Preserve edited/missing asset before rebuilding: '+row['path'])
    recipes = json.loads((OUT/'recipes.json').read_text())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1
    mat = material(); mat.name = 'PreparedPlant_VertexPBR'
    (OUT/'models').mkdir(parents=True,exist_ok=True)
    records,files = [],[]
    for index,recipe in enumerate(recipes['shapes']):
        for finish in recipes['finishes']:
            record = {'id':recipe['id']+'_'+finish,'shape':recipe['id'],'kind':recipe['kind'],'finish':finish,'seed':recipe['seed'],'models':[]}
            for lod in range(3):
                geo = geometry(recipe,finish,lod)
                name = record['id']+'_lod'+str(lod)
                obj = geo.object(name,mat)
                obj['asset_role'] = 'plant_only'; obj['shape'] = recipe['id']; obj['finish'] = finish; obj['lod'] = lod
                obj['leaf_count'] = geo.leaves; obj['coated_leaves'] = geo.coated
                bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
                bpy.context.view_layer.objects.active = obj
                path = OUT/'models'/(name+'.glb')
                bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,
                    export_yup=True,export_extras=True,export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=False)
                obj.data.calc_loop_triangles(); bpy.context.view_layer.update()
                row = {'file':path.name,'lod':lod,'sha256':sha(path),'bytes':path.stat().st_size,'triangles':len(obj.data.loop_triangles),
                    'leaves':geo.leaves,'coated_leaves':geo.coated,'base_triangles':geo.base_triangles,'snow_triangles':geo.snow_triangles,
                    'surfaces':1,'dimensions_blender_xyz_m':list(obj.dimensions),'dimensions_godot_xyz_m':[obj.dimensions.x,obj.dimensions.z,obj.dimensions.y]}
                record['models'].append(row)
                files.append({'path':'models/'+path.name,'sha256':row['sha256'],'bytes':row['bytes']})
                obj.hide_set(lod != 0 or finish != 'green'); obj.hide_render = lod != 0 or finish != 'green'
                obj.location = Vector(((index%3)*.85,(index//3)*.95,0))
            records.append(record)
            print('PLANT_PREPARED',record['id'],[m['triangles'] for m in record['models']],flush=True)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.scene['package_status'] = 'prepared_only_not_integrated'
    source = OUT/'plant_library.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    files.append({'path':source.name,'sha256':sha(source),'bytes':source.stat().st_size})
    manifest = {'schema':1,'kind':'plants','status':'prepared_only_not_integrated','geometry_origin':'Original procedural foliage from recipes; generic growth forms, not scanned botanical species',
        'authoring_blender':bpy.app.version_string,'builder_path':'scripts/art/prepare_plant_assets.py','builder_sha256':sha(Path(__file__)),
        'builder_dependencies':{'scripts/art/prepare_grass_assets.py':sha(ROOT/'scripts/art/prepare_grass_assets.py')},
        'recipe_sha256':sha(OUT/'recipes.json'),'units':'metres','export_axes':'Y up, Blender Z up',
        'material':'One opaque double-sided vertex-colored PBR surface; stems and leaves, no external textures',
        'vertex_contract':{'COLOR_0':'linear appearance RGB; alpha 1','TEXCOORD_0':'y is clamped local height / authored plant height, for future bend weighting',
                           'TEXCOORD_1':'root pivot at origin, encoded (.5,.5)','pivot_span_m':1.0},
        'inspected_references_not_embedded':[],'rock_geometry':False,'collision':False,'wind_or_skier_runtime_implemented':False,
        'assets':records,'files':files,'total_payload_bytes':sum(r['bytes'] for r in files)}
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    print('PLANT_PACKAGE_COMPLETE',len(records),'variants',sum(len(r['models']) for r in records),'GLBs',manifest['total_payload_bytes'],'bytes',flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--rebuild',action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    build(args.rebuild)
