"""Deterministic needle atlas and curved sprays; executed inside Blender.

The atlas is baked from editable needle/twig meshes, not painted rectangles.
Runtime color is albedo only. Its lighting stays in Godot.
"""
import bpy
import bmesh
import hashlib
import json
import math
import random
import struct
from pathlib import Path
import numpy as np
from mathutils import Vector

REVISION = 3
LIVING = ('spruce', 'fir', 'pine')


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build_identity(ctx):
    paths=['scripts/art/build_tree_collection.py','scripts/art/foliage_clusters.py']
    paths += ['assets/graphics/trees/textures/foliage_'+channel+suffix+'.res'
              for channel in ('color','normal_ao') for suffix in ('','_balanced','_low')]
    values={p:digest(ctx['ROOT']/p) for p in paths}
    values.update(source=ctx['source_hash'],blender=bpy.app.version_string)
    return hashlib.sha256(json.dumps(values,sort_keys=True).encode()).hexdigest()


def png(path, pixels, data=False):
    h, w, _ = pixels.shape
    im = bpy.data.images.new(path.stem, width=w, height=h, alpha=True)
    if data:
        im.colorspace_settings.name = 'Non-Color'
    im.pixels.foreach_set(np.ascontiguousarray(pixels, dtype=np.float32).ravel())
    im.file_format = 'PNG'; im.filepath_raw = str(path); im.save()
    bpy.data.images.remove(im)


def dilate_rgb(pixels, steps=12):
    """Fill transparent gutters with nearby color without changing coverage."""
    out = pixels.copy(); valid = out[:, :, 3] > .01
    for _ in range(steps):
        total = np.zeros_like(out[:, :, :3]); count = np.zeros_like(valid, dtype=np.float32)
        for axis, delta in ((0,-1),(0,1),(1,-1),(1,1)):
            m = np.roll(valid, delta, axis); c = np.roll(out[:,:,:3], delta, axis)
            if axis == 0: m[0 if delta == 1 else -1,:] = False
            else: m[:,0 if delta == 1 else -1] = False
            total += c*m[:,:,None]; count += m
        fill = ~valid & (count > 0)
        out[fill,:3] = total[fill] / count[fill,None]
        valid |= fill
    return out


def srgb(linear):
    return np.where(linear <= .0031308, linear*12.92, 1.055*np.maximum(linear,0)**(1/2.4)-.055)


