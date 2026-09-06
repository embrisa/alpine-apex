"""Embed source textures so the editable Blender library can be relocated."""
import bpy, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / 'art_source/blender'
report = []
for name in ['alpine_library', 'skier', 'spruce_library', 'spruce_impostor_bake']:
    path = FOLDER / (name + '.blend')
    bpy.ops.wm.open_mainfile(filepath=str(path))
    bpy.ops.file.pack_all()
    images = [image for image in bpy.data.images if image.source == 'FILE']
    assert all(image.packed_file for image in images), f'Unpacked texture in {name}'
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    report.append({'source': str(path.relative_to(ROOT)), 'packed_images': len(images)})
(FOLDER / 'packed_sources.json').write_text(json.dumps(report, indent=2) + '\n')
print('PACKED_SOURCES', json.dumps(report))
