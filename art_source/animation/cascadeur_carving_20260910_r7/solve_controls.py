"""Execute inside Cascadeur on the task-owned R6 scene. Save/export separately."""
import json
from pathlib import Path
import numpy as np
path=Path(app.current_scene().get_path_name())
assert path.name=='carving_r7.casc' and path.parent.name=='cascadeur_carving_20260910_r7'
scene=app.current_scene().domain_scene(); mv=scene.model_viewer(); bv=scene.behaviour_viewer()
assert scene.data_viewer().get_animation_size()==61
ids={mv.get_object_name(o):o for o in mv.get_objects() if mv.get_object_type_name(o)=='Point'}
samples=json.loads((path.parent/'control_targets.json').read_text())['samples']
def modify(model,update,su,session):
    for frame,sample in enumerate(samples):
        changed=set()
        for name,value in sample.items():
            data=bv.get_behaviour_data(bv.get_behaviour_by_name(ids[name],'Transform'),'global_position')
            model.data_editor().set_data_value(data,frame,np.array(value,dtype=np.float32)); changed.add(data)
        su.generate_update(); su.run_update(changed,frame)
    session.set_current_frame(15)
assert scene.modify_update_with_session('Author small left and right carving counterbalance offsets',modify)
print('R7 carve solve completed; 61 frames, all oriented controls. Save and export separately.')

