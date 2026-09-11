"""Offline, manifest-driven preparation of the MCP-generated Male 1 bank.

No ElevenLabs API calls or credentials. MCP writes the credit ledger separately.
Downloads only generation URLs exported by MCP, retains originals, and records
local Whisper word timing plus signal boundaries for explicit clip review.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import math
import subprocess
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / 'art_source/audio/voice/male_1_v1'
QA = ROOT / 'artifacts/voice/male_1_v1'
FFMPEG = ROOT / '.tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def decode(path, rate=48000):
    import numpy as np
    raw = subprocess.check_output([str(FFMPEG), '-v', 'error', '-i', str(path),
                                   '-f', 'f32le', '-ar', str(rate), '-ac', '1', '-'])
    return np.frombuffer(raw, dtype='<f4').copy()


def ingest(result_path):
    result = read(result_path)
    ledger = read(BANK / 'credit_ledger.json')
    generation_map = {}
    for entry in ledger['entries']:
        for item in entry.get('result', {}).get('pending', []):
            generation_map[item['generation_id']] = entry['batch']
    originals = BANK / 'originals'
    originals.mkdir(parents=True, exist_ok=True)
    for media in result.get('media', []):
        gid = media['generation_id']
        if gid not in generation_map:
            continue
        batch = generation_map[gid]
        path = originals / (batch + '.mp3')
        if not path.exists():
            url = media.get('master_url') or media['url']
            if not url.startswith('https://'):
                raise ValueError('Generation download must be HTTPS')
            with urllib.request.urlopen(url, timeout=90) as response:
                path.write_bytes(response.read())
        write(originals / (batch + '.json'), {
            'batch': batch, 'generation_id': gid, 'sha256': sha(path),
            'duration_reported': media.get('duration_secs'),
            'voice_id': ledger['voice_id'], 'model_id': ledger['model_id']})
        print('RETAINED', batch, path.stat().st_size, flush=True)


def analyze():
    import numpy as np
    from faster_whisper import WhisperModel
    model = None
    for path in sorted((BANK / 'originals').glob('*.mp3')):
        target = QA / 'analysis' / (path.stem + '.json')
        if target.exists() and read(target).get('sha256') == sha(path):
            continue
        pcm = decode(path)
        if model is None:
            cached = sorted((Path.home() / '.cache/huggingface/hub').glob(
                'models--*--faster-whisper-base/snapshots/*/model.bin'))
            model = WhisperModel(str(cached[0].parent) if cached else 'base', device='cpu', compute_type='int8',
                                 cpu_threads=4, local_files_only=True)
        segments, info = model.transcribe(str(path), language='en', beam_size=5,
                                         word_timestamps=True, vad_filter=False,
                                         condition_on_previous_text=False)
        words = []
        for segment in segments:
            words.extend({'word': w.word, 'start': w.start, 'end': w.end,
                          'probability': w.probability} for w in segment.words or [])
        # 10 ms RMS blocks; keep silence spans for phrase-boundary review.
        hop = 480
        rms = np.array([np.sqrt(np.mean(pcm[i:i+hop] ** 2)) for i in range(0, len(pcm), hop)])
        threshold = max(float(rms.max()) * 10 ** (-32/20), 0.0001)
        quiet = rms < threshold
        silences, start = [], None
        for i, value in enumerate(np.append(quiet, False)):
            if value and start is None:
                start = i
            elif not value and start is not None:
                if i-start >= 8:
                    silences.append([start*.01, min(i*.01, len(pcm)/48000)])
                start = None
        write(target, {'sha256': sha(path), 'duration': len(pcm)/48000,
                       'peak': float(np.max(np.abs(pcm))), 'words': words,
                       'silences': silences, 'transcript': ''.join(w['word'] for w in words),
                       'note': 'Local transcription and signal analysis; not subjective listening.'})
        print(path.stem, ''.join(w['word'] for w in words), silences, flush=True)



ALIASES = {'air_big': 'big_air', 'save': 'landing_bad', 'impact_hard': 'impact',
           'crash_start': 'crash', 'finish_normal': 'finish', 'pb': 'personal_best',
           'record': 'race_record'}
NONVERBAL = {'hup', 'hnh', 'ugh', 'ah', 'ngh', 'huh', 'oof', 'mmgh', 'oh', 'ooh', 'whew', 'woo', 'hmm'}


def tokens(text):
    text = text.lower().replace('’', "'")
    text = text.replace("c'mon", "come on").replace("dammit", "damn it")
    text = re.sub(r'\ball right\b', 'alright', text)
    found = re.findall(r"[a-z]+(?:'[a-z]+)?", text)
    aliases = {'woah': 'whoa', 'ohhh': 'oh', 'ohhhh': 'oh', 'ahh': 'ah', 'ahhh': 'ah',
               'agh': 'ah', 'nghhh': 'ngh', 'mm': 'hmm', 'mmm': 'hmm',
               'whoo': 'woo', 'wooo': 'woo', 'woooo': 'woo'}
    return [aliases.get(w, w) for w in found]


def align(expected, heard):
    # Global word edit alignment retains order across short repeated reactions.
    n, m = len(expected), len(heard)
    cost = [[0.0]*(m+1) for _ in range(n+1)]
    step = {}
    for i in range(1, n+1):
        cost[i][0] = i
        step[i, 0] = (i-1, 0)
    for j in range(1, m+1):
        cost[0][j] = j
        step[0, j] = (0, j-1)
    for i in range(1, n+1):
        for j in range(1, m+1):
            same = expected[i-1] == heard[j-1]
            vocal = expected[i-1] in NONVERBAL and heard[j-1] in NONVERBAL
            options = [(cost[i-1][j-1] + (0 if same else .25 if vocal else 1.3), (i-1,j-1)),
                       (cost[i-1][j]+1, (i-1,j)), (cost[i][j-1]+1, (i,j-1))]
            cost[i][j], step[i,j] = min(options, key=lambda x: x[0])
    pairs = {}
    i, j = n, m
    while i or j:
        a, b = step[i,j]
        if a == i-1 and b == j-1:
            pairs[i-1] = j-1
        i, j = a, b
    return pairs


def catalog():
    script = read(BANK / 'script.json')
    entries = {line['id']: dict(line, category=g['id']) for g in script['groups'] for line in g['lines']}
    for i in range(1,5):
        entries[f'voice_breathing_{i:02}'] = {
            'id': f'voice_breathing_{i:02}', 'caption': 'Heavy breathing (nonverbal)',
            'category': 'breathing', 'weight': 1, 'min_race_progress': 0}
    return entries


def propose():
    ledger = read(BANK / 'credit_ledger.json')
    entries = catalog()
    cuts = {}
    for entry in ledger['entries']:
        batch = entry['batch']
        analysis = QA / 'analysis' / (batch+'.json')
        if not analysis.exists():
            continue
        ids = entry.get('line_ids') or [key for key, line in entries.items() if line['category']==batch]
        data = read(analysis)
        words, heard = [], []
        source_words = []
        for word in data['words']:
            if source_words and tokens(source_words[-1]['word'])==['all'] and tokens(word['word'])==['right']:
                source_words[-1] = dict(word,word='alright',start=source_words[-1]['start'])
            else:
                source_words.append(word)
        for word in source_words:
            for token in tokens(word['word']):
                words.append(word)
                heard.append(token)
        lines = [entries[key] for key in ids]
        if entry.get('category') == 'breathing':
            # Contextual vowel sounds give the MCP non-empty speech input.
            expected_lines = [['ah'], ['ah'], ['ugh'], ['oh']]
        else:
            expected_lines = [tokens(line['caption']) for line in lines]
        expected = [t for line in expected_lines for t in line]
        pairs = align(expected, heard)
        cursor = 0
        aligned = []
        for line_tokens in expected_lines:
            indices = [pairs[i] for i in range(cursor,cursor+len(line_tokens)) if i in pairs]
            matches = [expected[i] == heard[pairs[i]] or
                       (expected[i] in NONVERBAL and heard[pairs[i]] in NONVERBAL)
                       for i in range(cursor,cursor+len(line_tokens)) if i in pairs]
            exact = len(indices)==len(line_tokens) and all(matches)
            aligned.append((indices,exact))
            cursor += len(line_tokens)
        for i, (line, (indices,exact)) in enumerate(zip(lines,aligned)):
            if not indices:
                continue
            first, last = indices[0], indices[-1]
            start = max(0.0, words[first]['start']-.08)
            end = min(data['duration'], words[last]['end']+.12)
            before = next((a[0][-1] for a in reversed(aligned[:i]) if a[0]), None)
            after = next((a[0][0] for a in aligned[i+1:] if a[0]), None)
            if before is not None:
                target = (words[before]['end']+words[first]['start'])/2
                spaces = [s for s in data['silences'] if abs(sum(s)/2-target)<.26]
                start = max(0.0, sum(min(spaces,key=lambda s:abs(sum(s)/2-target)))/2 if spaces else target)
            if after is not None:
                target = (words[last]['end']+words[after]['start'])/2
                spaces = [s for s in data['silences'] if abs(sum(s)/2-target)<.26]
                end = min(data['duration'], sum(min(spaces,key=lambda s:abs(sum(s)/2-target)))/2 if spaces else target)
            vocal = all(t in NONVERBAL for t in expected_lines[i]) or line['category']=='breathing'
            row = dict(line, batch=batch, start=round(start,4), end=round(end,4),
                       aligned_transcript=' '.join(heard[first:last+1]),
                       status='accepted' if exact and end-start>=.18 else 'needs_review',
                       review='Nonverbal delivery provisional' if vocal else 'Words aligned to local transcription',
                       source_sha256=data['sha256'])
            cuts[line['id']] = row
    manual = BANK / 'cut_overrides.json'
    if manual.exists():
        for key, override in read(manual).items():
            row = cuts.get(key, dict(entries[key]))
            row.update(override)
            cuts[key] = row
    missing = [key for key in entries if key not in cuts]
    write(BANK / 'cuts.json', {'clips': list(cuts.values()), 'missing': missing})
    print(json.dumps({'proposed':len(cuts), 'missing':missing,
                      'review':[c for c in cuts.values() if c['status']!='accepted']}, indent=2), flush=True)


def build():
    import numpy as np
    data = read(BANK / 'cuts.json')
    runtime = ROOT / 'assets/audio/voice/male_1_v1'
    masters = BANK / 'wav'
    runtime.mkdir(parents=True, exist_ok=True)
    masters.mkdir(parents=True, exist_ok=True)
    clips, cache = [], {}
    old_manifest = BANK / 'manifest.json'
    old_clips = {c['id']:c for c in read(old_manifest)['clips']} if old_manifest.exists() else {}
    for row in data['clips']:
        if row['status'] != 'accepted':
            continue
        source = BANK / 'originals' / (row['batch']+'.mp3')
        if row['batch'] not in cache:
            cache[row['batch']] = decode(source)
        full = cache[row['batch']]
        pcm = full[round(row['start']*48000):round(row['end']*48000)].copy()
        if len(pcm)<8640 or not np.all(np.isfinite(pcm)):
            raise ValueError('Invalid cut '+row['id'])
        peak = float(np.max(np.abs(pcm)))
        if peak<.002:
            raise ValueError('Silent cut '+row['id'])
        active = np.flatnonzero(np.abs(pcm)>peak*10**(-43/20))
        first = max(0,int(active[0])-3840)
        last = min(len(pcm),int(active[-1])+5760)
        pcm = pcm[first:last]
        peak = float(np.max(np.abs(pcm)))
        rms = float(np.sqrt(np.mean(pcm*pcm)))
        breath = row['category']=='breathing'
        gain_db = min((-27 if breath else -21)-20*math.log10(max(rms,1e-9)),
                      (-10 if breath else -6)-20*math.log10(max(peak,1e-9)))
        pcm *= 10**(gain_db/20)
        pcm *= np.minimum(1.0, np.minimum(np.arange(len(pcm))/240,
                                         np.arange(len(pcm)-1,-1,-1)/720))
        wav_path = masters / (row['id']+'.wav')
        with wave.open(str(wav_path),'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(48000)
            wav.writeframes(np.rint(pcm*32767).astype('<i2').tobytes())
        ogg_path = runtime / (row['id']+'.ogg')
        old = old_clips.get(row['id'], {})
        if not (ogg_path.exists() and old.get('wav_sha256')==sha(wav_path) and old.get('runtime_sha256')==sha(ogg_path)):
            subprocess.run([str(FFMPEG),'-v','error','-y','-i',str(wav_path),
                            '-c:a','libvorbis','-q:a','6',str(ogg_path)],check=True)
        event = ALIASES.get(row['category'],row['category'])
        clips.append(dict(row,event=event,intensity=row['category'].split('_')[-1],
                          source=str(source.relative_to(ROOT)).replace('\\','/'),source_sha256=sha(source),
                          source_start_seconds=row['start']+first/48000,
                          source_end_seconds=row['start']+last/48000,
                          gain_db=gain_db,duration_seconds=len(pcm)/48000,
                          wav=str(wav_path.relative_to(ROOT)).replace('\\','/'),wav_sha256=sha(wav_path),
                          runtime=str(ogg_path.relative_to(ROOT)).replace('\\','/'),
                          runtime_sha256=sha(ogg_path),bytes=ogg_path.stat().st_size))
    rejected = [r['id'] for r in data['clips'] if r['status']!='accepted']
    accepted_ids = {r['id'] for r in clips}
    for obsolete in runtime.glob('voice_*.ogg'):
        if obsolete.stem not in accepted_ids:
            assert obsolete.resolve().parent == runtime.resolve()
            obsolete.unlink() # Only this bank's generated runtime derivatives.
            obsolete.with_suffix('.ogg.import').unlink(missing_ok=True)
    write(BANK / 'manifest.json', {
        'version':1,'voice':'Alpine Apex Male 1','voice_id':'V04rTlFwpnbuqHOMNQEj',
        'model_id':'eleven_v3','expected_spoken_clips':183,'expected_breathing_clips':4,
        'encoding':'48 kHz mono PCM16 WAV masters / Vorbis q6; 5/15 ms fades; constant gain',
        'acceptance':'Local transcription, timing and signal QA. Human delivery/mix acceptance pending.',
        'missing':data['missing'],'rejected':rejected,'clips':clips})
    gd = ['extends RefCounted','## Generated by scripts/art/prepare_male_voice.py; never includes batch recordings.',
          'const VOICE_NAME = "Alpine Apex Male 1"','const CLIPS = [']
    for c in clips:
        fields = {k:c[k] for k in ['id','event','category','intensity','caption','weight','min_race_progress']}
        line = json.dumps(fields,ensure_ascii=False)
        gd.append('\t'+line[:-1]+', "stream":preload("res://'+c['runtime']+'")},')
    gd.append(']\n')
    (ROOT / 'scripts/presentation/voice_library.gd').write_text('\n'.join(gd),encoding='utf-8')
    print(json.dumps({'runtime_clips':len(clips),'bytes':sum(c['bytes'] for c in clips),
                      'missing':len(data['missing']),'rejected':len(rejected)}),flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ingest', type=Path)
    parser.add_argument('--analyze', action='store_true')
    parser.add_argument('--propose', action='store_true')
    parser.add_argument('--build', action='store_true')
    args = parser.parse_args()
    if args.ingest:
        ingest(args.ingest)
    if args.analyze:
        analyze()
    if args.propose:
        propose()
    if args.build:
        build()


if __name__ == '__main__':
    main()
