"""Collect controlled full descents without conflating historical PC results."""
from pathlib import Path
import json
import shutil

ROOT=Path(__file__).resolve().parents[1]
EVIDENCE=ROOT/'artifacts/golden_sunlight'
DEST=EVIDENCE/'benchmarks'
RUNS=[('before_clear','baseline_project','golden_before_clear',-1,'clear'),
      ('after_clear','comparison_project','golden_after_clear',-1,'clear'),
      ('before_snow','baseline_project','golden_before_snow',1,'snowfall'),
      ('after_snow','comparison_project','golden_after_snow',1,'snowfall')]

def load_runs():
    runs={}
    for key,project,label,side,weather in RUNS:
        folder=EVIDENCE/project/'artifacts/pc_environment'/label
        engine=folder/f'native_{side}_{weather}.json'
        system=folder/'system.json'
        if not engine.exists() or not system.exists(): continue
        r=json.loads(engine.read_text(encoding='utf-8-sig'))
        s=json.loads(system.read_text(encoding='utf-8-sig'))
        assert r['finished'] and r['section_completed'] and not r['crash'],key
        assert r['scope']=='full_descent' and not r['capture_overhead_included'] and r['unranked'],key
        assert r['actual_pixels']==[3840,2160] and r['display']['internal_pixels_from_viewport_scale']==[2880,1620],key
        assert not s['changed_sources'] and s['exit_code']==0,key
        target=DEST/key
        target.mkdir(parents=True,exist_ok=True)
        for file in [engine,system,folder/'stdout.log',folder/'stderr.log']:
            if file.exists(): shutil.copy2(file,target/file.name)
        samples=s['samples']
        r['system_summary']={'private_peak_gib':max(v['private_bytes'] for v in samples)/2**30,
           'working_set_peak_gib':max(v['working_set_bytes'] for v in samples)/2**30,
           'free_system_min_gib':min(v['system_free_bytes'] for v in samples)/2**30,
           'wow_samples':sum(v['wow_running'] for v in samples),'samples':len(samples),
           'cpu':s['cpu'],'installed_ram_bytes':s['installed_ram_bytes']}
        runs[key]=r
    return runs

if __name__=='__main__':
    runs=load_runs()
    if len(runs)!=4:
        print('AVAILABLE',list(runs))
        raise SystemExit(1)
    delta={}
    for weather in ['clear','snow']:
        a,b=runs['before_'+weather],runs['after_'+weather]
        for key in ['height_sha256','obstacle_sha256','seconds','position','display']:
            assert a[key]==b[key],(weather,key)
        delta[weather]={'mean_gpu_ms':b['render_gpu_ms']['mean']-a['render_gpu_ms']['mean'],
                       'mean_frame_ms':b['frame_ms']['mean']-a['frame_ms']['mean'],
                       'p95_frame_ms':b['frame_ms']['p95']-a['frame_ms']['p95']}
    result={'runs':runs,'increment':delta,'scope':'Only the 14 lighting source differences on the frozen initial working tree; see comparison_source_audit.json. Concurrent UI work excluded from the controlled timing comparison.'}
    (EVIDENCE/'benchmark_comparison.json').write_text(json.dumps(result,indent=2))
    metrics=[('Average FPS',lambda r:f"{r['frame_ms']['average_fps']:.1f}"),
             ('Mean frame, ms',lambda r:f"{r['frame_ms']['mean']:.3f}"),
             ('Frame p95 / p99, ms',lambda r:f"{r['frame_ms']['p95']:.3f} / {r['frame_ms']['p99']:.3f}"),
             ('Slowest-1% FPS',lambda r:f"{r['frame_ms']['slowest_one_percent_fps']:.1f}"),
             ('Forest average FPS',lambda r:f"{r['forest_frame_ms']['average_fps']:.1f}"),
             ('Forest p95 / p99, ms',lambda r:f"{r['forest_frame_ms']['p95']:.3f} / {r['forest_frame_ms']['p99']:.3f}"),
             ('Forest slowest-1% FPS',lambda r:f"{r['forest_frame_ms']['slowest_one_percent_fps']:.1f}"),
             ('Render GPU mean / p95, ms',lambda r:f"{r['render_gpu_ms']['mean']:.3f} / {r['render_gpu_ms']['p95']:.3f}"),
             ('Render CPU mean / p95, ms',lambda r:f"{r['render_cpu_ms']['mean']:.3f} / {r['render_cpu_ms']['p95']:.3f}"),
             ('Solver mean / p95, us',lambda r:f"{r['physics_step_us']['mean']:.1f} / {r['physics_step_us']['p95']:.1f}"),
             ('Draw calls mean / p95',lambda r:f"{r['draw_calls']['mean']:.1f} / {r['draw_calls']['p95']:.0f}"),
             ('Measured frames',lambda r:str(r['frame_ms']['samples'])),
             ('Descent duration, s',lambda r:f"{r['seconds']:.2f}"),
             ('Engine video memory peak, GiB',lambda r:f"{r['peak_video_bytes']/2**30:.3f}"),
             ('Process private / working set peak, GiB',lambda r:f"{r['system_summary']['private_peak_gib']:.3f} / {r['system_summary']['working_set_peak_gib']:.3f}"),
             ('Minimum free system RAM, GiB',lambda r:f"{r['system_summary']['free_system_min_gib']:.3f}"),
             ('WoW observed samples',lambda r:f"{r['system_summary']['wow_samples']} / {r['system_summary']['samples']}"),
             ('Generation / world build, ms (excluded)',lambda r:f"{r['generation_ms']:.0f} / {r['world_build_ms']:.0f}")]
    text='| Metric | Clear before | Clear golden | Snowfall before | Snowfall golden |\n|---|---:|---:|---:|---:|\n'
    for label,fmt in metrics:
        text+='| '+label+' | '+' | '.join(fmt(runs[k]) for k,_,_,_,_ in RUNS)+' |\n'
    text+=f"\nMean GPU increment: **{delta['clear']['mean_gpu_ms']:+.3f} ms Clear**, **{delta['snow']['mean_gpu_ms']:+.3f} ms Snowfall**.\n"
    (EVIDENCE/'benchmarks.md').write_text(text)
    print(text)
