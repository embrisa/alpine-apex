"""Execute inside Cascadeur. Caller sets output_name to a fresh GLB basename."""
from pathlib import Path
source=Path(app.current_scene().get_path_name())
assert source.name=='carving_r7.casc' and source.parent.name=='cascadeur_carving_20260910_r7', source
assert Path(output_name).name==output_name and output_name.endswith('.glb')
output=source.with_name(output_name); assert not output.exists(), output
scene=app.current_scene().domain_scene(); mv=scene.model_viewer()
joints={o for o in mv.get_objects() if mv.get_object_type_name(o)=='Joint'}
expected={'Hips','Spine02','Spine01','Spine','neck','Head','headfront','head_end',*{s+n for s in ['Left','Right'] for n in ['Shoulder','Arm','ForeArm','Hand','UpLeg','Leg','Foot','ToeBase']}}
assert len(joints)==24 and {mv.get_object_name(o) for o in joints}==expected
armatures={o for o in mv.get_objects() if mv.get_object_name(o)=='Armature'}; assert len(armatures)==1
scene.selector().select(joints|armatures)
options=csc.glb.ExportOptions(); options.include_animation=True; options.for_selected_objects=True; options.for_selected_interval=False
options.scale_factor=.01; options.fps=30; options.throw_exception=True
csc.glb.process_export(scene,str(output),options)
assert output.is_file() and output.stat().st_size>0
print('Exported',output,output.stat().st_size)

