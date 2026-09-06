"""Rebuild the authored alpine library in Blender. Metres, Z-up sources, Y-up GLB.

Run with blender --background --python scripts/art/build_alpine_assets.py.
Only standalone source scenes are touched; no interactive Blender scene is used.
"""
import bpy, bmesh, math, random, json
from pathlib import Path
from mathutils import Vector, noise

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/graphics/models'; OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'art_source/blender'; SOURCE.mkdir(parents=True,exist_ok=True)
TEX=ROOT/'assets/graphics/textures'
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name,color,rough=.8,metal=0,texture=None,alpha=False):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    m.use_backface_culling=not alpha
    if texture:
        t=m.node_tree.nodes.new('ShaderNodeTexImage'); t.image=bpy.data.images.load(str(TEX/texture),check_existing=True)
        m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
        if alpha:
            m.node_tree.links.new(t.outputs['Alpha'],p.inputs['Alpha'])
            if hasattr(m,'surface_render_method'): m.surface_render_method='DITHERED'
    return m

bark=material('Bark',(.19,.16,.12),texture='bark_albedo.jpg')
needles=material('Needles',(.08,.13,.09),texture='spruce_needles.png',alpha=True)
snow=material('Snow',(.80,.86,.91),.84)
rock=material('Rock',(.24,.25,.27),texture='rock_albedo.jpg')
ink=material('EquipmentGraphite',(.025,.037,.048),.4)
metal=material('EquipmentMetal',(.35,.40,.43),.25,.85)
orange=material('EquipmentOrange',(.85,.19,.045),.42)
lime=material('EquipmentLime',(.65,.83,.20),.38)

class Builder:
    def __init__(self): self.v=[]; self.f=[]; self.mi=[]; self.uv=[]
    def face(self,points,mat=0,uv=None):
        i=len(self.v); self.v.extend([tuple(p) for p in points]); self.f.append(tuple(range(i,i+len(points)))); self.mi.append(mat)
        self.uv.extend(uv or [(p[0]*.6,p[2]*.6) for p in points])
    def tube(self,a,b,r1,r2,mat=0,sides=6):
        a,b=Vector(a),Vector(b); up=(b-a).normalized(); ax=up.cross(Vector((0,0,1)))
        if ax.length<.01: ax=Vector((1,0,0))
        ax.normalize(); ay=up.cross(ax)
        for i in range(sides):
            d1=ax*math.cos(i*math.tau/sides)+ay*math.sin(i*math.tau/sides)
            d2=ax*math.cos((i+1)*math.tau/sides)+ay*math.sin((i+1)*math.tau/sides)
            self.face([a+d1*r1,a+d2*r1,b+d2*r2,b+d1*r2],mat,[(i/sides,0),((i+1)/sides,0),((i+1)/sides,(b-a).length),(i/sides,(b-a).length)])
    def card(self,center,direction,width,length,mat=1,tilt=0):
        c=Vector(center); along=Vector(direction).normalized(); cross=along.cross(Vector((0,0,1))).normalized()
        cross=(cross*math.cos(tilt)+Vector((0,0,1))*math.sin(tilt)).normalized()
        self.face([c-along*length*.5-cross*width*.5,c-along*length*.5+cross*width*.5,c+along*length*.5+cross*width*.15,c+along*length*.5-cross*width*.15],mat,[(0,0),(1,0),(1,1),(0,1)])
    def cap(self,c,along,length,width,height,mat=2):
        c=Vector(c); along=Vector(along).normalized(); across=along.cross(Vector((0,0,1))).normalized()
        # Low rounded snow shelves with a broken outline, not solid cone layers.
        ring=[]
        for i in range(6):
            a=i*math.tau/6; ring.append(c+along*math.cos(a)*length*.5+across*math.sin(a)*width*.5)
        peak=c+Vector((0,0,height)); upper=[p.lerp(peak,.42)+Vector((0,0,height*.26)) for p in ring]
        for i in range(6):
            j=(i+1)%6
            self.face([upper[i],upper[j],ring[j],ring[i]],mat)
            self.face([peak,upper[j],upper[i]],mat)
    def object(self,name,mats):
        mesh=bpy.data.meshes.new(name); mesh.from_pydata(self.v,[],self.f); mesh.update()
        obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
        for m in mats: mesh.materials.append(m)
        uv=mesh.uv_layers.new(name='UVMap')
        for poly,mi in zip(mesh.polygons,self.mi):
            poly.material_index=mi
            for l in poly.loop_indices: uv.data[l].uv=self.uv[mesh.loops[l].vertex_index]
        # Weld geometry before smoothing bark and rounded snow clumps. UVs stay per loop.
        bm=bmesh.new();bm.from_mesh(mesh)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
        bm.to_mesh(mesh);bm.free()
        for poly in mesh.polygons:poly.use_smooth=poly.material_index!=1
        return obj

