"""Author nine conifers and six fractured rocks, then bake eight-view far LODs.

Run with Blender --background --python scripts/art/build_pc_environment.py.
No generation service or paid assets. Sources use metre-scale geometry, a
single surface per tree, vertex material masks, and the pinned CC0 bark map.
"""
import bpy
import math
import random
import json
import hashlib
import os
import time
import struct
from pathlib import Path
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / 'assets/graphics/models'
TEXTURES = ROOT / 'assets/graphics/textures'
SOURCE = ROOT / 'art_source/blender/pc_environment'
SOURCE.mkdir(parents=True, exist_ok=True)
STAGING = ROOT / '.tools/pc-art-export'
STAGING.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def linear(c):
    return c / 12.92 if c < .04045 else ((c + .055) / 1.055) ** 2.4

class Geometry:
    def __init__(self):
        self.vertices, self.faces, self.colors, self.uvs = [], [], [], []

    def face(self, points, color, mask, uv=None):
        begin = len(self.vertices)
        self.vertices.extend([tuple(v) for v in points])
        self.faces.append(tuple(range(begin, begin + len(points))))
        self.colors.extend([(*[linear(c) for c in color], mask)] * len(points))
        self.uvs.extend(uv or [(0, 0)] * len(points))

    def tube(self, a, b, r0, r1, color, sides=5):
        a, b = Vector(a), Vector(b)
        axis = (b-a).normalized()
        right = axis.cross(Vector((0, 0, 1)))
        if right.length < .01: right = Vector((1, 0, 0))
        right.normalize()
        up = axis.cross(right).normalized()
        for i in range(sides):
            t, u = math.tau*i/sides, math.tau*(i+1)/sides
            p, q = right*math.cos(t)+up*math.sin(t), right*math.cos(u)+up*math.sin(u)
            self.face([a+p*r0, a+q*r0, b+q*r1, b+p*r1], color, 0,
                      [(i/sides, 0), ((i+1)/sides, 0), ((i+1)/sides, (b-a).length*2), (i/sides, (b-a).length*2)])

    def needle(self, root, direction, length, color):
        d = direction.normalized()
        side = d.cross(Vector((.17, .07, 1))).normalized() * length * .055
        tip = root + d*length
        self.face([root-side, root+side, tip], color, .5)
        self.face([root+Vector((0, 0, -.004)), root+Vector((0, 0, .004)), tip], color, .5)

    def spray(self, root, end, color, planes):
        # Opaque needle clusters retain projected coverage through mip/LOD
        # transitions. Fine needles break the edges in the near mesh.
        axis = (end-root).normalized()
        side = axis.cross(Vector((0, 0, 1))).normalized()
        up = axis.cross(side).normalized()
        for i in range(planes):
            angle = i*math.pi/planes
            width = (side*math.cos(angle)+up*math.sin(angle))*.16
            shoulder = root.lerp(end, .52)
            self.face([root-axis*.04, shoulder-width, end+axis*.12, shoulder+width], color, .6,
                      [(0,.5),(.52,0),(1,.5),(.52,1)])

    def snow(self, center, extent, rng):
        # Small settled deposits, not a solid crown shell.
        center = Vector(center)
        levels = [(0, .88), (.55, 1), (.92, .58)]
        rings = []
        for height, scale in levels:
            rings.append([center + Vector((math.cos(i*math.tau/7)*extent[0]*scale,
                                          math.sin(i*math.tau/7)*extent[1]*scale,
                                          height*extent[2])) for i in range(7)])
        color = (.84+rng.random()*.06, .89+rng.random()*.045, .94)
        for j in range(2):
            for i in range(7):
                self.face([rings[j][i], rings[j][(i+1)%7], rings[j+1][(i+1)%7], rings[j+1][i]], color, 1)
        peak = center + Vector((-.03, .01, extent[2]))
        for i in range(7): self.face([rings[-1][i], rings[-1][(i+1)%7], peak], color, 1)

    def object(self, name, material):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        uv = mesh.uv_layers.new(name='UVMap')
        colors = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
        for i, color in enumerate(self.colors): colors.data[i].color = color
        for loop in mesh.loops: uv.data[loop.index].uv = self.uvs[loop.vertex_index]
        mesh.materials.append(material)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.hide_render = True
        return obj

