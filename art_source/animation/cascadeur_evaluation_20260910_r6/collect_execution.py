"""Preserve bounded R6 receipts; do not promote an interrupted batch to a pass."""
import hashlib,json,re,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[3]
out=root/'artifacts/pose_review/comparisons/cascadeur-20260910-r6'
dest=out/'execution';dest.mkdir(exist_ok=True)
report={'scope':'Functional checks; concurrent wall times are not performance baselines. Original regression batch interrupted after two completed suites; remaining three completed in a separate guarded run. Production batch interrupted after encoding; its full audit completed separately.','guards':{},'regressions':[]}
for folder in sorted((root/'artifacts/guarded').glob('cascadeur-r6-*')):
    target=dest/folder.name
    if not target.exists():shutil.copytree(folder,target)
    g=folder/'guard.json'
    report['guards'][folder.name]=({k:v for k,v in json.loads(g.read_text()).items() if k in ['started','finished','exit_code','stop_reason','concurrent','workload_launched','background_driver_app_errors']} if g.exists() else {'completed_guard_receipt':False})
    if folder.name not in ['cascadeur-r6-regression','cascadeur-r6-remaining-regression']:continue
    for line in (folder/'stdout.log').read_text(errors='replace').splitlines():
        if '_RESULTS ' in line:
            tag,body=line.split(' ',1)
            try:data=json.loads(body)
            except ValueError:continue
            report['regressions'].append({'guard':folder.name,'tag':tag,'checks':data.get('checks'),'failures':data.get('failures'),'schema_keys':list(data)})
        elif re.search(r'COMPACT_POSTURE.*(checks|failures)',line):report['regressions'].append({'guard':folder.name,'line':line})
report['mcp']=[]
for p in sorted((Path(__file__).parent/'receipts').glob('*.json')):
    d=json.loads(p.read_text());result=(d.get('response') or {}).get('result',{})
    report['mcp'].append({k:d.get(k) for k in ['label','started_unix','seconds','transport_error']}|{'isError':result.get('isError',False),'content':result.get('content')})
(out/'execution_summary.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'regressions':report['regressions'],'guards':report['guards']},indent=2))