stats=[]; sources=[]
def export(obj,name):
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    path=OUT/(name+'.glb')
    original_materials=list(obj.data.materials)
    for i,m in enumerate(original_materials):
        if m.name in ['Bark','Needles','Rock']:
            placeholder=bpy.data.materials.get(m.name+'.Runtime') or bpy.data.materials.new(m.name+'.Runtime')
            placeholder.diffuse_color=m.diffuse_color
            obj.data.materials[i]=placeholder
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_materials='EXPORT',export_apply=True,export_animations=False)
    for i,m in enumerate(original_materials): obj.data.materials[i]=m
    obj.data.calc_loop_triangles()
    stats.append(dict(asset=name,triangles=len(obj.data.loop_triangles),dimensions=list(obj.dimensions),materials=[m.name for m in obj.data.materials]))
    sources.append(obj); obj.hide_render=True; obj.hide_set(True)

for variant in range(3):
    for lod in range(3):
        rng=random.Random(441+variant); b=Builder(); height=[10.3,10.8,9.9][variant]
        b.tube((0,0,0),(0,0,1),.46,.24,0,10 if lod==0 else 6)
        b.tube((0,0,1),(.07,-.06,height),.24,.016,0,8 if lod==0 else 5)
        levels=[14,10,7][lod]; branches=[7,6,5][lod]; tufts=[4,3,2][lod]
        for level in range(levels):
            z=1.5+(height-2)*level/levels; radius=(2.9+variant*.12)*pow(1-z/(height+.2),.77)
            for j in range(branches):
                a=level*2.399+j*math.tau/branches+rng.uniform(-.14,.14)
                out=Vector((math.cos(a),math.sin(a),-.12)); reach=radius*rng.uniform(.8,1.15)
                start=Vector((.02,0,z)); tip=start+out*reach
                if lod<2: b.tube(start,tip,.045*(1-z/(height+1)),.007,0,5)
                for k in range(tufts):
                    t=.24+.7*k/max(1,tufts-1); c=start+out*reach*t
                    length=reach*(.54 if lod<2 else .73); width=length*.60
                    b.card(c,out,width,length,1,0.25)
                    if lod==0: b.card(c,out,width*.65,length*.9,1,1.2)
                    b.cap(c+Vector((0,0,.04+rng.uniform(-.035,.065))),out,length*rng.uniform(.63,.9),width*rng.uniform(.65,.95),.14+width*.14)
        obj=b.object(f'Spruce{variant+1}_LOD{lod}',[bark,needles,snow]); export(obj,f'spruce_{variant+1}_lod{lod}')

for variant in range(2):
    rng=random.Random(715+variant); b=Builder()
    for i in range(8):
        a=rng.random()*math.tau; out=Vector((math.cos(a),math.sin(a),.38)); c=out*rng.uniform(.12,.3)
        b.tube((0,0,0),out*.55,.018,.003,0,4); b.card(c,out,.35,.6)
        b.cap(c+Vector((0,0,.055)),out,.3,.15,.04)
    export(b.object('Scrub',[bark,needles,snow]),f'scrub_{variant+1}')

for variant in range(3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1)
    obj=bpy.context.object; obj.name=f'Boulder{variant+1}'
    for v in obj.data.vertices:
        p=v.co.copy(); n=noise.noise_vector(p*2.1+Vector((variant*4,2,7)))[0]
        v.co=p*(1+n*.18); v.co.x*=1.22; v.co.y*=1.08; v.co.z=v.co.z*.91+.87
        v.co.z=max(0,v.co.z)
    # Exact common obstacle envelope; artists can reshape inside this volume.
    radius=max(math.hypot(v.co.x,v.co.y) for v in obj.data.vertices)
    for v in obj.data.vertices: v.co.x*=1.35/radius; v.co.y*=1.35/radius
    obj.data.materials.append(rock)
    for poly in obj.data.polygons:poly.use_smooth=True
    export(obj,f'boulder_{variant+1}')