tree_mat = bpy.data.materials.new('PC_Conifer')
tree_mat.use_nodes = True
nodes, links = tree_mat.node_tree.nodes, tree_mat.node_tree.links
principled = nodes.get('Principled BSDF')
attribute = nodes.new('ShaderNodeVertexColor')
attribute.layer_name = 'Color'
bark = nodes.new('ShaderNodeTexImage')
bark.image = bpy.data.images.load(str(TEXTURES/'bark_albedo_high.jpg'))
is_wood = nodes.new('ShaderNodeMath')
is_wood.operation = 'LESS_THAN'
is_wood.inputs[1].default_value = .25
links.new(attribute.outputs['Alpha'], is_wood.inputs[0])
mix = nodes.new('ShaderNodeMixRGB')
links.new(is_wood.outputs[0], mix.inputs[0])
links.new(attribute.outputs['Color'], mix.inputs[1])
links.new(bark.outputs['Color'], mix.inputs[2])
links.new(mix.outputs[0], principled.inputs['Base Color'])
principled.inputs['Roughness'].default_value = .88
# The same analytic needle cutout is used by the Godot shader and the atlas
# bake. It breaks broad cluster planes into paired needles without blending.
def math_node(operation, a, b=None):
    n = nodes.new('ShaderNodeMath')
    n.operation = operation
    for index, value in enumerate([a,b]):
        if value is None: continue
        if isinstance(value, (int,float)): n.inputs[index].default_value = value
        else: links.new(value,n.inputs[index])
    return n.outputs[0]
uv_coordinates = nodes.new('ShaderNodeTexCoord')
uv_components = nodes.new('ShaderNodeSeparateXYZ')
links.new(uv_coordinates.outputs['UV'],uv_components.inputs[0])
across = math_node('ABSOLUTE', math_node('SUBTRACT',uv_components.outputs['Y'],.5))
phase = math_node('SUBTRACT',math_node('MULTIPLY',uv_components.outputs['X'],16),math_node('MULTIPLY',across,10))
needles = math_node('LESS_THAN',math_node('FRACT',phase),.35)
stem = math_node('LESS_THAN',across,.025)
cutout = math_node('MAXIMUM',needles,stem)
spray_mask = math_node('MULTIPLY',math_node('GREATER_THAN',attribute.outputs['Alpha'],.55),math_node('LESS_THAN',attribute.outputs['Alpha'],.75))
opacity = math_node('SUBTRACT',1,math_node('MULTIPLY',spray_mask,math_node('SUBTRACT',1,cutout)))
links.new(opacity,principled.inputs['Alpha'])
tree_mat.surface_render_method = 'DITHERED'
rock_mat = bpy.data.materials.new('Rock.PC')
rock_mat.diffuse_color = (.22, .25, .29, 1)
rock_mat.use_nodes = True
rock_shader = rock_mat.node_tree.nodes.get('Principled BSDF')
rock_tex = rock_mat.node_tree.nodes.new('ShaderNodeTexImage')
rock_tex.image = bpy.data.images.load(str(TEXTURES/'rock_albedo_high.jpg'))
rock_mat.node_tree.links.new(rock_tex.outputs['Color'], rock_shader.inputs['Base Color'])
rock_shader.inputs['Roughness'].default_value = .88

