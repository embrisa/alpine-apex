"""Build short skier reactions from the user's immutable ElevenLabs downloads.

Run with the project's ordinary Python and bundled FFmpeg. The first ingest
also needs artifacts/voice/transcripts.json (local Whisper base audit).
"""
from array import array
from pathlib import Path
import argparse
import hashlib
import json
import math
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
MASTERS = ROOT / "art_source/audio/voice/elevenlabs_v1"
RUNTIME = ROOT / "assets/audio/voice/liam_v1"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    # The old Liam recipe remains explicitly available and preserves its sources.
    if "--male-1" in sys.argv:
        from prepare_male_voice import main as prepare_male
        sys.argv.remove("--male-1")
        prepare_male()
        return
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path.home() / "Downloads")
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg") or str(
        ROOT / ".tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"))
    args = parser.parse_args()
    MASTERS.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    audit = MASTERS / "source_audit.json"
    if not audit.exists():
        shutil.copy2(ROOT / "artifacts/voice/transcripts.json", audit)
    rows = json.loads(audit.read_text(encoding="utf-8"))
    (MASTERS / ".gdignore").touch()
    source_map = {}
    for row in rows:
        master = MASTERS / row["source"]
        if not master.exists():
            source = args.source / row["source"]
            if sha(source) != row["sha256"]:
                raise SystemExit(f"Source changed: {source.name}")
            shutil.copy2(source, master)
        if sha(master) != row["sha256"]:
            raise SystemExit(f"Master changed: {master.name}")
        source_map[row["index"]] = (master, row)

    # Short excerpts use Whisper word boundaries plus context padding; the
    # original montage is retained. Nonverbal labels are provisional auditions.
    cuts = [
        ("big_air_01", "big_air", 16, 2.73, 3.83, "That's a big jump!"),
        ("big_air_02", "big_air", 15, 5.71, 7.28, "Huge air!"),
        ("big_air_03", "big_air", 16, 2.27, 2.75, "Whoa!"),
        ("finish_01", "finish", 17, 0.0, 1.4, "That was huge!"),
        ("finish_02", "finish", 17, 1.65, 2.65, "Yes!"),
        ("finish_03", "finish", 17, 2.92, 4.15, "Come on!"),
        ("landing_bad_01", "landing_bad", 16, 5.38, 6.8, "Whoa, whoa, whoa!"),
        ("landing_bad_02", "landing_bad", 15, 0.0, 1.4, "Oh my god!"),
        ("impact_01", "impact", 2, 0.0, None, "Ah! [nonverbal, provisional]"),
        ("impact_02", "impact", 6, 0.0, None, "Ah! [nonverbal, provisional]"),
        ("crash_01", "crash", 3, 0.0, None, "Aah! [nonverbal, provisional]"),
        ("crash_02", "crash", 8, 0.0, None, "Aah! [nonverbal, provisional]"),
        ("breathing_01", "breathing", 19, 0.0, None, "Heavy breaths [provisional]"),
        ("breathing_02", "breathing", 18, 0.0, None, "Heavy breaths [provisional]"),
    ]
    for variant, source_id in enumerate([20, 21, 22, 23], 1):
        cuts.append((f"personal_best_{variant:02}", "personal_best", source_id, 0.0, None, "Yes, that's a PB!"))
    for variant, source_id in enumerate([24, 25, 26, 27], 1):
        cuts.append((f"race_record_{variant:02}", "race_record", source_id, 0.0, None,
                     "No way! Yes, I'm the best!" if source_id < 26 else "Holy! I did it! I'm the top!"))

    clips = []
    for cue_id, event, source_id, begin, end, caption in cuts:
        master, row = source_map[source_id]
        raw = subprocess.check_output([args.ffmpeg, "-v", "error", "-i", str(master),
                                       "-f", "f32le", "-ar", "48000", "-ac", "1", "-"])
        pcm = array("f")
        pcm.frombytes(raw)
        pcm = pcm[round(begin * 48000):round(end * 48000) if end is not None else len(pcm)]
        # Trim only quiet outside edges, with padding for consonants and breaths.
        peak = max(abs(x) for x in pcm)
        threshold = peak * 10 ** (-43 / 20)
        block = 480
        voiced = [i for i in range(0, len(pcm), block)
                  if max(abs(x) for x in pcm[i:i + block]) > threshold]
        trim_start = max(0, voiced[0] - 3840) if voiced else 0
        trim_end = min(len(pcm), voiced[-1] + block + 5760) if voiced else len(pcm)
        pcm = pcm[trim_start:trim_end]
        rms = math.sqrt(sum(x * x for x in pcm) / len(pcm))
        breath = event == "breathing"
        gain_db = min((-27 if breath else -21) - 20 * math.log10(max(rms, 1e-9)),
                      (-10 if breath else -6) - 20 * math.log10(max(peak, 1e-9)))
        gain = 10 ** (gain_db / 20)
        for i in range(len(pcm)):
            pcm[i] *= gain * min(1.0, i / 240, (len(pcm) - 1 - i) / 720)
        output = RUNTIME / (cue_id + ".ogg")
        subprocess.run([args.ffmpeg, "-v", "error", "-y", "-f", "f32le", "-ar", "48000", "-ac", "1",
                        "-i", "-", "-c:a", "libvorbis", "-q:a", "6", str(output)], input=pcm.tobytes(), check=True)
        clips.append({"id": cue_id, "event": event, "caption": caption,
                      "source": row["source"], "source_sha256": row["sha256"],
                      "source_start_seconds": begin + trim_start / 48000,
                      "source_end_seconds": begin + trim_end / 48000,
                      "gain_db": gain_db, "duration_seconds": len(pcm) / 48000,
                      "runtime": str(output.relative_to(ROOT)).replace("\\", "/"),
                      "runtime_sha256": sha(output), "bytes": output.stat().st_size})
    manifest = {"version": 2, "voice": "Liam", "source_count": len(rows),
                "analysis": "Local faster-whisper base. Words reviewed as text; nonverbal labels inferred, subjective listening pending.",
                "record_semantics": "finish fires at an eligible saved race finish; personal_best takes precedence for a new PB. Finish celebrations never belong to riding events. race_record is reserved for a future verified shared record source.",
                "retained_only": "Unused shouts, longer ambiguous breath takes, unclear speech at 23_27_58, and James alternate voice remain in masters.",
                "encoding": "48 kHz mono Vorbis q6, constant gain, edge trim and 5/15 ms fades; no pitch change or compression",
                "clips": clips}
    (MASTERS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    gd = ['extends RefCounted', '## Generated by scripts/art/prepare_voice_audio.py; edits belong in that recipe.', 'const CLIPS = [']
    for c in clips:
        gd.append('\t{"id":%s,"event":%s,"caption":%s,"stream":preload("res://%s")},' %
                  (json.dumps(c["id"]), json.dumps(c["event"]), json.dumps(c["caption"]), c["runtime"]))
    gd.append(']\n')
    (ROOT / "scripts/presentation/voice_library.gd").write_text("\n".join(gd), encoding="utf-8")
    print(json.dumps({"sources": len(rows), "runtime_clips": len(clips), "runtime_bytes": sum(c["bytes"] for c in clips)}))


if __name__ == "__main__":
    main()
