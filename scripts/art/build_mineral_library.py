"""Build an additive game-asset pack from the supplied rock_generator.blend.

blender --background --factory-startup --disable-autoexec --python-exit-code 1
    --python scripts/art/build_mineral_library.py [-- --sample | --formations-only]

The source is read with scripts disabled and is never saved over. Original GN
shape generation drives every part; composition, union, UVs and PBR conversion
are the export pipeline. No external services or paid generation are used.
"""
import bpy
import bmesh
import hashlib
import json
import math
import random
import shutil
import sys
import time
from pathlib import Path
from mathutils import Vector, Matrix, noise

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'rock_generator.blend'
OUT = ROOT / 'assets/graphics/minerals'
ART = ROOT / 'art_source/blender/minerals'
QA = ROOT / 'artifacts/minerals'
SAMPLE = '--sample' in sys.argv
FORMATIONS_ONLY = '--formations-only' in sys.argv
VERSION = 'mineral-library-v2'
FAMILIES = ['rounded', 'fractured', 'sedimentary', 'outcrop', 'cliff', 'glacier']
CATEGORIES = ['small', 'medium', 'large', 'huge_boulders', 'cliffs']
CATEGORY_FAMILIES = {category:FAMILIES for category in CATEGORIES[:3]}
CATEGORY_FAMILIES['huge_boulders'] = ['erratic', 'block', 'split', 'dome', 'overhang', 'monolith']
CATEGORY_FAMILIES['cliffs'] = ['wall', 'layered_wall', 'corner', 'recess', 'overhang_wall', 'buttress']
SELECTED = CATEGORIES[3:] if FORMATIONS_ONLY else (['medium'] if SAMPLE else CATEGORIES)
# Longest dimension, in metres; never enlarge a small mesh at placement time.
LENGTHS = {'small': [.35, .60, .90, 1.20], 'medium': [2.0, 3.2, 4.8, 6.5], 'large': [10., 16., 24., 36.],
           'huge_boulders': [40.,55.,75.,100.], 'cliffs': [60.,100.,150.,220.]}
BUDGETS = {'small': 1600, 'medium': 4500, 'large': 10000, 'huge_boulders':18000, 'cliffs':24000}
PALETTES = {
    'rounded': [(.66,.69,.72), (.74,.66,.55), (.38,.43,.48), (.78,.77,.71)],
    'fractured': [(.39,.43,.49), (.63,.62,.58), (.49,.40,.32), (.60,.65,.70)],
    'sedimentary': [(.77,.72,.61), (.55,.58,.60), (.69,.52,.39), (.46,.50,.55)],
    'outcrop': [(.44,.48,.51), (.62,.58,.51), (.35,.41,.48), (.71,.71,.65)],
    'cliff': [(.60,.62,.63), (.73,.67,.55), (.46,.50,.57), (.67,.58,.49)],
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply(obj, mod):
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def triangles(mesh):
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def fit(mesh, dims, bottom=True):
    mn = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
    mx = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])
    span = mx-mn
    for v in mesh.vertices:
        for i in range(3):
            v.co[i] = ((v.co[i]-mn[i])/span[i] - (0. if bottom and i==2 else .5))*dims[i]
    mesh.update()


def simplify(obj, budget):
    count = triangles(obj.data)
    if count > budget:
        dec = obj.modifiers.new('Game triangle budget', 'DECIMATE')
        dec.ratio = (budget-40)/count
        apply(obj, dec)


def remove_debris(obj):
    obj.data.validate(clean_customdata=False)
    bm=bmesh.new();bm.from_mesh(obj.data)
    unseen=set(bm.verts);debris=[]
    while unseen:
        first=unseen.pop();component={first};pending=[first]
        while pending:
            vertex=pending.pop()
            for edge in vertex.link_edges:
                other=edge.other_vert(vertex)
                if other in unseen:unseen.remove(other);component.add(other);pending.append(other)
        if len(component)<20:debris.extend(component)
    if debris:bmesh.ops.delete(bm,geom=debris,context='VERTS')
    bm.to_mesh(obj.data);bm.free();obj.data.update()