def conifer(family, variant, lod):
    seed = 8300 + variant*71 + ['spruce', 'fir', 'pine'].index(family)*1001
    rng = random.Random(seed)
    g = Geometry()
    wood = (.31, .24, .17)
    g.tube((0, 0, 0), (.035, -.035, 10.5), .44, .008, wood, 9 if lod==0 else 6)
    pine = family == 'pine'
    count = 11 if pine else 15
    base = 4.1 if pine else 2.1
    for level in range(count):
        t = level/(count-1)
        height = base + t*(10.0-base)
        radius = ((1-t)*2.65 + .13) * (1.0 if family=='fir' else 1.08)
        if pine: radius *= .72 + .65*math.sin(t*math.pi)
        branches = (6 if pine else 7) - (1 if t>.8 else 0)
        phase = random.Random(seed+level*913).uniform(0, math.tau)
        for arm in range(branches):
            rng = random.Random(seed+level*143+arm*317)
            angle = phase + arm*math.tau/branches + rng.uniform(-.12, .12)
            direction = Vector((math.cos(angle), math.sin(angle), 0))
            side = Vector((-direction.y, direction.x, 0))
            length = radius*rng.uniform(.73, 1.09)
            drop = -.30 if family=='spruce' else (-.10 if family=='fir' else .28)
            root = Vector((0, 0, height+rng.uniform(-.22, .22)))
            bend = root + direction*length*.57 + Vector((0, 0, drop))
            tip = root + direction*length + Vector((0, 0, .18 if pine else -.06))
            g.tube(root, bend, .045*(1-t)+.01, .025, wood, 5 if lod==0 else 4)
            g.tube(bend, tip, .025, .004, wood, 4)
            for twig in range(5):
                q = .23 + twig*.155
                branch_p = root.lerp(tip, q) + Vector((0, 0, drop*math.sin(q*math.pi)))
                for wing in [-1, 1]:
                    twig_direction = (direction*.65 + side*wing*.9 + Vector((0, 0, .08))).normalized()
                    twig_length = (.46*(1-q)+.12)*(1.0 if not pine else 1.2)
                    endpoint = branch_p + twig_direction*twig_length
                    g.spray(branch_p, endpoint, (.20, .32, .22), 3 if lod==0 else 2)
                    if lod==0: g.tube(branch_p, endpoint, .009, .0025, wood, 3)
                    needles = 5 if lod==0 else 2
                    for needle in range(needles):
                        progress = (needle+.3)/needles
                        p = branch_p.lerp(endpoint, progress)
                        a = twig*1.7 + needle*2.4 + wing*.8
                        leaf_direction = twig_direction*.48 + side*math.cos(a) + Vector((0, 0, math.sin(a)*.5+.35))
                        green = rng.uniform(.0, .10)
                        color = (.17+green*.60, .26+green, .19+green*.7)
                        g.needle(p, leaf_direction, rng.uniform(.085, .16)*(1 if lod==0 else 1.65), color)
            rng = random.Random(seed+level*517+arm*217)
            if rng.random()<.42:
                p = root.lerp(tip, .53) + Vector((0, 0, drop*.8+.025))
                g.snow(p, (.30, .24, .095), rng)
                if lod==0: g.snow(root.lerp(tip, .76)+Vector((0, 0, .015)), (.22, .17, .075), rng)
    return g.object(f'pc_{family}_{variant}_lod{lod}', tree_mat)

def rock(kind, variant):
    rng = random.Random(932 + variant + ['buttress', 'ledge', 'boulder'].index(kind)*91)
    g = Geometry()
    rings = []
    sides = 9
    heights = [-.24, .10, .67, 1.25, 1.92]
    radii = [1.13, 1.28, 1.13, 1.02, .50]
    if kind=='ledge':
        heights, radii = [-.24, .12, .65, .86, 1.35, 1.56, 1.94], [1.15, 1.27, 1.23, .89, 1.04, .72, .45]
    if kind=='boulder': radii = [.94, 1.19, 1.28, 1.03, .62]
    angles = [i*math.tau/sides+rng.uniform(-.10, .10) for i in range(sides)]
    shape = [rng.uniform(.78, 1) for i in range(sides)]
    for level, (height, radius) in enumerate(zip(heights, radii)):
        rings.append([Vector((math.cos(a)*radius*shape[i], math.sin(a)*radius*shape[i], height+(rng.uniform(-.04, .04) if level>0 else 0))) for i, a in enumerate(angles)])
    for level in range(len(rings)-1):
        for i in range(sides):
            tint = (.39, .41, .44)
            g.face([rings[level][i], rings[level][(i+1)%sides], rings[level+1][(i+1)%sides], rings[level+1][i]], tint, 0)
    center = Vector((.12, -.08, 1.99))
    for i in range(sides): g.face([rings[-1][i], rings[-1][(i+1)%sides], center], (.43, .45, .48), 0)
    return g.object(f'pc_rock_{kind}_{variant}', rock_mat)

records = []

