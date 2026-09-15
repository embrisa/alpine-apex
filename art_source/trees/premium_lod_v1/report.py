"""Build the local visual review index from actual native captures and receipts."""
import html
import json
from pathlib import Path

PACK = Path(__file__).resolve().parent
ROOT = PACK.parents[2]
OUT = ROOT/'artifacts/premium_tree_review'
native = OUT/'native'
manifest = json.loads((PACK/'manifest.json').read_text(encoding='utf-8'))
rows=[]
old_mid=sum(r['baseline_triangles'][1] for r in manifest['assets'])
new_mid=sum(r['models'][1]['triangles'] for r in manifest['assets'])
mid_summary=f'{old_mid:,} to {new_mid:,} mid triangles across the catalog ({(1-new_mid/old_mid)*100:.1f}% fewer).'
for r in manifest['assets']:
    m=r['models']
    old=r['baseline_triangles']
    rows.append(f"<tr><td>{html.escape(r['id'])}</td><td>{old[0]:,} → {m[0]['triangles']:,}</td>"
                f"<td>{old[1]:,} → {m[1]['triangles']:,}</td><td>{(1-m[1]['triangles']/old[1])*100:.1f}%</td>"
                f"<td>{m[2]['triangles']}</td><td>{r['shadow']['triangles']:,}</td></tr>")
captures=[]
capture_manifest=json.loads((native/'capture_manifest.json').read_text(encoding='utf-8'))
for entry in capture_manifest['captures']:
    p=native/entry['file']
    rel=p.relative_to(OUT).as_posix()
    name=p.stem.replace('_',' ')
    captures.append(f'<figure data-name="{html.escape(name.lower())}"><a href="{rel}" target="_blank"><img loading="lazy" src="{rel}" alt="{html.escape(name)}"></a><figcaption>{html.escape(name)}</figcaption></figure>')