def generated_part(seed, variation, dims, loc=(0,0,0), tilt=(0,0,0), rounded=False):
    seed_node.integer = seed
    variation_node.integer = variation
    graph.update_tag()
    generator.update_tag()
    bpy.context.view_layer.update()
    evaluated = generator.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = bpy.data.meshes.new_from_object(evaluated)
    if not mesh.vertices:
        raise RuntimeError(f'Empty generator output: {seed}/{variation}')
    mesh.materials.clear()
    obj = bpy.data.objects.new(f'generator_part_{seed}', mesh)
    bpy.context.collection.objects.link(obj)
    fit(mesh, (1,1,1), bottom=False)
    # Preserve the original generator's ledges for angular families. Rounding
    # blends its actual surface toward an ellipsoid, then unions its two shells.
    if rounded:
        for v in mesh.vertices:
            p = v.co.copy()
            if p.length > .001:
                target = p.normalized() * (.50 + .025*noise.noise(p*5+Vector((seed%31,3,9))))
                v.co = p.lerp(target, .78 if rounded is True else float(rounded))
    simplify(obj, 2600)
    fit(mesh, dims)
    rot = Matrix.Rotation(tilt[2], 4, 'Z') @ Matrix.Rotation(tilt[1], 4, 'Y') @ Matrix.Rotation(tilt[0], 4, 'X')
    for v in mesh.vertices:
        v.co = rot @ v.co + Vector(loc)
    return obj