def finalize_material_masks(path):
    # Preserve the RGBA accessor produced above, then declare the final GLB
    # opaque. COLOR.a is data for our shader, never runtime transparency.
    raw = path.read_bytes()
    size = struct.unpack_from('<I',raw,12)[0]
    document = json.loads(raw[20:20+size])
    for material in document.get('materials',[]):
        material.pop('alphaMode',None)
        material.pop('alphaCutoff',None)
    encoded = json.dumps(document,separators=(',',':')).encode()
    encoded += b' '*((-len(encoded))%4)
    tail = raw[20+size:]
    path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(encoded)+len(tail))+
                     struct.pack('<II',len(encoded),0x4e4f534a)+encoded+tail)
def export(obj, **extra):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = MODELS/(obj.name+'.glb')
    # Publish complete files atomically: a running Godot editor may import them.
    # Runtime shader names bind the shared maps; embedding a 4K bark map into
    # every tree would duplicate imports and unnecessarily consume memory.
    staging = STAGING/path.name
    source_materials = list(obj.data.materials)
    placeholder = bpy.data.materials.new(source_materials[0].name.split('.')[0]+'.Runtime')
    placeholder.use_nodes = True
    vertex = placeholder.node_tree.nodes.new('ShaderNodeVertexColor')
    vertex.layer_name = 'Color'
    placeholder.node_tree.links.new(vertex.outputs['Color'], placeholder.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    # glTF drops vertex alpha for OPAQUE source materials. The exported alpha
    # is a runtime material mask, not transparency; preserve all four channels.
    placeholder.node_tree.links.new(vertex.outputs['Alpha'], placeholder.node_tree.nodes.get('Principled BSDF').inputs['Alpha'])
    placeholder.surface_render_method = 'DITHERED'
    obj.data.materials.clear()
    obj.data.materials.append(placeholder)
    bpy.ops.export_scene.gltf(filepath=str(staging), export_format='GLB', use_selection=True,
                             export_animations=False, export_extras=True)
    finalize_material_masks(staging)
    obj.data.materials.clear()
    for material in source_materials: obj.data.materials.append(material)
    for attempt in range(20):
        try:
            os.replace(staging, path)
            break
        except OSError:
            if attempt==19: raise
            time.sleep(.25)
    obj.data.calc_loop_triangles()
    records.append(dict(asset=obj.name, path=path.relative_to(ROOT).as_posix(), bytes=path.stat().st_size,
                        triangles=len(obj.data.loop_triangles), dimensions_m=list(obj.dimensions),
                        surfaces=len(obj.data.materials), materials=[m.name for m in obj.data.materials],
                        sha256=hashlib.sha256(path.read_bytes()).hexdigest(), **extra))
    print('PC_EXPORT', obj.name, records[-1]['triangles'], flush=True)

trees = []
for family in ['spruce', 'fir', 'pine']:
    for variant in range(1, 4):
        for lod in [0, 1]:
            obj = conifer(family, variant, lod)
            export(obj, family=family, lod=lod, silhouette=variant)
            if lod==0: trees.append(obj)
for kind in ['buttress', 'ledge', 'boulder']:
    for variant in [1, 2]: export(rock(kind, variant), family=kind)

bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'pc_environment.blend'))

# Bake only albedo. Geometry/cloud shadows and weather remain runtime lighting.
output = next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
emit = nodes.new('ShaderNodeEmission')
links.new(mix.outputs[0], emit.inputs['Color'])
transparent = nodes.new('ShaderNodeBsdfTransparent')
bake_shader = nodes.new('ShaderNodeMixShader')
links.new(opacity,bake_shader.inputs[0])
links.new(transparent.outputs[0],bake_shader.inputs[1])
links.new(emit.outputs[0],bake_shader.inputs[2])
links.new(bake_shader.outputs[0],output.inputs['Surface'])
camera_data = bpy.data.cameras.new('Directional impostor camera')
camera = bpy.data.objects.new('Directional impostor camera', camera_data)
bpy.context.collection.objects.link(camera)
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 11
scene = bpy.context.scene
scene.camera = camera
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'Standard'
scene.render.image_settings.color_depth = '8'
if hasattr(scene, 'eevee'): scene.eevee.taa_render_samples = 16

