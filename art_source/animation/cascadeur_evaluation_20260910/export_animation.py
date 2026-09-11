"""Run inside Cascadeur's run_script context on the saved evaluation bake.

Exports animation only to a NEW file beside the .casc. Does not save or replace
the scene, production mesh, or an existing export. Tested with 2026.2.2.0.16638.
"""
from pathlib import Path

scene_path = Path(app.current_scene().get_path_name())
assert scene_path.name == 'ready_compression_baked.casc', scene_path
assert scene_path.parent.name in {
    'cascadeur_evaluation_20260910', 'cascadeur_rig_20260910_r4'
}, scene_path
scene = app.current_scene().domain_scene()
mv = scene.model_viewer()
joints = {o for o in mv.get_objects() if mv.get_object_type_name(o) == 'Joint'}
expected = {
    'Hips', 'Spine02', 'Spine01', 'Spine', 'neck', 'Head', 'headfront', 'head_end',
    *{side + name for side in ['Left', 'Right'] for name in
      ['Shoulder', 'Arm', 'ForeArm', 'Hand', 'UpLeg', 'Leg', 'Foot', 'ToeBase']},
}
assert {mv.get_object_name(o) for o in joints} == expected
assert len(joints) == 24
output = scene_path.with_name('ready_compression_baked_reexport.glb')
assert not output.exists(), f'Choose a fresh output filename: {output}'
armatures = {o for o in mv.get_objects() if mv.get_object_name(o) == 'Armature'}
assert len(armatures) == 1
scene.selector().select(joints | armatures)
options = csc.glb.ExportOptions()
options.include_animation = True
options.for_selected_objects = True
options.for_selected_interval = False
options.scale_factor = .01
options.fps = 30
options.throw_exception = True
csc.glb.process_export(scene, str(output), options)
assert output.is_file() and output.stat().st_size > 0
print('Exported evaluation animation only:', output)