def compose_shape_parts(category, family, variant):
    seed = 920700 + CATEGORIES.index(category)*10000 + CATEGORY_FAMILIES[category].index(family)*1000 + variant*83
    rng = random.Random(seed)
    parts = []
    def part(dims, loc=(0,0,0), tilt=(0,0,0), rounded=False):
        parts.append(generated_part(seed+len(parts)*31, variant+len(parts)*7, dims, loc, tilt, rounded))
    if category == 'huge_boulders':
        yaw=variant*.31
        if family == 'erratic':
            part([(1,.82,.65),(.95,.67,.89),(1,.89,.70),(.86,.81,1)][variant],
                 tilt=(.05*(variant-1),-.10,yaw),rounded=.48)
        elif family == 'block':
            part((1,.70,.87),tilt=(.03*variant,-.06,yaw),rounded=.12)
            part((.68,.60,.30),(.10,-.02,.65),tilt=(0,.08,-.12))
        elif family == 'split':
            part((.56,.82,.95),(-.30,0,0),tilt=(0,-.09,yaw*.2))
            part((.52,.74,.72+variant*.08),(.28,.04,0),tilt=(0,.12,-.10))
        elif family == 'dome':
            part((1,.74+variant*.04,.40+variant*.04),rounded=.86)
        elif family == 'overhang':
            part((.59,.66,.68),(-.10,0,0),rounded=.18)
            part((1,.83,.52),(.13,.02,.43),tilt=(0,-.10+variant*.05,yaw),rounded=.38)
        else:
            part((.57+variant*.07,.69,1.45),tilt=(.04,-.12+variant*.07,yaw),rounded=.15)
            part((.72,.78,.34),(.07,0,0),rounded=.25)
    elif category == 'cliffs':
        # Broad connected face masses, with a deep back and a level foundation.
        # The front is Blender -Y / Godot +Z; variation changes the skyline.
        height=1.05+variant*.14
        if family == 'wall':
            part((2.0,.66,height),(0,.12,0))
            for j in range(4):
                part((.65,.30,height*(.77+rng.random()*.24)),
                     ((j-1.5)*.48,-.17,0),tilt=(.03,0,rng.uniform(-.05,.05)))
        elif family == 'layered_wall':
            part((2.2,.57,height*.93),(0,.16,0))
            for j in range(5+variant):
                part((2.22-j*.025,.63+rng.random()*.12,.25),
                     (.045*math.sin(j),-.02,j*height/(5+variant)),tilt=(0,.01,0))
        elif family == 'corner':
            part((1.70,.64,height),(-.30,.10,0))
            part((1.55,.67,height*.87),(.49,.65,0),tilt=(0,0,math.pi/2))
        elif family == 'recess':
            part((2.1,.49,height*.94),(0,.38,0))
            part((.66,.97,height),(-.88,-.04,0),tilt=(0,0,-.13))
            part((.62,.92,height*.86),(.89,-.02,0),tilt=(0,0,.14))
        elif family == 'overhang_wall':
            part((1.94,.61,height*.71),(0,.30,0))
            part((2.17,1.00,height*.44),(.05,.02,height*.56),tilt=(.04,0,.01))
        else:
            part((2.12,.56,height),(0,.23,0))
            for j in range(3+variant%2):
                part((.45,.90,height*(.76+rng.random()*.20)),
                     ((j-1)*.60,-.14,0),tilt=(.12,0,rng.uniform(-.08,.08)))
        part((2.26,.78,.13),(0,.12,0))
    elif family == 'rounded':
        proportions = [(1,.79,.55), (.76,.90,.85), (1,.55,.42), (.84,.74,1)][variant]
        part(proportions, rounded=True, tilt=(.08,-.12,variant*.4))
    elif family == 'fractured':
        # Detached, mutually facing pieces make the fracture readable in outline.
        for j in range(2 + variant%2):
            part((rng.uniform(.42,.68),rng.uniform(.62,.85),rng.uniform(.55,.96)),
                 (j*.41-.3, .10*math.sin(j*3),0), (0,rng.uniform(-.16,.16),rng.uniform(-.2,.2)))
    elif family == 'sedimentary':
        layers = 4+variant
        for j in range(layers):
            width = 1.05-j*.055+rng.uniform(-.08,.08)
            part((width, rng.uniform(.62,.86), .13+rng.random()*.06),
                 (math.sin(j*1.3+variant)*.05, rng.uniform(-.04,.04), j*.112),
                 (0, .03*(variant-1),rng.uniform(-.09,.09)))
    elif family == 'outcrop':
        for j in range(3+variant):
            a = j*2.399+variant
            height = (1.2 if j==0 else rng.uniform(.48,1.0))
            part((rng.uniform(.25,.39),rng.uniform(.28,.48),height),
                 (.22*math.cos(a),.22*math.sin(a),0),
                 (rng.uniform(-.14,.14),rng.uniform(-.20,.20),a))
    elif family == 'cliff':
        count = 4+variant
        for j in range(count):
            h = .9+.21*math.sin(j*.95+variant)+rng.uniform(-.07,.14)
            part((.43,rng.uniform(.38,.60),h),
                 ((j-(count-1)*.5)*.34,.09*math.sin(j*1.1),0),
                 (rng.uniform(-.06,.06),.04*(variant-1),rng.uniform(-.12,.12)))
        # A low fractured foot merges most wall columns and hides placement seams.
        part((count*.35,.73,.24),(0,.02,0))
    else:
        # Ice tongue plus separated crevasse/serac blocks, deliberately opaque
        # PBR for stable depth sorting when many are placed in the game.
        count = 5+variant
        part((1.2,.88,.16),(0,.03,0))
        for j in range(count):
            x = ((j%3)-1)*.34 + rng.uniform(-.025,.025)
            y = (j//3)*.31-.20
            h = rng.uniform(.36,.82)*(1.+variant*.08)
            part((rng.uniform(.22,.31),rng.uniform(.26,.33),h), (x,y,.05),
                 (rng.uniform(-.08,.08),rng.uniform(-.12,.12),rng.uniform(-.08,.08)))
    return parts, seed


def build_shape(category, family, variant):
    parts, seed = compose_shape_parts(category, family, variant)
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts)>1:bpy.ops.object.join()
    obj=parts[0]
    # Voxel union closes the generator's intersecting shells and layered seams.
    bpy.context.view_layer.update()
    dim=max(obj.dimensions)
    remesh=obj.modifiers.new('Solid watertight union', 'REMESH')
    remesh.mode='VOXEL'
    remesh.voxel_size=dim/({'small':80,'medium':112,'large':144,'huge_boulders':176,'cliffs':208}[category])
    remesh.use_smooth_shade=True
    apply(obj,remesh)
    smooth=obj.modifiers.new('Eroded micro edges','SMOOTH')
    smooth.factor=.55 if family=='rounded' else .28
    smooth.iterations=3 if family=='rounded' else 2
    apply(obj,smooth)
    simplify(obj,BUDGETS[category])
    tri=obj.modifiers.new('Explicit triangles','TRIANGULATE');apply(obj,tri)
    # Remove any isolated voxel debris before final dimensions and normals.
    bm=bmesh.new();bm.from_mesh(obj.data)
    unseen=set(bm.verts)
    debris=[]
    while unseen:
        first=unseen.pop();component={first};pending=[first]
        while pending:
            vertex=pending.pop()
            for edge in vertex.link_edges:
                other=edge.other_vert(vertex)
                if other in unseen:unseen.remove(other);component.add(other);pending.append(other)
        if len(component)<20:debris.extend(component)
    if debris:bmesh.ops.delete(bm,geom=debris,context='VERTS')
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
    boundary=[e for e in bm.edges if e.is_boundary]
    if boundary:bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
    isolated=[v for v in bm.verts if not v.link_faces]
    if isolated:bmesh.ops.delete(bm,geom=isolated,context='VERTS')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free()
    # Near-touching ledges can produce a voxel-grid saddle with a nonmanifold
    # edge. Re-union at a different grid spacing, then re-check the final mesh.
    for attempt in range(6):
        remove_debris(obj)
        check=bmesh.new();check.from_mesh(obj.data)
        bad=any(not e.is_manifold for e in check.edges);check.free()
        if not bad:break
        bpy.context.view_layer.update()
        repair=obj.modifiers.new('Resolve touching ledges','REMESH');repair.mode='VOXEL'
        repair.voxel_size=max(obj.dimensions)/(91+attempt*17)
        repair.use_smooth_shade=True;apply(obj,repair)
        simplify(obj,BUDGETS[category])
        tr=obj.modifiers.new('Repair triangles','TRIANGULATE');apply(obj,tr)
    bpy.context.view_layer.update()
    dims=obj.dimensions.copy();dims*=LENGTHS[category][variant]/max(dims)
    fit(obj.data,dims)
    obj.name=f'mineral_{category}_{family}_{variant+1:02}'
    obj.data.name=obj.name+'_mesh'
    obj.data.materials.clear()
    obj.data.materials.append(ice_mat if family=='glacier' else rock_mat)
    # One material surface with per-vertex stone palette / blue ice and frost.
    colors=obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
    for v in obj.data.vertices:
        p=v.co/max(dims)
        n=noise.noise(p*7+Vector((seed%79,1,5)))
        if family=='glacier':
            up=max(0,v.normal.z)
            frost=max(0,min(1,(up-.36)*1.65 + (p.z-.28)*.24))
            deep=Vector((.12,.42,.61)); snow=Vector((.88,.96,1.))
            c=deep.lerp(snow,frost)*(.9+.14*n)
        else:
            palette=PALETTES.get(family,PALETTES['cliff' if category=='cliffs' else 'rounded'])
            c=Vector(palette[variant])*(.88+.16*n)
            if family in ['sedimentary','layered_wall']:
                c*=.88+.14*math.sin(p.z*68+noise.noise(p*4)*2)
            # Light mineral seams, without baking scene light or shadows.
            seam=abs(math.sin((p.x*.4+p.z)*26+n*.6))
            if seam>.985:c=c.lerp(Vector((.78,.80,.80)),.23)
        colors.data[v.index].color=(*c,1)
    obj.data.color_attributes.active_color=colors
    # Angle-based smoothing retains broad fracture planes, while curved surfaces
    # keep smooth normals. Smart UVs make the embedded maps portable to engines.
    for poly in obj.data.polygons:poly.use_smooth=True
    bm=bmesh.new();bm.from_mesh(obj.data)
    for edge in bm.edges:
        if len(edge.link_faces)==2:edge.smooth=edge.calc_face_angle()<math.radians(48 if family!='rounded' else 75)
    bm.to_mesh(obj.data);bm.free()
    activate(obj)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60),island_margin=.012)
    bpy.ops.object.mode_set(mode='OBJECT')
    if category in ['huge_boulders','cliffs']:
        for uv in obj.data.uv_layers.active.data:uv.uv*=max(dims)/8.0
    obj.data.validate(clean_customdata=False)
    obj.data.update()
    bpy.context.view_layer.update()
    obj['asset_id']=obj.name;obj['size_category']=category;obj['family']=family
    obj['seed']=seed;obj['variation']=variant;obj['units']='metres';obj['generator_version']=VERSION
    return obj,seed


