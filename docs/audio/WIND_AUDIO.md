# Wind audio library

Use `wind_<environment>_<number>` names, with two-digit variants: for example,
`wind_forest_01`, `wind_forest_02` and `wind_ridge_01`. Add new recordings under
new names rather than replacing an established master.

## Forest wind 01

The user supplied `Downloads/forest_wind.wav` on 2026-09-08 and identified it as
a valuable reference for Alpine Apex's wind sound. Its lossless master is kept
at `art_source/audio/wind/wind_forest_01.wav`. The original in Downloads remains
untouched. Both have SHA-256:

`f772b858f7f78431b04ea0151cea1dadaab2a036cbd0da12673cc8e4d1bda01e`

The master is 139.52 seconds of 48 kHz, stereo, 16-bit PCM (26,801,822 bytes).
Retain it for future sound work. `art_source/audio/wind/manifest.json` records
the master/runtime hashes, source format and preparation parameters.

The runtime asset is `assets/audio/ambience/wind/wind_forest_01.ogg`:

- Full 139.52-second first playback; stereo and the original 48 kHz rate.
- Vorbis quality 7, approximately 3.54 MB, decoded during playback.
- Constant +24.197 dB preparation gain places the source peak at -6 dBFS. This
  does not compress the recording's dynamics or apply EQ. The supplied recording
  measured -58.203 dBFS RMS and -30.197 dBFS peak before that gain.
- A 250 ms cosine overlap blends the end into the beginning. Subsequent loops
  resume at 0.25 seconds, immediately after the head used by that overlap. The
  immutable master retains its original beginning and end.

`scripts/presentation/wind_audio.gd` exposes `FOREST_01` and `forest_loop()`.
The asset's import settings also enable the prepared loop for direct editor use.
The helper returns a private `AudioStreamOggVorbis` with the correct loop offset;
each use owns its player and volume. This supports reuse for later environmental
wind layers without modifying another player's stream settings.

Loading screens now use this recording. Their base player gain is -12 dB plus
Interface sound volume; the lower source RMS and wider dynamics require a
different trim from the old generated noise. The default 0.55 interface volume
gives approximately -51 dBFS over the full recording. The separate Loading wind
ambience switch, global mute, fades and reduced-motion behavior remain available.

## Rebuild

```powershell
python scripts/art/prepare_wind_audio.py
# For first ingestion only, pass --source with the supplied recording's path.
./godotw.ps1 --headless --editor --import
./godotw.ps1 --script tests/interface_art_playtest.gd '--' --loading-audio-only
```

The preparation tool uses FFmpeg from PATH or the existing local video-tool
bundle; `--ffmpeg` selects another executable. It refuses to replace a master
with different content. It regenerates only this recording's runtime derivative
and manifest. Native audio review checks gain, private resources, loop wrapping,
source hash, live settings, fade interruption and teardown, and writes a captured
audio-bus sample under `artifacts/interface_art/loading_wind_review.wav`.

## Validation — 2026-09-08

All 15 native forest-audio checks passed. The Downloads original and the retained
master match the SHA-256 above. The runtime copy imports as stereo Vorbis; the
player wraps from its end to the prepared 0.25-second offset without stopping.

The 7.179-second native recording of its quiet opening and fades measures
-56.17 dBFS RMS, -38.14 dBFS peak, no clipped samples, and silence after fade-out.
The complete asset's louder gusts are outside that short capture. The preserved
results are `artifacts/loading_atmosphere/forest_audio_native.json`,
`forest_wind_review.wav` and `forest_audio_analysis.json`. These validate playback,
levels and lifecycle; subjective listening comfort remains a user check.
