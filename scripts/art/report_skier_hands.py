"""Build a local review gallery from unchanged native captures and QA records."""
import html
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/hands_v1'
before=json.loads((OUT/'native_before/report.json').read_text())
after=json.loads((OUT/'native_final/report.json').read_text())
assert not before['failures'] and not after['failures']
assert before['captures']==after['captures']
options=[]
for name in after['captures']:
    for folder in ['native_before','native_final']:
        assert (OUT/folder/(name+'.png')).is_file()
    label=name.replace('_',' ').title()
    options.append(f'<option value="{html.escape(name)}">{html.escape(label)}</option>')
page='''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Alpine Apex — glove comparison</title>
<style>
:root{color-scheme:dark;font:16px/1.5 system-ui;background:#141b23;color:#eaf0f5}
body{max-width:1600px;margin:0 auto;padding:32px}h1{font-size:32px;margin:0 0 10px}
p{max-width:900px;color:#bfcbd8}strong{color:#fff}select{font:inherit;padding:10px;border:1px solid #52667d;border-radius:6px;background:#263545;color:white;min-width:260px}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px;margin-top:22px}figure{margin:0;background:#25313e;border-radius:8px;overflow:hidden}figcaption{padding:12px 18px;font-weight:650}img{display:block;width:100%;height:auto}
.badge{display:inline-block;margin:8px 10px 8px 0;padding:6px 12px;border:1px solid #536675;border-radius:30px}a{color:#ffb975}
@media(max-width:700px){body{padding:18px}.pair{grid-template-columns:1fr}}
</style><h1>Skier gloves</h1>
<p>One connected glove per hand: four rounded fingers, one thumb and a fitted cuff. Original body, equipment, 24-bone rig and animations retained.</p>
<div><span class="badge">35 / 500 Meshy credits used</span><span class="badge">5,644 triangles for both gloves</span><span class="badge">2K PBR textures</span></div>
<p>The original pole straps and their visible surface artifacts remain in both views. Static finger grips also remain closed during grabs. These are native renders; your appearance review is still open.</p>
<label for="pose">View&nbsp; </label><select id="pose">OPTIONS</select>
<div class="pair"><figure><figcaption>Before · original tube fingers</figcaption><img id="before" alt="Original gloves"></figure><figure><figcaption>After · Meshy 7 glove, locally fitted</figcaption><img id="after" alt="Replacement gloves"></figure></div>
<p>All 43 native views use matched camera setups. Crash poses are frozen Jolt samples and can differ slightly in their final body position.</p>
<script>const choice=document.getElementById('pose');function show(){document.getElementById('before').src='native_before/'+choice.value+'.png';document.getElementById('after').src='native_final/'+choice.value+'.png';}choice.value='glide_Left_back';choice.addEventListener('change',show);show();</script></html>'''.replace('OPTIONS',''.join(options))
(OUT/'comparison.html').write_text(page,encoding='utf-8')
lines=['# Skier hands: matched native views','',
       '35 Meshy credits used. Four fingers and one thumb per glove. User appearance acceptance remains open.','']
for name in ['glide_Left_back','glide_Right_back','glide_Left_palm','glide_Right_palm','tuck_Right_back','turn_left_Left_palm','jump_Left_back','safety_Right_back','mute_Right_palm','crash_Left','crash_Right']:
    lines += ['## '+name.replace('_',' ').title(),'','| Before | After |','| --- | --- |',
              '| ![Before]('+str(OUT/'native_before'/(name+'.png')).replace('\\','/')+') | ![After]('+str(OUT/'native_final'/(name+'.png')).replace('\\','/')+') |','']
(OUT/'comparison.md').write_text('\n'.join(lines),encoding='utf-8')
print('HAND_GALLERY',OUT/'comparison.html')

source=ROOT/'art_source/meshy/hands_v1'
qa=json.loads((source/'runtime_qa.json').read_text())
installed=json.loads((source/'installation.json').read_text())
active_hash=hashlib.sha256((ROOT/'assets/graphics/models/skier_v7.glb').read_bytes()).hexdigest()
assert active_hash==qa['output_glb_sha256']==after['model_sha256']
suites=json.loads((OUT/'regression/results.json').read_text())
assert all(s['exit_code']==0 and not s['errors'] for s in suites)
matched=json.loads((OUT/'matched_timing.json').read_text())
assert matched['matched'] and not matched['source_changes']
manifest=json.loads((OUT/'matched_sources_after.json').read_text())
timed_model=next(value for key,value in manifest.items() if key.replace('\\','/')=='assets/graphics/models/skier_v7.glb')
assert timed_model.lower()==active_hash, 'Timing evidence belongs to a different installed model'
timings={}
for variant,folder in [('before',matched['baseline']),('after',matched['replacement'])]:
    result=json.loads((ROOT/'artifacts'/folder/'after_timing/results.json').read_text())
    assert not result['failures'] and result['actual_pixels']==[3840,2160] and result['quality']=='high'
    timings[variant]={key:result[key] for key in ['actual_pixels','device','display','quality','physics','version','seed','frame_ms','render_cpu_ms','render_gpu_ms','peak_video_bytes','peak_engine_static_bytes']}
    timings[variant]['average_fps']=1000/result['frame_ms']['mean']
    timings[variant]['measured_seconds']=result['frame_ms']['mean']*result['frame_ms']['count']/1000
