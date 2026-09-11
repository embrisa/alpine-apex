# Alpine Apex Male 1 voice bank

The runtime character is **Alpine Apex Male 1**, ElevenLabs voice
`V04rTlFwpnbuqHOMNQEj`, generated through MCP with `eleven_v3`.
Settings / Skier Voice preserves enabled, breathing and volume controls (75%
default), with 27 audition categories. Preview-only categories are labelled.
Global mute includes both players. Personal preferences remain in
`user://skier_voice_v1.cfg`; automated fixtures use disposable settings/records.
This presentation layer works with the current **v12 mountains** and reads the
completed ski simulation without changing its state or replay identity.

## Delivery and limits

The retained runtime bank has **170 clips: 166 scripted reactions and four
breathing clips**, 2,531,458 bytes of mono 48 kHz Vorbis. Each runtime file holds
one intended utterance, 0.34–2.54 seconds. ElevenLabs previews show longer
category batches; those downloads are retained as sources and never played
whole by the game.

The requested catalogue has 183 scripted reactions plus four breaths. Ten
requested variants have no usable successful generation, and seven additional
cuts are withheld because isolated transcription differed from the intended
wording. A mismatch is uncertainty, not proof that the speaker said the wrong
words. Every category retains at least one accepted alternative from this voice.
There is no unrelated-line or Liam fallback.

- Missing: record 03/05/06/07/09/10; misc 05/06/07/08.
- Withheld: air_small 02; save 01; speed_high 06; speed_extreme 04;
  terrain_cliff 01; nearmiss 01/10.
- All 138 lexical clips passed isolated local transcription; 32 nonverbal
  clips, including breaths, have provisional performance acceptance. Subjective
  delivery, breathing naturalness and balance against wind need user listening.

The conservative credit commitment is **2,992 / 3,000**: successful generation
prices total 2,187, with 805 still reserved against explicitly failed jobs.
MCP reports prices for failed jobs but exposes no debit/refund lookup. We assume
no refunds and perform no further generation. This is a conservative ledger,
not a verified account debit. Tag-only breathing attempts failed; contextual
breathing generation produced the four retained nonverbal cuts. Failed jobs and
replacement prompts are retained, with no automatic uncertain resubmissions.

## Runtime behavior

All routine reactions share a 60-second gap. Suppressed opportunities expire;
there is no dialogue queue. Category cooldowns and the riding gap survive local
restarts. Crash and saved eligible result cues can interrupt routine speech.
A flight and its landing cannot produce successive riding reactions.

| Category | Automatic trigger |
| --- | --- |
| Air | At least 3 seconds airborne and 18 m/s, once per flight; 50% chance. Valid existing prediction of 6 seconds total flight selects huge air. |
| Major landing | Unvoiced flight of at least 3 seconds; classify reserve loss over 0.24 seconds. Under 10% celebrates; greater surviving loss selects a save. Existing rough-landings after 1.5 seconds and 25% loss remain supported. |
| Impact | 15–35% reserve loss selects nonverbal compression; 35% or more selects hard impact. Landing classification consumes its damage to prevent duplicate candidates. |
| Crash | Onset interrupts riding speech. One follow-up after at least 1.5 seconds and 0.75 seconds below 2 m/s hip speed; expires at 10 seconds. |
| Low reserve | Breathing activates at 23%, recovers at 42%. One injured candidate after six continuous seconds below activation; recovery rearms it. Reserve remains impact capacity. |
| Speed | 180 km/h for eight seconds or 220 km/h for five seconds. Extreme wins; rearm after ten seconds below 150 km/h; three-minute category cooldown. |
| Near miss | Swept actual pass of a tree/rock at 15 m/s or more, 0–1 m outside its collision envelope, vertical overlap, no contact. Deduplicate until leaving a 40 m vicinity. |
| Terrain | At least 10 m/s while grounded. Steep >=45 degrees for one second, rearm below 35; cliff >=8 m extra drop below tangent within 16 m; tight 1.5–6 m between both sides within 24 m; open clear 30 m corridor for three seconds after constrained terrain. |
| Race start | Explicit timed start/restart, 25% chance and three-minute cooldown. Resuming does not call this hook. |
| Finish | Saved eligible PB first; otherwise <=3% slower than previous PB is good, >=10% slower is bad, intermediate/missing comparison normal. |
| Self-talk | Lowest priority, after three minutes without speech, grounded, recovered and moving with no hazard candidate. |