for obj in trees:
    atlas = np.zeros((512, 4096, 4), dtype=np.float32)
    obj.hide_render = False
    for view in range(8):
        angle = view*math.tau/8
        camera.location = (math.sin(angle)*25, -math.cos(angle)*25, 5.25)
        camera.rotation_euler = (Vector((0, 0, 5.25))-camera.location).to_track_quat('-Z', 'Y').to_euler()
        path = SOURCE / f'bake_{obj.name}_{view}.png'
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        rendered = bpy.data.images.load(str(path), check_existing=False)
        pixels = np.empty(512*512*4, dtype=np.float32)
        rendered.pixels.foreach_get(pixels)
        atlas[:, view*512:(view+1)*512] = pixels.reshape(512, 512, 4)
        bpy.data.images.remove(rendered)
    obj.hide_render = True
    base_name = obj.name.removesuffix('_lod0')
    image = bpy.data.images.new(base_name+'_atlas', width=4096, height=512, alpha=True)
    image.pixels.foreach_set(atlas.ravel())
    image.filepath_raw = str(TEXTURES/(base_name+'_atlas.png'))
    image.file_format = 'PNG'
    image.save()
    image.scale(2048, 256)
    image.filepath_raw = str(TEXTURES/(base_name+'_atlas_low.png'))
    image.save()
    mat = bpy.data.materials.new('PC_Impostor_'+base_name.removeprefix('pc_'))
    g = Geometry()
    g.face([(-5.5, 0, -.25), (5.5, 0, -.25), (5.5, 0, 10.75), (-5.5, 0, 10.75)], (1, 1, 1), 1,
           [(0, 0), (1, 0), (1, 1), (0, 1)])
    card = g.object(base_name+'_lod2', mat)
    export(card, family=base_name.split('_')[1], lod=2, views=8)
    print('PC_ATLAS', base_name, flush=True)

links.new(principled.outputs[0], output.inputs['Surface'])
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'pc_environment.blend'))
# Independent import checks catch axes, material masks and broken exports.
for record in records:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/record['path']))
    meshes = [o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(meshes)==1, record['asset']
    obj = meshes[0]
    obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles)==record['triangles'], record['asset']
    assert all(abs(a-b)<.01 for a, b in zip(obj.dimensions, record['dimensions_m'])), record['asset']
    if record.get('lod') in [0, 1]:
        assert len(obj.data.color_attributes)>0, record['asset']
        alpha = {round(c.color[3],2) for c in obj.data.color_attributes[0].data}
        assert {0.0,.5,.6,1.0}.issubset(alpha), (record['asset'],alpha)
    record['roundtrip_verified'] = True

atlas_records = []
for path in sorted(TEXTURES.glob('pc_*_atlas*.png')):
    data = path.read_bytes()
    atlas_records.append({'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(data).hexdigest(),
                          'bytes':len(data),'pixels':list(struct.unpack('>II',data[16:24]))})
(ROOT/'art_source/pc_environment_manifest.json').write_text(json.dumps({'source':'Blender authored', 'assets': records, 'atlases':atlas_records,
    'sources':['art_source/blender/pc_environment/pc_environment.blend','art_source/pc_texture_sources.json'],
    'mesh_budget': 'One surface per tree; three geometry LODs, eight-angle albedo-only far atlas'}, indent=2)+'\n')
runtime_path = ROOT/'assets/graphics/manifest.json'
runtime = json.loads(runtime_path.read_text())
runtime['assets'] = [a for a in runtime['assets'] if not Path(a['path']).name.startswith('pc_')]
runtime['assets'].extend({key: a[key] for key in ['path','triangles','bytes','sha256']} for a in records)
runtime['assets'].sort(key=lambda a: a['path'])
runtime_path.write_text(json.dumps(runtime, indent=2)+'\n')
ledger_path = ROOT/'art_source/pc_environment_credit_ledger.json'
if not ledger_path.exists():
    ledger_path.write_text(json.dumps({'authorized_ceiling':1500,
        'first_batch_ceiling':300,'spent':0,'jobs':[], 'note':'All current PC environment assets authored in Blender from local geometry and CC0 textures.'}, indent=2)+'\n')
print('PC_ENVIRONMENT_COMPLETE', len(records), flush=True)