def write_dds(path, base, color=False, coverage=False):
    """RGBA8 DDS with an explicit mip chain. Coverage fixed per atlas tile."""
    # Blender pixels are bottom-up; DDS rows follow the top-down runtime image.
    levels=[]; img=base[::-1].copy(); targets=[]
    # Blender's loaded PNG pixel buffer already contains encoded sRGB values.
    # Filter color in linear space, then encode once when storing each DDS mip.
    if color:
        rgb=img[:,:,:3]
        img[:,:,:3]=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
    for y in range(2):
        for x in range(2):
            tile=img[y*img.shape[0]//2:(y+1)*img.shape[0]//2,x*img.shape[1]//2:(x+1)*img.shape[1]//2]
            targets.append(float((tile[:,:,3]>=.5).mean()))
    while True:
        stored=img.copy()
        if color: stored[:,:,:3]=srgb(stored[:,:,:3])
        levels.append(np.uint8(np.clip(stored,0,1)*255+.5).tobytes())
        h,w,_=img.shape
        if h==1: break
        img=img.reshape(h//2,2,w//2,2,4).mean(axis=(1,3))
        if coverage and h//2 >= 8:
            for y in range(2):
                for x in range(2):
                    a=img[y*h//4:(y+1)*h//4,x*w//4:(x+1)*w//4,3]
                    lo,hi=.05,8.0
                    for _ in range(18):
                        m=(lo+hi)*.5
                        if (a*m>=.5).mean()<targets[y*2+x]: lo=m
                        else: hi=m
                    a[:]=np.clip(a*((lo+hi)*.5),0,1)
        elif not color:
            n=img[:,:,:3]*2-1; n/=np.maximum(np.linalg.norm(n,axis=2,keepdims=True),.001)
            img[:,:,:3]=n*.5+.5
    h,w,_=base.shape
    header=[124,0x2100F,h,w,w*4,0,len(levels)]+[0]*11
    header += [32,0x41,0,32,0xFF,0xFF00,0xFF0000,0xFF000000]
    header += [0x401008,0,0,0,0]
    assert len(header)==31
    path.write_bytes(b'DDS '+struct.pack('<31I',*header)+b''.join(levels))


def bake_needles(ctx):
    root=ctx['ROOT']; base=ctx['BASE']; edit=root/'art_source/blender/foliage_v3'
    out=root/'artifacts/foliage_v3/atlas'; out.mkdir(parents=True,exist_ok=True); edit.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=12
    scene.render.threads_mode='FIXED'; scene.render.threads=6
    scene.render.resolution_x=scene.render.resolution_y=1024; scene.render.resolution_percentage=100
    scene.render.film_transparent=True; scene.render.image_settings.color_mode='RGBA'
    scene.view_settings.view_transform='Standard'
    mat=bpy.data.materials.new('Needle source albedo'); mat.use_nodes=True
    n=mat.node_tree.nodes; l=mat.node_tree.links; output=n.get('Material Output')
    vc=n.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    ao=n.new('ShaderNodeAmbientOcclusion'); ao.inputs['Distance'].default_value=.08; ao.only_local=True
    tint=n.new('ShaderNodeMixRGB'); tint.blend_type='MULTIPLY'; tint.inputs[0].default_value=.38
    l.new(vc.outputs['Color'],tint.inputs[1]); l.new(ao.outputs['AO'],tint.inputs[2])
    emission=n.new('ShaderNodeEmission'); l.new(tint.outputs[0],emission.inputs[0]); l.new(emission.outputs[0],output.inputs['Surface'])
    geom=n.new('ShaderNodeNewGeometry'); scale=n.new('ShaderNodeVectorMath'); scale.operation='MULTIPLY_ADD'
    l.new(geom.outputs['Normal'],scale.inputs[0]); scale.inputs[1].default_value=(.5,.5,.5); scale.inputs[2].default_value=(.5,.5,.5)
    cam=bpy.data.objects.new('Needle bake camera',bpy.data.cameras.new('Needle bake camera')); scene.collection.objects.link(cam); scene.camera=cam
    cam.location=(0,.5,3); cam.rotation_euler=(0,0,0); cam.data.type='ORTHO'; cam.data.ortho_scale=1.12
    color=np.zeros((2048,2048,4),np.float32); normal=np.zeros_like(color); normal[:,:,:3]=(.5,.5,1); normal[:,:,3]=1
    for tile,species in enumerate(('spruce','fir','pine','spruce')):
        g=ctx['Geometry'](1); rng=random.Random(8620+tile*131)
        roots=[(Vector((0,.055,.015)),Vector((0,.92,.02)))]
        for i in range(9):
            y=.13+i*.083; length=.35*(1-.69*i/9)
            for side in (-1,1):
                reach=length*rng.uniform(.83,1.13)
                roots.append((Vector((0,y+rng.uniform(-.012,.012),.022)),Vector((side*reach,y+reach*rng.uniform(.35,.57),.025+rng.random()*.015))))
        for j,(a,b) in enumerate(roots):
            direction=(b-a).normalized(); side=Vector((direction.y,-direction.x,0)); length=(b-a).length
            g.tube([a,b],[.006 if j==0 else .003,.0008],(.11,.061,.023,1),5,0)
            count=65 if j==0 else 28
            for i in range(count):
                t=(i+.3)/count; p=a.lerp(b,t)
                for sign in (-1,1):
                    d=(side*sign*.85+direction*.45+Vector((0,0,rng.uniform(-.12,.28)))).normalized()
                    le={'pine':.135,'spruce':.09,'fir':.082}[species]*rng.uniform(.72,1.24)*(1-.45*t)
                    width={'fir':.007,'spruce':.0065,'pine':.0055}[species]*rng.uniform(.8,1.15)
                    shade=rng.uniform(.78,1.24); green={'spruce':(.035,.145,.045),'fir':(.035,.125,.055),'pine':(.065,.165,.035)}[species]
                    c=tuple(v*shade for v in green)+(1,)
                    across=Vector((-d.y,d.x,0)).normalized()*width
                    ridge=p+d*le*.45+Vector((0,0,width*1.2)); tip=p+d*le
                    g.face([p-across,tip,ridge],c,0); g.face([ridge,tip,p+across],c,0)
        obj=g.object('Editable '+species+' needle spray '+str(tile),mat)
        # Explicit normals and albedo are rendered from the identical mesh/camera.
        passes={}
        for mode,socket in [('color',tint.outputs[0]),('normal',scale.outputs['Vector']),('ao',ao.outputs['AO'])]:
            l.new(socket,emission.inputs[0]); scene.view_settings.view_transform='Standard' if mode=='color' else 'Raw'
            scene.render.filepath=str(out/f'tile{tile}_{mode}.png'); bpy.ops.render.render(write_still=True)
            im=bpy.data.images.load(scene.render.filepath,check_existing=False)
            if mode!='color': im.colorspace_settings.name='Non-Color'
            buf=np.empty(1024*1024*4,np.float32); im.pixels.foreach_get(buf); passes[mode]=buf.reshape(1024,1024,4); bpy.data.images.remove(im)
        c=dilate_rgb(passes['color']); nm=passes['normal']; nm[:,:,3]=passes['ao'][:,:,0]
        nm[c[:,:,3]<.01]=(.5,.5,1,1)
        y,x=divmod(tile,2); color[y*1024:(y+1)*1024,x*1024:(x+1)*1024]=c
        normal[y*1024:(y+1)*1024,x*1024:(x+1)*1024]=nm
        obj.hide_render=True
    l.new(tint.outputs[0],emission.inputs[0]); scene.view_settings.view_transform='Standard'
    for obj in scene.objects:
        if obj.type=='MESH': obj.hide_render=False; obj.location.x+=int(obj.name[-1])*1.25
    bpy.ops.wm.save_as_mainfile(filepath=str(edit/'needle_sources.blend'))
    png(base/'textures/foliage_color.png',color); png(base/'textures/foliage_normal_ao.png',normal,True)
    write_dds(base/'textures/foliage_color.dds',color,color=True,coverage=True)
    write_dds(base/'textures/foliage_normal_ao.dds',normal)
    (out/'receipt.json').write_text(json.dumps({'revision':REVISION,'blender':bpy.app.version_string,'source':str(edit/'needle_sources.blend'),'color_sha256':digest(base/'textures/foliage_color.dds'),'normal_sha256':digest(base/'textures/foliage_normal_ao.dds'),'resolution':[2048,2048],'mip_levels':12,'alpha_threshold':.5,'mesh_source':'modeled needles and twigs; Cycles albedo, normals and local AO'},indent=2))


def foliage_material(ctx):
    mat,color=ctx['material'](); n=mat.node_tree.nodes; l=mat.node_tree.links
    vc=next(x for x in n if x.type=='VERTEX_COLOR')
    tex=n.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(ctx['BASE']/'textures/foliage_color.png'),check_existing=True)
    mask=n.new('ShaderNodeMath'); mask.operation='GREATER_THAN'; l.new(vc.outputs['Alpha'],mask.inputs[0]); mask.inputs[1].default_value=.45
    upper=n.new('ShaderNodeMath'); upper.operation='LESS_THAN'; l.new(vc.outputs['Alpha'],upper.inputs[0]); upper.inputs[1].default_value=.8
    both=n.new('ShaderNodeMath'); both.operation='MULTIPLY'; l.new(mask.outputs[0],both.inputs[0]); l.new(upper.outputs[0],both.inputs[1])
    tint=n.new('ShaderNodeMixRGB'); tint.blend_type='MULTIPLY'; tint.inputs[0].default_value=1
    l.new(tex.outputs['Color'],tint.inputs[1]); l.new(vc.outputs['Color'],tint.inputs[2])
    mix=n.new('ShaderNodeMixRGB'); l.new(both.outputs[0],mix.inputs[0]); l.new(color,mix.inputs[1]); l.new(tint.outputs[0],mix.inputs[2])
    alpha=n.new('ShaderNodeMixRGB'); l.new(both.outputs[0],alpha.inputs[0]); alpha.inputs[1].default_value=(1,1,1,1); l.new(tex.outputs['Alpha'],alpha.inputs[2])
    l.new(mix.outputs[0],n.get('Principled BSDF').inputs['Base Color']); l.new(alpha.outputs[0],n.get('Principled BSDF').inputs['Alpha'])
    return mat,mix.outputs[0],alpha.outputs[0]


def spray(g,root,direction,length,tile,bid,lod,tint):
    direction=direction.normalized(); side=direction.cross(Vector((0,0,1))).normalized()
    if side.length<.1: side=Vector((1,0,0))
    up=side.cross(direction).normalized(); row,col=divmod(tile,2)
    segments=4 if lod==0 else 1
    # Two bent sheets and a narrow central spray give volume from every heading.
    for angle in [0,1.05,-1.05]:
        across=side*math.cos(angle)+up*math.sin(angle)
        normal=direction.cross(across).normalized()
        for k in range(segments):
            points=[]; uv=[]
            for t,sign in ((k/segments,-1),(k/segments,1),((k+1)/segments,1),((k+1)/segments,-1)):
                # The texture has a tapered branched silhouette; trim the mesh to it.
                width=.45*(1-.60*t) if segments>1 else .45
                p=root+direction*(t*length)+across*(sign*width*length)
                p+=normal*(length*.13*math.sin(t*math.pi))+Vector((0,0,-length*.10*t*t))
                points.append(p)
                uv.append(((col+.5+sign*width)/2,(row+.05+t*.90)/2))
            g.face(points,tint,bid,uv)


def build(ctx,family,variant,wood,shoots,points_by_cluster,component_count):
    base=ctx['BASE']; root=ctx['ROOT']; name=f'forest_{family}_{variant:02}'
    old=next(a for a in ctx['manifest']['assets'] if a['id']==name)
    height=old['nominal_height_m']; fixed_height=old['height_m']; seed=old['seed']
    # height_m is the full grounded envelope, not the top coordinate.
    fixed_top=old['normalization_bounds']['max'][1]
    for source in bpy.context.scene.objects: source.hide_render=True
    mat,color,alpha=foliage_material(ctx); models=[]; near=None; crown=[]
    for lod in (0,1,3):
        g=ctx['Geometry'](height)
        for pts,tint,bid,uv in wood: g.face(pts,tint,bid,uv)
        obj=g.object(name+'_woody_source',mat); obj.data.calc_loop_triangles()
        bpy.context.view_layer.objects.active=obj; obj.select_set(True)
        if lod in (1,3):
            # Decimation cannot remove the minimum triangles of hundreds of
            # disconnected twig tubes. Prune whole fine tubes before simplifying;
            # the baked sprays already contain their terminal twigs.
            ranked=[]; keep=set()
            for indices,polygons in ctx['wood_components'](obj.data):
                pts=[obj.data.vertices[v].co for v in indices]
                if min(p.z for p in pts)<height*.08:
                    keep.update(polygons)
                else:
                    extent=Vector(tuple(max(p[j] for p in pts)-min(p[j] for p in pts) for j in range(3))).length
                    ranked.append((extent,polygons))
            ranked.sort(key=lambda item:item[0],reverse=True)
            for _,polygons in ranked[:96 if lod==1 else 12]: keep.update(polygons)
            bm=bmesh.new(); bm.from_mesh(obj.data); bm.faces.ensure_lookup_table()
            bmesh.ops.delete(bm,geom=[face for face in bm.faces if face.index not in keep],context='FACES')
            bm.to_mesh(obj.data); bm.free(); obj.data.calc_loop_triangles()
        budget={0:11500,1:2450,3:520}[lod]
        dec=obj.modifiers.new('Woody budget','DECIMATE'); dec.ratio=min(1,budget/max(1,len(obj.data.loop_triangles)))
        bpy.ops.object.modifier_apply(modifier=dec.name)
        geo=ctx['Geometry'](height)
        for v in obj.data.vertices:
            radius=math.hypot(v.co.x,v.co.y); limit=.44*height/10.5
            if v.co.z<height*.065 and radius>limit: v.co.x*=limit/radius; v.co.y*=limit/radius
        wm=obj.data
        for p in wm.polygons:
            pts=[wm.vertices[v].co.copy() for v in p.vertices]; c=sum(pts,Vector())/len(pts)
            geo.face(pts,tuple(wm.color_attributes['Color'].data[p.loop_start].color),ctx['cluster'](c,height),[tuple(wm.uv_layers[0].data[i].uv) for i in p.loop_indices])
        bpy.data.objects.remove(obj,do_unlink=True)
        for i,(center,direction,bid) in enumerate(shoots):
            rng=random.Random(seed+i*19); length=height*rng.uniform(.069,.086)*(1.1 if family=='pine' else 1)
            tint=(rng.uniform(.84,1.04),rng.uniform(.88,1.06),rng.uniform(.86,1.04),.7)
            tile=LIVING.index(family) if not (family=='spruce' and i%3==0) else 3
            if lod==3:
                if i%3: continue
                c=center+direction*length*.38
                r=length*.28; s=Vector((-direction.y,direction.x,0)).normalized()*r
                ends=[c-direction*length*.46,c+direction*length*.56]
                ring=[c+s,c+Vector((0,0,r*.65)),c-s,c-Vector((0,0,r*.65))]
                for j in range(4):
                    geo.face([ends[0],ring[j],ring[(j+1)%4]],(.1,.2,.1,.6),bid)
                    geo.face([ends[1],ring[(j+1)%4],ring[j]],(.1,.2,.1,.6),bid)
            else:
                before=len(geo.points); spray(geo,center,direction,length,tile,bid,lod,tint)
                for p in geo.points[before:]:
                    p.z=min(p.z,fixed_top)
                    crown.append(p.copy())
                if i%6==0:
                    # Broad curved top; integrated into the same branch asset.
                    geo.snow(center+Vector((0,0,length*.07)),center+direction*length*.68,length*.18,bid,rng)
        obj=geo.object(name+('_shadow' if lod==3 else f'_lod{lod}'),mat)
        for v in obj.data.vertices: v.co.z=min(v.co.z,fixed_top)
        for poly in obj.data.polygons: poly.use_smooth=True
        if lod!=3:
            # Keep the original normalization envelope exactly, independent of foliage fullness.
            top=max(obj.data.vertices,key=lambda v:v.co.z); top.co.z=fixed_top
        rec=ctx['export'](obj,base/'models'/f'{obj.name}.glb')
        assert rec['triangles']<={0:30000,1:6000,3:1500}[lod],(name,lod,rec['triangles'])
        obj.hide_render=True; obj.hide_set(True)
        if lod==0: near=obj; models.append(rec)
        elif lod==1: models.append(rec)
        else: shadow=rec
    # Bake actual albedo and cutouts; no directional lighting gets frozen in.
    near.hide_render=False; near.hide_set(False)
    bake_tree(ctx,near,mat,color,alpha,name,height)
    models.append(old['models'][2])
    for obj in list(bpy.context.scene.objects):
        if obj!=near: bpy.data.objects.remove(obj,do_unlink=True)
    near.asset_mark(); near.asset_data.description=f'{family} {variant}: textured curved needle clusters'
    bpy.ops.file.pack_all(); bpy.ops.wm.save_as_mainfile(filepath=str(ctx['EDIT']/f'{name}.blend'))
    lo=Vector(tuple(min(p[j] for p in crown) for j in range(3))); hi=Vector(tuple(max(p[j] for p in crown) for j in range(3)))
    center=(lo+hi)*.5; radius=max((p-center).length for p in crown)
    # Convert Blender Z-up metadata to Godot Y-up.
    old.update({'models':models,'shadow':shadow,'foliage_revision':REVISION,'height_m':fixed_height,
        'crown_center':[center.x,center.z,-center.y],'crown_radius':radius,
        'foliage_atlas':'assets/graphics/trees/textures/foliage_color.res','foliage_normal_ao':'assets/graphics/trees/textures/foliage_normal_ao.res',
        'build_sha256':digest(Path(__file__)),'build_identity':build_identity(ctx),
        'source_sha256':ctx['source_hash'],'atlas_complete':True})
    # Keep the existing twelve pivots and tree response parameters.
    ctx['manifest']['version']=REVISION
    ctx['manifest']['needle_geometry']='Curved needle sprays with baked albedo, normal, occlusion and coverage-preserving mipmaps'
    ctx['manifest_path'].write_text(json.dumps(ctx['manifest'],indent=2)+'\n')
    print('FOLIAGE_BUILT',name,[m['triangles'] for m in models],'shadow',shadow['triangles'],flush=True)


def bake_tree(ctx,obj,mat,color,alpha,name,height):
    scene=bpy.context.scene; n=mat.node_tree.nodes; l=mat.node_tree.links
    output=n.get('Material Output'); emission=n.new('ShaderNodeEmission'); transparent=n.new('ShaderNodeBsdfTransparent'); mix=n.new('ShaderNodeMixShader')
    l.new(color,emission.inputs[0]); l.new(alpha,mix.inputs[0]); l.new(transparent.outputs[0],mix.inputs[1]); l.new(emission.outputs[0],mix.inputs[2]); l.new(mix.outputs[0],output.inputs['Surface'])
    scene.render.engine='CYCLES'; scene.cycles.samples=8; scene.render.threads_mode='FIXED'; scene.render.threads=6
    scene.cycles.transparent_max_bounces=16
    scene.render.resolution_x=scene.render.resolution_y=512; scene.render.resolution_percentage=100
    scene.render.film_transparent=True; scene.render.image_settings.color_mode='RGBA'; scene.view_settings.view_transform='Standard'
    cam=bpy.data.objects.new('Tree albedo atlas camera',bpy.data.cameras.new('Tree albedo atlas camera')); scene.collection.objects.link(cam); scene.camera=cam
    cam.data.type='ORTHO'; cam.data.ortho_scale=height*1.12
    atlas=np.zeros((512,4096,4),np.float32); out=ctx['ROOT']/'artifacts/foliage_v3/atlas'; out.mkdir(parents=True,exist_ok=True)
    for view in range(8):
        a=view*math.tau/8; cam.location=(math.sin(a)*height*3,-math.cos(a)*height*3,height*.5)
        cam.rotation_euler=(Vector((0,0,height*.5))-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/f'{name}_{view}.png'); bpy.ops.render.render(write_still=True)
        im=bpy.data.images.load(scene.render.filepath,check_existing=False); buf=np.empty(512*512*4,np.float32); im.pixels.foreach_get(buf)
        atlas[:,view*512:(view+1)*512]=dilate_rgb(buf.reshape(512,512,4),6); bpy.data.images.remove(im)
    png(ctx['BASE']/'textures'/f'{name}_atlas.png',atlas)
    low=atlas.reshape(256,2,2048,2,4).mean(axis=(1,3)); png(ctx['BASE']/'textures'/f'{name}_atlas_low.png',low)
    l.new(n.get('Principled BSDF').outputs[0],output.inputs['Surface']); bpy.data.objects.remove(cam,do_unlink=True)