assert timings['before']['physics']==timings['after']['physics']==before['physics']==after['physics']
report={'installed':installed,'automated':{'asset':qa,'suites':suites,'checks_passed':sum(s['checks'] for s in suites)},
        'rendered':{'native_captures_per_variant':len(after['captures']),'asset_views':['Left_back','Left_palm','Left_side','Right_back','Right_palm','Right_side'],
                    'findings':'Four rounded fingers and one thumb per connected glove; covered wrist junction, existing pole grip retained. Tight contact lining uses a softened normal bake.',
                    'unchanged_limits':['Existing pole strap and equipment surface artifacts','Static fingers remain closed during grabs'],
                    'gallery':'artifacts/hands_v1/comparison.html'},
        'performance':{'matched_sources':True,'timings':timings,'limits':['One short pair, including scenario cuts; no hard FPS floor established','Both variants use identical full-detail non-glove surfaces','Baseline process retains the loaded replacement resource, so memory is not a clean old-asset residency comparison']},
        'user_appearance_acceptance':'Awaiting user review'}
(OUT/'delivery.json').write_text(json.dumps(report,indent=2)+'\n')
b,a=timings['before'],timings['after']
table=['| Metric | Before | After |','| --- | ---: | ---: |',f"| Average FPS | {b['average_fps']:.2f} | {a['average_fps']:.2f} |"]
for label,key in [('Frame','frame_ms'),('Render CPU','render_cpu_ms'),('GPU','render_gpu_ms')]:
    for stat in ['mean','p95','p99','max']:
        table.append(f'| {label} {stat} (ms) | {b[key][stat]:.3f} | {a[key][stat]:.3f} |')
for label,key in [('Peak engine video memory','peak_video_bytes'),('Peak engine static memory','peak_engine_static_bytes')]:
    table.append(f'| {label} (GiB) | {b[key]/2**30:.3f} | {a[key]/2**30:.3f} |')
text=f'''# Skier hand replacement — delivery

Only the glove surface and cuffs were replaced. The runtime path remains
`assets/graphics/models/skier_v7.glb`, with material `SkierV7Gloves`. The body data,
non-glove materials, nodes, skin and inverse bind transforms retain their original
bytes. The 24-bone skeleton and animation files were retained. No finger rigging
or paid animation calls were added.

## Creation and cost

One explicit Meshy 7 Ultra job, 2K PBR, GLB: **35 credits spent; 465 of the
500-credit allowance unused**. Job: `01a08610-5532-7391-87a6-47f9a9b0ce52`.
The retained source had 3,082,092 triangles. Local Blender preparation produced
5,644 triangles across both gloves and baked stitched detail into three 2K maps.

Reference: [reference.png](../../art_source/meshy/hands_v1/reference.png).
Exact image-generation prompt: [reference_prompt.txt](../../art_source/meshy/hands_v1/reference_prompt.txt).
[Credit ledger](../../art_source/meshy/hands_v1/credit_ledger.json),
[rebuild instructions](../../docs/SKIER_HANDS.md), and
[installed hashes](../../art_source/meshy/hands_v1/installation.json).

## Automated acceptance

**Passed.** 19 motion checks and 71 anatomy checks, with no engine errors.
Independent GLB reimport, normalized hand/cuff weights, embedded 2K textures,
connected topology, zero boundary/non-manifold edges, 24 bones and the
6,000-triangle glove limit passed. Exact non-glove preservation passed.

## Rendered acceptance

Reviewed both hands from palm, back and side. Captured 43 native views per variant
covering glide, tuck, both turns, jump, Safety/Mute grabs, landing and crash,
with representative pose close-ups inspected.
The glove silhouettes have four rounded fingers and one thumb, connected
knuckles and a covered sleeve junction. Tight contact surfaces use a softened
normal bake to avoid projection artifacts. The existing pole straps retain
their visible surface artifacts; fixed finger grips remain closed during grabs.

[Interactive matched gallery](comparison.html) · [Selected close-ups](comparison.md).
Crash images use frozen Jolt samples and can differ slightly in final position.

## Performance evidence

One matched pair on the v{a['version']} production course, seed {a['seed']}, physics
model {a['physics']}: actual 3840 x 2160 High, 75% FSR2, 120 FPS cap, approximately
{a['measured_seconds']:.1f} measured seconds per run. Tracked source/model hashes remained
stable across the pair. Capture overhead was excluded from these timing runs.

'''+ '\n'.join(table)+'''

This is a short comparison including scenario cuts, not a hard FPS-floor claim.
Both variants use the same full-detail non-glove surface path. The baseline
process retains the loaded replacement resource; memory values therefore do not
isolate the old and new glove residency. Raw results and source manifests are
linked in `delivery.json` and stored beside the matched timing folders.

## User appearance acceptance

**Awaiting your review.** Automated and rendered checks do not establish personal
appearance preference or live controller feel. The installed asset is ready for
the next game launch.
'''
(OUT/'delivery.md').write_text(text,encoding='utf-8')
print('HAND_DELIVERY',OUT/'delivery.md')