motions=[]
motion_data=[]
for index, sequence in enumerate(capture_manifest.get('motion_sequences',[])):
    frames=[f for f in sequence['frames'] if f['captured']]
    motion_data.append(frames)
    motions.append(f'<section class="motion"><h3>{html.escape(sequence["label"])}</h3><img id="motion{index}" src="native/{frames[0]["file"]}"><button onclick="play({index})">Play / pause</button><input id="slider{index}" type="range" min="0" max="{len(frames)-1}" value="0" oninput="seek({index},Number(this.value))"><span id="time{index}"></span></section>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Alpine Apex · Forest source review</title><style>
:root{color-scheme:dark;font:16px/1.55 system-ui;background:#0b161c;color:#e9f2f3}body{max-width:1500px;margin:auto;padding:36px}h1{font-size:clamp(32px,5vw,64px);line-height:1.05;margin:16px 0}h2{margin-top:48px}p{max-width:950px;color:#b8cdd2}.eyebrow{letter-spacing:.18em;color:#84d5c3;text-transform:uppercase}.summary{border-left:3px solid #84d5c3;padding:12px 24px;background:#13252d}.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(480px,1fr));gap:20px}figure{margin:0;background:#13252d;border-radius:12px;overflow:hidden}img{width:100%;display:block}figcaption{padding:12px 18px}table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}th,td{text-align:left;padding:9px 14px;border-bottom:1px solid #26414a}th{color:#84d5c3}button,input{font:inherit;color:inherit;background:#1c343d;border:1px solid #365862;border-radius:7px;padding:10px 15px;margin:4px;cursor:pointer}input{min-width:280px}a{color:#84d5c3}.hidden{display:none}.controls{position:sticky;top:0;background:#0b161cf2;padding:12px 0;z-index:2}@media(max-width:600px){body{padding:16px}.gallery{grid-template-columns:1fr}table{font-size:12px}td,th{padding:7px}}
</style><header><div class="eyebrow">Alpine Apex · Prepared asset family</div><h1>A forest from branch<br>to mountain slope.</h1><div class="summary">30 trees · 8 families · coherent near, mid and far sources · separate shadow derivatives</div>
<p>This is a source preparation review in an isolated native Godot scene. The live forest is unchanged. Close and middle tiers use dimensional geometry; distant trees use eight directional views baked from the same close source, with a separate normal atlas for lighting.</p>
<p>Inspect crown fullness, species identity, exposed branch structure, snow placement, repeated silhouettes and both LOD transitions. The elevated and backlit views deliberately stress the representations. Click any image for full resolution.</p></header>
<figure><a href="native/forest_depth.png" target="_blank"><img src="native/forest_depth.png" alt="Layered snowy forest at skier height"></a><figcaption>Skier-height glade · mixed species · all three tiers</figcaption></figure>
<p>MID_SUMMARY Close geometry retains fine sprays and snow volume. Mid geometry concentrates on crown coverage, and distant trees retain the same branch and snow silhouette in directional images.</p>
<h2>Continuous transitions</h2><p>Scrub the two approaches through the existing dense-forest bands. These are chronological camera samples, played at their authored cadence; capture writing time is not performance evidence.</p>MOTIONS
<h2>Native visual evidence</h2><div class="controls"><input id="filter" placeholder="Filter: close, spruce, transition…"><button onclick="setFilter('')">All</button><button onclick="setFilter('close')">Close</button><button onclick="setFilter('lod1')">Mid</button><button onclick="setFilter('far')">Far</button><button onclick="setFilter('transition')">Transitions</button><button onclick="document.querySelector('.gallery').style.gridTemplateColumns='1fr'">Large images</button></div><div class="gallery">CAPTURES</div>
<h2>Geometry inventory</h2><p>Counts compare the hashed production catalog with the prepared derivatives. Triangle savings describe assets, not measured GPU time or gameplay FPS. Three portable role surfaces are intended to be packed into the production one-surface role-mask contract during a later installation.</p><table><thead><tr><th>Tree</th><th>Near triangles</th><th>Mid triangles</th><th>Mid reduction</th><th>Far</th><th>Shadow</th></tr></thead><tbody>ROWS</tbody></table>
<h2>Acceptance boundary</h2><p>Native captures and independent asset audits cover this prepared pack. Runtime conversion, production wind and visibility-assistance behavior, residency, matched 4K forest performance and human skiing acceptance require a later integration milestone. Eight azimuth views remain a limited approximation at steep overhead angles; the elevated capture makes that limit reviewable.</p>
<p><a href="native/native_validation.json">Native receipt</a> · <a href="audit.json">Asset audit</a> · <a href="blender_audit.json">Blender roundtrip</a></p>
<script>const motionData=MOTION_DATA;const timers={};function seek(i,k){const f=motionData[i][k];document.getElementById('motion'+i).src='native/'+f.file;document.getElementById('slider'+i).value=k;document.getElementById('time'+i).textContent=f.crown_distance_m.toFixed(2)+' m · state '+f.frame_index;}function play(i){if(timers[i]){clearInterval(timers[i]);delete timers[i];return}timers[i]=setInterval(()=>{let k=(Number(document.getElementById('slider'+i).value)+1)%motionData[i].length;seek(i,k)},50)}function setFilter(q){document.getElementById('filter').value=q;document.querySelectorAll('.gallery figure').forEach(f=>f.classList.toggle('hidden',!f.dataset.name.includes(q.toLowerCase())))}document.getElementById('filter').oninput=e=>setFilter(e.target.value)</script></html>'''
(OUT/'review.html').write_text(page.replace('CAPTURES','\n'.join(captures)).replace('ROWS','\n'.join(rows)).replace('MOTIONS','\n'.join(motions)).replace('MOTION_DATA',json.dumps(motion_data)).replace('MID_SUMMARY',mid_summary),encoding='utf-8')
print('Visual review:',OUT/'review.html','captures:',len(captures))