def make_materials():
    # Export-compatible Principled BSDF graph; texture data originates in the
    # supplied file. 1K JPEG maps keep standalone GLBs modest in size.
    imgs=[]
    texdir=ART/'textures';texdir.mkdir(parents=True,exist_ok=True)
    for source_name,label in [('ROCK_Base Color.jpeg','rock_albedo'),('ROCK_Normal.jpeg','rock_normal')]:
        img=bpy.data.images[source_name].copy();img.name='Mineral_'+label
        img.scale(1024,1024)
        img.file_format='JPEG';img.filepath_raw=str(texdir/(label+'.jpg'))
        img.save()
        (OUT/'textures').mkdir(parents=True,exist_ok=True)
        shutil.copy2(img.filepath_raw,OUT/'textures'/Path(img.filepath_raw).name)
        scaled=bpy.data.images.load(img.filepath_raw,check_existing=False)
        scaled.name='Mineral_export_'+label
        bpy.data.images.remove(img)
        img=scaled;img.pack()
        if 'normal' in label:img.colorspace_settings.name='Non-Color'
        imgs.append(img)
    rock=bpy.data.materials.new('Mineral_Stone_PBR');rock.use_nodes=True
    nodes=rock.node_tree.nodes;links=rock.node_tree.links
    bs=nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.86
    bs.inputs['Specular IOR Level'].default_value=.25
    tex=nodes.new('ShaderNodeTexImage');tex.image=imgs[0]
    vc=nodes.new('ShaderNodeVertexColor');vc.layer_name='Color'
    mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
    links.new(tex.outputs['Color'],mix.inputs[1]);links.new(vc.outputs['Color'],mix.inputs[2]);links.new(mix.outputs[0],bs.inputs['Base Color'])
    normaltex=nodes.new('ShaderNodeTexImage');normaltex.image=imgs[1]
    normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.55
    links.new(normaltex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bs.inputs['Normal'])
    ice=bpy.data.materials.new('Mineral_Glacier_PBR');ice.use_nodes=True
    ib=ice.node_tree.nodes.get('Principled BSDF');ib.inputs['Roughness'].default_value=.32
    ib.inputs['IOR'].default_value=1.31;ib.inputs['Metallic'].default_value=0
    iv=ice.node_tree.nodes.new('ShaderNodeVertexColor');iv.layer_name='Color'
    ice.node_tree.links.new(iv.outputs['Color'],ib.inputs['Base Color'])
    return rock,ice


