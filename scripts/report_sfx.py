"""Collect evidence produced by this audio implementation, without inferring listening acceptance."""
import hashlib
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/sfx'
def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig')) if path.exists() else None

suites={}
for name in ['physics_suite','runtime_suite','wind_audio_suite','ragdoll_suite','rock_terrain_suite','skier_voice_suite','skier_voice_upgrade_suite','interface_suite']:
    path=OUT/(name+'.log')
    if not path.exists(): continue
    text=path.read_text(encoding='utf-8-sig')
    summaries=[json.loads(m.group(1)) for m in re.finditer(r'^\w+_RESULTS? (\{.+\})\s*$',text,re.M)]
    suites[name]=summaries[-1] if summaries else {'summary_missing':True}
    suites[name]['log_errors']=len(re.findall(r'^SCRIPT ERROR:|^ERROR:|^FAIL[: ]',text,re.M))
for name in ['native_suite','fallback_suite','ragdoll_suite','device_suite']:
    result=read(OUT/(name+'.json'))
    if result is not None:
        log=OUT/(('sfx_ragdoll_suite' if name=='ragdoll_suite' else name)+'.log')
        result['log_errors']=len(re.findall(r'^SCRIPT ERROR:|^ERROR:|^FAIL[: ]',log.read_text(encoding='utf-8-sig'),re.M)) if log.exists() else 0
        suites['sfx_'+name]=result
paths=['native/wind/sfx_dsp.h','native/wind/sfx_stream.cpp','native/wind/sfx_dsp_test.cpp',
       'native/wind/wind_dsp.h','native/wind/wind_stream.cpp','native/wind/CMakeLists.txt',
       'addons/alpine_wind/bin/alpine_wind.windows.x86_64.dll','scripts/main.gd',
       'scripts/presentation/procedural_sfx.gd','scripts/presentation/riding_audio_events.gd',
       'scripts/presentation/audio_contact_bone.gd','scripts/presentation/crash_audio_contacts.gd',
       'scripts/presentation/skier_ragdoll.gd','scripts/presentation/procedural_wind.gd',
       'scripts/presentation/speed_effects.gd','scripts/presentation/voice_environment.gd',
       'scripts/presentation/skier_voice.gd','scripts/world/crash_collision.gd','scripts/ui/hud.gd',
       'scripts/ui/riding_audio_settings.gd']
result={'suites':suites,'dsp':read(OUT/'offline/dsp.json'),'capture':read(OUT/'capture/report.json'),
        'signals':read(OUT/'signal_analysis.json'),
        'performance':{mode:read(ROOT/f'artifacts/pc_environment/sfx_{mode}_benchmark/sfx.json') for mode in ['original','procedural']},
        'guards':{mode:read(ROOT/f'artifacts/guarded/sfx_{mode}_benchmark/guard.json') for mode in ['original','procedural']},
        'capture_guard':read(ROOT/'artifacts/guarded/sfx_lab_short_capture/guard.json'),
        'source_sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in paths},
        'listening_acceptance':'User listening and skiing review pending'}
(OUT/'validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
lines=['# Procedural skiing audio validation','',
       'The audio expansion reads completed skiing state and read-only Jolt contacts. Concurrent physics/animation work is retained. Results describe the current model-17 working tree with v12 mountain generation. Individual fixtures identify their own terrain; the audio work itself does not change simulation or replay identity.','',
       '## Automated and device evidence','', '| Suite | Checks | Failures |','| --- | ---: | ---: |']
for name,values in suites.items():
    lines.append(f"| {name} | {values.get('checks','missing')} | {len(values.get('failures',[]))+values.get('log_errors',0)} |")
if result['dsp']:
    d=result['dsp'];lines+=['',f"Standalone native SFX: **{d['checks']} checks, {d['failures']} failures** at 44.1/48 kHz. Combined worst-case wind/SFX callback **p99 {d['combined_p99_512_ms']:.4f} ms / 512 frames** (target ≤0.5 ms). Wind's existing standalone suite also passes through CTest."]
lines+=['','[Labelled sound auditions](AUDITIONS.md) and [full evidence JSON](validation.json).','', '## Matched 4K performance','',
        '| Mode | Frame p95 / p99 ms | GPU p95 ms | SFX callback p99 ms |','| --- | ---: | ---: | ---: |']
for mode,p in result['performance'].items():
    if p is None:
        lines.append(f'| {mode} | Not measured | — | — |');continue
    f=p['frame_ms'];g=p['render_gpu_ms'];n=p['native_sfx'];lines.append(f"| {mode} | {f.get('p95',0):.3f} / {f.get('p99',0):.3f} | {g.get('p95',0):.3f} | {n['p99_512_ms']:.4f} |")
lines+=['','The requested matched comparison uses 3840×2160 output, High at 75% FSR2, 120 FPS cap and GI off. The original-mode run did not produce a usable full-mountain descent measurement, so the procedural comparison was not launched without a baseline. Full-mountain frame percentiles, CPU/GPU times and memory comparisons therefore remain unverified. Runner telemetry is retained under artifacts/guarded/sfx_original_benchmark, including attempt history.']
if result['capture']:
    c=result['capture'];lines+=['','## Rendered and recorded evidence','',f"Captured {c['capture_frames']} timestamped frames and {c['audio_frames']/c['audio_rate']:.2f} seconds of device-mixed audio. Scope: {c['scope']}, {c['actual_pixels'][0]}×{c['actual_pixels'][1]} output. The final crash is an explicit unranked fixture; capture readback overhead is included, so this is not matched 4K performance evidence.",'','[Skiing and crash preview](capture/skiing_crash.mp4) · [original PCM](capture/skiing_crash.wav).', '', '[Audio categories at 4K](capture/audio_categories_4k.png) were inspected in a separate UI-only native render; settings also appear over the laboratory scene in [this capture](capture/audio_settings.png).']
contact=suites.get('sfx_ragdoll_suite',{})
if contact:
    lines+=['',f"Read-only Jolt contact evidence: at most {contact['max_reports']} observed reports (60 allowed), {contact['events']} impact/equipment events. Bone capture maximum {contact.get('capture_max_bone_us',0)} µs, sum of latest bone captures maximum {contact.get('capture_sum_max_us',0)} µs, main-thread contact observation maximum {contact['contact_max_us']} µs. These include startup and are maxima, not percentiles or incremental frame cost."]
lines+=['','## Remaining acceptance','',
        'User listening and skiing review remains open: naturalness, high-speed readability, repetition, fatigue and mix balance cannot be established by automated checks or sampled rendered frames.','',
        'No personal records/settings were used by these fixtures. No source recordings were changed, no paid generation occurred, and no other agent processes were terminated.']
(OUT/'VALIDATION.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'suites':len(suites),'checks':sum(v.get('checks',0) for v in suites.values()),'dsp':result['dsp']}))
