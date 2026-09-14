"""Merge packed broadleaves while preserving every other authored catalog value."""
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    if os.environ.get('ALPINE_VALIDATION_MODE') != 'Exclusive':
        raise SystemExit('Run integrate_colorful_trees.ps1 under its owning guard.')
    update = json.loads((ROOT / 'artifacts/colorful_forest_variety/catalog_update.json').read_text())
    catalog_path = ROOT / 'assets/graphics/trees/manifest.json'
    branches_path = ROOT / 'assets/graphics/trees/branches.json'
    catalog = json.loads(catalog_path.read_text())
    branches = json.loads(branches_path.read_text())
    for entry in update['assets']:
        assert entry['family'] in ('golden', 'maple')
        catalog['assets'] = [old for old in catalog['assets'] if old['id'] != entry['id']]
        catalog['assets'].append(entry)
        branches[entry['id']] = update['branches'][entry['id']]
    catalog['families'].update(update['families'])
    for path, data in ((catalog_path, catalog), (branches_path, branches)):
        raw = path.read_bytes()
        newline = '\r\n' if b'\r\n' in raw else '\n'
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline=newline)
    print(f"COLORFUL_CATALOG_MERGED {len(update['assets'])} preserved_existing_metadata=true")


if __name__ == '__main__':
    main()