def verify_mesh(obj):
    mesh=obj.data
    bm=bmesh.new();bm.from_mesh(mesh)
    result={'vertices':len(mesh.vertices),'triangles':triangles(mesh),
            'boundary_edges':sum(e.is_boundary for e in bm.edges),
            'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),
            'degenerate_faces':sum(f.calc_area()<1e-12 for f in bm.faces)}
    bm.free()
    assert result['triangles']>0 and not result['boundary_edges'],result
    assert not result['nonmanifold_edges'] and not result['degenerate_faces'],result
    assert all(math.isfinite(c) for v in mesh.vertices for c in v.co)
    return result


def export_asset(obj,category,family,variant,seed):
    activate(obj)
    folder=OUT/category;folder.mkdir(parents=True,exist_ok=True)
    path=folder/(obj.name+'.glb')
    bpy.context.view_layer.update()
    dims=list(obj.dimensions)
    stats=verify_mesh(obj)
    assert stats['triangles']<=BUDGETS[category],stats
    # glTF automatically multiplies COLOR_0 with baseColorTexture. Give the
    # exporter a direct image link so it can preserve the map without baking.
    bs=rock_mat.node_tree.nodes.get('Principled BSDF')
    old=bs.inputs['Base Color'].links[0].from_socket
    tex=next(n for n in rock_mat.node_tree.nodes if n.bl_idname=='ShaderNodeTexImage' and 'albedo' in n.image.name)
    rock_mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
        export_apply=True,export_animations=False,export_cameras=False,export_lights=False,
        export_extras=True,export_materials='EXPORT',export_image_format='JPEG',export_jpeg_quality=85,
        export_vertex_color='ACTIVE')
    rock_mat.node_tree.links.new(old,bs.inputs['Base Color'])
    # Read exported JSON to ensure portable materials, vertex colors and UVs.
    raw=path.read_bytes();doc=json.loads(raw[20:20+int.from_bytes(raw[12:16],'little')])
    primitives=[p for m in doc['meshes'] for p in m['primitives']]
    assert len(primitives)==1
    assert 'TEXCOORD_0' in primitives[0]['attributes'] and 'COLOR_0' in primitives[0]['attributes']
    assert all('bufferView' in i for i in doc.get('images',[]))
    if family!='glacier':
        assert len(doc.get('images',[]))==2
        assert 'baseColorTexture' in doc['materials'][0]['pbrMetallicRoughness']
        assert 'normalTexture' in doc['materials'][0]
    obj.hide_render=True;obj.hide_set(True)
    return dict(asset=obj.name,category=category,family=family,variant=variant+1,seed=seed,
                dimensions_blender_xyz_m=dims,dimensions_godot_xyz_m=[dims[0],dims[2],dims[1]],
                path=path.relative_to(ROOT).as_posix(),sha256=sha(path),bytes=path.stat().st_size,
                material_surfaces=1,embedded_textures=len(doc.get('images',[])),**stats)


