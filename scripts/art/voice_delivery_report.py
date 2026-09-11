"""Validate source provenance and assemble the individual-clip audition reel."""
from collections import Counter
import json
import wave
import numpy as np
from prepare_male_voice import ROOT, BANK, QA, read, write, sha


def main():
    manifest = read(BANK / 'manifest.json')
    ledger = read(BANK / 'credit_ledger.json')
    audit = read(QA / 'clip_audit.json')
    generations = {e.get('generation_id') for e in ledger['entries']}
    errors, index, blocks = [], [], []
    elapsed = 0.0
    for clip in manifest['clips']:
        source = ROOT / clip['source']
        meta = read(source.with_suffix('.json'))
        for name, path, expected in [('source', source, clip['source_sha256']),
                                     ('master', ROOT / clip['wav'], clip['wav_sha256']),
                                     ('runtime', ROOT / clip['runtime'], clip['runtime_sha256'])]:
            if sha(path) != expected:
                errors.append(f"{clip['id']}: {name} hash mismatch")
        if meta['generation_id'] not in generations or meta['voice_id'] != manifest['voice_id']:
            errors.append(f"{clip['id']}: generation or voice mismatch")
        with wave.open(str(ROOT / clip['wav']), 'rb') as reader:
            if (reader.getnchannels(), reader.getframerate(), reader.getsampwidth()) != (1, 48000, 2):
                errors.append(f"{clip['id']}: wrong master format")
            audio = np.frombuffer(reader.readframes(reader.getnframes()), dtype='<i2')
        index.append({'id': clip['id'], 'caption': clip['caption'], 'category': clip['category'],
                      'start_seconds': round(elapsed, 3), 'duration_seconds': len(audio)/48000})
        silence = np.zeros(21600, dtype='<i2')
        blocks.extend([audio, silence])
        elapsed += (len(audio)+len(silence))/48000
    with wave.open(str(QA / 'audition_reel.wav'), 'wb') as writer:
        writer.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
        writer.writeframes(np.concatenate(blocks).tobytes())
    write(QA / 'audition_index.json', index)
    report = {'clip_count': len(index), 'runtime_bytes': sum(c['bytes'] for c in manifest['clips']),
              'duration_range_seconds': [min(c['duration_seconds'] for c in manifest['clips']),
                                         max(c['duration_seconds'] for c in manifest['clips'])],
              'categories': dict(Counter(c['category'] for c in manifest['clips'])),
              'audit_statuses': dict(Counter(c['status'] for c in audit['clips'])),
              'clipped_samples': audit['clipped_samples'], 'errors': errors,
              'conservative_credits': ledger['conservative_total_credits'],
              'failed_job_reservations': ledger['failed_generation_reservations'],
              'missing': manifest['missing'], 'withheld': manifest['rejected'],
              'reel_seconds': elapsed,
              'acceptance': 'Provenance and local transcription verified; nonverbal delivery and user listening pending.'}
    write(QA / 'delivery_audit.json', report)
    print(json.dumps(report, indent=2))
    if errors: raise SystemExit(1)


if __name__ == '__main__':
    main()
