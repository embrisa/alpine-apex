"""Bake compact PBR data maps from the retained imagegen leaf artwork in Blender.

Relief is a restrained luminance-derived approximation, not a measured scan.
The original generated artwork is preserved unchanged alongside its prompt.
"""
import hashlib
import json
from pathlib import Path

import bpy
import numpy as np


def bake(directory):
    directory = Path(directory)
    source = bpy.data.images.load(str(directory / 'leaf_texture_master.png'), check_existing=True)
    source.scale(1024, 512)
    pixels = np.array(source.pixels[:], dtype=np.float32).reshape(512, 1024, 4)
    luminance = pixels[:, :, :3] @ np.array([.2126, .7152, .0722])
    albedo = np.ones_like(pixels)
    normal = np.ones_like(pixels)
    roughness = np.ones_like(pixels)
    # Process tiles separately so filtering never invents a seam-crossing vein.
    for start in (0, 512):
        value = luminance[:, start:start + 512]
        mean = np.mean(value)
        tint = np.clip(.74 + (value - mean) * 1.8, .28, 1.0)
        albedo[:, start:start + 512, :3] = tint[:, :, None]
        dy, dx = np.gradient(value)
        vectors = np.stack((-dx * 5.0, -dy * 5.0, np.ones_like(value)), axis=-1)
        vectors /= np.linalg.norm(vectors, axis=-1, keepdims=True)
        normal[:, start:start + 512, :3] = vectors * .5 + .5
        roughness[:, start:start + 512, :3] = np.clip(.73 - (value - mean) * .5, .55, .86)[:, :, None]
    records = []
    for name, data, color_space in [('leaf_albedo.png', albedo, 'sRGB'),
                                    ('leaf_normal.png', normal, 'Non-Color'),
                                    ('leaf_roughness.png', roughness, 'Non-Color')]:
        img = bpy.data.images.new(name, width=1024, height=512, alpha=False)
        img.colorspace_settings.name = color_space
        img.pixels.foreach_set(data.reshape(-1))
        img.filepath_raw = str(directory / name)
        img.file_format = 'PNG'
        img.save()
        records.append({'file': name, 'sha256': hashlib.sha256((directory / name).read_bytes()).hexdigest(),
                        'size': [1024, 512], 'color_space': color_space})
        bpy.data.images.remove(img)
    bpy.data.images.remove(source)
    (directory / 'bake.json').write_text(json.dumps({
        'source': 'leaf_texture_master.png',
        'source_sha256': hashlib.sha256((directory / 'leaf_texture_master.png').read_bytes()).hexdigest(),
        'tiles': ['left: pinnate birch venation', 'right: palmate maple venation'],
        'relief': 'Approximate luminance-gradient tangent normal; shader strength 0.35; not a measured scan',
        'baker_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'maps': records}, indent=2) + '\n')