def render_contact_sheet(objects,category):
    scene=bpy.context.scene
    for o in scene.objects:o.hide_render=True
    for o in studio:o.hide_render=False
    # Normalized thumbnails emphasize shape comparisons; captions give the
    # actual metre span. Editable object transforms are restored afterwards.
    temporary=[]
    for index,obj in enumerate(objects):
        f=CATEGORY_FAMILIES[category].index(obj['family']);v=obj['variation']
        dup=obj.copy();dup.data=obj.data;scene.collection.objects.link(dup)
        dup.hide_render=False;dup.hide_set(False)
        dup.scale=(2.6/max(obj.dimensions),)*3
        dup.location=((v-1.5)*3.8,(2.5-f)*4.2,0)
        temporary.append(dup)
        font=bpy.data.curves.new('asset caption','FONT')
        font.body=f'{obj["family"].upper()} {v+1:02}  |  {LENGTHS[category][v]:g} m'
        font.align_x='CENTER';font.size=.21
        label=bpy.data.objects.new('caption',font);scene.collection.objects.link(label)
        label.location=dup.location+Vector((0,-1.8,.012));font.materials.append(label_mat)
        temporary.append(label)
    camera.location=(0,-28,42);camera.rotation_euler=(Vector((0,0,.1))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=29
    scene.render.resolution_x=1600;scene.render.resolution_y=1800
    scene.render.filepath=str(QA/(category+'_contact_sheet.png'))
    bpy.ops.render.render(write_still=True)
    for o in temporary:bpy.data.objects.remove(o,do_unlink=True)


def make_studio():
    scene=bpy.context.scene
    world=bpy.data.worlds.new('Mineral gallery atmosphere');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.47,.62,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=world
    objects=[]
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.035))
    floor=bpy.context.object;floor.name='Preview ground'
    mat=bpy.data.materials.new('Preview snow');mat.diffuse_color=(.70,.76,.82,1);floor.data.materials.append(mat);objects.append(floor)
    data=bpy.data.lights.new('Gallery sun','SUN');sun=bpy.data.objects.new('Gallery sun',data)
    scene.collection.objects.link(sun);data.energy=2.4;data.angle=.12;sun.rotation_euler=(.45,-.65,-.4);objects.append(sun)
    data=bpy.data.lights.new('Gallery fill','AREA');fill=bpy.data.objects.new('Gallery fill',data)
    scene.collection.objects.link(fill);fill.location=(0,-12,17);data.energy=1800;data.shape='DISK';data.size=14
    fill.rotation_euler=(Vector((0,0,0))-fill.location).to_track_quat('-Z','Y').to_euler();objects.append(fill)
    data=bpy.data.cameras.new('Gallery camera');cam=bpy.data.objects.new('Gallery camera',data)
    scene.collection.objects.link(cam);data.type='ORTHO';scene.camera=cam;objects.append(cam)
    scene.render.engine='BLENDER_EEVEE';scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.view_settings.view_transform='AgX'
    label=bpy.data.materials.new('Caption ink');label.diffuse_color=(.025,.045,.07,1)
    return objects,cam,label


