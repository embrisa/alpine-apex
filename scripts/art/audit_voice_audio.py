"""Audit individual Male 1 cuts locally; never sends audio to a paid service."""
from pathlib import Path
import json
import numpy as np
from faster_whisper import WhisperModel
from prepare_male_voice import ROOT, BANK, QA, read, write, decode, sha, tokens, NONVERBAL


def main():
    manifest = read(BANK / 'manifest.json')
    cached = sorted((Path.home()/'.cache/huggingface/hub').glob('models--*--faster-whisper-base/snapshots/*/model.bin'))
    model = WhisperModel(str(cached[0].parent), device='cpu', compute_type='int8', cpu_threads=4)
    target = QA / 'clip_audit.json'
    existing = {c['id']:c for c in read(target)['clips']} if target.exists() else {}
    rows = []
    for clip in manifest['clips']:
        path = ROOT / clip['wav']
        if clip['id'] in existing and existing[clip['id']]['wav_sha256']==sha(path):
            row = existing[clip['id']]
            expected, heard = tokens(clip['caption']), tokens(row['transcript'])
            nonverbal = all(t in NONVERBAL for t in expected) or clip['category']=='breathing'
            correct = len(expected)==len(heard) and all(a==b or (a in NONVERBAL and b in NONVERBAL) for a,b in zip(expected,heard))
            row['status'] = 'nonverbal_provisional' if nonverbal else 'words_verified' if correct else 'review'
            rows.append(row)
            continue
        pcm = decode(path)
        decoded = decode(ROOT/clip['runtime'])
        audio = decode(path,16000)
        segments, _ = model.transcribe(audio,language='en',beam_size=5,vad_filter=False,condition_on_previous_text=False)
        text = ' '.join(s.text.strip() for s in segments).strip()
        expected = tokens(clip['caption'])
        heard = tokens(text)
        nonverbal = all(t in NONVERBAL for t in expected) or clip['category']=='breathing'
        correct = len(expected)==len(heard) and all(a==b or (a in NONVERBAL and b in NONVERBAL) for a,b in zip(expected,heard))
        # Breath/grunt spelling is inherently ambiguous to ASR; retain a distinct status.
        status = 'nonverbal_provisional' if nonverbal else 'words_verified' if correct else 'review'
        row = {'id':clip['id'],'caption':clip['caption'],'transcript':text,'status':status,
               'wav_sha256':sha(path),'duration':len(pcm)/48000,
               'wav_peak_dbfs':float(20*np.log10(max(np.max(np.abs(pcm)),1e-9))),
               'decoded_ogg_peak_dbfs':float(20*np.log10(max(np.max(np.abs(decoded)),1e-9))),
               'clipped_samples':int(np.sum(np.abs(decoded)>=1.0))}
        rows.append(row)
        if status=='review':
            print('REVIEW',clip['id'],clip['caption'],'=>',text,flush=True)
        if len(rows)%20==0:
            write(target,{'clips':rows,'note':'Local transcription/signal evidence; listening acceptance separate.'})
            print('AUDITED',len(rows),flush=True)
    report = {'clips':rows,'clip_count':len(rows),'clipped_samples':sum(r['clipped_samples'] for r in rows),
              'review':[r['id'] for r in rows if r['status']=='review'],
              'note':'Local transcription/signal evidence; listening acceptance separate.'}
    write(target,report)
    print(json.dumps({k:v for k,v in report.items() if k!='clips'}),flush=True)


if __name__=='__main__':
    main()