Terrain cliff/tight conditions require 0.3 seconds; all terrain conditions rearm
after five seconds outside, with three minutes between repeats of each category.
The open corridor is 12 m wide. Terrain/obstacle uncertainty suppresses cues.
"Almost there" requires at least 85% timed-race progress. "Nailed it!" has 0.2
selection weight. "This is fast." also has reduced weight in the script but its
cut is currently withheld. Profanity is unrestricted.

Small-air, ordinary clean-landing, shared-record and race-win clips are audition
only. No shared record or win is announced without a future authoritative source.
Priorities descend through result/crash, hard impact/save/compression, near miss,
air/landing, injured, terrain, speed and self-talk.

Pause, focus loss, loading, restart and leaving the crash view cancel pending
crash follow-up. Breathing uses a separate player, a 0.28-second inter-clip gap,
recovery fades and 12% ducking during speech. There is one reaction player and
one breathing player; no speed-related pitch processing.

## Architecture and source bank

- `scripts/presentation/voice_events.gd`: completed-tick observation, with no
  Node dependencies, random numbers or writes to simulation.
- `voice_environment.gd`: read-only 10 Hz survey of the authoritative heightfield
  and existing obstacle index; swept travel, <=24 height samples and <=128
  obstacle candidates per update. Current terrain look-ahead uses nine samples.
- `skier_voice.gd`: private presentation RNG, weighted pools, compatible
  request/preview/cue_started mappings, scheduling and two players.
- Main: completed-tick delivery, lifecycle, hip telemetry and verified results.

`art_source/audio/voice/male_1_v1/` contains the full script, credit ledger,
original MP3 downloads with generation IDs and SHA-256 hashes, explicit cuts and
review overrides, WAV masters and the generated manifest. `.gdignore` excludes
source masters from Godot import. The old `elevenlabs_v1` bank remains intact.

The offline pipeline uses cached local faster-whisper word timestamps plus
silence boundaries, explicit reviewed overrides, padded trimming and 5/15 ms
edge fades. Gain targets remain speech -21 dBFS RMS / -6 dBFS peak, breaths
-27 / -10, taking the more conservative gain. PCM16 WAV masters are mono 48 kHz;
Vorbis q6 derivatives have explicit preloads for export. Unchanged derivatives
retain their bytes to avoid needless imports. No paid API calls occur in these
preparation/audit scripts.

```powershell
.tools/voice-analysis/Scripts/python.exe scripts/art/prepare_voice_audio.py --male-1 --analyze --propose --build
.tools/voice-analysis/Scripts/python.exe scripts/art/audit_voice_audio.py
.tools/voice-analysis/Scripts/python.exe scripts/art/voice_delivery_report.py
./godotw.ps1 --headless --editor --import --quit
```

## Verification — 2026-09-08

Audio provenance audit passes for all 170 retained clips: original generation
mapping, voice ID, all source/master/runtime hashes, 48 kHz mono PCM format and
zero clipped decoded samples. Evidence, the full 247-second audition reel and
its timestamp/caption index are in `artifacts/voice/male_1_v1/`.

Automated voice tests cover thresholds, episode suppression, priorities,
context, weighted pools, cooldowns and lifecycle. Synthetic environment tests
cover passes, collisions, vertical separation, cliffs versus continuous slopes,
corridor transitions, boundaries, teleport and query limits. Native integration
uses disposable record storage; its settings/audition fixture is a laboratory,
while performance measurements explicitly use the current v12 mountain fixture.

