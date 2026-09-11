"""Shared source-to-wrist mapping for the low mesh and its texture bake."""
import math
from mathutils import Vector


def fit_point(point,fit):
    p=Vector(point);relative=p-Vector(fit['grip_source'])
    x=.070+relative.dot(Vector(fit['outward']))*fit['scale'][0]
    y=-relative.dot(Vector(fit['thumb_direction']))*fit['scale'][1]+fit['grip_across_offset']
    z=relative.y*fit['scale'][2]
    # Open the existing connected grip by a smooth radial deformation, keeping
    # fingertips rounded. No boolean cuts or new finger ends are introduced.
    radius=math.hypot(x-.070,z)
    ratio=math.sqrt(radius*radius+.017*.017)/max(radius,.000001)
    hand=Vector((.070+(x-.070)*ratio,y,z*ratio))
    longitudinal=p.dot(Vector((-.7071067811865476,0,.7071067811865476)))
    across=p.dot(Vector((.7071067811865476,0,.7071067811865476)))
    cuff=Vector(((longitudinal+.60)*.070,-(across-.11)*.090,(p.y-.25)*.090+.005))
    weight=max(0,min(1,(-.15-longitudinal)/.30));weight=weight*weight*(3-2*weight)
    return hand.lerp(cuff,weight)