for variant in range(3):
    b=Builder(); nx,ny=100,48; pts=[]
    for j in range(ny+1):
        y=(j/ny*2-1)*850
        for i in range(nx+1):
            x=(i/nx*2-1)*1500; phase=x/530+variant*2.4
            crest=math.sin(x*.0018+variant)*130+math.sin(x*.005+variant)*55
            along=.65+.20*math.sin(phase*2.1)+.15*math.sin(phase*4.6+.7)
            cross=max(0,1-abs(y-crest)/950)
            ribs=abs(noise.fractal(Vector((x*.004,y*.006,variant+1)),1.1,2,4))
            z=pow(cross,1.7)*(500+along*520)+(ribs-.35)*140*cross
            z*=max(0,1-pow(abs(x)/1550,8))
            pts.append(Vector((x,y,z)))
    (OUT/f"ridge_{variant+1}.heights.json").write_text(json.dumps({"nx":nx+1,"ny":ny+1,"heights":[round(p.z,4) for p in pts]}))
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i
            b.face([pts[a],pts[a+1],pts[a+nx+2]],0)
            b.face([pts[a],pts[a+nx+2],pts[a+nx+1]],0)
    obj=b.object('AlpineRidge',[rock])
    # Weld shared points then smooth the continuous ridge surface.
    bpy.context.view_layer.objects.active=obj; obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.remove_doubles(threshold=.001); bpy.ops.object.mode_set(mode='OBJECT')
    for p in obj.data.polygons: p.use_smooth=True
    export(obj,f'ridge_{variant+1}')

def bevel_box(name,location,scale,mat,bevel=.018):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location); o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=o.modifiers.new('Manufactured edges','BEVEL'); mod.width=bevel; mod.segments=2
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.append(mat); return o

# Model coordinates: Blender -Y is Godot +Z (the skier's forward).
b=Builder()
sections=[(-1.02,.028,.018),(-.91,.050,.012),(-.5,.052,.007),(0,.048,.0),(.55,.061,.012),(.87,.073,.045),(1.03,.066,.12),(1.12,.043,.21),(1.15,.008,.24)]
for i in range(len(sections)-1):
    a,w,z=sections[i]; c,v,h=sections[i+1]
    top=[(-w,-a,z),(w,-a,z),(v,-c,h),(-v,-c,h)]
    b.face(list(reversed(top)),0)
    b.face([(x,y,zz-.016) for x,y,zz in top],1)
    for s in [-1,1]: b.face([(s*w,-a,z),(s*w,-a,z-.016),(s*v,-c,h-.016),(s*v,-c,h)],1)
    if i>3: b.face([(-v*.12,-c,h+.001),(v*.12,-c,h+.001),(w*.12,-a,z+.001),(-w*.12,-a,z+.001)],2 if i%2 else 3)
ski=b.object('Ski',[ink,metal,lime,orange]); export(ski,'ski')

for name,parts in [
    ('binding', [((0,0,.035),(.14,.4,.065),metal),((0,-.16,.08),(.13,.10,.10),ink),((0,.15,.10),(.14,.14,.14),ink)]),
    ('boot', [((0,-.035,.075),(.135,.30,.15),ink),((0,.045,.22),(.14,.17,.30),ink),((0,-.10,.13),(.145,.035,.03),metal),((0,-.05,.25),(.15,.025,.035),metal),((0,-.035,.35),(.15,.035,.025),orange)])]:
    objs=[bevel_box(name,p,s,m,.015) for p,s,m in parts]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]; bpy.ops.object.join(); export(objs[0],name)
b=Builder(); b.tube((0,0,0),(0,0,-1.18),.008,.006,0,8); b.tube((0,0,.015),(0,0,-.13),.018,.014,1,10)
for i in range(8):
    a=i*math.tau/8; b.tube((0,0,-1.02),(.055*math.cos(a),.055*math.sin(a),-1.02),.006,.004,1,4)
export(b.object('Pole',[metal,ink]),'pole')

for o in sources: o.hide_set(False); o.hide_render=False
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'alpine_library.blend'))
(SOURCE/'library_stats.json').write_text(json.dumps(stats,indent=2))
# Verify the model-only exports, independently of the authoring scene.
roundtrip=[]
for s in stats:
    bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=str(OUT/(s['asset']+'.glb')))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    count=0
    for o in meshes:o.data.calc_loop_triangles(); count+=len(o.data.loop_triangles)
    assert count==s['triangles'],(s['asset'],count,s['triangles'])
    assert all(o.type in ['MESH','EMPTY'] for o in bpy.context.scene.objects)
    roundtrip.append(dict(asset=s['asset'],triangles=count,verified=True))
(SOURCE/'roundtrip.json').write_text(json.dumps(roundtrip,indent=2))
print('ALPINE_ASSETS_COMPLETE',len(stats),'verified exports')
