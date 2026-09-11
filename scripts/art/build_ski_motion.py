"""Deterministically build original Apex scalar profiles; never consumes native clips."""
from pathlib import Path
import hashlib, json

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art_source/animation/apex_ski_v17/motion_profiles.json'
TARGET=ROOT/'assets/animation/apex_ski_motion.gd'

def build():
    data=json.loads(SOURCE.read_text(encoding='utf-8'))
    assert data['version']==1
    for profile in data['profiles'].values():
        assert all(isinstance(v,(int,float)) and abs(v)<2 for v in profile.values())
    result='extends RefCounted\n## Original Apex profiles. Edit art_source/animation/apex_ski_v17/motion_profiles.json.\n'
    result+='## Rebuild: python scripts/art/build_ski_motion.py\n'
    result+='const SOURCE_SHA256 = "'+hashlib.sha256(SOURCE.read_bytes()).hexdigest()+'"\n'
    result+='const PROFILES = '+json.dumps(data['profiles'],indent='\t')+'\n'
    TARGET.parent.mkdir(parents=True,exist_ok=True)
    TARGET.write_text(result,encoding='utf-8',newline='\n')
    print(TARGET)

if __name__=='__main__': build()
