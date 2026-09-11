"""Run independent source/proxy audits in bounded background Blender workers."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import os
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/geology_v11'
OUT.mkdir(parents=True,exist_ok=True)
BLENDER=os.environ.get('BLENDER_BIN',r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe')
assets=[r['asset'] for r in json.loads((ROOT/'assets/graphics/minerals_v3/manifest.json').read_text())['assets']]
workers=1
def audit(index):
    report=OUT/f'proxy_audit_part_{index}.json'
    report.unlink(missing_ok=True)
    with (OUT/f'proxy_audit_part_{index}.log').open('w') as log:
        result=subprocess.run([BLENDER,'--background','--factory-startup','--disable-autoexec',
            '--python-exit-code','1','--python',str(ROOT/'tests/geology_proxy_audit.py'),'--',
            '--output='+str(report)]+assets[index::workers],stdout=log,stderr=subprocess.STDOUT,
            env=dict(os.environ,OMP_NUM_THREADS='1'),
            creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
    assert report.exists(),f'Worker {index} failed before writing its audit: exit {result.returncode}'
    return json.loads(report.read_text())
with ThreadPoolExecutor(max_workers=workers) as pool:
    parts=list(pool.map(audit,range(workers)))
rows={row['asset']:row for part in parts for row in part['assets']}
assert set(rows)==set(assets) and len(rows)==120
report={key:parts[0][key] for key in ('clearance_m','rider_size_m','grid_per_axis')}
report['assets']=[rows[asset] for asset in assets]
report['failures']=[asset for asset in assets if rows[asset]['blocked_samples']]
(OUT/'proxy_audit.json').write_text(json.dumps(report,indent=2))
print('SOURCE_PROXY_AUDIT',len(rows),'assets;',sum(r['rider_sized_free_samples'] for r in rows.values()),
      'clearance samples;',len(report['failures']),'assets need correction',flush=True)
sys.exit(1 if report['failures'] else 0)