| Automated verification | Result |
| --- | --- |
| Voice suite | 209 checks passed |
| Voice upgrade / synthetic environment | 93 checks passed, including recursive equality of every script-owned model-17 state field for 1,200 ticks with voice enabled/disabled |
| Physics | 56 checks passed |
| Runtime | 126 checks passed; stale laboratory identity assertion updated to model 17 |
| Interface | 106 checks passed |
| Headless Main/lifecycle integration | 14 checks passed |
| Native voice integration | 16 checks passed |

Native settings captures at 1280x720 and 3840x2160 were inspected. Volume,
switches, audition selection, complete Play/Stop buttons and help fit in the
panel. Native audio captured riding/result auditions, the automatic crash
follow-up scheduler using settled-hip telemetry, and global mute: 36.437 seconds,
48 kHz stereo, -14.26 dBFS peak, -32.23 dBFS RMS, zero clipped samples and zero
nonzero samples in the final quarter-second after mute. Main's real tick/crash/
save hooks are tested separately in the same fixture. This does not establish
subjective emotion, breathing quality, ragdoll settling or the skiing mix.

## Coordinated v12 performance measurement

The other skiing task paused heavy tests and main/core/presentation/terrain
edits for the paired run. Both completed the same 61.125-second section on
seed 849205174, v12, face 0, z1900–2450, clear weather. Actual output was
3840x2160, High, FSR2 75% (2880x1620 internally), 120 FPS cap, terrain GI off,
Ryzen 5 5600X / RX 9070. Audio device playback was disabled for this observer
measurement; DSP output was checked in native audition instead.

| Measurement | Observer off | Observer on |
| --- | ---: | ---: |
| Frame mean / p95 / p99, ms | 8.383 / 9.594 / 10.174 | 8.401 / 9.517 / 9.925 |
| Average FPS | 119.29 | 119.04 |
| Render CPU p95 / p99, ms | 1.544 / 1.932 | 1.364 / 1.806 |
| Render GPU p95 / p99, ms | 6.455 / 7.642 | 6.957 / 8.455 |
| Physics step p95 / p99, us | 742 / 913 | 700 / 820 |
| Peak engine working set, GiB | 1.294 | 1.322 |
| Peak private bytes, GiB | 6.134 | 6.143 |
| Engine video memory, GiB | 4.638 | 4.638 |
| Minimum free system RAM, MiB | 208 | 316 |

Voice observation cost **21 / 71 / 109 microseconds mean/p95/p99 per ski tick**.
Its 611 environment updates cost **66 / 115 / 185 microseconds** at 10 Hz;
the observed maxima were nine height samples and 62 obstacle candidates, with
no truncated queries. The synthetic suite separately exercises the 128 limit.

Both runs had identical terrain/obstacle hashes, section duration and peak
speed; no other Godot engines or WoW were sampled. Main, core, presentation,
terrain and the benchmark source hashes matched. Only unrelated test files
changed while the off run was active. Source snapshots and process samples are
retained in each run's `system.json` under
`artifacts/pc_environment/voice_male1_v12_off` and `voice_male1_v12_on`.

This pair measures an early stable model-17 build; subsequent skiing work may
change performance. It shows a small observer CPU cost, not a causal GPU
improvement or a guaranteed 90 FPS minimum. Maximum frames were 47.5/75.5 ms,
and available system RAM was low; other desktop applications remained open.
The earlier overlapping `voice_male1_observer_off` run is discarded. Combined
results are in `artifacts/voice/male_1_v1/performance_comparison.json`.

Automated audio/state acceptance, rendered settings acceptance and measured
section performance are complete. **User listening and skiing acceptance remain
pending**, especially the 32 nonverbal clips and the seven withheld cuts.
