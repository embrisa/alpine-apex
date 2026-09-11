# Dated Cascadeur visual report

Compile the retained September 10–11 R6, R7 and R9 experiments into a portable
HTML report. This is a historical comparison, not a new capture of main.
Outputs stay in ignored `artifacts/`; the builder preserves every source file.

From the repository root on this Windows workstation:

```powershell
.tools/art-venv/Scripts/python.exe scripts/pose_review/report/build.py --ffmpeg .tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe --output artifacts/animation_comparison_20260912
```

Use a fresh output directory on subsequent runs. Requires Python with Pillow,
FFmpeg with libx264, Windows Segoe UI fonts, and the retained local evidence.
Media and frames are deliberately not committed to Git. An independent checkout
without those artifacts cannot rebuild the report from source alone.

Open the generated `index.html` in Chrome/Edge, or serve its directory using
the existing `scripts/pose_review/serve_review.py`. All viewing media is bundled
and uses relative paths; there are no external dependencies or network requests.

The builder verifies all seven source revision seals, rechecks matched physical
fields and camera metadata, stacks the two original movies into one synchronized
movie, and decodes/counts all 121 frames in each output. The viewer selects a
camera by cropping that movie. Fixed still crops preserve scale and frame identity.
R9 intentionally has different physics and disables overlay comparison.

The build receipt records source/output hashes, input identity, local Git state
and actual verification. It does not infer visual quality or user acceptance.
Check the browser's rendering, playback, seeking, camera modes and notes before
delivery. Human/controller preference remains a separate decision.
