"""Confirm this graphics work did not edit baseline simulation/contact source."""
from pathlib import Path
import tarfile,hashlib,json
ROOT=Path(__file__).resolve().parents[2]
archive=ROOT/'art_source/baseline/source_before_graphics.tar.gz'
checked=[];changed=[]
with tarfile.open(archive) as tar:
 for member in tar.getmembers():
  name=member.name.removeprefix('./')
  if not member.isfile() or Path(name).name.startswith('._'):continue
  if (name.startswith('scripts/core/') and name.endswith('.gd')) or name=='scripts/world/test_slope.gd':
   original=tar.extractfile(member).read();current=(ROOT/name).read_bytes()
   checked.append({'path':name,'sha256':hashlib.sha256(current).hexdigest()})
   if original!=current:changed.append(name)
assert checked,'No baseline sources found'
report={'checked':checked,'changed':changed,'baseline_archive':str(archive.relative_to(ROOT))}
(ROOT/'artifacts/simulation_source_identity.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
assert not changed,changed
