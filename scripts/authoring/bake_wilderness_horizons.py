"""Explicit offline bake from each actual authored background geometry tier.

Requires numpy. Export with export_wilderness_horizons.gd first, then pack with
pack_wilderness_horizons.gd. Never invoked by game startup or a setting change.
"""
import argparse
import json
import math
from pathlib import Path
import time
import numpy as np

EXTENT = 36000.0


def rasterize(vertices, indices, size, extent):
    cell = extent / size
    grid = np.full((size, size), np.nan, np.float32)
    for triangle in indices.reshape(-1, 3):
        v = vertices[triangle]
        p = (v[:, [0, 2]] + extent / 2) / cell - .5
        lo = np.maximum(np.ceil(p.min(axis=0)).astype(int), 0)
        hi = np.minimum(np.floor(p.max(axis=0)).astype(int), size - 1)
        if np.any(hi < lo):
            continue
        x, z = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        a, b, c = p
        denominator = (b[1]-c[1])*(a[0]-c[0]) + (c[0]-b[0])*(a[1]-c[1])
        if abs(denominator) < 1e-10:
            continue
        u = ((b[1]-c[1])*(x-c[0]) + (c[0]-b[0])*(z-c[1])) / denominator
        w = ((c[1]-a[1])*(x-c[0]) + (a[0]-c[0])*(z-c[1])) / denominator
        inside = (u >= -1e-5) & (w >= -1e-5) & (u+w <= 1.00001)
        target = grid[lo[1]:hi[1]+1, lo[0]:hi[0]+1]
        target[inside] = (u*v[0, 1] + w*v[1, 1] + (1-u-w)*v[2, 1])[inside]
    return grid


def horizons(heights, cell, count, bias_m=8.0):
    """Maximum upward obstruction angle; invalid/variable terrain never occludes."""
    size = heights.shape[0]
    result = np.zeros((count, size, size), np.float32)
    for direction in range(count):
        theta = direction * math.tau / count
        sx, sz = math.sin(theta), math.cos(theta)
        for step in np.arange(1.0, math.sqrt(2)*size, 1.0):
            dx, dz = sx*step, sz*step
            ix, iz = math.floor(dx), math.floor(dz)
            fx, fz = dx-ix, dz-iz
            x0, z0 = max(0, -ix), max(0, -iz)
            x1, z1 = min(size, size-1-ix), min(size, size-1-iz)
            if x1 <= x0 or z1 <= z0:
                continue
            source = heights[z0+iz:z1+iz+1, x0+ix:x1+ix+1]
            sampled = np.zeros((z1-z0, x1-x0), np.float32)
            for oz, ox, weight in [(0,0,(1-fx)*(1-fz)),(0,1,fx*(1-fz)),(1,0,(1-fx)*fz),(1,1,fx*fz)]:
                if weight > 1e-9:
                    sampled += source[oz:oz+z1-z0, ox:ox+x1-x0] * weight
            slope = (sampled-heights[z0:z1,x0:x1]-bias_m)/(step*cell)
            np.fmax(result[direction,z0:z1,x0:x1], slope, out=result[direction,z0:z1,x0:x1])
        np.arctan(result[direction], out=result[direction])
    return result


def fixture_checks():
    flat = np.zeros((24,24), np.float32)
    assert np.all(horizons(flat,10,8)==0)
    ridge = flat.copy(); ridge[16,:] = 50
    h = horizons(ridge,10,8,bias_m=0)
    assert abs(h[0,8,12]-math.atan(50/80))<1e-6 and h[4,8,12] == 0
    assert h[4,20,12] > .5 and h[0,20,12] == 0
    assert np.isfinite(h).all() and np.array_equal(h,horizons(ridge,10,8,bias_m=0))
    void = ridge.copy(); void[16,:] = np.nan
    assert np.all(horizons(void,10,8)==0)
    print('HORIZON_FIXTURES passed: flat, ridge directions, finite, deterministic, excluded occluders', flush=True)


def bake(source, output, tier, quality, metadata):
    started = time.perf_counter()
    size, directions = [(128, 16), (256, 32)][quality - 1]
    vertices = np.fromfile(source/f'vertices_{tier}.f32',dtype='<f4').reshape(-1,3)
    indices = np.fromfile(source/f'indices_{tier}.i32',dtype='<i4')
    assert np.isfinite(vertices).all() and np.max(np.abs(vertices)) < 20000
    assert indices.min() >= 0 and indices.max() < len(vertices)
    grid = rasterize(vertices,indices,size,EXTENT)
    points = (np.arange(size)+.5)*EXTENT/size-EXTENT/2
    x,z = np.meshgrid(points,points)
    apron = np.fromfile(source/'apron.f32',dtype='<f4').reshape(259,259)
    u = (x+4128)/32; v = (z+4128)/32
    ix = np.floor(u).astype(int).clip(0,257); iz = np.floor(v).astype(int).clip(0,257)
    valid = (u>=0)&(v>=0)&(u<258)&(v<258)
    fx=u-ix;fz=v-iz
    surface=(apron[iz,ix]*(1-fx)+apron[iz,ix+1]*fx)*(1-fz)+(apron[iz+1,ix]*(1-fx)+apron[iz+1,ix+1]*fx)*fz
    grid[valid]=surface[valid]
    # Max physical radius 3116 + join24 + variable delta640 = 3780 m.
    # Discard variable/unknown occluders, including a filter margin. This omits
    # their cast shadows rather than stamping the bake seed onto other seeds.
    grid[np.hypot(x,z)<3900]=np.nan
    angles=horizons(grid,EXTENT/size,directions)
    assert np.isfinite(angles).all() and angles.min()>=0 and angles.max()<math.pi/2
    target=output/f't{tier}_q{quality}'
    target.mkdir(parents=True,exist_ok=True)
    for layer in range(directions//4):
        angles[layer*4:layer*4+4].transpose(1,2,0).astype('<f2').tofile(target/f'angles_{layer}.rgba16f')
    report={'schema':1,'source':metadata,'geometry_tier':tier,'quality':quality,
            'size':size,'extent_m':EXTENT,'directions':directions,
            'excluded_radius_m':3900,'receiver_full_radius_m':4300,
            'format':'rgba16f','payload_bytes':angles.size*2,
            'seconds':time.perf_counter()-started,'valid_texels':int(np.isfinite(grid).sum()),
            'max_angle_degrees':float(np.rad2deg(angles.max()))}
    (target/'bake.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('HORIZON_BAKE',json.dumps({k:v for k,v in report.items() if k!='source'}),flush=True)
    return report


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input',type=Path)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--fixtures-only',action='store_true')
    args=parser.parse_args()
    fixture_checks()
    if args.fixtures_only: return
    if not args.input or not args.output: parser.error('--input and --output are required for an explicit bake')
    metadata=json.loads((args.input/'metadata.json').read_text(encoding='utf-8'))
    assert metadata['presentation_version']==3 and metadata['footprint_revision']==1 and len(metadata['tiers'])==3
    reports=[bake(args.input,args.output,tier,quality,metadata) for tier in range(3) for quality in (1,2)]
    (args.output/'bake.json').write_text(json.dumps({'schema':1,'variants':reports},indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':
    main()
