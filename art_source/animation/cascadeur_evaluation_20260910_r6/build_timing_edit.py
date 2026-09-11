"""One sparse timing edit, not native AI interpolation. Re-solve all 31 controls."""
import json, math
from pathlib import Path
root=Path(__file__).resolve().parent
source=root.with_name('cascadeur_evaluation_20260910_r5')/'control_targets.json'
samples=json.loads(source.read_text())['samples']
# Monotone Hermite timing knots. Retain the three approach beats, compression
# peak, and final endpoint; move only the recovery beat from 44 to 48.
x=[0,12,24,30,48,60]; y=[0,12,24,30,44,60]
d=[(y[i+1]-y[i])/(x[i+1]-x[i]) for i in range(len(x)-1)]
m=[d[0]]+[2*d[i-1]*d[i]/(d[i-1]+d[i]) for i in range(1,len(d))]+[d[-1]]
def at(t):
    i=next((i for i in range(len(x)-1) if t<=x[i+1]),len(x)-2)
    h=x[i+1]-x[i]; u=(t-x[i])/h
    return (2*u**3-3*u**2+1)*y[i]+(u**3-2*u**2+u)*h*m[i]+(-2*u**3+3*u**2)*y[i+1]+(u**3-u**2)*h*m[i+1]
rows=[]; mapping=[]
for frame in range(61):
    t=max(0,min(60,at(frame))); a=int(t); b=min(60,a+1); f=t-a
    rows.append({name:[v+(samples[b][name][k]-v)*f for k,v in enumerate(pos)] for name,pos in samples[a].items()})
    mapping.append(t)
out=root/'control_targets.json'; assert not out.exists()
out.write_text(json.dumps({'scope':__doc__,'timing_knots':list(zip(x,y)),'source_frames':mapping,'samples':rows},indent=2))
print('Prepared 61 frames; 31 controls; one edited timing knot. No per-frame hand repair.')
