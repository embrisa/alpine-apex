"""Blender: subtract only source-verified empty rider boxes from convex proxies.

The audit proves each centre is outside the source union and at least one metre
from every source triangle. Each carved box fits wholly inside that empty ball.
Half-space splitting preserves convexity and removes no visible source surface.
"""
from pathlib import Path
import json
import hashlib
import sys
import bmesh
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
audit=json.loads((ROOT/'artifacts/geology_v11/proxy_audit.json').read_text())
half=Vector((.36,.81,.36))

def overlaps_box(points,centre):
    bm=bmesh.new()
    for p in points: bm.verts.new(p)
    bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
    bm.normal_update()
    axes=[face.normal.copy() for face in bm.faces]
    for edge in bm.edges:
        direction=edge.verts[1].co-edge.verts[0].co
        for box_axis in (Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1))):
            axis=direction.cross(box_axis)
            if axis.length_squared>1e-12: axes.append(axis.normalized())
    vertices=[Vector(p) for p in points]
    bm.free()
    for axis in axes:
        padding=sum(abs(axis[a])*half[a] for a in range(3))
        offset=axis.dot(centre)
        projected=[axis.dot(p) for p in vertices]
        if min(projected)>offset+padding or max(projected)<offset-padding: return False
    return True

def topology(points):
    bm=bmesh.new()
    for p in points: bm.verts.new(p)
    bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
    edges=[(edge.verts[0].co.copy(),edge.verts[1].co.copy()) for edge in bm.edges]
    bm.free()
    return edges

def clip(points,edges,axis,limit,positive):
    def side(p): return (p[axis]-limit)*(1 if positive else -1)
    result=[Vector(p) for p in points if side(p)>=-1e-7]
    for a,b in edges:
        sa,sb=side(a),side(b)
        if sa*sb < -1e-12:
            result.append(a.lerp(b,sa/(sa-sb)))
    unique={tuple(round(v,7) for v in p):list(p) for p in result}
    if len(unique)<4: return []
    values=[unique[key] for key in sorted(unique)]
    cloud=np.asarray(values)
    singular=np.linalg.svd(cloud-cloud.mean(axis=0),compute_uv=False)
    if singular[-1]<max(1e-4,singular[0]*1e-7): return []
    bm=bmesh.new()
    for p in values: bm.verts.new(p)
    bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
    volume=abs(bm.calc_volume())
    bm.free()
    return values if volume>1e-8 else []

for report in audit['assets']:
    if not report['blocked_samples']: continue
    path=ROOT/'assets/graphics/geology_v11/collision'/f"{report['asset']}.json"
    row=json.loads(path.read_text())
    if '--current-only' in sys.argv:
        if row['category'] not in ('small','medium') and row.get('collision_bake_version',0)<3:
            continue
        if hashlib.sha256(json.dumps(row['hulls'],separators=(',',':')).encode()).hexdigest()!=report['proxy_sha256']:
            continue
    assert row['source_sha256']==report['source_sha256']
    assert hashlib.sha256(json.dumps(row['hulls'],separators=(',',':')).encode()).hexdigest()==report['proxy_sha256']
    backup=ROOT/'artifacts/geology_v11/uncarved_proxies'/path.name
    backup.parent.mkdir(parents=True,exist_ok=True)
    if not backup.exists(): backup.write_text(json.dumps(row,separators=(',',':')))
    original_count=len(row['hulls'])
    for sample in report['blocked_samples']:
        assert half.length+.01 < sample['source_clearance_m']
        centre=Vector(sample['position']); low=centre-half; high=centre+half
        output=[]
        for hull in row['hulls']:
            if any(max(p[a] for p in hull)<low[a] or min(p[a] for p in hull)>high[a] for a in range(3)):
                output.append(hull); continue
            if not overlaps_box(hull,centre):
                output.append(hull); continue
            remaining=hull
            for axis,limit,outside_positive in [(a,low[a],False) for a in range(3)]+[(a,high[a],True) for a in range(3)]:
                if not remaining: break
                edges=topology(remaining)
                outside=clip(remaining,edges,axis,limit,outside_positive)
                if outside: output.append(outside)
                remaining=clip(remaining,edges,axis,limit,not outside_positive)
            # The final intersection is entirely in proven source-free space.
        row['hulls']=output
    row['empty_volume_repairs']=report['blocked_samples']
    assert len(row['hulls'])<=max(5000,original_count*4),(row['id'],'excessive correction complexity')
    row['pieces_before_void_repairs']=original_count
    temporary=path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(row,separators=(',',':')))
    temporary.replace(path)
    print('REPAIRED_VOIDS',row['id'],len(report['blocked_samples']),original_count,'->',len(row['hulls']),'pieces',flush=True)
