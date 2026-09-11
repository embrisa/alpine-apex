"""Solve explicit point/orientation controls; preserve R4 and exported anatomy."""
import json
from pathlib import Path
import numpy as np
root=Path('C:/Users/hp/Downloads/alpine-apex/artifacts/cascadeur_rig_20260910_r5')
assert Path(app.current_scene().get_path_name())==root/'ready_compression_r5.casc'
scene=app.current_scene().domain_scene()
mv,bv=scene.model_viewer(),scene.behaviour_viewer()
ids={mv.get_object_name(o):o for o in mv.get_objects() if mv.get_object_type_name(o)=='Point'}
inputs=json.loads((root/'control_targets.json').read_text())['samples']
def modify(model,update,su,session):
    for frame,sample in enumerate(inputs):
        changed=set()
        for n,v in sample.items():
            d=bv.get_behaviour_data(bv.get_behaviour_by_name(ids[n],'Transform'),'global_position')
            model.data_editor().set_data_value(d,frame,np.array(v,dtype=np.float32));changed.add(d)
        su.generate_update();su.run_update(changed,frame)
    session.set_current_frame(30)
assert scene.modify_update_with_session('Constrain torso orientation and anatomical arm planes',modify)
selected={o for o in mv.get_objects() if mv.get_object_type_name(o)=='Joint' or mv.get_object_name(o)=='Armature'}
scene.selector().select(selected)
opts=csc.glb.ExportOptions();opts.include_animation=True;opts.for_selected_objects=True;opts.for_selected_interval=False
opts.scale_factor=.01;opts.fps=30;opts.throw_exception=True
csc.glb.process_export(scene,str(root/'ready_compression_r5_animation.glb'),opts)
print('Solved and exported R5. Save separately after inspecting this result.')