OUT.mkdir(parents=True,exist_ok=True);ART.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
previous=json.loads((OUT/'manifest.json').read_text()) if (OUT/'manifest.json').exists() else {}
preserved=[r for r in previous.get('assets',[]) if r['category'] not in SELECTED]
for row in preserved:assert sha(ROOT/row['path'])==row['sha256'],row['asset']
source_hash=sha(SOURCE)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),use_scripts=False)
bpy.context.preferences.filepaths.save_version=0
generator=bpy.data.objects['Cube']
graph=generator.modifiers[0].node_group.copy();graph.name='Alpine Mineral Generator'
generator.modifiers[0].node_group=graph
# Constant nodes retain single-value socket semantics in current Blender; a
# disconnected Random Value ID socket implicitly becomes the Index field.
constant_nodes={}
for name,v in [('Seed',281),('Variation',2),('Stone Density',0),('Add Grass',0)]:
    node=graph.nodes.new('FunctionNodeInputInt');node.integer=v;node.label='Library '+name
    for link in list(graph.links):
        if link.from_node.bl_idname=='NodeGroupInput' and link.from_socket.name==name:
            graph.links.new(node.outputs[0],link.to_socket)
    constant_nodes[name]=node
seed_node=constant_nodes['Seed'];variation_node=constant_nodes['Variation']
graph.nodes['Subdivide Mesh'].inputs['Level'].default_value=3
# Export the original deformed rock surface before optional stone/grass scatter.
graph.links.new(graph.nodes['Set Position.003'].outputs['Geometry'],graph.nodes['Group Output'].inputs['Geometry'])
generator.name='SOURCE_Generator_do_not_export'
for obj in list(bpy.data.objects):
    if obj!=generator:bpy.data.objects.remove(obj,do_unlink=True)
generator.hide_render=True
rock_mat,ice_mat=make_materials()
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
records=[];all_objects=[]
start=time.time()
for category in SELECTED:
    category_objects=[]
    for family in CATEGORY_FAMILIES[category]:
        for variant in range(1 if SAMPLE else 4):
            obj,seed=build_shape(category,family,variant)
            records.append(export_asset(obj,category,family,variant,seed))
            category_objects.append(obj);all_objects.append(obj)
            print('MINERAL_EXPORTED',obj.name,records[-1]['triangles'],flush=True)
    # Separate editable category files in metres, arranged without scaling.
    for obj in category_objects:
        obj.hide_set(False);obj.hide_render=False
        spacing=max(LENGTHS[category])*1.4
        obj.location=(obj['variation']*spacing,CATEGORY_FAMILIES[category].index(obj['family'])*spacing,0)
    generator.hide_set(True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(ART/(category+('_sample' if SAMPLE else '')+'.blend')),compress=True)
    for obj in category_objects:obj.location=(0,0,0);obj.hide_render=True;obj.hide_set(True)
    generator.hide_set(False)
studio,camera,label_mat=make_studio()
for category in CATEGORIES:
    objs=[o for o in all_objects if o['size_category']==category]
    if objs:render_contact_sheet(objs,category)
# Independent Blender GLB reimport checks run in a new empty scene.
for rec in records:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/rec['path']))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(meshes)==1
    obj=meshes[0];bpy.context.view_layer.update()
    assert triangles(obj.data)==rec['triangles'],(rec['asset'],triangles(obj.data),rec['triangles'])
    # glTF import converts back to Blender Z up.
    assert max(abs(obj.dimensions[i]-rec['dimensions_blender_xyz_m'][i]) for i in range(3))<.005
    assert len(obj.data.materials)==1 and len(obj.data.uv_layers)>0
    rec['blender_roundtrip_verified']=True
assert sha(SOURCE)==source_hash
for row in preserved:assert sha(ROOT/row['path'])==row['sha256'],row['asset']
new_count=len(records)
records=preserved+records
manifest=dict(version=VERSION,source='rock_generator.blend',source_sha256=source_hash,
    blender_version=bpy.app.version_string,size_definition='Longest bounding-box dimension in metres',
    categories=LENGTHS,category_families=CATEGORY_FAMILIES,triangle_budgets=BUDGETS,asset_count=len(records),
    source_preserved=True,collision='Visual assets only; no skiing/contact changes',
    lod_policy='Godot importer generates mesh LODs; one surface per asset',
    elapsed_seconds=round(time.time()-start,2),generated_categories=SELECTED,
    preserved_asset_count=len(preserved),assets=records)
(OUT/('sample_manifest.json' if SAMPLE else 'manifest.json')).write_text(json.dumps(manifest,indent=2)+'\n')
print('MINERAL_LIBRARY_COMPLETE',len(records),'total assets;',new_count,'generated;',len(preserved),'preserved;',round(time.time()-start,1),'seconds',flush=True)
